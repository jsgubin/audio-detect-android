import Foundation
import CoreBluetooth

/// 指环 BLE 协议配置 — 与 Android ringapp 共用同一套 UUID
///
/// 指环已有固件，BLE 协议固定。修改此处的 UUID 即可适配不同指环固件。
struct RingBLEConfig {
    /// 指环 BLE Service UUID
    let serviceUUID: CBUUID
    /// 震动指令 Characteristic UUID（App 写入此特征值发送震动指令）
    let vibrationCharUUID: CBUUID
    /// 通知 Characteristic UUID（指环向 App 回传状态，可为 nil）
    let notifyCharUUID: CBUUID?
    /// 扫描时按设备名过滤的前缀
    let scanNamePrefixes: [String]

    static let `default` = RingBLEConfig(
        serviceUUID: CBUUID(string: "0000ffe0-0000-1000-8000-00805f9b34fb"),
        vibrationCharUUID: CBUUID(string: "0000ffe1-0000-1000-8000-00805f9b34fb"),
        notifyCharUUID: nil,
        scanNamePrefixes: ["Ring", "SmartRing", "指环", "VibrationRing", "BLE_RING"]
    )
}
