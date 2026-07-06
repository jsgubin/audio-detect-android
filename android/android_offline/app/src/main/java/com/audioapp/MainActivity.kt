package com.audioapp

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 主界面：录音 -> Mel 频谱提取 -> 模型推理 -> 显示结果
 */
class MainActivity : AppCompatActivity() {

    private val PERMISSION_REQUEST_CODE = 1001

    private lateinit var audioRecorder: AudioRecorder
    private lateinit var melSpectrogram: MelSpectrogram
    private lateinit var modelInference: ModelInference

    private lateinit var statusText: TextView
    private lateinit var startBtn: Button
    private lateinit var stopBtn: Button
    private lateinit var logContainer: LinearLayout
    private lateinit var scrollView: ScrollView
    private lateinit var modelStatusText: TextView

    private var isListening = false
    private var emptyLogMsg: TextView? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // 初始化 UI 组件
        statusText = findViewById(R.id.statusText)
        startBtn = findViewById(R.id.startBtn)
        stopBtn = findViewById(R.id.stopBtn)
        logContainer = findViewById(R.id.logContainer)
        scrollView = findViewById(R.id.scrollView)
        modelStatusText = findViewById(R.id.modelStatusText)

        // 初始化模块
        audioRecorder = AudioRecorder(this)
        melSpectrogram = MelSpectrogram(this)
        modelInference = ModelInference(this)

        // 检查模型状态
        if (modelInference.isLoaded()) {
            modelStatusText.text = "✓ 模型已加载 (EfficientAT Lite)"
            modelStatusText.setTextColor(ContextCompat.getColor(this, android.R.color.holo_green_dark))
        } else {
            modelStatusText.text = "✗ 模型加载失败"
            modelStatusText.setTextColor(ContextCompat.getColor(this, android.R.color.holo_red_dark))
            startBtn.isEnabled = false
        }

        // 空提示
        emptyLogMsg = TextView(this).apply {
            text = "正在等待识别...\n(环境中出现目标声音时将在此处显示)"
            textSize = 14f
            setTextColor(ContextCompat.getColor(this@MainActivity, android.R.color.darker_gray))
            textAlignment = View.TEXT_ALIGNMENT_CENTER
            setPadding(0, 150, 0, 0)
        }
        logContainer.addView(emptyLogMsg)

        // 按钮事件
        startBtn.setOnClickListener { startListening() }
        stopBtn.setOnClickListener { stopListening() }

        // 检查权限
        if (!audioRecorder.checkPermission()) {
            requestPermission()
        }
    }

    private fun requestPermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            PERMISSION_REQUEST_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            if (grantResults.isEmpty() || grantResults[0] != PackageManager.PERMISSION_GRANTED) {
                AlertDialog.Builder(this)
                    .setTitle("需要麦克风权限")
                    .setMessage("环境音识别需要麦克风权限才能录制音频。")
                    .setPositiveButton("确定") { _, _ -> requestPermission() }
                    .setNegativeButton("取消") { _, _ -> finish() }
                    .show()
            }
        }
    }

    private fun startListening() {
        if (!audioRecorder.checkPermission()) {
            requestPermission()
            return
        }
        if (!modelInference.isLoaded()) {
            showToast("模型未加载，无法开始")
            return
        }

        isListening = true
        startBtn.isEnabled = false
        stopBtn.isEnabled = true
        statusText.text = "🎙️ 正在实时监听中..."
        statusText.setTextColor(ContextCompat.getColor(this, android.R.color.holo_green_dark))

        // 开始录音循环
        recordCycle()
    }

    private fun stopListening() {
        isListening = false
        audioRecorder.stopRecording()
        startBtn.isEnabled = true
        stopBtn.isEnabled = false
        statusText.text = "监听已暂停"
        statusText.setTextColor(ContextCompat.getColor(this, android.R.color.holo_orange_dark))
    }

    /**
     * 录音循环：每 3 秒录一段，处理并推理，然后递归继续
     */
    private fun recordCycle() {
        if (!isListening) return

        statusText.text = "🎙️ 正在录音..."

        audioRecorder.startRecording { pcmData ->
            if (!isListening) return@startRecording

            statusText.text = "🧠 正在识别..."

            // 在后台线程处理（避免阻塞 UI）
            Thread {
                try {
                    // 1. 提取 Mel 频谱
                    val melData = melSpectrogram.extract(pcmData)

                    // 2. 模型推理
                    val results = modelInference.predict(melData)

                    // 3. 在主线程更新 UI
                    handler.post {
                        if (!isListening) return@post

                        statusText.text = "🎙️ 正在实时监听中..."

                        if (results.isNotEmpty()) {
                            // 隐藏空提示
                            emptyLogMsg?.visibility = View.GONE

                            results.forEach { result ->
                                addLogEntry(result.displayName, result.probability)
                            }
                        }
                        // 如果结果为空，不做任何显示（与原 Web 版一致）

                        // 递归继续录音
                        if (isListening) {
                            recordCycle()
                        }
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                    handler.post {
                        statusText.text = "❌ 识别出错: ${e.message}"
                        statusText.setTextColor(ContextCompat.getColor(this, android.R.color.holo_red_dark))
                        if (isListening) {
                            recordCycle()
                        }
                    }
                }
            }.start()
        }
    }

    private fun addLogEntry(className: String, prob: Float) {
        val timeStr = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date())
        val probPercent = String.format(Locale.getDefault(), "%.1f%%", prob * 100)

        val entryLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(16, 12, 16, 12)
            setBackgroundColor(ContextCompat.getColor(this@MainActivity, android.R.color.white))
        }

        val timeView = TextView(this).apply {
            text = "[$timeStr]"
            textSize = 12f
            setTextColor(ContextCompat.getColor(this@MainActivity, android.R.color.darker_gray))
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        val classView = TextView(this).apply {
            text = className
            textSize = 16f
            setTextColor(ContextCompat.getColor(this@MainActivity, android.R.color.holo_red_dark))
            setPadding(8, 0, 8, 0)
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 2f)
        }

        val probView = TextView(this).apply {
            text = "置信度: $probPercent"
            textSize = 13f
            setTextColor(ContextCompat.getColor(this@MainActivity, android.R.color.holo_blue_dark))
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        entryLayout.addView(timeView)
        entryLayout.addView(classView)
        entryLayout.addView(probView)

        // 添加分隔线
        val divider = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 1
            )
            setBackgroundColor(ContextCompat.getColor(this@MainActivity, android.R.color.darker_gray))
            alpha = 0.2f
        }

        // 插入到顶部
        logContainer.addView(entryLayout, 0)
        logContainer.addView(divider, 1)

        // 保持最多 50 条
        while (logContainer.childCount > 100) {
            logContainer.removeViewAt(logContainer.childCount - 1)
        }

        // 自动滚动到顶部
        scrollView.post {
            scrollView.scrollTo(0, 0)
        }
    }

    private fun showToast(message: String) {
        android.widget.Toast.makeText(this, message, android.widget.Toast.LENGTH_SHORT).show()
    }

    override fun onDestroy() {
        super.onDestroy()
        isListening = false
        audioRecorder.stopRecording()
    }
}
