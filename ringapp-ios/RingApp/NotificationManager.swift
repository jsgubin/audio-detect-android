import Foundation
import UserNotifications
import UIKit

/// 本地通知管理器
///
/// 接收来自 Shortcuts AppIntent 的声音识别结果，
/// 发送本地通知到 iPhone 通知中心。
///
/// 智能指环通过 ANCS (Apple Notification Center Service) 协议
/// 自动获取通知并根据 userInfo 中的 sound_type / vibration_pattern / priority 震动。
///
/// 不需要直接调用 SoundAnalysis 框架 —
/// 声音识别由 iOS 系统的「辅助功能 → 声音识别」完成，
/// Shortcuts 自动化触发我们的 AppIntent，然后调用此管理器发送通知。
class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Authorization

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error = error {
                print("❌ 通知权限请求失败: \(error.localizedDescription)")
            } else {
                print(granted ? "✅ 通知权限已获取" : "⚠️ 通知权限被拒绝")
            }
        }
    }

    // MARK: - Send Alert (from AppIntent)

    /// 由 Shortcuts AppIntent 调用
    func sendSoundAlert(
        category: SoundCategory,
        intensity: VibrationIntensity,
        repeatCount: Int
    ) {
        let content = UNMutableNotificationContent()

        // 标题
        content.title = "\(category.emoji) \(category.displayName)"

        // 正文（根据强度和重复次数）
        let intensityText: String
        switch intensity {
        case .light:  intensityText = "轻微"
        case .medium: intensityText = "中等"
        case .strong: intensityText = "强烈"
        case .sos:    intensityText = "SOS 紧急"
        }
        content.body = repeatCount > 1
            ? "\(intensityText)震动提醒，重复 \(repeatCount) 次"
            : "检测到声音，\(intensityText)震动提醒"

        // 声音
        content.sound = .default

        // Category：供指环 App 识别
        content.categoryIdentifier = "SOUND_ALERT_\(intensity.rawValue.uppercased())"

        // 附加数据：指环固件通过 ANCS 读取
        content.userInfo = [
            "sound_type": category.rawValue,
            "vibration_pattern": category.vibrationPattern,
            "priority": category.priority,
            "intensity": intensity.rawValue,
            "repeat_count": repeatCount,
            "timestamp": Date().timeIntervalSince1970
        ]

        // 立即发送
        let request = UNNotificationRequest(
            identifier: "sound-alert-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 发送通知失败: \(error.localizedDescription)")
            } else {
                print("📢 已发送 \(category.emoji) \(category.displayName) 警报 → 指环震动")
            }
        }

        // 同时触发手机震动（双重保险）
        triggerHaptic(intensity: intensity)
    }

    // MARK: - Haptic

    private func triggerHaptic(intensity: VibrationIntensity) {
        let style: UINotificationFeedbackGenerator.FeedbackType
        switch intensity {
        case .light:  style = .success
        case .medium: style = .warning
        case .strong, .sos: style = .error
        }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(style)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        UNUserNotificationCenter.current().setBadgeCount(0)
        completionHandler()
    }
}
