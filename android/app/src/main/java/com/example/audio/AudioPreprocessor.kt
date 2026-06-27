package com.example.audio

import org.pytorch.Tensor
import java.nio.FloatBuffer
import kotlin.math.*

/**
 * 音频预处理（Android 原生实现，替代 librosa）
 * 支持两种模型输入格式：
 *   - EfficientAT / PANNs: [1, 1, 64, 94]  Mel spectrogram
 *   - MobileNetV1: [1, 1, 128, 256]  Mel spectrogram
 */
class AudioPreprocessor {

    companion object {
        const val N_MELS_64 = 64
        const val N_MELS_128 = 128
        const val N_FFT = 1024
        const val HOP_LENGTH = 512
        const val TARGET_FRAMES_94 = 94
        const val TARGET_FRAMES_256 = 256
    }

    /** EfficientAT / PANNs 预处理：返回 [1, 1, 64, 94] */
    fun preprocessForEfficientAT(pcm16: ShortArray, sampleRate: Int): Tensor {
        try {
            // 1. Short -> Float (-1.0 ~ 1.0)
            val wav = FloatArray(pcm16.size) { pcm16[it] / 32768.0f }

            // 2. 选择能量最高的 3 秒窗口
            val windowSamples = sampleRate * 3
            val bestWindow = selectBestWindow(wav, windowSamples)

            // 3. 填充到 3 秒
            val padded = if (bestWindow.size < windowSamples) {
                FloatArray(windowSamples) { i -> if (i < bestWindow.size) bestWindow[i] else 0f }
            } else bestWindow

            // 4. 提取 Mel 频谱 (64 bins, power_to_db)
            val melSpec = computeMelSpectrogram(padded, sampleRate, N_MELS_64, N_FFT, HOP_LENGTH)
            val logMel = melSpecToDb(melSpec)

            // 5. 对齐到 94 帧
            val aligned = alignFrames(logMel, N_MELS_64, TARGET_FRAMES_94, -80.0f)

            // 6. 转为 PyTorch Tensor [1, 1, 64, 94]
            // PyTorch 内存布局: [batch][channel][height][width] = [1][1][64][94]
            // 最内层是 width(94)，外层是 height(64)
            val floatBuffer = FloatBuffer.allocate(N_MELS_64 * TARGET_FRAMES_94)
            for (m in 0 until N_MELS_64) {
                for (f in 0 until TARGET_FRAMES_94) {
                    floatBuffer.put(aligned[m][f])
                }
            }
            floatBuffer.rewind()

            return Tensor.fromBlob(floatBuffer, longArrayOf(1, 1, N_MELS_64.toLong(), TARGET_FRAMES_94.toLong()))
        } catch (e: Exception) {
            android.util.Log.e("AudioPreprocessor", "Error in preprocessForEfficientAT", e)
            throw e
        }
    }

