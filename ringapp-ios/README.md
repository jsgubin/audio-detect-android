# 声感指环 iOS 版

iOS App：系统声音识别 → Shortcuts 自动化 → 指环震动。

## 核心设计

**不自己跑声音识别模型。** 利用 iOS 系统自带的「声音识别」功能（辅助功能），通过 Shortcuts 自动化桥接，将检测结果转发给指环。

## 工作原理

```
iPhone 环境声音
    ↓
iOS 系统「声音识别」(设置 → 辅助功能 → 声音识别)
    ↓ 检测到声音后触发
Shortcuts 自动化
    ↓ 调用
SendSoundAlertIntent (AppIntent)
    ↓ 发送
本地通知 (UNUserNotificationCenter)
    ↓ ANCS 蓝牙协议
指环震动
```

## 与 Android 版的对应关系

| | Android (ringapp) | iOS (ringapp-ios) |
|---|---|---|
| 声音识别 | 系统「声音通知」(Android 14+) | 系统「声音识别」(辅助功能) |
| 识别结果桥接 | NotificationListenerService | Shortcuts 自动化 + AppIntent |
| 指环通信 | BLE GATT 直连 | ANCS 协议 |
| 自己跑模型 | ❌ 不跑 | ❌ 不跑 |

## 项目结构

```
RingApp/
├── RingApp.swift              # @main 入口，请求通知权限
├── ContentView.swift          # 设置引导界面（3 步指南）
├── SoundCategory.swift        # 声音类别（13 类，AppEnum）
├── SoundDetectionIntent.swift # AppIntent + Shortcuts 入口
├── NotificationManager.swift  # 本地通知 → ANCS → 指环
└── Info.plist                 # App 配置
```

## 首次设置（3 步）

### 1. 开启系统声音识别
iPhone **设置 → 辅助功能 → 声音识别** → 打开开关

### 2. 创建 Shortcuts 自动化
打开 **Shortcuts（快捷指令）App**：
- 自动化 → 创建个人自动化 → 声音识别
- 选择要检测的声音类别
- 下一步 → 搜索「发送声音警报」
- 选择 → 完成

> ⚠️ 每种声音类别需要单独创建一条自动化规则（共可创建约 13 条）。

### 3. 确保指环已连接
指环需支持 ANCS 协议，并已与 iPhone 蓝牙配对。

## 构建

在 Mac 上用 Xcode 打开 `ringapp-ios/` 目录，Cmd+R。

需要 iOS 16+（AppIntents 框架要求）。
