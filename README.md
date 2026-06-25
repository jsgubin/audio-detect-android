# 实时环境音识别 Demo（可直接运行版）

这个文件夹包含运行网站所需的最小文件。

## 目录结构

```
webapp/
├── app_zyx.py              # 主程序，运行这个
├── models.py
├── requirements.txt
├── static/
│   └── index.html
└── models/                 # 模型权重（必须）
    ├── efficientat_lite_v3.pth
    ├── panns_cnn6.pth
    └── best_model_v2.pth
```

## 运行步骤

### 1. 安装依赖

```bash
cd webapp
pip install -r requirements.txt
```

### 2. 确保模型文件在正确位置

模型应该放在 `webapp/models/` 目录下（当前代码已支持此结构）。

### 3. 启动服务

```bash
python app_zyx.py
```

服务默认运行在 `http://0.0.0.0:8000`

### 4. 在浏览器中打开

**必须使用以下地址之一**（浏览器麦克风权限限制）：

- http://localhost:8000
- http://127.0.0.1:8000

**不要使用** `192.168.x.x` 或 `0.0.0.0` 直接访问，否则麦克风会无法使用。

## 重要注意事项

- 页面上可以切换三种识别引擎（EfficientAT、PANNs、MobileNetV1）
- 可以实时调节「静音阈值」和「置信度阈值」
- 浏览器会持续录音并每 3 秒发送一次片段进行识别
- 如果环境中没有这 6 类声音（警报、婴儿哭声、汽车鸣笛、门铃、玻璃破碎、枪声），页面不会显示任何结果

## 系统依赖

部分音频格式（浏览器录制的 webm）需要系统安装 `ffmpeg`：

- Ubuntu / Debian: `sudo apt update && sudo apt install ffmpeg`
- macOS: `brew install ffmpeg`
- Windows: 从 https://ffmpeg.org 下载并添加到 PATH

## 打包说明（给打包者）

如果你是打包者，请确保只包含以下内容，不要把训练代码、数据集、特征文件打包进去：

- webapp/ 目录下除 server.log、app.py 之外的所有文件
- models/ 目录下的三个 .pth 文件

训练相关的代码（Audio_v1/train_*.py、dataset/、features/ 等）请不要分享。

## 联系

如有问题请联系原作者。
