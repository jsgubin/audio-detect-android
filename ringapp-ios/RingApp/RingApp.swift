import SwiftUI

/// 声感指环 iOS 版
///
/// 不自己跑声音识别。利用 iOS 系统「辅助功能 → 声音识别」+ Shortcuts 自动化。
/// 指环通信：CoreBluetooth 直连 BLE GATT（不用 ANCS）。
///
/// 设备要求：iOS 16+
@main
struct RingApp: App {

    @StateObject private var bleManager = RingBLEManager.shared

    init() {
        // 前置请求通知权限（用于系统声音识别后的提示）
        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bleManager)
        }
    }
}
