# 快速开始指南

## 1. 给后端添加 CORS 支持（重要）

由于 APP 的 WebView 加载的是本地 `file://` 页面，向远程服务器发送请求时会触发 **CORS 跨域限制**。

请在 `app_zyx.py` 中添加以下代码（放在 `app = FastAPI()` 之后即可）：

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境请限制为具体域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

## 2. 启动后端服务

```bash
cd webapp_v2
pip install -r requirements.txt
python app_zyx.py
```

默认监听 `0.0.0.0:8000`，确保防火墙放行 8000 端口。

## 3. 查看服务器 IP 地址

**Windows:**
```cmd
ipconfig
```
找 `IPv4 地址`，例如 `192.168.1.100`

**Linux/macOS:**
```bash
ip addr show
# 或
ifconfig
```

## 4. 编译 APK

### 方式 A：Android Studio（推荐）
1. 下载并安装 [Android Studio](https://developer.android.com/studio)
2. 打开 `android_app` 文件夹
3. 等待 Gradle 同步（首次可能较慢）
4. 连接手机或启动模拟器
5. 点击 Run 按钮（▶）或 Build -> Build APK

### 方式 B：命令行（需已配置 Android SDK）
```bash
cd android_app
./gradlew assembleDebug
# APK 输出在: app/build/outputs/apk/debug/app-debug.apk
```

## 5. 安装到手机

```bash
adb install app/build/outputs/apk/debug/app-debug.apk
```

或使用 Android Studio 直接 Run 到已连接设备。

## 6. 首次使用配置

1. 打开 APP
2. 点击右上角 **⚙️ 设置**
3. 输入服务器地址，例如：`http://192.168.1.100:8000`
4. 点击 **保存**
5. 返回主界面，点击 **开始监听**

## 7. 测试连通性

在手机的浏览器中访问：
```
http://<服务器IP>:8000
```

如果能看到页面，说明网络连通。然后再用 APP 测试。

## 注意事项

- 手机和服务器必须在 **同一局域网** 内（连同一个 WiFi）
- 如果服务器有防火墙，需要开放 8000 端口
- 如果服务器是 Windows，可能需要在防火墙设置中允许 Python 通过
