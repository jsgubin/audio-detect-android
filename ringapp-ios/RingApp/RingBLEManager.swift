import Foundation
import CoreBluetooth

/// 指环 BLE 管理器 — CoreBluetooth 直连指环
///
/// 不依赖 ANCS。直接通过 BLE GATT 写入震动指令到指环的 Characteristic。
/// 与 Android 版的 RingBLEManager 使用相同的 BLE 协议和 UUID。
///
/// 用法：
/// ```
///   let manager = RingBLEManager.shared
///   manager.startScan()
///   // 用户选择设备后:
///   manager.connect(peripheral)
///   // 发送震动:
///   manager.sendVibration(category: .doorbell)
/// ```
@MainActor
class RingBLEManager: NSObject, ObservableObject {

    static let shared = RingBLEManager()

    // MARK: - Published State

    @Published var state: BLEState = .idle
    @Published var discoveredDevices: [BLEDevice] = []
    @Published var logMessages: [String] = []

    enum BLEState: String {
        case idle         = "未连接"
        case scanning     = "正在扫描..."
        case connecting   = "正在连接..."
        case connected    = "已连接"
        case disconnected = "已断开"
    }

    struct BLEDevice: Identifiable {
        let id: UUID
        let name: String
        let peripheral: CBPeripheral
        var rssi: Int
    }

    // MARK: - Config

    var config: RingBLEConfig = .default
    var onVibrationSent: ((SoundCategory, Bool) -> Void)?

    // MARK: - Private

    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var vibrationCharacteristic: CBCharacteristic?
    private var pendingCategory: SoundCategory?

    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Scan

    func startScan() {
        guard centralManager.state == .poweredOn else {
            log("蓝牙未就绪，请确保蓝牙已开启")
            return
        }
        state = .scanning
        discoveredDevices.removeAll()
        log("开始扫描指环...")
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScan() {
        centralManager.stopScan()
        if state == .scanning { state = .idle }
    }

    // MARK: - Connect / Disconnect

    func connect(_ peripheral: CBPeripheral) {
        stopScan()
        targetPeripheral = peripheral
        state = .connecting
        log("正在连接 \(peripheral.name ?? "指环")...")
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        guard let peripheral = targetPeripheral else { return }
        log("断开连接")
        centralManager.cancelPeripheralConnection(peripheral)
        targetPeripheral = nil
        vibrationCharacteristic = nil
        state = .disconnected
    }

    // MARK: - Send Vibration

    /// 发送震动指令到指环
    /// 数据格式（与 Android 版一致）：
    ///   [版本, 命令类型, 震动模式, 强度, 重复次数, 校验和]
    func sendVibration(category: SoundCategory) {
        guard let peripheral = targetPeripheral,
              let char = vibrationCharacteristic,
              peripheral.state == .connected else {
            log("⚠️ 指环未连接，无法发送震动")
            onVibrationSent?(category, false)
            return
        }

        pendingCategory = category
        let command = buildVibrationCommand(category: category)
        let hex = command.map { String(format: "%02X", $0) }.joined(separator: " ")
        log("发送震动: \(category.emoji) \(category.displayName)")
        log("指令: \(hex)")

        peripheral.writeValue(Data(command), for: char, type: .withResponse)
    }

    private func buildVibrationCommand(category: SoundCategory) -> [UInt8] {
        let repeatCount = UInt8(min(category.priority > 1 ? category.priority * 2 : 1, 255))
        let intensity = UInt8(min(category.priority, 3))

        let payload: [UInt8] = [
            0x01,                          // 协议版本
            0x01,                          // 命令类型：震动
            UInt8(category.vibrationPattern), // 震动模式
            intensity,                     // 强度
            repeatCount                    // 重复次数
        ]
        let checksum = payload.reduce(0) { $0 ^ $1 }
        return payload + [checksum]
    }

    // MARK: - Log

    private func log(_ message: String) {
        print("[BLE] \(message)")
        logMessages.append(message)
        if logMessages.count > 200 { logMessages.removeFirst() }
    }
}

// MARK: - CBCentralManagerDelegate

extension RingBLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            log("蓝牙已就绪")
        case .poweredOff:
            log("蓝牙已关闭")
            state = .idle
        case .unsupported:
            log("设备不支持 BLE")
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "Unknown"
        let rssi = RSSI.intValue

        // 按名称前缀过滤
        let matches = config.scanNamePrefixes.contains { prefix in
            name.lowercased().contains(prefix.lowercased())
        }

        guard matches else { return }

        // 去重更新
        if let existing = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            discoveredDevices[existing].rssi = rssi
        } else {
            let device = BLEDevice(id: peripheral.identifier, name: name, peripheral: peripheral, rssi: rssi)
            discoveredDevices.append(device)
            log("发现指环: \(name) (\(rssi) dBm)")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log("✅ 已连接，发现服务...")
        peripheral.delegate = self
        peripheral.discoverServices([config.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log("❌ 连接失败: \(error?.localizedDescription ?? "unknown")")
        state = .disconnected
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log("🔌 已断开: \(error?.localizedDescription ?? "主动断开")")
        vibrationCharacteristic = nil
        state = .disconnected
    }
}

// MARK: - CBPeripheralDelegate

extension RingBLEManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == config.serviceUUID }) else {
            log("未找到振动服务: \(config.serviceUUID)")
            return
        }
        log("找到振动服务")
        peripheral.discoverCharacteristics(
            [config.vibrationCharUUID] + (config.notifyCharUUID.map { [$0] } ?? []),
            for: service
        )
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let chars = service.characteristics else { return }

        for char in chars {
            if char.uuid == config.vibrationCharUUID {
                vibrationCharacteristic = char
                log("找到震动特征值")
            }
            if char.uuid == config.notifyCharUUID {
                peripheral.setNotifyValue(true, for: char)
            }
        }

        if vibrationCharacteristic != nil {
            state = .connected
            log("✅ 指环就绪")
        } else {
            log("未找到震动特征值: \(config.vibrationCharUUID)")
            state = .disconnected
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        let success = error == nil
        log("震动指令写入: \(success ? "成功" : "失败")")
        if let category = pendingCategory {
            onVibrationSent?(category, success)
            pendingCategory = nil
        }
    }
}
