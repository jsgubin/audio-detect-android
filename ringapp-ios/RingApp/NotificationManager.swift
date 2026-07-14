import Foundation
import UserNotifications
import UIKit

/// 本地通知管理器
///
/// 当检测到声音时，发送本地通知到 iPhone 通知中心。
/// 智能指环通过 ANCS (Apple Notification Center Service) 协议
/// 自动接收通知并根据 sound_type 和 priority 触发相应震动。
///
/// 注意：指环端需要支持 ANCS 协议才能工作。
/// 如果指环不支持 ANCS，需改为 CoreBluetooth 直连方式。
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

    // MARK: - Send Notification

    /// 发送声音检测通知
    /// - Parameters:
    ///   - category: 检测到的声音类别
    ///   - confidence: 置信度 (0.0 ~ 1.0)
    func sendDetectionNotification(category: SoundCategory, confidence: Float) {
        let content = UNMutableNotificationContent()

        // 标题：类别图标 + 名称
        content.title = "\(category.emoji) 检测到 \(category.displayName)"

        // 正文：置信度
        content.body = "置信度: \(Int(confidence * 100))%"

        // 声音
        content.sound = .default

        // categoryIdentifier：供指环 App 识别通知类型
        content.categoryIdentifier = "SOUND_DETECTION"

        // 附加数据：指环固件可通过 ANCS 读取这些字段来决定震动模式
        content.userInfo = [
            "sound_type": category.rawValue,
            "vibration_pattern": category.vibrationPattern,
            "priority": category.priority,
            "confidence": confidence,
            "timestamp": Date().timeIntervalSince1970
        ]

        // 立即触发
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 发送通知失败: \(error.localizedDescription)")
            } else {
                print("📢 已发送通知: \(category.displayName) → 指环震动")
            }
        }

        // 同时触发手机震动（双重保险）
        triggerHapticFeedback(category: category)
    }

    // MARK: - Haptic Feedback

    private func triggerHapticFeedback(category: SoundCategory) {
        let type: UINotificationFeedbackGenerator.FeedbackType
        switch category.priority {
        case 3: type = .error
        case 2: type = .warning
        default: type = .success
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// 前台也显示通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// 用户点击通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        UNUserNotificationCenter.current().setBadgeCount(0)
        completionHandler()
    }
}
