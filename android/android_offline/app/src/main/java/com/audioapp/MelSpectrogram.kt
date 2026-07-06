package com.audioapp

import android.content.Context
import org.jtransforms.fft.DoubleFFT_1D
import java.io.DataInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.log10
import kotlin.math.sqrt

/**
 * Mel 频谱提取器：在 Android 上替代 librosa
 *
 * 参数（与训练时一致）：
 *   - sr = 16000, n_fft = 1024, hop_length = 512, n_mels = 64
 *   - f_min = 0, f_max = 8000
 *   - power = 2.0 (功率谱)
 *   - power_to_db ref = np.max
 */
class MelSpectrogram(private val context: Context) {

    companion object {
        const val N_FFT = 1024
        const val HOP_LENGTH = 512
        const val N_MELS = 64
        const val SAMPLE_RATE = 16000
        const val TARGET_FRAMES = 94
    }

    // 预加载的 Hann 窗 [1024]
    private val hannWindow: FloatArray
    // 预加载的 Mel 滤波器矩阵 [64 x 513]
    private val melFilterBank: Array<FloatArray>
    // FFT 引擎
    private val fft: DoubleFFT_1D

    init {
        hannWindow = loadHannWindow()
        melFilterBank = loadMelFilterBank()
        fft = DoubleFFT_1D(N_FFT)
    }

    /**
     * 从 short[] PCM 数据提取 Mel 频谱
     * 返回: FloatArray[64 * 94] (flat，row-major)
     */
    fun extract(pcm: ShortArray): FloatArray {
        // 1. PCM short -> float [-1, 1]
        val samples = FloatArray(pcm.size)
        for (i in pcm.indices) {
            samples[i] = pcm[i] / 32768.0f
        }

        // 2. STFT: 分帧 -> 加窗 -> FFT -> 功率谱
        val numFrames = (samples.size - N_FFT) / HOP_LENGTH + 1
        val fftSize = N_FFT / 2 + 1  // 513

        // 3. Mel 滤波 + 对数转换
        val melSpec = Array(N_MELS) { FloatArray(numFrames) }

        for (frameIdx in 0 until numFrames) {
            val start = frameIdx * HOP_LENGTH

            // 加 Hann 窗并转 double
            val frame = DoubleArray(N_FFT)
            for (i in 0 until N_FFT) {
                frame[i] = (samples[start + i] * hannWindow[i]).toDouble()
            }

            // FFT (原地变换，结果 packed)
            fft.realForward(frame)

            // 提取功率谱 (513 bins)
            val powerSpectrum = DoubleArray(fftSize)
            // k=0: DC
            powerSpectrum[0] = frame[0] * frame[0]
            // k=1..511
            for (k in 1 until fftSize - 1) {
                val re = frame[2 * k]
                val im = frame[2 * k + 1]
                powerSpectrum[k] = re * re + im * im
            }
            // k=512: Nyquist (frame[1])
            powerSpectrum[fftSize - 1] = frame[1] * frame[1]

            // Mel 滤波器矩阵乘法 (64 x 513) @ (513) = (64)
            for (melIdx in 0 until N_MELS) {
                var sum = 0.0
                for (bin in 0 until fftSize) {
                    sum += melFilterBank[melIdx][bin] * powerSpectrum[bin]
                }
                melSpec[melIdx][frameIdx] = sum.toFloat()
            }
        }

        // 4. power_to_db: 10 * log10(mel / ref)
        // 找到全局最大值作为 ref
        var maxVal = 0.0f
        for (i in 0 until N_MELS) {
            for (j in 0 until numFrames) {
                if (melSpec[i][j] > maxVal) maxVal = melSpec[i][j]
            }
        }

        val eps = 1e-9f
        val ref = if (maxVal > eps) maxVal else eps

        // 5. 对齐到 [64, 94] (pad 或 crop)
        val result = FloatArray(N_MELS * TARGET_FRAMES) { -80.0f }
        val actualFrames = minOf(numFrames, TARGET_FRAMES)
        for (i in 0 until N_MELS) {
            for (j in 0 until actualFrames) {
                val ratio = (melSpec[i][j] / ref).toDouble()
                val db = if (ratio > 1e-10) {
                    (10.0 * log10(ratio)).toFloat()
                } else {
                    -100.0f
                }
                result[i * TARGET_FRAMES + j] = db
            }
        }

        return result
    }

    // ======================== 加载预计算文件 ========================

    private fun loadHannWindow(): FloatArray {
        context.assets.open("hann_window.bin").use { stream ->
            DataInputStream(stream).use { dis ->
                val size = readLittleEndianInt(dis)
                val buf = ByteArray(size * 4)
                dis.readFully(buf)
                val result = FloatArray(size)
                val bb = ByteBuffer.wrap(buf).order(ByteOrder.LITTLE_ENDIAN)
                for (i in 0 until size) {
                    result[i] = bb.getFloat()
                }
                return result
            }
        }
    }

    private fun loadMelFilterBank(): Array<FloatArray> {
        context.assets.open("mel_filter_bank.bin").use { stream ->
            DataInputStream(stream).use { dis ->
                val rows = readLittleEndianInt(dis)
                val cols = readLittleEndianInt(dis)
                val buf = ByteArray(rows * cols * 4)
                dis.readFully(buf)
                val bb = ByteBuffer.wrap(buf).order(ByteOrder.LITTLE_ENDIAN)
                val result = Array(rows) { FloatArray(cols) }
                for (i in 0 until rows) {
                    for (j in 0 until cols) {
                        result[i][j] = bb.getFloat()
                    }
                }
                return result
            }
        }
    }

    private fun readLittleEndianInt(dis: DataInputStream): Int {
        val b = ByteArray(4)
        dis.readFully(b)
        return ByteBuffer.wrap(b).order(ByteOrder.LITTLE_ENDIAN).getInt()
    }
}
