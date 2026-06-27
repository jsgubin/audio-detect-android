package com.example.audio

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import android.webkit.*
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import org.pytorch.Tensor
import java.io.File
import java.io.FileOutputStream
import java.nio.FloatBuffer

class MainActivity : AppCompatActivity() {

    companion object {
        private const val REQUEST_AUDIO = 200
        private const val SAMPLE_RATE = 16000
        private const val CHUNK_DURATION_MS = 3000
        private const val TAG = "MainActivity"
    }

    private lateinit var webView: WebView
    private lateinit var audioRecorder: AudioRecorder
    private lateinit var preprocessor: AudioPreprocessor
    private lateinit var modelInference: ModelInference
    private lateinit var jsBridge: JsBridge

    private var isRecording = false
    private var recordingThread: Thread? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        webView = findViewById(R.id.webView)
        setupWebView()

        // 初始化组件
        preprocessor = AudioPreprocessor()
        modelInference = ModelInference(this)
        audioRecorder = AudioRecorder(SAMPLE_RATE)
        jsBridge = JsBridge(webView)

        // 请求麦克风权限
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                REQUEST_AUDIO
            )
        }
    }

    private fun setupWebView() {
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowFileAccess = true
            mediaPlaybackRequiresUserGesture = false
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onPermissionRequest(request: PermissionRequest?) {
                request?.grant(request.resources)
            }
        }

        // JS 桥接
        webView.addJavascriptInterface(JsInterface(), "AndroidNative")

        // 加载本地 assets
        webView.loadUrl("file:///android_asset/index.html")
    }

    /** 开始音频侦测 */
    fun startDetection(modelName: String, vadThreshold: Float, confThreshold: Float) {
        try {
            if (isRecording) {
                Log.d(TAG, "Already recording, ignoring start request")
                return
            }
            isRecording = true

            // 加载对应模型
            if (!modelInference.loadModel(modelName)) {
                isRecording = false
                runOnUiThread {
                    jsBridge.sendError("模型加载失败，请检查模型文件是否正确")
                }
                return
            }

            audioRecorder.start()

            recordingThread = Thread {
                try {
                    while (isRecording) {
                        try {
                            val startTime = System.currentTimeMillis()

                            // 录制 3 秒音频
                            val audioBuffer = audioRecorder.read(CHUNK_DURATION_MS)
                            if (audioBuffer == null || audioBuffer.isEmpty()) {
                                Thread.sleep(100)
                                continue
                            }

                            // VAD 检测（简单峰值检测）
                            val maxAmp = audioBuffer.maxOf { kotlin.math.abs(it.toInt()) }
                            if (maxAmp < vadThreshold * 32768) {
                                // 静音，跳过
                                continue
                            }

                            // 预处理
                            val inputTensor = when (modelName) {
                                "mobilenet" -> preprocessor.preprocessForMobileNet(audioBuffer, SAMPLE_RATE)
                                else -> preprocessor.preprocessForEfficientAT(audioBuffer, SAMPLE_RATE)
                            }

                            // 推理
                            val results = modelInference.run(inputTensor, confThreshold)

                            // 发送结果到前端
                            runOnUiThread {
                                jsBridge.sendDetections(results)
                            }

                            // 补偿时间，确保约 3 秒一个循环
                            val elapsed = System.currentTimeMillis() - startTime
                            val sleepTime = CHUNK_DURATION_MS - elapsed
                            if (sleepTime > 0) {
                                Thread.sleep(sleepTime)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error in audio processing loop", e)
                            Thread.sleep(100)
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Recording thread fatal error", e)
                } finally {
                    try {
                        audioRecorder.stop()
                    } catch (e: Exception) {
                        Log.e(TAG, "Error stopping audio recorder", e)
                    }
                }
            }
            recordingThread?.start()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start detection", e)
            isRecording = false
            runOnUiThread {
                jsBridge.sendError("启动侦测失败: ${e.message}")
            }
        }
    }

    /** 停止音频侦测 */
    fun stopDetection() {
        try {
            isRecording = false
            recordingThread?.join(500)
            recordingThread = null
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping detection", e)
        }
    }

    /** JS 桥接接口 */
    inner class JsInterface {
        @JavascriptInterface
        fun startListening(model: String, vad: Float, conf: Float) {
            runOnUiThread { startDetection(model, vad, conf) }
        }

        @JavascriptInterface
        fun stopListening() {
            runOnUiThread { stopDetection() }
        }

        @JavascriptInterface
        fun showToast(msg: String) {
            runOnUiThread { Toast.makeText(this@MainActivity, msg, Toast.LENGTH_SHORT).show() }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_AUDIO) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                jsBridge.sendReady()
            } else {
                jsBridge.sendError("麦克风权限被拒绝")
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopDetection()
        modelInference.release()
    }
}
