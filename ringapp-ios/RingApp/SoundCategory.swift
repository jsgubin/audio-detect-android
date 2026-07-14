import Foundation

/// 声音类别 — 对齐 Apple SoundAnalysis 框架支持的所有类别 + 与 Android ringapp 一致的震动映射
///
/// iOS 的 SNClassifySoundRequest 原生支持约 300 种声音，
/// 这里列出与指环震动提醒相关的高优先级类别。
enum SoundCategory: String, CaseIterable, Identifiable {
    // 紧急警报
    case fireAlarm     = "fire_alarm"
    case smokeDetector = "smoke_detector"
    case siren         = "siren"
    case alarm         = "alarm_clock"

    // 人身安全
    case babyCrying    = "baby_crying"
    case glassBreaking = "glass_breaking"
    case gunshot       = "gunshot"
    case shouting      = "shouting"
    case screaming     = "screaming"

    // 日常提醒
    case doorbell      = "doorbell"
    case doorKnock     = "knocking"
    case carHorn       = "car_horn"

    // 动物 / 环境
    case dogBark       = "dog_bark"
    case catMeow       = "cat_meow"
    case waterRunning  = "water_running"
    case coughing      = "coughing"

    // MARK: - Display

    var id: String { rawValue }

    /// Apple SoundAnalysis 中对应的分类标签
    var appleLabel: String {
        switch self {
        case .fireAlarm:     return "fire_alarm"
        case .smokeDetector: return "smoke_detector"
        case .siren:         return "siren"
        case .alarm:         return "alarm_clock"
        case .babyCrying:    return "baby_crying"
        case .glassBreaking: return "glass_breaking"
        case .gunshot:       return "gunshot_gunfire"
        case .shouting:      return "shouting"
        case .screaming:     return "screaming"
        case .doorbell:      return "doorbell"
        case .doorKnock:     return "knock"
        case .carHorn:       return "car_horn"
        case .dogBark:       return "dog_bark"
        case .catMeow:       return "cat_meow"
        case .waterRunning:  return "water"
        case .coughing:      return "coughing"
        }
    }

    var emoji: String {
        switch self {
        case .fireAlarm:     return "🔥"
        case .smokeDetector: return "💨"
        case .siren:         return "🚨"
        case .alarm:         return "⏰"
        case .babyCrying:    return "👶"
        case .glassBreaking: return "💥"
        case .gunshot:       return "🔫"
        case .shouting:      return "🗣️"
        case .screaming:     return "😱"
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
        case .alarm:         return "闹钟声"
        case .babyCrying:    return "婴儿啼哭"
        case .glassBreaking: return "玻璃破碎"
        case .gunshot:       return "枪声"
        case .shouting:      return "喊叫声"
        case .screaming:     return "尖叫声"
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
        case .fireAlarm, .smokeDetector, .siren, .gunshot, .screaming:
            return 5  // SOS 紧急
        case .alarm, .babyCrying, .glassBreaking:
            return 4  // 间歇长震
        case .shouting:
            return 3  // 间歇短震
        case .carHorn, .doorKnock:
            return 2  // 长震
        default:
            return 1  // 短震
        }
    }

    /// 优先级 0-3（3=最高）
    var priority: Int {
        switch self {
        case .fireAlarm, .smokeDetector, .gunshot, .screaming, .babyCrying, .siren:
            return 3
        case .alarm, .glassBreaking, .shouting:
            return 2
        default:
            return 1
        }
    }

    /// 用户默认选中的类别
    static var defaultSelected: Set<SoundCategory> {
        Set([
            .fireAlarm, .smokeDetector, .siren,
            .babyCrying, .glassBreaking, .gunshot,
            .doorbell, .doorKnock, .shouting
        ])
    }
}
