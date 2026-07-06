# 环境音识别 - Android APK 转换方案

本项目提供 **两种** 将 Web 服务转换为 Android APK 的方案，请根据实际需求选择。

---

## 📋 项目现状分析

| 组件 | 说明 | 大小 |
|------|------|------|
| 后端框架 | FastAPI + PyTorch + librosa + transformers | - |
| EfficientAT 模型 | zyx 的 Mel 频谱分类模型 | ~6 MB |
| MobileNetV1 模型 | jmy 的 log-Mel 分类模型 | ~13 MB |
| AST 模型 | xyr 的 HuggingFace Transformers 模型 | ~329 MB |
| **模型总计** | | **~350 MB** |

> ⚠️ **关键问题**：3 个深度学习模型 + PyTorch + transformers + librosa 等依赖在 Android 原生环境下运行存在重大技术挑战。

---

## ✅ 方案1：WebView 封装 + 远程 API（⭐ 推荐）

**思路**：将前端页面打包到 APK 中，后端推理服务部署在远程服务器（或本地局域网内的电脑）上，APP 通过 HTTP 调用后端 API。

### 优点
- ✅ APK 极小（~5 MB）
- ✅ 无需改动现有模型和后端代码
- ✅ 推理性能与 Web 版完全一致
- ✅ 编译简单，成功率高

### 缺点
- ❌ 需要网络连接（可部署在局域网内）
- ❌ 后端服务需要一直运行

### 文件结构
```
android_app/
├── app/
│   ├── build.gradle.kts
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── assets/index.html          # 前端页面（已适配移动端）
│       ├── java/com/audioapp/
│       │   ├── MainActivity.kt        # 主界面（WebView）
│       │   ├── SettingsActivity.kt    # 服务器设置
│       │   └── WebAppInterface.kt     # JS 与 Android 通信接口
│       └── res/
│           ├── layout/
│           │   ├── activity_main.xml
│           │   └── activity_settings.xml
│           └── values/
│               ├── colors.xml
│               ├── strings.xml
│               └── themes.xml
├── build.gradle.kts
├── settings.gradle.kts
└── gradle.properties
```

### 编译步骤

#### 前提条件
1. 安装 **Android Studio**（https://developer.android.com/studio）
2. 安装 **JDK 17** 或更高版本
3. 安装 **Android SDK**（通过 Android Studio 的 SDK Manager）

#### 编译
```bash
# 1. 用 Android Studio 打开 android_app 目录
# File -> Open -> 选择 android_app 文件夹

# 2. 等待 Gradle 同步完成

# 3. 连接 Android 手机（开启 USB 调试），或启动模拟器

# 4. 点击工具栏的 "Run" 按钮（绿色三角形）
#    或选择 Build -> Build Bundle(s) / APK(s) -> Build APK(s)
```

#### 使用方式
1. **部署后端服务**：在一台电脑/服务器上运行原 Web 服务：
   ```bash
   cd webapp_v2
   pip install -r requirements.txt
   python app_zyx.py
   ```
   确保手机和服务器在同一 WiFi 下。

2. **配置服务器地址**：打开 APP，点击右上角 **⚙️ 设置**，输入服务器地址：
   - 例如：`http://192.168.1.100:8000`
   - 用手机浏览器访问 `http://服务器IP:8000` 测试连通性

3. **开始使用**：返回主界面，选择模型引擎，点击 **开始监听**。

---

## ⚠️ 方案2：全离线打包（实验性 / 不推荐）

**思路**：使用 Python-for-Android (P4A) + Kivy 将整个 Python 环境、依赖和模型一起打包进 APK。

### 严重风险提示

| 问题 | 影响 | 解决难度 |
|------|------|---------|
| PyTorch 无官方 P4A recipe | 无法直接在 Android 上运行 PyTorch | 🔴 极高 |
| transformers 依赖复杂 | 大量子依赖在 Android 上无法编译 | 🔴 极高 |
| librosa 依赖 C 扩展 | 需要 sndfile、ffmpeg 等原生库 | 🟠 高 |
| AST 模型 329MB | APK 超 400MB，远超 Google Play 150MB 限制 | 🟡 中 |
| 内存占用 | 加载 350MB 模型后手机可能 OOM | 🟠 高 |

> 🔴 **强烈不建议直接使用此方案**，除非你有丰富的 Android NDK/P4A 开发经验。

### 更可行的离线替代思路

如果你真的需要**完全离线运行**，建议：

1. **模型转换路线**：
   ```
   PyTorch (.pth) -> ONNX -> TensorFlow Lite (.tflite)
   ```
   然后用 **Kotlin/Java + TFLite Android Interpreter** 重写推理逻辑。
   - EfficientAT (6MB) 和 MobileNetV1 (13MB) 转换相对容易
   - AST (329MB) 基于 HuggingFace，转换困难且体积太大

2. **Chaquopy 路线**：
   使用 [Chaquopy](https://chaquo.com/chaquopy/)（Android 上的 Python 环境），它对 PyTorch 的支持比 P4A 更好，但商业使用需付费。

3. **仅保留小模型**：
   去掉 AST 模型，只保留 EfficientAT + MobileNetV1（共 19MB），然后用 Chaquopy 或自行编译 P4A recipe。

### 文件结构
```
android_offline/
├── buildozer.spec       # Buildozer 配置文件
└── main.py              # Kivy 应用入口（框架代码）
```

---

## 🔧 推荐的部署架构

### 局域网模式（无需互联网）
```
┌─────────────────┐      WiFi/LAN      ┌─────────────────────┐
│   Android APP   │  ───────────────>  │  电脑/树莓派/服务器  │
│  (WebView APK)  │     HTTP POST      │  python app_zyx.py  │
│    ~5 MB        │  <───────────────  │    模型 + FastAPI   │
└─────────────────┘    JSON 结果        └─────────────────────┘
```

### 公网模式（随时随地使用）
将后端部署到云服务器（阿里云/腾讯云/AWS 等），APP 配置公网域名即可。

---

## 📝 后续优化建议

1. **支持 HTTPS**：生产环境请为后端配置 HTTPS（可用 Let's Encrypt 免费证书），并将 APP 中 `android:usesCleartextTraffic="true"` 移除。

2. **添加心跳检测**：在 `SettingsActivity` 中添加真正的服务器连通性测试（ping `/` 或 `/predict`）。

3. **本地缓存结果**：添加 SQLite 本地数据库，保存识别历史记录。

4. **推送通知**：检测到重要声音（如 gun_shot、glass_shatter）时，发送系统通知。

5. **后台运行**：使用 Android Foreground Service 实现锁屏后持续监听。

---

## ❓ 常见问题

**Q: 为什么不用直接把 Python 后端一起打包进 APK？**  
A: PyTorch + transformers + librosa 在 Android 上没有现成的打包方案，且 350MB 模型会让 APK 巨大无比。WebView + 远程 API 是最务实的选择。

**Q: 后端服务一定要部署在服务器上吗？**  
A: 不一定。如果你的手机和电脑连同一个 WiFi，直接运行 `python app_zyx.py`，然后在 APP 里填电脑的局域网 IP 即可。

**Q: 录音有延迟吗？**  
A: 和 Web 版一致：EfficientAT / MobileNetV1 约 3 秒一段，AST 约 10 秒一段。局域网内 HTTP 延迟通常 < 50ms，可忽略。

**Q: 可以发布到应用商店吗？**  
A: 方案1 的 APK 完全可以发布到各大应用商店（Google Play、华为、小米等）。
