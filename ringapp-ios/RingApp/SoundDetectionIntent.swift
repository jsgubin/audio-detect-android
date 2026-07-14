import AppIntents
import Foundation

/// 震动强度选项
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
/// Shortcuts 自动化调用此 Intent，将声音检测结果通过 BLE 发送给指环。
///
/// 使用前：确保 App 已在运行且指环已通过 BLE 连接（打开 App 扫描连接指环即可）。
///
/// Shortcuts 自动化配置：
///   自动化 → 创建个人自动化 → 声音识别 → 选择类别
///   → 下一步 → 搜索「发送声音警报」→ 完成
///
struct SendSoundAlertIntent: AppIntent {

    static var title: LocalizedStringResource = "发送声音警报"
    static var description = IntentDescription(
        "接收 iOS 系统声音识别结果，通过蓝牙发送震动指令给智能指环"
    )

    @Parameter(title: "声音类别")
    var soundType: SoundCategory

    @Parameter(title: "震动强度", default: .medium)
    var intensity: VibrationIntensity

    @Parameter(title: "重复次数", default: 1)
    var repeatCount: Int

    static var parameterSummary: some ParameterSummary {
        Summary("发送「\(\.$soundType)」警报，强度 \(\.$intensity)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // 通过 CoreBluetooth BLE 直连发送震动指令
        let manager = RingBLEManager.shared

        // 如果已连接，直接发送
        if manager.state == .connected {
            manager.sendVibration(category: soundType)
            return .result(value: "已发送 \(soundType.emoji) \(soundType.displayName) 震动指令到指环")
        }

        // 如果未连接，发送本地通知兜底 + 震动手机
        NotificationManager.shared.sendSoundAlert(
            category: soundType,
            intensity: intensity,
            repeatCount: repeatCount
        )

        return .result(value: "指环未连接，已发送手机通知作为兜底提醒")
    }
}

// MARK: - App Shortcuts Provider

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
