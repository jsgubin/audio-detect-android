package com.audioapp

import android.content.Context
import org.pytorch.IValue
import org.pytorch.Module
import org.pytorch.Tensor
import java.io.File
import java.io.FileOutputStream

/**
 * PyTorch Mobile 模型推理
 * 只加载 EfficientAT_Lite 模型，支持 sigmoid 多标签检测
 */
class ModelInference(private val context: Context) {

    private var module: Module? = null
    private val labels = mutableListOf<String>()
    private val confThreshold = 0.60f

    // 类别中文映射
    private val labelNames = mapOf(
        "alarm" to "🚨 警报声",
        "baby_cry" to "👶 婴儿啼哭",
        "car_horn" to "🚗 汽车鸣笛",
        "doorbell" to "🚪 门铃声",
        "glass_shatter" to "💥 玻璃破碎",
        "gun_shot" to "🔫 枪声"
    )

    init {
        loadModel()
        loadLabels()
    }

    fun isLoaded(): Boolean = module != null

    /**
     * 从 assets 加载模型到本地缓存，然后用 PyTorch Mobile 加载
     */
    private fun loadModel() {
        try {
            val modelPath = assetFilePath("efficientat_lite.pt")
            module = Module.load(modelPath)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun loadLabels() {
        try {
            context.assets.open("labels.txt").bufferedReader().useLines { lines ->
                lines.forEach { labels.add(it.trim()) }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * 推理：输入 Mel 频谱，返回检测到的类别列表
     *
     * @param melData FloatArray[64 * 94]，row-major，来自 MelSpectrogram.extract()
     * @return 检测结果列表，每个元素包含 className 和 probability
     */
    fun predict(melData: FloatArray): List<DetectionResult> {
        val m = module ?: return emptyList()

        // 构建 Tensor: [1, 1, 64, 94]
        val inputTensor = Tensor.fromBlob(
            melData,
            longArrayOf(1, 1, 64, 94)
        )

        // 推理
        val outputTensor = m.forward(IValue.from(inputTensor)).toTensor()
        val outputData = outputTensor.dataAsFloatArray

        // sigmoid 激活 + 阈值过滤
        val results = mutableListOf<DetectionResult>()
        for (i in outputData.indices) {
            val prob = sigmoid(outputData[i])
            if (prob > confThreshold && i < labels.size) {
                val label = labels[i]
                val displayName = labelNames[label] ?: label
                results.add(DetectionResult(displayName, label, prob))
            }
        }

        // 按置信度降序排列
        results.sortByDescending { it.probability }
        return results
    }

    private fun sigmoid(x: Float): Float {
        return (1.0f / (1.0f + kotlin.math.exp(-x)))
    }

    /**
     * 将 assets 中的文件复制到本地缓存，返回可加载的路径
     */
    private fun assetFilePath(assetName: String): String {
        val file = File(context.cacheDir, assetName)
        if (file.exists() && file.length() > 0) {
            return file.absolutePath
        }
        context.assets.open(assetName).use { input ->
            FileOutputStream(file).use { output ->
                val buffer = ByteArray(4 * 1024)
                var read: Int
                while (input.read(buffer).also { read = it } != -1) {
                    output.write(buffer, 0, read)
                }
                output.flush()
            }
        }
        return file.absolutePath
    }

    data class DetectionResult(
        val displayName: String,
        val className: String,
        val probability: Float
    )
}
