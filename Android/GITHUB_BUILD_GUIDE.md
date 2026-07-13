# GitHub Actions 自动编译 APK 指南

## ✅ 方案优势

- **无需本地安装任何环境**（不用装 JDK、Android Studio、SDK）
- **云端自动编译**：push 代码到 GitHub，Actions 自动出 APK
- **下载 APK**：编译完成后直接下载到手机安装
- **免费**：GitHub Actions 免费额度足够用

---

## 📁 需要 push 到 GitHub 的文件

确保以下文件都在你的仓库里：

```
audio-detect-android/Android/                  ← 项目根目录
├── .github/workflows/build-apk.yml            ← GitHub Actions 配置（已创建）
├── android_offline/                           ← 离线 APK 项目
│   ├── app/
│   │   ├── build.gradle.kts
│   │   ├── proguard-rules.pro
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       ├── assets/
│   │       │   ├── efficientat_lite.pt        ← 6.2 MB 模型
│   │       │   ├── mel_filter_bank.bin
│   │       │   ├── hann_window.bin
│   │       │   └── labels.txt
│   │       ├── java/com/audioapp/
│   │       │   ├── AudioRecorder.kt
│   │       │   ├── MainActivity.kt
│   │       │   ├── MelSpectrogram.kt
│   │       │   └── ModelInference.kt
│   │       └── res/layout/activity_main.xml
│   ├── build.gradle.kts
│   ├── settings.gradle.kts
│   ├── gradle.properties
│   ├── gradlew / gradlew.bat
│   └── gradle/wrapper/
│       ├── gradle-wrapper.jar
│       └── gradle-wrapper.properties
├── models/                                    ← 模型源文件（可选）
│   └── efficientat_lite_v3.pth
├── convert_for_android.py                     ← 转换脚本（可选）
└── README.md
```

---

## 🚀 步骤

### 1. 将代码推送到 GitHub

如果你已经有 GitHub 仓库：

```bash
cd /c/Users/jsgub/Documents/GitHub/audio-detect-android

# 确保 .github/workflows 目录已创建
mkdir -p .github/workflows

# 添加 GitHub Actions 文件（已创建）
git add .github/workflows/build-apk.yml

# 添加 android_offline 项目
git add android_offline/

# 提交并推送
git commit -m "Add GitHub Actions for APK build"
git push origin main
```

如果你还没有 GitHub 仓库：

```bash
cd /c/Users/jsgub/Documents/GitHub/audio-detect-android

# 初始化仓库
git init

# 添加远程仓库（替换 YOUR_USERNAME 和 REPO_NAME）
git remote add origin https://github.com/YOUR_USERNAME/REPO_NAME.git

# 添加所有文件（注意：不要上传 350MB 的 AST 模型）
git add .github/workflows/build-apk.yml
git add android_offline/
git add models/efficientat_lite_v3.pth   # 如果需要保留源模型
git add README.md

# 提交
git commit -m "Initial commit with offline APK project"

# 推送
git push -u origin main
```

### 2. 触发编译

推送后，GitHub Actions 会自动触发编译。你也可以手动触发：

1. 打开 GitHub 仓库页面
2. 点击 **Actions** 标签
3. 选择 **Build Android APK**
4. 点击 **Run workflow** → 选择分支 → 点击 **Run workflow**

### 3. 等待编译完成

- 首次编译需要下载 Gradle 和依赖（约 5-10 分钟）
- 后续编译会快很多（约 1-3 分钟）
- 可以在 Actions 页面查看实时日志

### 4. 下载 APK

编译成功后：

1. 在 Actions 页面点击最新的 workflow run
2. 滚动到最下方 **Artifacts** 区域
3. 点击 **app-debug-apk** 下载 ZIP 文件
4. 解压 ZIP，得到 `app-debug.apk`
5. 发送到手机安装即可

---

## ⚠️ 常见问题

### Q: Actions 编译失败，提示找不到 `org.pytorch:pytorch_android:1.12.1`

A: 修改 `android_offline/app/build.gradle.kts`，换成其他版本试试：

```kotlin
// 尝试这些版本之一
implementation("org.pytorch:pytorch_android:1.12.0")
implementation("org.pytorch:pytorch_android:1.13.0")
implementation("org.pytorch:pytorch_android:1.10.0")
```

改完后 push 到 GitHub，Actions 会自动重新编译。

### Q: Actions 编译失败，提示找不到 JTransforms

A: 修改 `android_offline/app/build.gradle.kts`：

```kotlin
// 备选坐标
implementation("org.jtransforms:jtransforms:3.1")
// 或者去掉 JTransforms，用 Android 自带的 FFT 实现
```

### Q: 模型文件太大（6MB），GitHub 上传慢

A: 6MB 完全在 GitHub 的接受范围内（单个文件限制 100MB）。如果嫌慢，可以：
- 用 Git LFS 管理（不推荐，6MB 没必要）
- 或者把模型从 Git 中排除，每次编译前手动用 Actions 下载（更复杂）

### Q: APK 编译成功但安装后运行报错

A: 查看 APK 是否正确包含了模型文件：
```bash
# 在 Actions 日志中查看编译输出
# 或者下载 APK 后检查：
unzip -l app-debug.apk | grep assets
```

应该能看到 `assets/efficientat_lite.pt` 等文件。

### Q: 怎么编译 Release 版（带签名）？

A: 当前 workflow 只编译 debug 版。如果要 release 签名版，需要：
1. 在 GitHub Settings → Secrets 中添加签名密钥
2. 修改 workflow 添加签名步骤

```yaml
# 在 workflow 中添加（可选）
- name: Sign APK
  uses: r0adkll/sign-android-release@v1
  with:
    releaseDirectory: android_offline/app/build/outputs/apk/release
    signingKeyBase64: ${{ secrets.SIGNING_KEY }}
    alias: ${{ secrets.ALIAS }}
    keyStorePassword: ${{ secrets.KEY_STORE_PASSWORD }}
```

---

## 📊 编译时间估算

| 步骤 | 首次 | 后续 |
|------|------|------|
| 下载 JDK 17 | 30s | 缓存 |
| 下载 Android SDK | 60s | 缓存 |
| Gradle 下载 | 30s | 缓存 |
| 下载依赖（PyTorch + JTransforms） | 3-5 min | 缓存 |
| 编译 APK | 1-2 min | 1 min |
| **总计** | **~8-10 min** | **~2-3 min** |

---

## 📝 提示

- **不要**上传 AST 模型（329MB），会超出 GitHub 限制
- **不要**上传 `.idea`、`.gradle` 等本地缓存目录（已在 `.gitignore` 中）
- 每次修改 `android_offline/` 下的代码后 push，Actions 会自动重新编译
- 可以设置 Actions 只在特定分支触发（如 `main`），修改 `.github/workflows/build-apk.yml` 中的 `on.push.branches`
