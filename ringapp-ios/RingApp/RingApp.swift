import SwiftUI

/// 声感指环 iOS 版
///
/// 不自己跑声音识别模型。声音识别由 iOS 系统的「设置 → 辅助功能 → 声音识别」完成。
/// 用户在 Shortcuts（快捷指令）中创建自动化：
///   「当声音识别检测到 X → 运行 发送声音警报」
/// 然后本 App 的 AppIntent 被触发，发送本地通知 → ANCS → 指环震动。
@main
struct RingApp: App {

    init() {
        // 请求通知权限（指环通过 ANCS 接收通知）
        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
