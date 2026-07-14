package com.ringapp

/**
 * 声音类别枚举 — 对应 Android 系统声音通知支持的所有类别
 *
 * 每个类别包含：
 * - identifier: 内部标识符
 * - emoji: 展示图标
 * - displayName: 中文展示名
 * - vibrationPattern: 指环震动模式 (0=无, 1=短震, 2=长震, 3=间歇短震, 4=间歇长震, 5=SOS)
 * - priority: 优先级 (0-3, 3最高, 决定通知强度)
 */
enum class SoundCategory(
    val identifier: String,
    val emoji: String,
    val displayName: String,
    val vibrationPattern: Int,
    val priority: Int
) {
    ALARM("alarm", "🚨", "警报声", 4, 3),
    FIRE_ALARM("fire_alarm", "🔥", "火灾警报", 5, 3),
    SMOKE_ALARM("smoke_detector", "💨", "烟雾警报", 5, 3),
    BABY_CRY("baby_cry", "👶", "婴儿啼哭", 4, 3),
    GLASS_BREAK("glass_break", "💥", "玻璃破碎", 3, 2),
    GUN_SHOT("gun_shot", "🔫", "枪声", 5, 3),
    SIREN("siren", "📢", "警笛声", 5, 3),
    CAR_HORN("car_horn", "🚗", "汽车鸣笛", 2, 1),
    DOORBELL("doorbell", "🔔", "门铃声", 1, 1),
    DOOR_KNOCK("knocking", "🚪", "敲门声", 1, 1),
    SHOUTING("shouting", "🗣️", "喊叫声", 3, 2),
    DOG_BARK("dog", "🐶", "狗叫声", 1, 1),
    CAT_MEOW("cat", "🐱", "猫叫声", 1, 0),
    WATER_RUNNING("water_running", "💧", "流水声", 1, 0),
    COUGHING("coughing", "😷", "咳嗽声", 1, 0),
    APPLAUSE("applause", "👏", "掌声", 1, 0),
    UNKNOWN("unknown", "❓", "未知声音", 2, 1);

    companion object {
        /** 根据 identifier 查找类别 */
        fun fromId(id: String): SoundCategory =
            entries.firstOrNull { it.identifier == id } ?: UNKNOWN
    }
}
