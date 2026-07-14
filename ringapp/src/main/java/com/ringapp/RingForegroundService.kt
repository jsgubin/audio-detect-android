package com.ringapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.os.PowerManager
import android.util.Log

/**
 * 指环后台前台服务
 *
 * 保持 BLE 连接在后台存活。
 * 运行前台服务 + 常驻通知 + WakeLock 防止系统杀死进程。
 *
 * 同时监听 [SoundNotificationService.onSoundDetected] 回调，
 * 当检测到声音时自动发送震动指令给指环。
 */
class RingForegroundService : Service() {

    companion object {
        private const val TAG = "RingForeground"
        const val CHANNEL_ID = "ring_foreground"
        const val NOTIFICATION_ID = 1001

        /** 是否正在运行 */
        var isRunning = false
            private set

        /** 供外部获取 BLE 管理器 */
        var bleManager: RingBLEManager? = null
            private set
    }

    private lateinit var wakeLock: PowerManager.WakeLock

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        Log.i(TAG, "RingForegroundService 已创建")

        // 初始化 BLE 管理器
        bleManager = RingBLEManager(this)
        bleManager?.onLog = { Log.i(TAG, "BLE: $it") }

        // 获取 WakeLock
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "RingApp::BLEWakeLock"
        )
        wakeLock.acquire(30 * 60 * 1000L) // 30 分钟

        // 监听声音检测回调
        SoundNotificationService.onSoundDetected = { result ->
            bleManager?.sendVibration(result.category)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        Log.i(TAG, "前台服务已启动")
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        bleManager?.destroy()
        bleManager = null
        try { wakeLock.release() } catch (_: Exception) {}
        Log.i(TAG, "RingForegroundService 已销毁")
    }

    // ── 通知 ──────────────────────────────────────────────

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "指环连接",
            NotificationManager.IMPORTANCE_LOW  // LOW = 不发出声音，但显示在状态栏
        ).apply {
            description = "显示指环蓝牙连接状态"
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val stateText = when (bleManager?.state) {
            RingBLEManager.State.CONNECTED -> "指环已连接 ✅"
            RingBLEManager.State.CONNECTING -> "正在连接指环..."
            RingBLEManager.State.SCANNING -> "正在扫描指环..."
            else -> "指环未连接"
        }

        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("声感指环")
            .setContentText(stateText)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    /** 更新前台通知内容 */
    fun updateNotification(text: String) {
        val notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("声感指环")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setContentIntent(
                PendingIntent.getActivity(
                    this, 0,
                    Intent(this, MainActivity::class.java),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
            )
            .build()
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, notification)
    }
}
