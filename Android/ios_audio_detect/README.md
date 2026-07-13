# iOS 声音识别 + 智能指环联动 App

利用 iPhone 的 `SoundAnalysis` 框架实时识别环境声音，检测到目标声音后发送系统通知，智能指环通过 **ANCS（Apple Notification Center Service）** 协议自动接收通知并震动。

---

## 📱 功能概述

| 功能 | 实现方式 |
|------|---------|
| 声音识别 | `SNAudioStreamAnalyzer` + Apple 内置声音分类模型（iOS 15+） |
| 监听控制 | 用户选择要监听的声音类别，一键开始/停止 |
| 通知推送 | `UNUserNotificationCenter` 发送本地通知 |
| 指环震动 | 指环通过 ANCS 蓝牙协议自动抓取 iPhone 通知并震动 |
| 置信度阈值 | 可调节，减少误报 |

---

## 🎯 与系统"辅助功能 → 声音识别"的区别

| 特性 | 系统辅助功能 | 本 App |
|------|-------------|--------|
| 可控性 | 必须在系统设置中开关 | App 内直接控制 |
| 自定义 | 只能选 Apple 预设类别 | 可自定义阈值、组合 |
| 通知方式 | 系统弹窗 | 系统弹窗 + 本地通知（ANCS） |
| 后台运行 | 系统级，稳定 | 需要 App 在前台或后台音频模式 |
| 扩展性 | 无法扩展 | 可扩展为自定义模型（CoreML） |

> ⚠️ **本 App 不能替代系统辅助功能的声音识别**。它是在 App 内部独立运行的识别引擎，使用 Apple 的 `SoundAnalysis` 框架。

---

## 📁 项目结构

```
ios_audio_detect/
├── AudioDetect/
│   ├── AudioDetectApp.swift      # App 入口 + 通知代理
│   ├── ContentView.swift          # SwiftUI 主界面
│   ├── AudioClassifier.swift      # 声音识别核心（麦克风 + 分析）
│   ├── NotificationManager.swift  # 本地通知发送
│   └── Info.plist                 # 权限声明
└── README.md
```

---

## 🛠️ 开发环境

- **Xcode 15.0+**（需要 iOS 17 SDK 中的 SoundAnalysis 框架）
- **iOS 15.0+**（运行最低版本）
- **Swift 5.9+**
- **macOS**（必须有 Mac 才能编译 iOS App）

---

## 🚀 编译步骤（Mac 上）

### 1. 创建 Xcode 项目

```bash
cd ios_audio_detect

# 创建 Swift Package 项目
swift package init --type executable --name AudioDetect

# 或者直接用 Xcode 创建 iOS App 项目
# 打开 Xcode → File → New → Project → iOS App
```

### 2. 配置项目

1. 打开 Xcode，创建 **iOS App** 项目
2. 项目名：`AudioDetect`
3. 界面：`SwiftUI`
4. 语言：`Swift`
5. 将 `AudioDetect/` 目录下的 Swift 文件复制到 Xcode 项目中
6. 在 `Info.plist` 中添加麦克风权限描述（已提供）

### 3. 添加依赖

在 Xcode 中：
1. 选中项目 → **Target** → **AudioDetect** → **Frameworks, Libraries, and Embedded Content**
2. 点击 **+** 添加：
   - `SoundAnalysis.framework`
   - `AVFoundation.framework`
   - `UserNotifications.framework`

### 4. 编译运行

1. 连接 iPhone 或选择模拟器
2. 点击 ▶ Run 按钮
3. 首次运行会请求麦克风和通知权限，点击允许

---

## ☁️ GitHub Actions 自动编译（无需 Mac）

GitHub Actions 提供 **macOS runner**，可以在云端编译 iOS App。

### 配置步骤

1. 确保代码已 push 到 GitHub
2. GitHub Actions 会自动触发（`.github/workflows/build-ios.yml`）
3. 在 Actions 页面查看编译结果

### ⚠️ 限制

- GitHub Actions 只能编译 **Debug 版本** 或 **模拟器版本**
- **安装到真机需要 Apple Developer 签名证书**（$99/年）
- 没有签名证书的话，只能：
  - 在 Xcode 模拟器运行
  - 或有 Mac 的情况下用 Free Provisioning 安装到自己的 iPhone

