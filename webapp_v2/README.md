# webapp_v2 — 实时环境音识别（桌面版，AST 增强版）

在原 `webapp/` 基础上接入 xyr 的 AST 七分类模型并更新 mobilenet 权重后的版本。
原 `webapp/` 保持不动作为备份。

## 识别引擎

| 引擎 | 模型来源 | 采集时长 | 说明 |
|------|---------|---------|------|
| EfficientAT V3 | zyx | 3 秒 | Mel 频谱 + MobileNetV3 backbone，sigmoid 多标签 |
| MobileNetV1 | jmy | 3 秒 | log-Mel + MobileNetV1，softmax 单标签 |
| AST 七分类 | xyr | **10 秒** | HuggingFace Audio Spectrogram Transformer，softmax 单标签 |

- AST 训练时输入固定 10 秒，因此前端在 AST 模式下每 10 秒采集一次，识别延迟较长。
- AST 的 7 类中 `negative`（无事件/背景音）会被自动过滤，不显示。
- 识别目标 6 类：警报、婴儿哭声、汽车鸣笛、门铃、玻璃破碎、枪声。

> PANNs Cnn6 引擎已从此版本中移除（原 `webapp/` 仍有保留）。

## 目录结构

```
webapp_v2/
├── app_zyx.py              # 主程序，运行这个
├── models.py               # EfficientAT / MobileNetV1 模型定义
├── requirements.txt
├── static/
│   └── index.html          # 前端页面
└── models/                 # 模型权重（需要自行补全，见下）
    ├── efficientat_lite_v3.pth
    ├── best_model.pth            # jmy 的 MobileNetV1 权重
    ├── ast_best_model.pt         # xyr 的 AST 权重（329MB）
    └── ast_label_map.json        # AST 类别映射（已随代码入库）
```

## 运行步骤

### 1. 安装依赖

```bash
cd webapp_v2
pip install -r requirements.txt
```

> **注意 `transformers` 版本**：必须用 4.x（如 `4.40.2`）。5.x 会因 sklearn/numpy 冲突导致 AST 模块无法导入。
> 若安装后导入报错，执行：`pip install transformers==4.40.2`

部分音频格式（浏览器录制的 webm）需要系统安装 `ffmpeg`：

```bash
sudo apt install ffmpeg   # Ubuntu/Debian
```

### 2. 补全模型权重

代码仓库**不包含**模型权重文件（`*.pth` / `*.pt` 被 `.gitignore` 排除，AST 权重 329MB 超 GitHub 100MB 限制）。
运行前需要把以下文件放到 `webapp_v2/models/` 目录：

| 文件 | 大小 | 来源 |
|------|------|------|
| `efficientat_lite_v3.pth` | 6 MB | 向 zyx 获取，或从原 `webapp/models/` 复制 |
| `best_model.pth` | 13 MB | jmy 的 MobileNetV1 权重，向 jmy 获取 |
| `ast_best_model.pt` | 329 MB | xyr 的 AST 权重，从 `release_ast_7class/model/best_model.pt` 复制并重命名 |

`ast_label_map.json` 已随代码入库，无需单独获取。

复制 AST 权重的命令（如果项目根目录有 `release_ast_7class/`）：

```bash
cp ../release_ast_7class/model/best_model.pt webapp_v2/models/ast_best_model.pt
```

### 3. 启动服务

```bash
python app_zyx.py
```

服务默认运行在 `http://0.0.0.0:8000`。

### 4. 在浏览器中打开

**必须使用以下地址之一**（浏览器麦克风权限限制）：

- http://localhost:8000
- http://127.0.0.1:8000

**不要使用** `192.168.x.x` 或 `0.0.0.0` 直接访问，否则麦克风会无法使用。

## 与原 webapp 的差异

- 新增 AST 七分类引擎（xyr 模型，HuggingFace transformers）
- MobileNetV1 权重从 `best_model_v2.pth` 更新为 `best_model.pth`
- 移除 PANNs Cnn6 引擎（前端选项 + 后端加载 + 推理分支）
- 启动横幅提示从 `cd webapp` 改为 `cd webapp_v2`

## 系统依赖

- Python 3.9 ~ 3.11
- `ffmpeg`（解码浏览器录制的 webm）
- 建议 CPU 推理即可，AST 模型加载约需 10-30 秒（329MB 权重）
