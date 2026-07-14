# 声感指环 iOS 版

iOS App：系统声音识别 → Shortcuts 自动化 → **CoreBluetooth 直连指环 BLE**。

## 为什么不用 ANCS

ANCS（Apple Notification Center Service）是 Apple 专有的 GATT 服务，
需要指环固件完整实现 ANCS 协议栈才能接收 iPhone 通知。

**你的自研指环使用的是自定义 BLE 协议（固定 Service/Characteristic），
因此 iOS 端和 Android 端一样，通过 CoreBluetooth 直连 BLE GATT**
写入震动指令到指环的 Characteristic。

## 工作原理

```
🎤 环境声音
  → iOS 系统「声音识别」(设置 → 辅助功能 → 声音识别)
    → Shortcuts 自动化
      → SendSoundAlertIntent (AppIntent)
        → RingBLEManager (CoreBluetooth)
          → BLE GATT writeCharacteristic
            → 💍 指环震动
```

如果指环未连接，降级为发送本地通知（手机本身提醒）。

## 与 Android 版的统一

| | Android (ringapp) | iOS (ringapp-ios) |
|---|---|---|
| 声音识别来源 | 系统「声音通知」 | 系统「声音识别」 |
| 结果桥接 | NotificationListenerService | Shortcuts 自动化 + AppIntent |
| 指环通信 | **BLE GATT 直连** | **CoreBluetooth BLE 直连** |
| BLE UUID | `RingBLEConfig.DEFAULT` | `RingBLEConfig.default` |
| 震动指令格式 | `[0x01, 0x01, pattern, intensity, repeat, checksum]` | 相同 |

## 项目结构

```
RingApp/
├── RingApp.swift              # @main 入口
├── ContentView.swift          # 设置引导 + BLE 连接管理
├── SoundCategory.swift        # 声音类别 (AppEnum)
├── SoundDetectionIntent.swift # Shortcuts 调用的 AppIntent
├── RingBLEManager.swift       # CoreBluetooth BLE 管理器
├── RingBLEConfig.swift        # BLE UUID 配置
├── NotificationManager.swift  # 本地通知（兜底提醒）
└── Info.plist                 # 蓝牙权限 + 后台模式
```

## 首次使用

1. 打开 App → 切换到「💍 BLE 指环」Tab → 扫描连接指环
2. 切换到「📋 设置引导」→ 按步骤操作：
   - 开启系统声音识别
   - 创建 Shortcuts 自动化
3. 确认指环已连接（状态栏显示绿色「已连接」）
4. 环境声音被检测到时，指环自动震动

## BLE UUID 配置

如果指环的 BLE UUID 与默认值不同，修改 `RingBLEConfig.swift` 中的 `default` 对象：
```swift
static let `default` = RingBLEConfig(
    serviceUUID: CBUUID(string: "你的 Service UUID"),
    vibrationCharUUID: CBUUID(string: "你的 Characteristic UUID"),
    ...
)
```

与 Android 的 `RingBLEConfig.kt` 保持一致即可。

## 构建

macOS + Xcode 打开 `ringapp-ios/` 目录，Cmd+R。
需要 iOS 16+（AppIntents 要求）。
