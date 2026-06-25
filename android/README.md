# 实时环境音识别 - Android 构建指南

## 📱 项目概述

将 PC 端的 Python 深度学习模型打包为 **Android APK**，在手机上实现离线环境音实时识别。

**技术栈：**
- PyTorch Mobile (Android Lite) 模型推理
- Kotlin 原生音频录制 + 预处理（替代 librosa）
- WebView 前端界面（与 PC 网页一致）
- JS Bridge 原生 ↔ 前端通信

---

## 📁 目录结构

```
audio_demo_package/
├── android/                          ← Android 项目
│   ├── app/
│   │   ├── build.gradle
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       ├── assets/
│   │       │   ├── models/         ← 转换后的 .pt 模型文件
│   │       │   │   ├── efficientat_lite.pt
│   │       │   │   ├── panns_cnn6.pt
│   │       │   │   └── mobilenetv1.pt
│   │       │   └── index.html      ← Android 前端页面
│   │       ├── java/com/example/audio/
│   │       │   ├── MainActivity.kt
│   │       │   ├── AudioRecorder.kt   (Android AudioRecord)
│   │       │   ├── AudioPreprocessor.kt (Mel Spectrogram 原生实现)
│   │       │   ├── ModelInference.kt    (PyTorch Mobile 推理)
│   │       │   └── JsBridge.kt        (WebView 通信桥)
│   │       └── res/layout/activity_main.xml
│   ├── build.gradle
│   └── settings.gradle
├── webapp/
│   ├── models/                     ← 原始 .pth 模型
│   └── convert_models.py           ← 模型转换脚本
```

---

## 🔧 构建步骤

### 第 1 步：转换模型（必须）

```bash
cd webapp
python convert_models.py
```

这会读取 `webapp/models/` 下的三个 `.pth` 文件，转换为 Android 可用的 TorchScript `.pt` 格式，输出到 `android/app/src/main/assets/models/`。

> ✅ 如果已完成转换，可跳过此步。

---

### 第 2 步：安装 Android Studio

1. 下载 [Android Studio](https://developer.android.com/studio)
2. 安装时勾选 **Android SDK**、**Android SDK Platform** 和 **Android Virtual Device**
3. 安装完成后，打开 SDK Manager，确保安装了：
   - **SDK Platforms**: Android 13.0 (API 33) 或 Android 14.0 (API 34)
   - **SDK Tools**: Android SDK Build-Tools, Android Emulator, Android SDK Platform-Tools

---

### 第 3 步：打开项目并构建

1. 打开 **Android Studio**
2. 选择 **Open** → 定位到 `audio_demo_package/android` 文件夹
3. 等待 Gradle 同步完成（首次可能需要下载大量依赖，约 5-10 分钟）
4. 同步完成后，点击菜单栏：
   ```
   Build → Build Bundle(s) / APK(s) → Build APK(s)
   ```
5. 构建成功后，APK 文件位于：
   ```
   android/app/build/outputs/apk/debug/app-debug.apk
   ```

---

### 第 4 步：安装到手机

**方式 A：通过 Android Studio 直接安装**
1. 用 USB 连接手机，开启 **开发者选项** → **USB 调试**
2. 点击工具栏的绿色 ▶ 按钮（Run 'app'）

**方式 B：手动安装 APK**
```bash
adb install android/app/build/outputs/apk/debug/app-debug.apk
```

**方式 C：传输 APK 到手机安装**
- 将 `app-debug.apk` 发送到手机
- 在手机上点击安装（需允许安装未知来源应用）

---

## 🧪 测试 APK

安装后打开 App，确保：
1. **授予麦克风权限**（首次启动会弹窗）
2. 选择识别引擎（EfficientAT / PANNs / MobileNet）
3. 点击「开始」按钮
4. 对着手机麦克风发出目标声音（警报、婴儿哭声、汽车鸣笛等）
5. 观察检测结果是否显示在记录面板中

---

## ⚠️ 已知限制

| 问题 | 说明 |
|------|------|
| 模型大小 | 每个 `.pt` 模型约 10-20MB，APK 体积约 50-80MB |
| 预处理精度 | Android 原生 Mel 频谱实现为简化版，与 PC 版 librosa 略有差异，可能影响识别精度 |
| 设备性能 | 在低端设备上推理可能较慢（3 秒音频约 1-2 秒处理时间）|
| 麦克风采样 | 固定 16kHz 单声道，与 PC 版一致 |
| 首次启动 | 模型从 assets 复制到缓存目录，首次启动可能耗时 2-3 秒 |

---

## 🔧 可能遇到的问题

### 1. `LiteModuleLoader` 找不到

**原因：** PyTorch Mobile 依赖未正确下载。

**解决：** 在 `android/app/build.gradle` 中确认依赖已添加：
```gradle
implementation 'org.pytorch:pytorch_android_lite:1.13.0'
```
然后点击 **File → Sync Project with Gradle Files**。

### 2. `ClassNotFoundException: com.facebook.soloader`

**解决：** 添加 SoLoader 依赖：
```gradle
implementation 'com.facebook.soloader:soloader:0.10.5'
```

### 3. 模型推理失败 / 输出异常

**原因：** TorchScript 模型与 Android 版本不兼容。

**解决：** 确保转换时的 PyTorch 版本与 Android 依赖版本一致。当前使用 PyTorch 1.13 (LTS)。如果 PC 端 torch 版本更高，需要：
```bash
pip install torch==1.13.0 torchvision==0.14.0
python convert_models.py
```

### 4. APK 体积过大

**解决：** 在 `build.gradle` 中启用 ABI 过滤，只保留 arm64：
```gradle
android {
    defaultConfig {
        ndk {
            abiFilters 'arm64-v8a'
        }
    }
}
```

---

## 📝 自定义修改

### 添加新模型
1. 在 `webapp/models.py` 定义模型结构
2. 在 `convert_models.py` 中添加转换逻辑
3. 在 `ModelInference.kt` 中添加模型加载和推理分支
4. 在 `index.html` 的 `<select>` 中添加选项

### 修改前端界面
直接编辑 `android/app/src/main/assets/index.html`，修改后重新构建 APK 即可。

---

## 📚 相关链接

- [PyTorch Mobile Android](https://pytorch.org/mobile/android/)
- [Android Studio 下载](https://developer.android.com/studio)
- [AudioRecord API](https://developer.android.com/reference/android/media/AudioRecord)
