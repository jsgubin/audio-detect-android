//
//  AudioDetectLightApp.swift
//  AudioDetectLight
//
//  App 入口
//  轻量级版本：不录音、不做 AI，只做通知中转
//

import SwiftUI
import UserNotifications

@main
struct AudioDetectLightApp: App {
    
    init() {
        // 初始化通知管理器（请求权限）
        _ = NotificationManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