    /** MobileNetV1 预处理：返回 [1, 1, 128, 256] */
    fun preprocessForMobileNet(pcm16: ShortArray, sampleRate: Int): Tensor {
        try {
            var wav = FloatArray(pcm16.size) { pcm16[it] / 32768.0f }

            // 1. 幅度自适应补偿
            val peak = wav.maxOf { abs(it) } + 1e-9f
            if (peak < 0.30f) {
                val boost = min(3.0f, 0.50f / peak)
                wav = FloatArray(wav.size) { wav[it] * boost }
            }

            // 2. 缩放（与训练时一致）
            wav = FloatArray(wav.size) { wav[it] * 32768.0f }

            // 3. 至少 0.5 秒
            val minSamples = (0.5 * sampleRate).toInt()
            if (wav.size < minSamples) {
                val repeats = (minSamples + wav.size - 1) / wav.size
                val repeated = wav.copyOf(wav.size * repeats)
                for (i in wav.size until repeated.size) {
                    repeated[i] = wav[i % wav.size]
                }
                wav = repeated.copyOf(minSamples)
            }

            // 4. 提取 Mel 频谱 (128 bins)
            val melSpec = computeMelSpectrogram(wav, sampleRate, N_MELS_128, 1024, 512)
            val logMel = Array(N_MELS_128) { m ->
                FloatArray(melSpec[0].size) { f -> ln(melSpec[m][f].toDouble() + 1e-9).toFloat() }
            }

            // 5. 双线性插值到 128x256（简化：直接裁剪或填充）
            val aligned = alignFrames(logMel, N_MELS_128, TARGET_FRAMES_256, 0f)

            // 6. 转为 PyTorch Tensor [1, 1, 128, 256]
            // 最内层是 width(256)，外层是 height(128)
            val floatBuffer = FloatBuffer.allocate(N_MELS_128 * TARGET_FRAMES_256)
            for (m in 0 until N_MELS_128) {
                for (f in 0 until TARGET_FRAMES_256) {
                    floatBuffer.put(aligned[m][f])
                }
            }
            floatBuffer.rewind()

            return Tensor.fromBlob(floatBuffer, longArrayOf(1, 1, N_MELS_128.toLong(), TARGET_FRAMES_256.toLong()))
        } catch (e: Exception) {
            android.util.Log.e("AudioPreprocessor", "Error in preprocessForMobileNet", e)
            throw e
        }
    }

    /** 选择能量最高的窗口 */
    private fun selectBestWindow(wav: FloatArray, windowSize: Int): FloatArray {
        if (wav.size <= windowSize) return wav
        val stride = max(1, windowSize / 15)
        var bestEnergy = -1.0f
        var bestStart = 0
        for (start in 0..(wav.size - windowSize) step stride) {
            var energy = 0.0f
            for (i in start until start + windowSize) {
                energy += wav[i] * wav[i]
            }
            if (energy > bestEnergy) {
                bestEnergy = energy
                bestStart = start
            }
        }
        return wav.copyOfRange(bestStart, bestStart + windowSize)
    }

    /** 计算 Mel 频谱（简化实现） */
    private fun computeMelSpectrogram(
        wav: FloatArray, sr: Int, nMels: Int, nFFT: Int, hopLength: Int
    ): Array<FloatArray> {
        // 计算 STFT 幅度
        val frames = (wav.size - nFFT) / hopLength + 1
        val magnitudes = Array(nFFT / 2 + 1) { FloatArray(frames) }

        val window = hammingWindow(nFFT)
        val fftBuffer = FloatArray(nFFT)

        for (f in 0 until frames) {
            val start = f * hopLength
            for (i in 0 until nFFT) {
                fftBuffer[i] = if (start + i < wav.size) wav[start + i] * window[i] else 0f
            }

            val real = fftBuffer.copyOf()
            val imag = FloatArray(nFFT)
            fft(real, imag)

            for (i in 0 until nFFT / 2 + 1) {
                magnitudes[i][f] = real[i] * real[i] + imag[i] * imag[i]
            }
        }

        // 创建 Mel filter bank
        val melBank = createMelFilterBank(sr, nFFT, nMels)

        // 应用 Mel filter bank
        val melSpec = Array(nMels) { FloatArray(frames) }
        for (m in 0 until nMels) {
            for (f in 0 until frames) {
                var sum = 0.0f
                for (i in 0 until nFFT / 2 + 1) {
                    sum += melBank[m][i] * magnitudes[i][f]
                }
                melSpec[m][f] = sum
            }
        }

        return melSpec
    }

    /** 将 Mel 频谱转为 dB */
    private fun melSpecToDb(melSpec: Array<FloatArray>): Array<FloatArray> {
        var maxVal = 0.0f
        for (m in melSpec.indices) {
            for (f in melSpec[m].indices) {
                if (melSpec[m][f] > maxVal) maxVal = melSpec[m][f]
            }
        }
        val ref = max(maxVal.toDouble(), 1e-10)
        return Array(melSpec.size) { m ->
            FloatArray(melSpec[m].size) { f ->
                (10.0 * log10(max(melSpec[m][f].toDouble() / ref, 1e-10))).toFloat()
            }
        }
    }

