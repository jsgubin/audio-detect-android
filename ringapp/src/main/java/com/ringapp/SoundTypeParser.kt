package com.ringapp

import android.util.Log

/**
 * 多语言声音类别解析器
 *
 * 解析来自 Android 系统声音通知（Sound Notifications）的通知文本，
 * 从中提取声音类别。需要适配不同语言和不同厂商 ROM 的通知文案差异。
 *
 * 工作原理：
 * 1. 对通知标题和正文分别做关键词匹配
 * 2. 支持中文、英文两种主要语言
 * 3. 采用优先级匹配：标题权重 > 正文权重
 * 4. 无法匹配时返回 UNKNOWN
 */
object SoundTypeParser {

    private const val TAG = "SoundTypeParser"

    /**
     * 解析结果：包含识别到的类别和置信度
     */
    data class ParseResult(
        val category: SoundCategory,
        /** 0.0 ~ 1.0，基于匹配质量 */
        val confidence: Float,
        /** 原始通知标题 */
        val rawTitle: String,
        /** 原始通知正文 */
        val rawText: String,
        /** 命中的关键词 */
        val matchedKeyword: String = ""
    )

    // ──────────────────────────────────────────
    // 中文关键词映射（key = 关键词，value = 类别ID）
    // 支持原生 Android 和各厂商 ROM 的常见措辞
    // ──────────────────────────────────────────

    private val zhKeywordMap = linkedMapOf(
        // 警报类
        "火警" to "fire_alarm", "火灾" to "fire_alarm", "火灾警报" to "fire_alarm",
        "烟雾" to "smoke_detector", "烟雾警报" to "smoke_detector", "烟雾探测器" to "smoke_detector",
        "警报" to "alarm", "警报声" to "alarm", "报警" to "alarm",
        // 婴儿
        "婴儿" to "baby_cry", "婴儿哭" to "baby_cry", "婴儿啼哭" to "baby_cry",
        "宝宝哭" to "baby_cry", "小孩哭" to "baby_cry",
        // 玻璃
        "玻璃" to "glass_break", "玻璃破碎" to "glass_break", "玻璃碎裂" to "glass_break",
        // 枪声
        "枪" to "gun_shot", "枪声" to "gun_shot", "枪击" to "gun_shot",
        // 警笛
        "警笛" to "siren", "警笛声" to "siren", "警报器" to "siren",
        // 汽车
        "汽车鸣笛" to "car_horn", "汽车喇叭" to "car_horn", "鸣笛" to "car_horn",
        "喇叭" to "car_horn",
        // 门铃
        "门铃" to "doorbell", "门铃声" to "doorbell",
        // 敲门
        "敲门" to "knocking", "敲门声" to "knocking",
        // 喊叫
        "喊叫" to "shouting", "叫喊" to "shouting", "尖叫声" to "shouting",
        "吼叫" to "shouting", "呼喊" to "shouting",
        // 动物
        "狗叫" to "dog", "狗吠" to "dog", "犬吠" to "dog",
        "猫叫" to "cat", "猫" to "cat",
        // 水
        "流水" to "water_running", "水流" to "water_running", "水声" to "water_running",
        // 咳嗽
        "咳嗽" to "coughing",
        // 掌声
        "掌声" to "applause", "鼓掌" to "applause",
        // 检测到（通用匹配 — 低优先级，放在后面）
        "检测到" to null, // 标记，需要结合上下文
    )

    // ──────────────────────────────────────────
    // 英文关键词映射
    // ──────────────────────────────────────────

    private val enKeywordMap = linkedMapOf(
        "fire alarm" to "fire_alarm", "fire" to "fire_alarm",
        "smoke" to "smoke_detector", "smoke detector" to "smoke_detector",
        "alarm" to "alarm",
        "baby" to "baby_cry", "crying" to "baby_cry", "baby cry" to "baby_cry",
        "glass" to "glass_break", "glass break" to "glass_break", "shatter" to "glass_break",
        "gun" to "gun_shot", "gunshot" to "gun_shot", "shot" to "gun_shot",
        "siren" to "siren",
        "car horn" to "car_horn", "horn" to "car_horn",
        "doorbell" to "doorbell", "door bell" to "doorbell",
        "knock" to "knocking", "knocking" to "knocking",
        "shout" to "shouting", "yelling" to "shouting", "scream" to "shouting",
        "dog" to "dog", "bark" to "dog",
        "cat" to "cat", "meow" to "cat",
        "water" to "water_running", "running water" to "water_running",
        "cough" to "coughing", "coughing" to "coughing",
        "applause" to "applause", "clap" to "applause",
    )

    /**
     * 解析通知文本
     * @param title 通知标题（通常如「检测到门铃声」「Sound Detected」）
     * @param text 通知正文（更详细的描述）
     * @return ParseResult，包含识别到的类别和置信度
     */
    fun parse(title: String?, text: String?): ParseResult {
        val rawTitle = title?.trim() ?: ""
        val rawText = text?.trim() ?: ""
        val combined = "$rawTitle $rawText"

        if (combined.isBlank()) {
            return ParseResult(SoundCategory.UNKNOWN, 0f, rawTitle, rawText)
        }

        // 优先在标题中匹配（权重更高）
        if (rawTitle.isNotBlank()) {
            val titleResult = matchInText(rawTitle.lowercase())
            if (titleResult != null && titleResult.first != "unknown") {
                Log.d(TAG, "Matched in title: ${titleResult.first} via '${titleResult.second}'")
                return ParseResult(
                    SoundCategory.fromId(titleResult.first),
                    0.95f,
                    rawTitle, rawText,
                    titleResult.second
                )
            }
        }

        // 在正文中匹配
        if (rawText.isNotBlank()) {
            val textResult = matchInText(rawText.lowercase())
            if (textResult != null && textResult.first != "unknown") {
                Log.d(TAG, "Matched in text: ${textResult.first} via '${textResult.second}'")
                return ParseResult(
                    SoundCategory.fromId(textResult.first),
                    0.75f,
                    rawTitle, rawText,
                    textResult.second
                )
            }
        }

        // 全局模糊匹配（combined）
        val combinedResult = matchInText(combined.lowercase())
        if (combinedResult != null && combinedResult.first != "unknown") {
            Log.d(TAG, "Matched in combined: ${combinedResult.first} via '${combinedResult.second}'")
            return ParseResult(
                SoundCategory.fromId(combinedResult.first),
                0.55f,
                rawTitle, rawText,
                combinedResult.second
            )
        }

        Log.d(TAG, "No match: title='$rawTitle', text='$rawText'")
        return ParseResult(SoundCategory.UNKNOWN, 0f, rawTitle, rawText)
    }

    /**
     * 在文本中按关键词优先级匹配
     * 返回 Pair<categoryId, matchedKeyword> 或 null
     */
    private fun matchInText(lowerText: String): Pair<String, String>? {
        // 先尝试中文关键词（通常更准确）
        for ((keyword, categoryId) in zhKeywordMap) {
            if (categoryId == null) continue  // 跳过通用标记
            if (lowerText.contains(keyword.lowercase())) {
                return Pair(categoryId, keyword)
            }
        }
        // 再尝试英文关键词
        for ((keyword, categoryId) in enKeywordMap) {
            if (lowerText.contains(keyword.lowercase())) {
                return Pair(categoryId, keyword)
            }
        }
        return null
    }
}
