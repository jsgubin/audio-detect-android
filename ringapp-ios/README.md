# 声感指环 iOS 版

iOS App：iPhone 内建声音识别 → 指环震动提醒。

## 工作原理

```
iPhone 麦克风
    ↓
SoundAnalysis 框架 (SNAudioStreamAnalyzer + SNClassifySoundRequest)
    ↓ Apple 内建模型（300+ 声音类别，完全本地运行，不联网）
SoundClassifier 回调
    ↓
NotificationManager 发送本地通知
    ↓ iPhone 通知中心
ANCS 蓝牙协议 (Apple Notification Center Service)
    ↓
指环震动
```

## 与 Android 版的区别

| | Android (ringapp) | iOS (ringapp-ios) |
|---|---|---|
| 声音识别 | Android 14+ 系统「声音通知」 | Apple SoundAnalysis 框架 |
| 指环通信 | BLE GATT 直连（写 Characteristic） | ANCS 协议（通知转发） |
| 后台运行 | NotificationListenerService + ForegroundService | 后台音频模式 |
| 声音类别数 | 取决于厂商 ROM | 300+（Apple 内建模型） |

## 项目结构

```
RingApp/
├── RingApp.swift              # @main App 入口，绑定分类器→通知
├── ContentView.swift          # SwiftUI 主界面
├── SoundClassifier.swift      # SoundAnalysis 核心逻辑
├── SoundCategory.swift        # 声音类别枚举（17 类 + 震动映射）
├── NotificationManager.swift  # 本地通知发送（→ ANCS → 指环）
└── Info.plist                 # 麦克风权限 + 后台音频
```

## 构建和安装

1. 在 Mac 上用 Xcode 打开 `ringapp-ios` 目录
2. 选择你的开发团队（Signing & Capabilities）
3. 连接 iPhone（需 iOS 15+）
4. Cmd+R 构建运行

## 首次使用

1. 打开 App → 允许麦克风权限
2. 允许通知权限（指环需要通过 ANCS 接收通知）
3. 选择要监听的声音类别（默认勾选了紧急类别）
4. 点击「开始监听」
5. App 进入后台后仍会继续监听（后台音频模式）

## 指环通信说明

iOS 版**不直接通过 BLE GATT 控制指环**，而是通过 Apple 的通知系统间接通信：

1. App 检测到声音后发送**本地通知**到 iPhone 通知中心
2. 通知中包含 `sound_type`、`vibration_pattern`、`priority` 等字段
3. 指环作为 BLE 外设，通过 **ANCS（Apple Notification Center Service）** 协议获取这些通知
4. 指环固件解析通知的 `userInfo` 字段，执行对应的震动模式

如果你的指环不包含 ANCS 支持，需要改用 CoreBluetooth 直连方式（类似 Android 版的 BLE GATT）。
