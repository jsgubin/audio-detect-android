//
//  SoundAlertIntent.swift
//  AudioDetectLight
//
//  App Intent：供 iOS 快捷指令（Shortcuts）调用
//  接收声音类别，发送本地通知到指环
//
//  iOS 16+ 支持 AppIntent 框架
//

import AppIntents
import UserNotifications

/// 震动强度选项
enum VibrationIntensity: String, AppEnum {
    case light = "light"
    case medium = "medium"
    case strong = "strong"
    case sos = "sos"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "震动强度")
    }
    
    static var caseDisplayRepresentations: [VibrationIntensity: DisplayRepresentation] {
        [
            .light: DisplayRepresentation(stringLiteral: "轻"),
            .medium: DisplayRepresentation(stringLiteral: "中"),
            .strong: DisplayRepresentation(stringLiteral: "强"),
            .sos: DisplayRepresentation(stringLiteral: "SOS 模式")
        ]
    }
}

/// 声音类别选项（与 iOS 系统声音识别对应）
enum SoundType: String, AppEnum {
    case babyCry = "baby_crying"
    case doorKnock = "knocking"
    case doorbell = "doorbell"
    case fireAlarm = "fire_alarm"
    case smokeAlarm = "smoke_detector"
    case glassBreak = "glass_breaking"
    case siren = "siren"
    case shouting = "shouting"
    case waterRunning = "water_running"
    case cat = "cat"
    case dog = "dog"
    case coughing = "coughing"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "声音类别")
    }
    
    static var caseDisplayRepresentations: [SoundType: DisplayRepresentation] {
        [
            .babyCry: DisplayRepresentation(stringLiteral: "👶 婴儿啼哭"),
            .doorKnock: DisplayRepresentation(stringLiteral: "🚪 敲门声"),
            .doorbell: DisplayRepresentation(stringLiteral: "🔔 门铃声"),
            .fireAlarm: DisplayRepresentation(stringLiteral: "🔥 火灾警报"),
            .smokeAlarm: DisplayRepresentation(stringLiteral: "💨 烟雾警报"),
            .glassBreak: DisplayRepresentation(stringLiteral: "💥 玻璃破碎"),
            .siren: DisplayRepresentation(stringLiteral: "🚨 警笛声"),
            .shouting: DisplayRepresentation(stringLiteral: "📢 喊叫声"),
            .waterRunning: DisplayRepresentation(stringLiteral: "💧 流水声"),
            .cat: DisplayRepresentation(stringLiteral: "🐱 猫叫声"),
            .dog: DisplayRepresentation(stringLiteral: "🐶 狗叫声"),
            .coughing: DisplayRepresentation(stringLiteral: "😷 咳嗽声")
        ]
    }
    
    var displayName: String {
        switch self {
        case .babyCry: return "婴儿啼哭"
        case .doorKnock: return "敲门声"
        case .doorbell: return "门铃声"
        case .fireAlarm: return "火灾警报"
        case .smokeAlarm: return "烟雾警报"
        case .glassBreak: return "玻璃破碎"
        case .siren: return "警笛声"
        case .shouting: return "喊叫声"
        case .waterRunning: return "流水声"
        case .cat: return "猫叫声"
        case .dog: return "狗叫声"
        case .coughing: return "咳嗽声"
        }
    }
    
    var icon: String {
        switch self {
        case .babyCry: return "👶"
        case .doorKnock: return "🚪"
        case .doorbell: return "🔔"
        case .fireAlarm: return "🔥"
        case .smokeAlarm: return "💨"
        case .glassBreak: return "💥"
        case .siren: return "🚨"
        case .shouting: return "📢"
        case .waterRunning: return "💧"
        case .cat: return "🐱"
        case .dog: return "🐶"
        case .coughing: return "😷"
        }
    }
}

// MARK: - App Intent

/// 发送声音警报 Intent
/// 在快捷指令中配置：当声音识别触发 → 运行此 Intent → 发送通知到指环
struct SendSoundAlertIntent: AppIntent {
    
    static var title: LocalizedStringResource = "发送声音警报"
    static var description = IntentDescription("将声音识别结果发送给智能指环，触发震动提醒")
    
    @Parameter(title: "声音类别", description: "检测到的声音类型")
    var soundType: SoundType
    
    @Parameter(title: "震动强度", description: "指环震动强度", default: .medium)
    var intensity: VibrationIntensity
    
    @Parameter(title: "重复次数", description: "震动重复次数", default: 1)
    var repeatCount: Int
    
    static var parameterSummary: some ParameterSummary {
        Summary("发送 \($soundType) 警报，强度 \($intensity)")
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // 发送本地通知
        let manager = NotificationManager.shared
        manager.sendSoundAlert(
            soundType: soundType,
            intensity: intensity,
            repeatCount: repeatCount
        )
        
        let message = "已发送 \(soundType.displayName) 警报到指环"
        return .result(value: message)
    }
}

// MARK: - App Shortcut Provider

/// 提供快捷指令入口，让用户可以直接在快捷指令中找到我们的 Action
struct SoundAlertShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        [
            AppShortcut(
                intent: SendSoundAlertIntent(),
                phrases: [
                    "发送声音警报",
                    "通知指环震动",
                    "发送 \(.applicationName) 警报"
                ],
                shortTitle: "声音警报",
                systemImageName: "bell.badge.fill"
            )
        ]
    }
}
