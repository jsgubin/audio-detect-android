# 声感指环 (ringapp)

Android App：手机系统声音通知 → 指环震动提醒。

## 工作原理

```
Android 系统「声音通知」(辅助功能)
    ↓ 发出通知
NotificationListenerService (SoundNotificationService)
    ↓ 拦截通知，解析文字
SoundTypeParser (多语言关键词匹配)
    ↓ 提取声音类别
RingBLEManager (BLE GATT)
    ↓ 写入震动指令
指环震动
```

## 模块结构

```
ringapp/src/main/java/com/ringapp/
├── MainActivity.kt              # 主界面：权限引导、BLE 扫描连接、日志
├── SoundNotificationService.kt  # NotificationListenerService，拦截系统声音通知
├── SoundTypeParser.kt           # 多语言声音类别解析器（中文/英文）
├── SoundCategory.kt             # 声音类别枚举 + 震动模式映射
├── RingBLEManager.kt            # BLE 扫描、连接、震动指令发送
├── RingBLEConfig.kt             # BLE 协议配置（UUID 等）
└── RingForegroundService.kt     # 前台服务，保持 BLE 后台连接
```

## 关键设计

### 1. 声音识别：不自己跑模型
直接利用手机系统已有的声音识别能力：
- Android 14+ 辅助功能中的「声音通知」(Settings → Accessibility → Sound Notifications)
- `NotificationListenerService` 拦截系统发出的声音通知
- `SoundTypeParser` 从通知文字中提取声音类别

### 2. 指环 BLE 通信
- BLE 协议通过 `RingBLEConfig` 配置，修改 UUID 即可适配不同指环固件
- 震动指令格式：`[版本, 命令, 震动模式, 强度, 重复次数, 校验和]`
- 自动重连：断连后最多尝试 5 次

### 3. 后台运行
- `RingForegroundService` 前台服务 + WakeLock 保持 BLE 连接
- 常驻通知显示连接状态

## 构建

```bash
./gradlew :ringapp:assembleDebug
```

输出 APK：`ringapp/build/outputs/apk/debug/ringapp-debug.apk`

## 首次使用

1. 安装 APK 后打开 App
2. 点击「前往设置」开启通知监听权限（必须手动在系统设置中授权）
3. 确保手机系统为 Android 14+，并在「设置 → 辅助功能 → 声音通知」中开启
4. 点击「开始扫描」搜索指环 BLE 设备
5. 点击找到的指环设备连接
6. 此时环境中的声音被系统检测到时，指环会自动震动
