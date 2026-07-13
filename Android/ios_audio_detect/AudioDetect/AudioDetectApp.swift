//
//  AudioDetectApp.swift
//  AudioDetect
//
//  App 入口
//

import SwiftUI
import UserNotifications

@main
struct AudioDetectApp: App {
    
    init() {
        // 注册通知代理
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// 通知代理（用于处理前台通知）
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
