package com.example.audio

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import java.nio.ShortBuffer

/**
 * 使用 Android AudioRecord API 录制原始音频
 */
class AudioRecorder(private val sampleRate: Int) {

    private var audioRecord: AudioRecord? = null
    private val bufferSize: Int by lazy {
        AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        ) * 2
    }

    private var isRecording = false

    fun start() {
        if (audioRecord?.recordingState == AudioRecord.RECORDSTATE_RECORDING) return

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )
        audioRecord?.startRecording()
        isRecording = true
    }

    fun stop() {
        isRecording = false
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
    }

    /** 读取指定毫秒数的音频数据，返回 ShortArray (PCM 16bit) */
    fun read(durationMs: Int): ShortArray? {
        val audioRecord = this.audioRecord ?: return null
        if (!isRecording) return null

        val samplesNeeded = (sampleRate * durationMs / 1000)
        val buffer = ShortArray(samplesNeeded)
        var read = 0
        var retries = 0

        while (read < samplesNeeded && retries < 50) {
            val count = audioRecord.read(buffer, read, samplesNeeded - read)
            if (count > 0) {
                read += count
            } else if (count == 0) {
                Thread.sleep(50)
                retries++
            } else {
                // 错误
                return null
            }
        }

        return if (read >= samplesNeeded * 0.8) buffer.copyOf(read) else null
    }
}