    /** 对齐帧数 */
    private fun alignFrames(
        data: Array<FloatArray>, nMels: Int, targetFrames: Int, padValue: Float
    ): Array<FloatArray> {
        val currentFrames = data[0].size
        return if (currentFrames < targetFrames) {
            Array(nMels) { m ->
                FloatArray(targetFrames) { f ->
                    if (f < currentFrames) data[m][f] else padValue
                }
            }
        } else {
            Array(nMels) { m -> data[m].copyOf(targetFrames) }
        }
    }

    /** 生成 Hamming 窗 */
    private fun hammingWindow(size: Int): FloatArray {
        return FloatArray(size) { i ->
            (0.54 - 0.46 * cos(2.0 * PI * i / (size - 1))).toFloat()
        }
    }

    /** 创建 Mel filter bank */
    private fun createMelFilterBank(sr: Int, nFFT: Int, nMels: Int): Array<FloatArray> {
        val fMin = 0.0f
        val fMax = sr / 2.0f
        val melMin = hzToMel(fMin)
        val melMax = hzToMel(fMax)
        val melPoints = FloatArray(nMels + 2) { i ->
            melMin + (melMax - melMin) * i / (nMels + 1)
        }
        val freqPoints = FloatArray(nMels + 2) { melToHz(melPoints[it]) }
        val binPoints = FloatArray(nMels + 2) { i ->
            floor((nFFT + 1) * freqPoints[i] / sr).toInt().toFloat()
        }

        val filterBank = Array(nMels) { FloatArray(nFFT / 2 + 1) { 0f } }
        for (m in 0 until nMels) {
            for (f in binPoints[m].toInt() until binPoints[m + 1].toInt()) {
                filterBank[m][f] = (f - binPoints[m]) / (binPoints[m + 1] - binPoints[m])
            }
            for (f in binPoints[m + 1].toInt() until binPoints[m + 2].toInt()) {
                filterBank[m][f] = (binPoints[m + 2] - f) / (binPoints[m + 2] - binPoints[m + 1])
            }
        }
        return filterBank
    }

    private fun hzToMel(hz: Float): Float = (1127.0 * ln(1.0 + hz / 700.0)).toFloat()
    private fun melToHz(mel: Float): Float = (700.0 * (exp(mel / 1127.0) - 1.0)).toFloat()

    /** 简化 FFT（Cooley-Tukey） */
    private fun fft(real: FloatArray, imag: FloatArray) {
        val n = real.size
        if (n <= 1) return

        // Bit reversal
        var j = 0
        for (i in 1 until n) {
            var bit = n shr 1
            while (j >= bit) {
                j -= bit
                bit = bit shr 1
            }
            j += bit
            if (i < j) {
                val tmpR = real[i]; real[i] = real[j]; real[j] = tmpR
                val tmpI = imag[i]; imag[i] = imag[j]; imag[j] = tmpI
            }
        }

        var len = 2
        while (len <= n) {
            val half = len / 2
            val ang = 2.0 * PI / len
            val wlenR = cos(ang).toFloat()
            val wlenI = sin(ang).toFloat()
            for (i in 0 until n step len) {
                var wR = 1.0f
                var wI = 0.0f
                for (j2 in 0 until half) {
                    val uR = real[i + j2]
                    val uI = imag[i + j2]
                    val vR = real[i + j2 + half] * wR - imag[i + j2 + half] * wI
                    val vI = real[i + j2 + half] * wI + imag[i + j2 + half] * wR
                    real[i + j2] = uR + vR
                    imag[i + j2] = uI + vI
                    real[i + j2 + half] = uR - vR
                    imag[i + j2 + half] = uI - vI
                    val nextWR = wR * wlenR - wI * wlenI
                    val nextWI = wR * wlenI + wI * wlenR
                    wR = nextWR
                    wI = nextWI
                }
            }
            len = len shl 1
        }
    }
}
