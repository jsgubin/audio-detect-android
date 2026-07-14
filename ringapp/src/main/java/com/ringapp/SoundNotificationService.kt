package com.ringapp

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 声音通知监听服务
 *
 * 继承 [NotificationListenerService]，
 * 在 Android 系统发出声音识别的通知时拦截并提取声音类别，
 * 然后驱动指环震动。
 *
 * 权限要求：用户必须手动在「设置 → 无障碍 → 已安装的服务」中开启。
 * App 首次启动时会引导用户前往设置。
 *
 * 注意：
 * - Android 14+ 才有系统「声音通知」功能（Settings → Accessibility → Sound Notifications）
 * - 通知格式因系统语言和厂商 ROM 而异，由 [SoundTypeParser] 处理
 */
class SoundNotificationService : NotificationListenerService() {

    companion object {
        private const val TAG = "SoundNotifyService"

        /** 系统声音通知的包名（原生 Android 和部分厂商） */
        private val SOUND_NOTIFICATION_PACKAGES = setOf(
            "com.google.android.apps.wellbeing",      // 原生 Android 14+: Sound Notifications
            "com.android.settings",                   // 部分厂商集成在设置中
            "com.google.android.as",                  // Android System Intelligence
            "com.android.systemui",                   // 系统 UI
        )

        /** 通知标题中常见的可能包含声音检测结果的关键词（用于预过滤，减少无效解析） */
        private val SOUND_KEYWORDS = listOf(
            "检测到", "detected", "声音", "sound", "侦测",
            "通知", "notification", "警报", "alarm", "alert",
        )

        // ── 跨进程回调 ──

        /** 当声音被检测到时回调，由 MainActivity 或 RingForegroundService 设置 */
        var onSoundDetected: ((SoundTypeParser.ParseResult) -> Unit)? = null

        /** 服务是否正在运行 */
        var isRunning = false
            private set
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        Log.i(TAG, "SoundNotificationService 已创建")
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        Log.i(TAG, "SoundNotificationService 已销毁")
    }

    /**
     * 当有新的通知发布时回调
     */
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val notification = sbn.notification
        val packageName = sbn.packageName

        // 获取通知标题和内容
        val title = notification.extras.getString(Notification.EXTRA_TITLE)
        val text = notification.extras.getString(Notification.EXTRA_TEXT)
            ?: notification.extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        val subText = notification.extras.getString(Notification.EXTRA_SUB_TEXT)
        val bigText = notification.extras.getString(Notification.EXTRA_BIG_TEXT)

        // 合并所有可用文本
        val allText = listOfNotNull(title, text, subText, bigText)
            .joinToString(" ") { it.trim() }
            .lowercase()

        // 预过滤：如果文本里完全没有声音相关关键词，跳过
        // （仅对不确定来源的通知做过滤，系统声音通知包直接解析）
        val isKnownSource = packageName in SOUND_NOTIFICATION_PACKAGES
        if (!isKnownSource && !containsSoundKeyword(allText)) return

        Log.d(TAG, "收到通知: pkg=$packageName, title='$title', text='$text'")

        // 解析声音类别
        val result = SoundTypeParser.parse(title, text)

        if (result.category == SoundCategory.UNKNOWN) {
            // 无法识别的通知，跳过（避免过度震动）
            Log.d(TAG, "非声音通知或无法解析: pkg=$packageName")
            return
        }

        // 记录并触发回调
        val timestamp = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date())
        Log.i(
            TAG,
            "[$timestamp] ${result.category.emoji} ${result.category.displayName} " +
                "(置信度: ${"%.0f".format(result.confidence * 100)}%, " +
                "匹配: '${result.matchedKeyword}')"
        )

        addToHistory(result, timestamp)
        onSoundDetected?.invoke(result)
    }

    /**
     * 当通知被移除时回调（本例不需要处理）
     */
    override fun onNotificationRemoved(sbn: StatusBarNotification?) {}

    /**
     * 检查文本中是否包含任意声音关键词
     */
    private fun containsSoundKeyword(text: String): Boolean {
        return SOUND_KEYWORDS.any { text.contains(it, ignoreCase = true) }
    }

    // ── 历史记录 ──────────────────────────────────────────

    data class DetectionRecord(
        val category: SoundCategory,
        val emoji: String,
        val name: String,
        val confidence: Int,
        val time: String
    )

    /** 最近的检测记录（最多保留 50 条） */
    private val history = mutableListOf<DetectionRecord>()

    private fun addToHistory(result: SoundTypeParser.ParseResult, timestamp: String) {
        val record = DetectionRecord(
            category = result.category,
            emoji = result.category.emoji,
            name = result.category.displayName,
            confidence = (result.confidence * 100).toInt(),
            time = timestamp
        )
        history.add(0, record)
        if (history.size > 50) history.removeAt(history.lastIndex)
    }

    fun getHistory(): List<DetectionRecord> = history.toList()

    fun clearHistory() { history.clear() }
}
