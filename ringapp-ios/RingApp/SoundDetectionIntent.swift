import AppIntents
import Foundation

/// 震动强度选项（供 Shortcuts 自动化中选择）
enum VibrationIntensity: String, AppEnum {
    case light  = "light"
    case medium = "medium"
    case strong = "strong"
    case sos    = "sos"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "震动强度")
    }

    static var caseDisplayRepresentations: [VibrationIntensity: DisplayRepresentation] {
        [
            .light:  DisplayRepresentation(stringLiteral: "轻微"),
            .medium: DisplayRepresentation(stringLiteral: "中等"),
            .strong: DisplayRepresentation(stringLiteral: "强烈"),
            .sos:    DisplayRepresentation(stringLiteral: "SOS 紧急"),
        ]
    }
}

// MARK: - App Intent

/// 发送声音警报 Intent
///
/// 在 Shortcuts（快捷指令）中配置自动化：
///   「当声音识别检测到 [声音类别] → 运行 发送声音警报」
///
/// 执行流程：
///   Shortcuts 触发 → 此 Intent 运行 → 发送本地通知
///   → 指环通过 ANCS 接收通知 → 指环震动
///
struct SendSoundAlertIntent: AppIntent {

    static var title: LocalizedStringResource = "发送声音警报"
    static var description = IntentDescription(
        "接收 iOS 系统声音识别的结果，将警报发送给智能指环，触发震动提醒"
    )

    @Parameter(title: "声音类别", description: "iOS 系统声音识别检测到的声音类型")
    var soundType: SoundCategory

    @Parameter(title: "震动强度", description: "指环震动强度", default: .medium)
    var intensity: VibrationIntensity

    @Parameter(title: "重复次数", description: "震动重复次数", default: 1)
    var repeatCount: Int

    static var parameterSummary: some ParameterSummary {
        Summary("发送「\(\.$soundType)」警报，强度 \(\.$intensity)，重复 \(\.$repeatCount) 次")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // 通过通知管理器发送 → ANCS → 指环
        let manager = NotificationManager.shared
        manager.sendSoundAlert(
            category: soundType,
            intensity: intensity,
            repeatCount: repeatCount
        )

        let message = "已发送 \(soundType.emoji) \(soundType.displayName) 警报，指环将震动"
        return .result(value: message)
    }
}

// MARK: - App Shortcuts Provider

/// 提供 Shortcuts 入口
struct SoundAlertShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        [
            AppShortcut(
                intent: SendSoundAlertIntent(),
                phrases: [
                    "发送声音警报",
                    "通知指环震动",
                    "\(.applicationName) 发送警报",
                    "声感指环发送提醒",
                ],
                shortTitle: "发送声音警报",
                systemImageName: "bell.badge.fill"
            )
        ]
    }
}
