# 环境音识别 - 离线 Android APK（EfficientAT 模型）

本项目将 Web 服务的 EfficientAT 模型转换为 Android 离线 APK，无需网络连接，模型直接在手机上运行。

---

## 🎯 技术方案

| 组件 | 技术方案 | 说明 |
|------|---------|------|
| 模型推理 | PyTorch Mobile (TorchScript) | `efficientat_lite.pt` 加载到手机运行 |
| 音频录制 | Android AudioRecord | 16kHz 16bit 单声道 PCM |
| 频谱提取 | Kotlin 手写 STFT + Mel 滤波器 | 替代 librosa，JTransforms 做 FFT |
| 预处理参数 | 预计算二进制文件 | Mel 滤波器矩阵 + Hann 窗从 assets 加载 |

---

## 📁 项目结构

```
android_offline/                          ← 用 Android Studio 打开此目录
├── gradlew / gradlew.bat                ← Gradle wrapper
├── gradle/wrapper/
│   ├── gradle-wrapper.jar
│   └── gradle-wrapper.properties
├── settings.gradle.kts
├── build.gradle.kts
├── gradle.properties
├── app/
│   ├── build.gradle.kts                  ← 依赖：PyTorch Mobile + JTransforms
│   ├── proguard-rules.pro
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── assets/
│       │   ├── efficientat_lite.pt       ← 6.2 MB 模型（TorchScript）
│       │   ├── mel_filter_bank.bin       ← 128 KB Mel 滤波器矩阵
│       │   ├── hann_window.bin           ← 4 KB Hann 窗
│       │   └── labels.txt                ← 6 个类别标签
│       ├── java/com/audioapp/
│       │   ├── MainActivity.kt           ← 主界面 + 录音循环
│       │   ├── AudioRecorder.kt          ← AudioRecord 录制 PCM
│       │   ├── MelSpectrogram.kt         ← STFT + Mel 提取 + 对数转换
│       │   └── ModelInference.kt         ← PyTorch Mobile 加载 + 推理
│       └── res/
│           ├── layout/activity_main.xml
│           └── values/
│               ├── colors.xml
│               ├── strings.xml
│               └── themes.xml
```

---

## ⚙️ 编译环境准备

### 1. 安装 Android Studio

下载地址：https://developer.android.com/studio

安装时选择：
- **Android SDK**（API 33 或更高）
- **JDK 17**（Android Studio 自带，通常无需额外安装）

### 2. 验证 Java 环境

```bash
java -version
# 应该显示 Java 17 或更高
```

如果提示 `JAVA_HOME` 未设置，Windows 用户可以：
```powershell
# 在 Android Studio 中，File → Settings → Build → Build Tools → Gradle
# 设置 Gradle JDK 为 Android Studio 自带的 JDK
```

---

## 🔨 编译步骤

### 方式 A：Android Studio（推荐）

1. **打开项目**：
   ```
   File → Open → 选择 android_offline 文件夹
   ```

2. **等待 Gradle 同步**：
   - 首次打开会自动下载 Gradle 和依赖（PyTorch Mobile + JTransforms）
   - 如果卡在 `Downloading pytorch_android_lite...`，请耐心等待（约 100 MB）

3. **编译 APK**：
   ```
   Build → Build Bundle(s) / APK(s) → Build APK(s)
   ```

4. **输出路径**：
   ```
   app/build/outputs/apk/debug/app-debug.apk
   ```

### 方式 B：命令行（需已配置环境变量）

```bash
cd android_offline
./gradlew assembleDebug          # Linux/macOS
gradlew.bat assembleDebug        # Windows CMD
```

### 安装到手机

```bash
adb install app/build/outputs/apk/debug/app-debug.apk
```

---

## 📱 使用说明

1. 打开 APP，等待模型加载（首次约 2-5 秒）
2. 点击 **▶ 开始监听**
3. APP 每 3 秒录制一段音频，自动识别 6 种声音：
   - 🚨 警报声、👶 婴儿啼哭、🚗 汽车鸣笛、🚪 门铃声、💥 玻璃破碎、🔫 枪声
4. 点击 **⏹ 停止** 结束监听

---

## 🔧 常见问题

### Q: 编译失败，提示找不到 `org.pytorch:pytorch_android_lite:1.13.0`

A: 尝试改用其他版本：
```kotlin
// app/build.gradle.kts
implementation("org.pytorch:pytorch_android_lite:1.12.0")
// 或
implementation("org.pytorch:pytorch_android:1.12.0")
```

### Q: 编译失败，提示找不到 JTransforms

A: 尝试更换坐标：
```kotlin
// app/build.gradle.kts
implementation("org.github.wendal:jtransforms:3.1")
// 或
implementation("pl.edu.icm:JTransforms:3.1")
```

### Q: 运行时提示 "模型加载失败"

A: 检查 `app/src/main/assets/` 中是否有 `efficientat_lite.pt`（约 6MB）。如果缺失，需要重新运行模型转换脚本。

### Q: 识别结果不准确

A: 离线版使用了 Kotlin 重写的预处理，与 Python 的 librosa 可能存在微小数值差异。如果准确率明显下降，可以检查：
1. `MelSpectrogram.kt` 中的 FFT 解析是否正确
2. `power_to_db` 的参考值是否与训练时一致

---

## 🔄 模型转换（如需重新转换）

如果更新了 `models/efficientat_lite_v3.pth`，需要重新转换：

```python
python convert_for_android.py
# 或手动运行 PythonRun 中的脚本
```

这会重新生成：
- `android_offline/app/src/main/assets/efficientat_lite.pt`
- `android_offline/app/src/main/assets/mel_filter_bank.bin`
- `android_offline/app/src/main/assets/hann_window.bin`

---

## 📊 APK 大小估算

| 组件 | 大小 |
|------|------|
| 模型 (efficientat_lite.pt) | ~6.2 MB |
| PyTorch Mobile 原生库 (arm64) | ~15-20 MB |
| JTransforms | ~2 MB |
| App 代码 + 资源 | ~1 MB |
| **APK 总计** | **~25-30 MB** |

---

## ⚠️ 已知限制

1. 只支持 **EfficientAT** 模型（6 分类），不支持 MobileNetV1 和 AST
2. 当前只支持 **arm64-v8a** 架构，如需支持 armeabi-v7a，需在 `build.gradle.kts` 中修改 `android.arch` 配置
3. 预处理用 Kotlin 重写，与 librosa 存在微小数值差异，理论上不影响准确率
4. 首次启动加载模型需要 2-5 秒

---

## 📝 与原 Web 版的差异

| 项目 | Web 版 | 离线 APK 版 |
|------|--------|------------|
| 网络需求 | 需要后端服务器 | 完全离线 |
| 模型支持 | EfficientAT + MobileNetV1 + AST | 仅 EfficientAT |
| 预处理 | librosa (Python) | Kotlin + JTransforms |
| 推理引擎 | PyTorch (CPU) | PyTorch Mobile (Android) |
| APK 大小 | ~5 MB | ~25-30 MB |
| 延迟 | HTTP 往返 + 推理 | 仅推理（<100ms） |
