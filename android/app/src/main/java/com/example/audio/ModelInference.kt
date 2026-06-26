package com.example.audio

import android.content.Context
import org.pytorch.IValue
import org.pytorch.LiteModuleLoader
import org.pytorch.Tensor
import java.io.File
import java.io.FileOutputStream

/**
 * PyTorch Mobile 模型推理
 * 支持三种模型：efficientat, panns, mobilenet
 */
class ModelInference(private val context: Context) {

    private var module: org.pytorch.Module? = null
    private var currentModel: String = ""

    val classes = arrayOf(
        "alarm", "baby_cry", "car_horn",
        "doorbell", "glass_shatter", "gun_shot"
    )

    /**
     * 加载模型（从 assets 复制到文件系统后加载）
     */
    fun loadModel(modelName: String) {
        if (modelName == currentModel && module != null) return

        // 释放旧模型（PyTorch Lite 的 Module 没有 close/destroy 方法，直接设为 null 让 GC 回收）
        module = null

        val assetName = when (modelName) {
            "efficientat" -> "models/efficientat_lite.pt"
            "panns" -> "models/panns_cnn6.pt"
            "mobilenet" -> "models/mobilenetv1.pt"
            else -> throw IllegalArgumentException("Unknown model: $modelName")
        }

        // 从 assets 复制到缓存目录
        val file = File(context.cacheDir, assetName.substringAfterLast("/"))
        if (!file.exists()) {
            context.assets.open(assetName).use { input ->
                FileOutputStream(file).use { output ->
                    input.copyTo(output)
                }
            }
        }

        module = LiteModuleLoader.load(file.absolutePath)
        currentModel = modelName
    }

    /**
     * 运行推理
     * @return 检测结果列表 [{class, prob}]
     */
    fun run(inputTensor: Tensor, confThreshold: Float): List<Map<String, Any>> {
        val mod = module ?: return emptyList()

        val output = mod.forward(IValue.from(inputTensor)).toTensor()
        val scores = output.dataAsFloatArray

        return when (currentModel) {
            "mobilenet" -> {
                // Softmax 单标签
                val expScores = scores.map { Math.exp(it.toDouble()) }
                val sumExp = expScores.sum()
                val probs = expScores.map { (it / sumExp).toFloat() }
                val maxIdx = probs.indices.maxByOrNull { probs[it] } ?: -1
                if (maxIdx >= 0 && probs[maxIdx] > confThreshold) {
                    listOf(mapOf("class" to classes[maxIdx], "prob" to probs[maxIdx]))
                } else emptyList()
            }
            else -> {
                // Sigmoid 多标签
                val results = mutableListOf<Map<String, Any>>()
                for (i in scores.indices) {
                    val prob = (1.0 / (1.0 + Math.exp(-scores[i].toDouble()))).toFloat() // sigmoid
                    if (prob > confThreshold) {
                        results.add(mapOf("class" to classes[i], "prob" to prob))
                    }
                }
                results.sortByDescending { it["prob"] as Float }
                results
            }
        }
    }

    fun release() {
        // PyTorch Lite 的 Module 没有 close/destroy 方法
        module = null
        currentModel = ""
    }
}
