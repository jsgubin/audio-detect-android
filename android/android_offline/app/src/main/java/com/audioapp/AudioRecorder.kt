package com.audioapp

import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.appcompat.app.AppCompatActivity
import kotlin.math.min

/**
 * 使用 Android AudioRecord 录制 16kHz 16bit 单声道 PCM 音频
 */
class AudioRecorder(private val activity: AppCompatActivity) {

    companion object {
        const val SAMPLE_RATE = 16000
        const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        const val RECORD_DURATION_MS = 3000  // 3 秒

        // 3 秒音频需要的样本数
        val TOTAL_SAMPLES = SAMPLE_RATE * 3
    }

    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var recordingThread: Thread? = null

    private val PERMISSION_REQUEST_CODE = 1001

    fun checkPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            activity, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun requestPermission(callback: (granted: Boolean) -> Unit) {
        if (checkPermission()) {
            callback(true)
            return
        }
        // 存储回调供 onRequestPermissionsResult 使用
        permissionCallback = callback
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            PERMISSION_REQUEST_CODE
        )
    }

    private var permissionCallback: ((Boolean) -> Unit)? = null

    fun onPermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            permissionCallback?.invoke(granted)
            permissionCallback = null
        }
    }

    fun startRecording(onComplete: (ShortArray) -> Unit) {
        if (isRecording) return

        val minBufferSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT
        )
        val bufferSize = minBufferSize * 2

        if (ActivityCompat.checkSelfPermission(
                activity, Manifest.permission.RECORD_AUDIO
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE,
            CHANNEL_CONFIG,
            AUDIO_FORMAT,
            bufferSize
        )

        if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
            return
        }

        isRecording = true
        audioRecord?.startRecording()

        recordingThread = Thread {
            val buffer = ShortArray(bufferSize / 2)
            val recordedData = mutableListOf<Short>()
            val targetSamples = SAMPLE_RATE * 3  // 3 秒

            while (isRecording && recordedData.size < targetSamples) {
                val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                if (read > 0) {
                    val toAdd = min(read, targetSamples - recordedData.size)
                    for (i in 0 until toAdd) {
                        recordedData.add(buffer[i])
                    }
                }
            }

            // 停止录音
            try {
                audioRecord?.stop()
                audioRecord?.release()
            } catch (_: Exception) {}
            audioRecord = null
            isRecording = false

            // 填充到正好 3 秒（如果不够）
            val result = ShortArray(targetSamples)
            for (i in recordedData.indices) {
                result[i] = recordedData[i]
            }

            // 在主线程回调
            Handler(Looper.getMainLooper()).post {
                onComplete(result)
            }
        }
        recordingThread?.start()
    }

    fun stopRecording() {
        isRecording = false
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (_: Exception) {}
        audioRecord = null
        try {
            recordingThread?.join(1000)
        } catch (_: Exception) {}
        recordingThread = null
    }
}
