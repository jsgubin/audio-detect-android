package com.ringapp

import android.bluetooth.*
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import kotlinx.coroutines.*
import java.util.UUID

/**
 * 指环 BLE 管理器
 *
 * 负责扫描、连接、通信指环设备。
 * BLE 协议可配置 — UUID 和震动指令格式通过 [RingBLEConfig] 指定。
 *
 * 用法：
 * ```
 *   val manager = RingBLEManager(context, RingBLEConfig.DEFAULT)
 *   manager.onStateChanged = { state -> ... }
 *   manager.startScan()
 *   // 用户选择设备后:
 *   manager.connect("00:11:22:33:44:55")
 *   // 发送震动:
 *   manager.sendVibration(SoundCategory.ALARM)
 * ```
 */
class RingBLEManager(
    private val context: Context,
    val config: RingBLEConfig = RingBLEConfig.DEFAULT
) {
    companion object {
        private const val TAG = "RingBLEManager"
        private const val SCAN_TIMEOUT_MS = 15_000L
        private const val RECONNECT_DELAY_MS = 3_000L
        private const val MAX_RECONNECT_ATTEMPTS = 5
    }

    // ── 状态 ──────────────────────────────────────────

    enum class State {
        IDLE, SCANNING, CONNECTING, CONNECTED, DISCONNECTED
    }

    data class DeviceInfo(
        val name: String,
        val address: String,
        val rssi: Int
    )

    var state: State = State.IDLE
        private set(value) {
            field = value
            handler.post { onStateChanged?.invoke(value) }
        }

    var onStateChanged: ((State) -> Unit)? = null
    var onDeviceFound: ((DeviceInfo) -> Unit)? = null
    var onVibrationSent: ((SoundCategory, Boolean) -> Unit)? = null
    var onLog: ((String) -> Unit)? = null

    // ── BLE 核心组件 ──────────────────────────────────

    private val handler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var bluetoothAdapter: BluetoothAdapter? =
        (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    private var bluetoothGatt: BluetoothGatt? = null
    private var targetDevice: BluetoothDevice? = null
    private var targetAddress: String? = null
    private var reconnectAttempts = 0
    private var isUserDisconnect = false

    // ── 扫描 ──────────────────────────────────────────

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device
            val name = device.name ?: "Unknown"
            val rssi = result.rssi

            // 根据设备名过滤
            for (prefix in config.scanNamePrefixes) {
                if (name.contains(prefix, ignoreCase = true)) {
                    log("发现指环: $name ($rssi dBm) [${device.address}]")
                    handler.post {
                        onDeviceFound?.invoke(DeviceInfo(name, device.address, rssi))
                    }
                    return
                }
            }
            // 也根据 Service UUID 过滤（如果设备广播了 Service）
            result.scanRecord?.serviceUuids?.forEach { uuid ->
                if (uuid.uuid == config.serviceUuid) {
                    log("发现指环 (UUID 匹配): $name [${device.address}]")
                    handler.post {
                        onDeviceFound?.invoke(DeviceInfo(name, device.address, rssi))
                    }
                    return
                }
            }
        }

        override fun onScanFailed(errorCode: Int) {
            log("扫描失败: errorCode=$errorCode")
            handler.post { stopScan() }
        }
    }

    fun startScan() {
        val adapter = bluetoothAdapter ?: run {
            log("蓝牙不可用")
            return
        }
        if (!adapter.isEnabled) {
            log("蓝牙未开启")
            return
        }
        if (state == State.SCANNING) return

        state = State.SCANNING
        log("开始扫描指环...")

        val scanner = adapter.bluetoothLeScanner ?: run {
            log("BLE 扫描器不可用")
            state = State.IDLE
            return
        }

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        val filters = if (config.scanServiceUuid != null) {
            listOf(ScanFilter.Builder()
                .setServiceUuid(ParcelUuid(config.scanServiceUuid))
                .build())
        } else null

        try {
            scanner.startScan(filters, settings, scanCallback)
        } catch (e: SecurityException) {
            log("缺少蓝牙权限: ${e.message}")
            state = State.IDLE
            return
        }

        // 扫描超时
        handler.postDelayed({ stopScan() }, SCAN_TIMEOUT_MS)
    }

    fun stopScan() {
        try {
            bluetoothAdapter?.bluetoothLeScanner?.stopScan(scanCallback)
        } catch (_: Exception) {}
        if (state == State.SCANNING) state = State.IDLE
    }

    // ── 连接 ──────────────────────────────────────────

    fun connect(address: String) {
        stopScan()
        targetAddress = address
        isUserDisconnect = false
        reconnectAttempts = 0

        val adapter = bluetoothAdapter ?: return
        val device = adapter.getRemoteDevice(address)
        targetDevice = device

        state = State.CONNECTING
        log("正在连接指环: $address")

        try {
            bluetoothGatt?.close()
            bluetoothGatt = device.connectGatt(context, false, gattCallback)
        } catch (e: SecurityException) {
            log("BLE 连接被拒绝: ${e.message}")
            state = State.DISCONNECTED
        }
    }

    fun disconnect() {
        isUserDisconnect = true
        reconnectAttempts = MAX_RECONNECT_ATTEMPTS // 阻止重连
        log("断开指环连接（用户操作）")
        bluetoothGatt?.disconnect()
        bluetoothGatt?.close()
        bluetoothGatt = null
        state = State.DISCONNECTED
    }

    private fun autoReconnect() {
        if (isUserDisconnect) return
        if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            log("重连已达最大次数 ($MAX_RECONNECT_ATTEMPTS)，停止重连")
            state = State.DISCONNECTED
            return
        }
        reconnectAttempts++
        log("尝试重连 (${reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS})...")
        handler.postDelayed({
            targetAddress?.let { connect(it) }
        }, RECONNECT_DELAY_MS)
    }

    // ── GATT 回调 ──────────────────────────────────────────

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    log("GATT 连接成功，发现服务...")
                    handler.post {
                        gatt.discoverServices()
                    }
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    log("GATT 断开: status=$status")
                    handler.post {
                        bluetoothGatt?.close()
                        bluetoothGatt = null
                        state = State.DISCONNECTED
                        if (!isUserDisconnect) autoReconnect()
                    }
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                log("服务发现失败: status=$status")
                return
            }

            val service = gatt.getService(config.serviceUuid)
            if (service == null) {
                log("未找到振动服务 UUID: ${config.serviceUuid}")
                log("可用服务: ${gatt.services.joinToString { it.uuid.toString() }}")
                return
            }
            log("找到振动服务: ${service.uuid}")

            val characteristic = service.getCharacteristic(config.vibrationCharUuid)
            if (characteristic == null) {
                log("未找到振动特征值 UUID: ${config.vibrationCharUuid}")
                return
            }
            log("找到振动特征值: ${characteristic.uuid}")

            // 如果需要启用通知
            if (config.notifyCharUuid != null) {
                val notifyChar = service.getCharacteristic(config.notifyCharUuid)
                if (notifyChar != null) {
                    gatt.setCharacteristicNotification(notifyChar, true)
                }
            }

            handler.post {
                state = State.CONNECTED
                reconnectAttempts = 0
                log("✅ 指环就绪，可以接收震动指令")
            }
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            val success = status == BluetoothGatt.GATT_SUCCESS
            log("震动指令写入: ${if (success) "成功" else "失败 (status=$status)"}")
            handler.post {
                onVibrationSent?.invoke(pendingCategory, success)
                pendingCategory = SoundCategory.UNKNOWN
            }
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            val data = characteristic.value
            log("指环响应: ${data?.joinToString { "%02X".format(it) } ?: "null"}")
        }
    }

    // ── 震动指令 ──────────────────────────────────────────

    private var pendingCategory: SoundCategory = SoundCategory.UNKNOWN

    /**
     * 发送震动指令到指环
     *
     * 数据格式（可配置，默认 6 字节）：
     *   Byte 0: 协议版本 (0x01)
     *   Byte 1: 命令类型 (0x01 = 震动)
     *   Byte 2: 震动模式 (0x00-0x05, 对应 vibrationPattern)
     *   Byte 3: 强度     (0x00-0x03, 对应 priority)
     *   Byte 4: 重复次数  (0x01-0xFF)
     *   Byte 5: 校验和    (前5字节 XOR)
     */
    fun sendVibration(category: SoundCategory) {
        val gatt = bluetoothGatt ?: run {
            log("⚠️ 指环未连接，无法发送震动")
            onVibrationSent?.invoke(category, false)
            return
        }
        if (state != State.CONNECTED) {
            log("⚠️ 指环未就绪 (state=$state)")
            onVibrationSent?.invoke(category, false)
            return
        }

        val service = gatt.getService(config.serviceUuid)
        val char = service?.getCharacteristic(config.vibrationCharUuid)
        if (char == null) {
            log("⚠️ 未找到震动特征值")
            onVibrationSent?.invoke(category, false)
            return
        }

        pendingCategory = category
        val command = buildVibrationCommand(category)
        log("发送震动: ${category.emoji} ${category.displayName}")
        log("指令: ${command.joinToString(" ") { "%02X".format(it) }}")

        char.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        char.value = command

        try {
            val success = gatt.writeCharacteristic(char)
            if (!success) {
                log("writeCharacteristic 返回 false")
                onVibrationSent?.invoke(category, false)
                pendingCategory = SoundCategory.UNKNOWN
            }
        } catch (e: SecurityException) {
            log("写入失败: ${e.message}")
            onVibrationSent?.invoke(category, false)
            pendingCategory = SoundCategory.UNKNOWN
        }
    }

    /**
     * 构建震动指令字节数组
     */
    private fun buildVibrationCommand(category: SoundCategory): ByteArray {
        val repeatCount = when (category.priority) {
            3 -> 5   // 紧急：重复5次
            2 -> 3   // 警告：重复3次
            1 -> 1   // 普通：1次
            else -> 1
        }
        val intensity = category.priority.coerceIn(0, 3).toByte()

        val payload = byteArrayOf(
            0x01.toByte(),                       // 协议版本
            0x01.toByte(),                       // 命令类型：震动
            category.vibrationPattern.toByte(),  // 震动模式
            intensity,                            // 强度
            repeatCount.toByte()                 // 重复次数
        )
        val checksum = payload.fold(0.toByte()) { acc, b -> (acc.toInt() xor b.toInt()).toByte() }
        return payload + checksum
    }

    // ── 辅助方法 ──────────────────────────────────────────

    private fun log(message: String) {
        Log.i(TAG, message)
        handler.post { onLog?.invoke(message) }
    }

    fun destroy() {
        stopScan()
        isUserDisconnect = true
        scope.cancel()
        bluetoothGatt?.disconnect()
        bluetoothGatt?.close()
        bluetoothGatt = null
        state = State.DISCONNECTED
    }
}
