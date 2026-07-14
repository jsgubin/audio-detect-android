import Foundation
import AppIntents

/// 声音类别 — 与 iOS 系统「声音识别」（辅助功能）对齐
///
/// 我们不自己跑 SoundAnalysis 模型，而是利用 iOS 系统设置中的「声音识别」功能：
///   设置 → 辅助功能 → 声音识别
///
/// 用户需要在 Shortcuts（快捷指令）中创建自动化：
///   「当声音识别检测到 [类别] → 运行声感指环的发送警报操作」
///
/// 此枚举同时用于 AppIntents 的参数类型，供 Shortcuts 调用。
enum SoundCategory: String, CaseIterable, AppEnum {

    // 火警类
    case fireAlarm     = "fire_alarm"
    case smokeDetector = "smoke_detector"
    case siren         = "siren"

    // 人身安全
    case babyCrying    = "baby_crying"
    case glassBreaking = "glass_breaking"
    case shouting      = "shouting"

    // 日常提醒
    case doorbell      = "doorbell"
    case doorKnock     = "knocking"
    case carHorn       = "car_horn"

    // 动物 / 环境
    case dogBark       = "dog"
    case catMeow       = "cat"
    case waterRunning  = "water_running"
    case coughing      = "coughing"

    // ── AppEnum 协议 ──────────────────────────────────

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "声音类别")
    }

    static var caseDisplayRepresentations: [SoundCategory: DisplayRepresentation] {
        Dictionary(uniqueKeysWithValues: allCases.map { cat in
            (cat, DisplayRepresentation(stringLiteral: "\(cat.emoji) \(cat.displayName)"))
        })
    }

    // ── 展示 ──────────────────────────────────────────

    var emoji: String {
        switch self {
        case .fireAlarm:     return "🔥"
        case .smokeDetector: return "💨"
        case .siren:         return "🚨"
        case .babyCrying:    return "👶"
        case .glassBreaking: return "💥"
        case .shouting:      return "🗣️"
        case .doorbell:      return "🔔"
        case .doorKnock:     return "🚪"
        case .carHorn:       return "🚗"
        case .dogBark:       return "🐶"
        case .catMeow:       return "🐱"
        case .waterRunning:  return "💧"
        case .coughing:      return "😷"
        }
    }

    var displayName: String {
        switch self {
        case .fireAlarm:     return "火灾警报"
        case .smokeDetector: return "烟雾警报"
        case .siren:         return "警笛声"
        case .babyCrying:    return "婴儿啼哭"
        case .glassBreaking: return "玻璃破碎"
        case .shouting:      return "喊叫声"
        case .doorbell:      return "门铃声"
        case .doorKnock:     return "敲门声"
        case .carHorn:       return "汽车鸣笛"
        case .dogBark:       return "狗叫声"
        case .catMeow:       return "猫叫声"
        case .waterRunning:  return "流水声"
        case .coughing:      return "咳嗽声"
        }
    }

    /// 震动模式 ID（与 Android ringapp 保持一致）
    /// 0=无, 1=短震, 2=长震, 3=间歇短震, 4=间歇长震, 5=SOS
    var vibrationPattern: Int {
        switch self {
        case .fireAlarm, .smokeDetector, .siren:
            return 5
        case .babyCrying, .glassBreaking:
            return 4
        case .shouting:
            return 3
        case .carHorn, .doorKnock:
            return 2
        default:
            return 1
        }
    }

    var priority: Int {
        switch self {
        case .fireAlarm, .smokeDetector, .siren, .babyCrying:
            return 3
        case .glassBreaking, .shouting:
            return 2
        default:
            return 1
        }
    }
}