---

## 📲 如何使用

### 第一步：安装 App

- 方式 A：用 Xcode 直接安装到 iPhone（需要 Mac + 数据线）
- 方式 B：通过 TestFlight 分发（需要 Apple Developer 账号）

### 第二步：配置指环

1. 确保你的智能指环已配对并连接到 iPhone
2. 打开指环配套 App（如 RingConn、Oura 等）
3. 进入 `消息提醒 / Notifications` 设置
4. 开启 `系统通知` 或 `其他应用通知`

### 第三步：使用 App

1. 打开 **声音识别** App
2. 选择要监听的声音类别（如婴儿啼哭、敲门声、警报器）
3. 调节置信度阈值（建议 70%）
4. 点击 **开始监听**
5. 当检测到目标声音时，iPhone 会弹通知，同时指环会震动

---

## 🔧 支持的识别类别

Apple 内置声音模型支持以下类别（本 App 已预设常用类别）：

| 类别 | 中文名 | 适用场景 |
|------|--------|---------|
| `baby_crying` | 婴儿啼哭 | 带娃 |
| `knocking` | 敲门声 | 独居老人 |
| `doorbell` | 门铃声 | 听力障碍 |
| `fire_alarm` | 火灾警报 | 安全防护 |
| `smoke_detector` | 烟雾报警 | 火灾预警 |
| `glass_breaking` | 玻璃破碎 | 防盗 |
| `siren` | 警笛声 | 紧急事件 |
| `shouting` | 喊叫声 | 紧急求助 |

---

## ⚠️ 已知限制

1. **后台运行**：iOS 不允许 App 在后台持续录音。App 切换到后台后，声音识别会暂停。解决方案：
   - 保持 App 在前台运行
   - 或使用 `UIBackgroundMode = audio` 在后台继续录音（但会被系统限制，且耗电明显增加）

2. **指环兼容性**：本 App 发送的是**标准 iOS 本地通知**，指环是否能接收取决于指环配套 App 是否支持 ANCS 协议。大多数主流智能指环（如 RingConn、Oura）都支持。

3. **误报**：环境噪音可能导致误报。建议：
   - 提高置信度阈值（如 80%）
   - 只开启真正需要监听的声音类别
   - 避免在嘈杂环境使用

4. **电量消耗**：持续监听麦克风会增加手机耗电量，大约每小时耗电 5-10%。

---

## 🔮 未来扩展

| 功能 | 技术方案 |
|------|---------|
| 自定义模型训练 | 用 CoreML 转换自己的模型（如 EfficientAT） |
| 直接 BLE 控制指环 | 逆向工程指环的 BLE 协议，直接发送震动指令 |
| 远程推送 | 用 PushKit 实现远程服务器触发通知 |
| 手表版本 | 开发 watchOS App，在 Apple Watch 上运行 |

---

## 📄 相关链接

- [Apple SoundAnalysis Documentation](https://developer.apple.com/documentation/soundanalysis)
- [AVAudioEngine Documentation](https://developer.apple.com/documentation/avfoundation/avaudioengine)
- [ANCS Protocol](https://developer.apple.com/library/archive/featuredarticles/ExternalAccessoryPT/Introduction/Introduction.html)

---

## ❓ 常见问题

**Q: 为什么不用系统辅助功能的声音识别？**  
A: 系统辅助功能无法被第三方 App 控制。本 App 提供独立的识别引擎，用户可以在 App 内自由配置，不需要跳转到系统设置。

**Q: 我的指环没有配套 App，能震动吗？**  
A: 不能。指环必须通过配套 App 接收 iPhone 通知。如果指环没有 iOS App，则无法使用此方案。

**Q: 可以识别更多自定义声音吗？**  
A: Apple 内置模型只支持预设类别。如果要识别自定义声音（如你的猫叫声），需要：
1. 自己训练 CoreML 模型
2. 或用第三方 ML 框架（如 TensorFlow Lite）

**Q: 为什么不用 Android？**  
A: Android 没有内置的声音识别框架（不像 iOS 有 SoundAnalysis）。Android 上需要自己训练模型（如我们之前的 PyTorch Mobile 方案）。
