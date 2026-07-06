package com.audioapp

import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

class SettingsActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)

        val editText = findViewById<EditText>(R.id.serverUrlInput)
        val saveBtn = findViewById<Button>(R.id.saveBtn)
        val testBtn = findViewById<Button>(R.id.testBtn)

        // 加载已保存的设置
        val prefs = getSharedPreferences("app_config", MODE_PRIVATE)
        val savedUrl = prefs.getString("server_url", "http://192.168.1.100:8000")
        editText.setText(savedUrl)

        saveBtn.setOnClickListener {
            val url = editText.text.toString().trim()
            if (url.isEmpty()) {
                Toast.makeText(this, "请输入服务器地址", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            prefs.edit().putString("server_url", url).apply()
            Toast.makeText(this, "保存成功", Toast.LENGTH_SHORT).show()
            finish()
        }

        testBtn.setOnClickListener {
            val url = editText.text.toString().trim()
            if (url.isEmpty()) {
                Toast.makeText(this, "请输入服务器地址", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            Toast.makeText(this, "正在测试连接...", Toast.LENGTH_SHORT).show()
            // 实际测试需要在JS中通过fetch实现，这里仅作提示
        }
    }
}
