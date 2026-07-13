//
//  NotificationManager.swift
//  AudioDetect
//
//  本地通知管理器
//  当检测到声音时，发送通知到 iPhone 通知中心
//  智能指环通过 ANCS (Apple Notification Center Service) 协议
//  自动接收通知并震动
//

import Foundation
import UserNotifications
import UIKit

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Authorization
    
    /// 请求通知权限
    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("通知权限请求失败: \(error.localizedDescription)")
            } else if granted {
                print("✅ 通知权限已获取")
            } else {
                print("⚠️ 用户拒绝了通知权限，指环将无法震动提醒")
            }
        }
    }
    
    // MARK: - Send Notification
    
    /// 发送声音检测通知
    func sendDetectionNotification(result: ClassificationResult) {
        let center = UNUserNotificationCenter.current()
        
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = "\(result.icon) 检测到 \(result.displayName)"
        content.body = "置信度: \(Int(result.confidence * 100))%"
        content.sound = .default
        content.badge = 1
        
        // 设置通知的 category（便于指环 App 识别）
        content.categoryIdentifier = "SOUND_DETECTION"
        
        // 添加自定义数据
        content.userInfo = [
            "sound_type": result.identifier,
            "confidence": result.confidence,
            "timestamp": result.timestamp.timeIntervalSince1970
        ]
        
        // 立即触发（不需要延迟）
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // nil 表示立即触发
        )
        
        center.add(request) { error in
            if let error = error {
                print("发送通知失败: \(error.localizedDescription)")
            } else {
                print("📢 已发送通知: \(result.displayName)")
            }
        }
        
        // 同时触发手机震动（触觉反馈）
        triggerHapticFeedback()
    }
    
    // MARK: - Haptic Feedback
    
    /// 触发手机震动反馈
    private func triggerHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// 前台也显示通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 允许在前台显示横幅和播放声音
        completionHandler([.banner, .sound, .badge])
    }
    
    /// 用户点击通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // 清除 badge
        UNUserNotificationCenter.current().setBadgeCount(0)
        completionHandler()
    }
}
