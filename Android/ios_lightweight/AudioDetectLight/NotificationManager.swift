//
//  NotificationManager.swift
//  AudioDetectLight
//
//  本地通知发送器
//  当快捷指令调用 App Intent 时，发送通知到 iPhone 通知中心
//  智能指环通过 ANCS 协议自动接收通知并震动
//

import Foundation
import UserNotifications
import UIKit

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    
    static let shared = NotificationManager()
    
    // MARK: - Init
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        requestAuthorization()
    }
    
    // MARK: - Authorization
    
    /// 请求通知权限
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error = error {
                print("通知权限请求失败: \(error)")
            } else {
                print(granted ? "✅ 通知权限已获取" : "⚠️ 通知权限被拒绝")
            }
        }
    }
    
    // MARK: - Send Sound Alert
    
    /// 发送声音警报通知（供快捷指令调用）
    func sendSoundAlert(
        soundType: SoundType,
        intensity: VibrationIntensity,
        repeatCount: Int
    ) {
        let content = UNMutableNotificationContent()
        
        // 通知标题：包含声音类别和图标
        content.title = "\(soundType.icon) \(soundType.displayName)"
        
        // 通知内容：根据强度生成不同描述
        content.body = buildBody(intensity: intensity, repeatCount: repeatCount)
        
        // 声音：根据强度设置不同提示音
        content.sound = buildSound(intensity: intensity)
        
        // Category：供指环 App 识别（如果需要过滤）
        content.categoryIdentifier = "SOUND_ALERT_\(intensity.rawValue.uppercased())"
        
        // 用户数据：供后续处理
        content.userInfo = [
            "sound_type": soundType.rawValue,
            "intensity": intensity.rawValue,
            "repeat_count": repeatCount,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // 立即触发（不需要延迟）
        let request = UNNotificationRequest(
            identifier: "sound-alert-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 发送通知失败: \(error)")
            } else {
                print("📢 已发送 \(soundType.displayName) 警报到指环")
            }
        }
        
        // 同时触发手机震动（即使指环没收到，手机也能提醒）
        triggerHaptic(intensity: intensity)
    }
    
    // MARK: - Build Content
    
    private func buildBody(intensity: VibrationIntensity, repeatCount: Int) -> String {
        let intensityText: String
        switch intensity {
        case .light: intensityText = "轻微"
        case .medium: intensityText = "中等"
        case .strong: intensityText = "强烈"
        case .sos: intensityText = "SOS 紧急"
        }
        
        if repeatCount > 1 {
            return "\(intensityText)震动提醒，重复 \(repeatCount) 次"
        } else {
            return "检测到异常声音，\(intensityText)震动提醒"
        }
    }
    
    private func buildSound(intensity: VibrationIntensity) -> UNNotificationSound {
        switch intensity {
        case .light:
            return .default
        case .medium:
            // 使用系统警报声（更强烈）
            return UNNotificationSound(named: UNNotificationSoundName("default"))
        case .strong, .sos:
            // 使用更紧急的提示
            return UNNotificationSound(named: UNNotificationSoundName("default"))
        }
    }
    
    // MARK: - Haptic Feedback
    
    private func triggerHaptic(intensity: VibrationIntensity) {
        let style: UINotificationFeedbackGenerator.FeedbackType
        switch intensity {
        case .light: style = .success
        case .medium: style = .warning
        case .strong, .sos: style = .error
        }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(style)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// 前台也显示通知横幅
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
        // 清除 badge
        UIApplication.shared.applicationIconBadgeNumber = 0
        completionHandler()
    }
}
