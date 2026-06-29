package com.example.audio

import android.webkit.WebView
import org.json.JSONArray
import org.json.JSONObject

/**
 * WebView 与 JS 通信桥
 */
class JsBridge(private val webView: WebView) {

    /**
     * 发送检测结果到前端
     */
    fun sendDetections(detections: List<Map<String, Any>>) {
        val jsonArray = JSONArray()
        for (det in detections) {
            val obj = JSONObject()
            obj.put("class", det["class"])
            obj.put("prob", det["prob"])
            jsonArray.put(obj)
        }
        val json = jsonArray.toString()
        evaluateJs("window.receiveDetections($json)")
    }

    /**
     * 通知前端就绪
     */
    fun sendReady() {
        evaluateJs("window.onNativeReady && window.onNativeReady()")
    }

    /**
     * 通知前端状态变化
     */
    fun sendStateChange(state: String) {
        evaluateJs("window.onNativeStateChange && window.onNativeStateChange('$state')")
    }

    /**
     * 发送错误信息
     */
    fun sendError(msg: String) {
        evaluateJs("window.onNativeError && window.onNativeError('${escapeJs(msg)}')")
    }

    /**
     * 发送音量信息
     */
    fun sendVolume(rms: Float) {
        val db = 20 * kotlin.math.log10(rms.toDouble() + 0.0001)
        val pct = kotlin.math.min(100.0, kotlin.math.max(0.0, (db + 60) / 60 * 100))
        evaluateJs("window.updateVolume && window.updateVolume($pct)")
    }

    private fun evaluateJs(script: String) {
        webView.post {
            webView.evaluateJavascript(script, null)
        }
    }

    private fun escapeJs(s: String): String {
        return s.replace("\\", "\\\\")
            .replace("'", "\\'")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
    }
}
