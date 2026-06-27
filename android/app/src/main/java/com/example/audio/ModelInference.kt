package com.example.audio

import android.content.Context
import android.util.Log
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
     * @return 是否成功加载
     */
    fun loadModel(modelName: String): Boolean {
        return try {
            if (modelName == currentModel && module != null) {
                Log.d("ModelInference", "Model $modelName already loaded")
                return true
            }

            // 释放旧模型
            module = null

            val assetName = when (modelName) {
                "efficientat" -> "models/efficientat_lite.pt"
                "panns" -> "models/panns_cnn6.pt"
                "mobilenet" -> "models/mobilenetv1.pt"
                else -> throw IllegalArgumentException("Unknown model: $modelName")
            }

            // 从 assets 复制到缓存目录
            val file = File(context.cacheDir, assetName.substringAfterLast("/"))
            if (!file.exists() || file.length() < 1000) {
                Log.d("ModelInference", "Copying model from assets: $assetName")
                context.assets.open(assetName).use { input ->
                    FileOutputStream(file).use { output ->
                        input.copyTo(output)
                    }
                }
                Log.d("ModelInference", "Model copied: ${file.length()} bytes")
            } else {
                Log.d("ModelInference", "Model already cached: ${file.length()} bytes")
            }

            if (file.length() < 1000) {
                Log.e("ModelInference", "Model file too small, may be a Git LFS pointer")
                return false
            }

            module = LiteModuleLoader.load(file.absolutePath)
            currentModel = modelName
            Log.d("ModelInference", "Model $modelName loaded successfully")
            true
        } catch (e: Exception) {
            Log.e("ModelInference", "Failed to load model $modelName", e)
            module = null
            currentModel = ""
            false
        }
    }

    /**
     * 运行推理
     * @return 检测结果列表 [{class, prob}]
     */
    fun run(inputTensor: Tensor, confThreshold: Float): List<Map<String, Any>> {
        return try {
            val mod = module ?: return emptyList()

            val output = mod.forward(IValue.from(inputTensor)).toTensor()
            val scores = output.dataAsFloatArray

            if (scores.isEmpty()) {
                Log.w("ModelInference", "Empty output from model")
                return emptyList()
            }

            if (scores.size != classes.size) {
                Log.w("ModelInference", "Output size mismatch: expected ${classes.size}, got ${scores.size}")
            }

            val validSize = minOf(scores.size, classes.size)

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
                    for (i in 0 until validSize) {
                        val prob = (1.0 / (1.0 + Math.exp(-scores[i].toDouble()))).toFloat()
                        if (prob > confThreshold) {
                            results.add(mapOf("class" to classes[i], "prob" to prob))
                        }
                    }
                    results.sortByDescending { it["prob"] as Float }
                    results
                }
            }
        } catch (e: Exception) {
            Log.e("ModelInference", "Inference failed", e)
            emptyList()
        }
    }

    fun release() {
        module = null
        currentModel = ""
    }
}
