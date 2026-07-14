package com.ringapp

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.text.method.ScrollingMovementMethod
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {

    // ── UI 组件 ──────────────────────────────────────────

    private lateinit var tvNotificationStatus: TextView
    private lateinit var btnNotificationSettings: Button
    private lateinit var tvAndroidVersionWarning: TextView
    private lateinit var tvBleStatus: TextView
    private lateinit var btnBleScan: Button
    private lateinit var btnBleDisconnect: Button
    private lateinit var tvBleDeviceList: TextView
    private lateinit var layoutBleDevices: LinearLayout
    private lateinit var tvLog: TextView
    private lateinit var btnTestVibration: Button
    private lateinit var tvServiceStatus: TextView

    // ── 状态 ──────────────────────────────────────────────

    private var bleManager: RingBLEManager? = null
    private var foundDevices = mutableMapOf<String, RingBLEManager.DeviceInfo>()
    private var isScanning = false
    private val logBuffer = StringBuilder()
    private val logLines = mutableListOf<String>()

    // ── 生命周期 ──────────────────────────────────────────

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        bindViews()
        setupClickListeners()

        // 检查权限和服务状态
        checkNotificationListenerStatus()
        checkAndroidVersion()
        checkBluetoothPermissions()

        // 尝试关联已有的 BLE 管理器（如果前台服务已在运行）
        bleManager = RingForegroundService.bleManager
        if (bleManager != null) {
            observeBLEState()
        }
    }

    override fun onResume() {
        super.onResume()
        checkNotificationListenerStatus()
        updateBLEStatus()
    }

    override fun onDestroy() {
        super.onDestroy()
        bleManager?.onDeviceFound = null
        bleManager?.onStateChanged = null
        bleManager?.onLog = null
    }

    // ── 初始化 ────────────────────────────────────────────

    private fun bindViews() {
        tvNotificationStatus = findViewById(R.id.tv_notification_status)
        btnNotificationSettings = findViewById(R.id.btn_notification_settings)
        tvAndroidVersionWarning = findViewById(R.id.tv_android_version_warning)
        tvBleStatus = findViewById(R.id.tv_ble_status)
        btnBleScan = findViewById(R.id.btn_ble_scan)
        btnBleDisconnect = findViewById(R.id.btn_ble_disconnect)
        tvBleDeviceList = findViewById(R.id.tv_ble_device_list)
        layoutBleDevices = findViewById(R.id.layout_ble_devices)
        tvLog = findViewById(R.id.tv_log)
        btnTestVibration = findViewById(R.id.btn_test_vibration)
        tvServiceStatus = findViewById(R.id.tv_service_status)
        tvLog.movementMethod = ScrollingMovementMethod()
    }

    private fun setupClickListeners() {
        btnNotificationSettings.setOnClickListener { openNotificationSettings() }
        btnBleScan.setOnClickListener { toggleScan() }
        btnBleDisconnect.setOnClickListener { disconnectRing() }
        btnTestVibration.setOnClickListener { testVibration() }
    }

    // ── 权限检查 ──────────────────────────────────────────

    /** 检查 Android 版本：系统声音通知需要 Android 14+ */
    private fun checkAndroidVersion() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            tvAndroidVersionWarning.visibility = View.VISIBLE
            tvAndroidVersionWarning.text = getString(R.string.android14_warning)
        } else {
            tvAndroidVersionWarning.visibility = View.GONE
        }
    }

    /**
     * 检查通知监听权限状态
     * NotificationListenerService 必须由用户手动在系统设置中授权，
     * App 无法通过代码静默开启（Android 安全机制）
     */
    private fun checkNotificationListenerStatus() {
        val enabledListeners = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        )
        val isGranted = enabledListeners?.contains(packageName) == true

        if (isGranted) {
            tvNotificationStatus.text = "✅ ${getString(R.string.notification_granted)}"
            tvNotificationStatus.setTextColor(ContextCompat.getColor(this, R.color.green))
            btnNotificationSettings.text = "已开启"
            btnNotificationSettings.isEnabled = false
        } else {
            tvNotificationStatus.text = "⚠️ ${getString(R.string.not_listening_warning)}"
            tvNotificationStatus.setTextColor(ContextCompat.getColor(this, R.color.orange))
            btnNotificationSettings.text = getString(R.string.open_settings)
            btnNotificationSettings.isEnabled = true
        }
    }

    /** 检查蓝牙权限 */
    private fun checkBluetoothPermissions() {
        val permissions = mutableListOf<String>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN)
                != PackageManager.PERMISSION_GRANTED
            ) permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT)
                != PackageManager.PERMISSION_GRANTED
            ) permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
                != PackageManager.PERMISSION_GRANTED
            ) permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }

        // Android 13+ 通知权限
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        if (permissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissions.toTypedArray(), 100)
        }
    }

    // ── BLE 操作 ──────────────────────────────────────────

    private fun initBLEManager() {
        if (bleManager == null) {
            bleManager = RingBLEManager(this)
            observeBLEState()
        }
    }

    private fun observeBLEState() {
        bleManager?.apply {
            onStateChanged = { state -> runOnUiThread { onBLEStateChanged(state) } }
            onDeviceFound = { device -> runOnUiThread { onDeviceFound(device) } }
            onLog = { message -> runOnUiThread { appendLog(message) } }
            onVibrationSent = { category, success ->
                runOnUiThread {
                    val status = if (success) "✅" else "❌"
                    appendLog("$status 震动: ${category.emoji} ${category.displayName}")
                }
            }
        }
    }

    private fun onBLEStateChanged(state: RingBLEManager.State) {
        updateBLEStatus()

        // 停止前台服务中的扫描超时更新
        when (state) {
            RingBLEManager.State.SCANNING -> {
                isScanning = true
                btnBleScan.text = getString(R.string.ble_scan_stop)
                tvBleDeviceList.text = getString(R.string.ble_scanning)
                foundDevices.clear()
                updateDeviceListUI()
            }
            RingBLEManager.State.IDLE -> {
                isScanning = false
                btnBleScan.text = getString(R.string.ble_scan_start)
                if (foundDevices.isEmpty()) {
                    tvBleDeviceList.text = getString(R.string.ble_not_found)
                }
            }
            RingBLEManager.State.CONNECTING -> {
                btnBleDisconnect.isEnabled = true
            }
            RingBLEManager.State.CONNECTED -> {
                isScanning = false
                btnBleScan.text = getString(R.string.ble_scan_start)
                btnBleDisconnect.isEnabled = true
                btnTestVibration.isEnabled = true
                // 确保前台服务运行
                startRingForegroundService()
                // 同时注册声音监听回调
                SoundNotificationService.onSoundDetected = { result ->
                    runOnUiThread {
                        appendLog("🔊 ${result.category.emoji} ${result.category.displayName} -> 发送震动")
                    }
                    bleManager?.sendVibration(result.category)
                }
            }
            RingBLEManager.State.DISCONNECTED -> {
                btnBleDisconnect.isEnabled = false
                btnTestVibration.isEnabled = false
                isScanning = false
                btnBleScan.text = getString(R.string.ble_scan_start)
            }
        }
    }

    private fun onDeviceFound(device: RingBLEManager.DeviceInfo) {
        foundDevices[device.address] = device
        updateDeviceListUI()

        // 如果之前连接过这个地址，自动尝试重连
        val savedAddress = getSharedPreferences("ring_prefs", Context.MODE_PRIVATE)
            .getString("ring_address", null)
        if (savedAddress == device.address && bleManager?.state != RingBLEManager.State.CONNECTED) {
            appendLog("发现已配对的指环，自动连接...")
            bleManager?.stopScan()
            bleManager?.connect(device.address)
        }
    }

    private fun updateDeviceListUI() {
        if (foundDevices.isEmpty()) {
            tvBleDeviceList.text = if (isScanning) getString(R.string.ble_scanning)
                                  else getString(R.string.ble_not_found)
        } else {
            tvBleDeviceList.text = foundDevices.values.joinToString("\n") { device ->
                "📱 ${device.name}  [${device.address}]  (${device.rssi} dBm)"
            }
        }

        // 创建可点击的设备按钮
        layoutBleDevices.removeAllViews()
        foundDevices.values.forEach { device ->
            val btn = Button(this).apply {
                text = "${device.name}\n${device.address} (${device.rssi} dBm)"
                textSize = 12f
                setOnClickListener {
                    bleManager?.stopScan()
                    bleManager?.connect(device.address)
                    // 记住地址，下次自动重连
                    getSharedPreferences("ring_prefs", Context.MODE_PRIVATE)
                        .edit().putString("ring_address", device.address).apply()
                    appendLog("手动连接: ${device.name}")
                }
                val params = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    bottomMargin = 4
                    topMargin = 4
                }
                layoutParams = params
            }
            layoutBleDevices.addView(btn)
        }
    }

    private fun toggleScan() {
        initBLEManager()
        if (isScanning) {
            bleManager?.stopScan()
        } else {
            checkBluetoothPermissions()
            val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            if (bluetoothManager?.adapter?.isEnabled != true) {
                Toast.makeText(this, R.string.bluetooth_disabled, Toast.LENGTH_SHORT).show()
                startActivity(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE))
                return
            }
            bleManager?.startScan()
        }
    }

    private fun disconnectRing() {
        bleManager?.disconnect()
        updateBLEStatus()
    }

    private fun updateBLEStatus() {
        val state = bleManager?.state
        tvBleStatus.text = when (state) {
            RingBLEManager.State.CONNECTED -> "🔵 ${getString(R.string.ble_connected)}"
            RingBLEManager.State.CONNECTING -> "🟡 ${getString(R.string.ble_connecting)}"
            RingBLEManager.State.SCANNING -> "🔍 ${getString(R.string.ble_scanning)}"
            RingBLEManager.State.DISCONNECTED -> "⚫ ${getString(R.string.ble_disconnected)}"
            else -> "⚫ ${getString(R.string.ble_disconnected)}"
        }
        tvServiceStatus.text = if (RingForegroundService.isRunning)
            "🟢 ${getString(R.string.service_running)}"
        else "🔴 ${getString(R.string.service_stopped)}"
    }

    private fun testVibration() {
        if (bleManager?.state != RingBLEManager.State.CONNECTED) {
            Toast.makeText(this, R.string.ble_disconnected, Toast.LENGTH_SHORT).show()
            return
        }
        appendLog("🧪 测试震动: 警报声")
        bleManager?.sendVibration(SoundCategory.ALARM)
    }

    // ── 前台服务 ──────────────────────────────────────────

    private fun startRingForegroundService() {
        val intent = Intent(this, RingForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    // ── 通知监听设置 ──────────────────────────────────────

    /** 跳转到系统通知监听设置页面 */
    private fun openNotificationSettings() {
        try {
            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            startActivity(intent)
        } catch (e: Exception) {
            // 部分厂商 ROM 路径不同，尝试直接打开无障碍设置
            try {
                val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                startActivity(intent)
            } catch (e2: Exception) {
                Toast.makeText(this, "请手动前往：设置 → 无障碍 → 已安装的服务 → 声感指环", Toast.LENGTH_LONG).show()
            }
        }
    }

    // ── 日志 ──────────────────────────────────────────────

    private fun appendLog(message: String) {
        logLines.add(message)
        if (logLines.size > 200) logLines.removeAt(0)
        tvLog.text = logLines.joinToString("\n")
    }

    // ── 权限回调 ──────────────────────────────────────────

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 100) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            if (!allGranted) {
                Toast.makeText(this, "蓝牙权限是连接指环所必需的", Toast.LENGTH_LONG).show()
            }
        }
    }
}
