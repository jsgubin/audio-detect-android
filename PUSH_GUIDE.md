# GitHub Actions 自动构建 APK - 操作指南

## 重要说明：GitHub 文件上传限制

| 上传方式 | 文件大小限制 | 说明 |
|---------|------------|------|
| **GitHub 网页上传 ZIP** | 25MB | ❌ 您的项目 34MB，超出限制 |
| **`git push` 命令/GitHub Desktop** | 单个文件 100MB | ✅ 完全足够，推荐此方式 |
| **GitHub LFS** | 2GB | 超大文件专用，不需要 |

**结论：使用 `git push` 或 GitHub Desktop 推送代码，没有 25MB 限制。**

---

## 方案 A：GitHub Desktop（推荐，完全图形界面，零命令行）

GitHub Desktop 是 GitHub 官方推出的免费桌面工具，**完全不需要输入任何命令**，鼠标操作即可。

### 步骤：

1. **下载安装 GitHub Desktop**
   - 访问 https://desktop.github.com/
   - 下载 Windows 版并安装

2. **打开 GitHub Desktop，登录 GitHub 账号**
   - 点击 **File → Options → Accounts**
   - 点击 **Sign in to GitHub.com**，按提示登录

3. **添加本地项目**
   - 点击 **File → Add local repository**
   - 点击 **Choose...**，选择文件夹：
     ```
     C:\Users\jsgub\Documents\audio_demo_package
     ```
   - 点击 **Add Repository**

4. **发布到 GitHub**
   - 在 GitHub Desktop 中，点击 **Publish repository**
   - Repository name 填：`audio-detect-android`
   - Description 填：`实时环境音识别 Android App`
   - 如果要私有仓库，勾选 **Keep this code private**
   - 点击 **Publish repository**
   - 等待上传完成（约 1-2 分钟，34MB 文件）

5. **等待自动构建 APK**
   - 打开浏览器，访问 `https://github.com/你的用户名/audio-detect-android`
   - 点击顶部 **Actions** 标签
   - 找到 **Build Android APK** 工作流，查看进度
   - 构建约需 **5-10 分钟**（首次下载依赖较慢）

6. **下载 APK**
   - 构建完成后（显示绿勾 ✓），点击进入该运行记录
   - 滚动到页面底部 **Artifacts**
   - 点击 **app-debug-apk** 下载 ZIP
   - 解压 ZIP，得到 `app-debug.apk`

7. **安装到手机**
   - 将 APK 传输到手机（微信、QQ、数据线等）
   - 在手机上点击安装，允许"安装未知来源应用"
   - 打开 App，授予麦克风权限，开始使用

---

## 方案 B：命令行 git push（备用，适合熟悉命令行的用户）

如果您愿意使用命令行，Git 其实已经存在于系统中：

```bash
cd C:\Users\jsgub\Documents\audio_demo_package
git remote add origin https://github.com/你的用户名/audio-detect-android.git
git branch -M main
git push -u origin main
```

输入密码时，使用 **GitHub Personal Access Token**（不是登录密码）：
1. 访问 https://github.com/settings/tokens
2. 点击 **Generate new token (classic)**
3. 勾选 `repo` 权限
4. 生成后复制，粘贴为密码

---

## 常见问题

### Q: 为什么 GitHub Desktop 可以上传 34MB，而网页上传不行？
**A:** GitHub Desktop 使用 `git push` 协议传输，单个文件限制是 100MB；而网页上传 ZIP 限制是 25MB。这是 GitHub 的两种不同机制。

### Q: 构建失败了怎么办？
**A:** 在 GitHub Actions 页面点击 **Re-run jobs** 重新构建。如果是网络问题，多试一次通常就能成功。

### Q: APK 下载后怎么安装？
**A:** 
- 方式 1：用数据线连接电脑，执行 `adb install app-debug.apk`
- 方式 2：将 APK 发送到手机微信/QQ，在手机上直接点击安装
- 安装时如果提示"未知来源应用"，请前往设置允许

### Q: 模型精度与 PC 版有差异？
**A:** Android 端的 Mel 频谱预处理是原生简化实现，与 PC 版 librosa 可能有微小差异（约 1-3%）。如需完全一致，可在 Actions 中集成完整 torchaudio，但会增大 APK 体积。

---

## 技术说明

| 组件 | 技术选型 |
|------|---------|
| 前端 | WebView + HTML/CSS/JS |
| 后端推理 | PyTorch Mobile Lite (Android) |
| 音频录制 | Android AudioRecord (16kHz, PCM16) |
| 预处理 | 原生 Kotlin 实现 Mel Spectrogram |
| 构建方式 | GitHub Actions + Gradle 8.4 |
| 最低 SDK | Android 8.0 (API 26) |
| 目标 SDK | Android 14 (API 34) |

---

如有问题，请查看 `android/README.md` 获取本地构建的详细说明。
