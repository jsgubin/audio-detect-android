package com.audioapp

import android.content.Context
import android.content.Intent
import android.webkit.JavascriptInterface
import android.widget.Toast

class WebAppInterface(private val context: Context) {

    @JavascriptInterface
    fun getServerUrl(): String {
        val prefs = context.getSharedPreferences("app_config", Context.MODE_PRIVATE)
        return prefs.getString("server_url", "") ?: ""
    }

    @JavascriptInterface
    fun showToast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    @JavascriptInterface
    fun openSettings() {
        context.startActivity(Intent(context, SettingsActivity::class.java))
    }
}
