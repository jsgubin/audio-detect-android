import os
import sys

# Windows 控制台 UTF-8 编码修复
if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

from pathlib import Path
import numpy as np
import torch
import torch.nn.functional as F
import librosa
from typing import Optional
from fastapi import FastAPI, UploadFile, File, Form
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from models import EfficientAT_Lite, PANNs_Cnn6, MobileNetV1Audio

# 让脚本无论从哪里运行都能找到模型和 static 目录
BASE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = BASE_DIR.parent

# =========================================================
# 模型路径解析（支持多种打包方式，便于分发）
# =========================================================
def resolve_model_path(relative_name: str) -> Path:
    """
    按优先级查找模型文件：
    1. webapp/models/          （推荐的干净打包方式）
    2. 项目根目录下的对应位置 （保持原有结构兼容）
    3. listen_demo/model/      （兼容旧位置）
    """
    candidates = [
        BASE_DIR / "models" / relative_name,                    # 推荐：webapp/models/xxx.pth
        BASE_DIR / relative_name,                               # webapp/ 直接放
        PROJECT_ROOT / relative_name,
        PROJECT_ROOT / "Audio_v3" / relative_name,
        PROJECT_ROOT / "Audio_v1" / relative_name,
        PROJECT_ROOT / "listen_demo" / "model" / relative_name,
    ]
    for p in candidates:
        if p.exists():
            return p
    # 返回第一个候选，方便报错信息
    return candidates[0]


app = FastAPI()

# 挂载静态文件目录 (存放 index.html)
static_dir = BASE_DIR / "static"
app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")

# 加载模型
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"正在加载模型至 {device}...")

# =========================================================
# 模型加载（使用 resolve_model_path 支持干净打包）
# =========================================================
eff_path = resolve_model_path("efficientat_lite_v3.pth")
print(f"正在加载 EfficientAT: {eff_path}")
eff_model = EfficientAT_Lite(num_classes=6)
eff_model.load_state_dict(torch.load(str(eff_path), map_location=device, weights_only=True))
eff_model.to(device).eval()

panns_path = resolve_model_path("panns_cnn6.pth")
print(f"正在加载 PANNs: {panns_path}")
panns_model = PANNs_Cnn6(num_classes=6)
panns_model.load_state_dict(torch.load(str(panns_path), map_location=device, weights_only=True))
panns_model.to(device).eval()

# MobileNetV1 (朋友的模型)
mobilenet_model_path = resolve_model_path("best_model_v2.pth")
if not mobilenet_model_path.exists():
    raise FileNotFoundError(f"未找到 jmy 的模型文件: {mobilenet_model_path}")

mobilenet_model = MobileNetV1Audio(num_classes=6)

checkpoint = torch.load(str(mobilenet_model_path), map_location=device, weights_only=True)
# 兼容两种保存格式：直接 state_dict 或 {"model_state_dict": ...}
if isinstance(checkpoint, dict) and "model_state_dict" in checkpoint:
    mobilenet_model.load_state_dict(checkpoint["model_state_dict"])
else:
    mobilenet_model.load_state_dict(checkpoint)

mobilenet_model.to(device).eval()
print(f"jmy 的 MobileNetV1 模型已加载: {mobilenet_model_path}")

classes = ['alarm', 'baby_cry', 'car_horn', 'doorbell', 'glass_shatter', 'gun_shot']


# =========================================================
# 实时识别关键参数（便于快速调优）
# =========================================================
VAD_THRESHOLD = 0.03          # 峰值低于此值直接认为无有效声音（原 0.05 偏严）
CONF_THRESHOLDS = {
    "efficientat": 0.60,
    "panns": 0.60,
    "mobilenet": 0.65,        # MobileNetV1 训练时置信度较高，适当收紧可减少误报
}


def select_best_3s_window(y: np.ndarray, sr: int = 16000, window_sec: float = 3.0, stride_sec: float = 0.2):
    """
    在较长音频中滑动选择「能量最高」的 window_sec 秒片段。
    极大改善“事件不在音频最后 3 秒”的问题。
    如果音频本身短于窗口，直接返回原音频（后续会 pad）。
    """
    target_samples = int(sr * window_sec)
    if len(y) <= target_samples:
        return y

    stride = max(1, int(sr * stride_sec))
    best_energy = -np.inf
    best_start = 0
    for start in range(0, len(y) - target_samples + 1, stride):
        seg = y[start: start + target_samples]
        energy = float(np.sum(seg ** 2))
        if energy > best_energy:
            best_energy = energy
            best_start = start
    return y[best_start: best_start + target_samples]


# =========================================================
# 其他人模型 (MobileNetV1Audio) 专用预处理
# 必须与 listen_demo/inference.py 中的逻辑完全一致：
#   - 16kHz 单声道
#   - y *= 32768.0 （接近训练时的 int16 量级）
#   - n_mels=128, n_fft=1024, hop=512, htk=True, norm=None
#   - log(mel + 1e-9)
#   - 双线性插值到固定大小 (128, 256)
# =========================================================

MOBILENET_SR = 16000
MOBILENET_N_MELS = 128
MOBILENET_N_FFT = 1024
MOBILENET_HOP_LENGTH = 512
MOBILENET_TARGET_FRAMES = 256

def preprocess_for_mobilenet(y: np.ndarray = None, audio_path: str = None):
    """
    返回 shape: [1, 1, 128, 256] 的 tensor (在 CPU 上)
    可传入已加载的 waveform (推荐，避免重复解码)，或音频路径。
    """
    if y is None:
        if audio_path is None:
            raise ValueError("preprocess_for_mobilenet 需要 y 或 audio_path")
        y, _ = librosa.load(audio_path, sr=MOBILENET_SR, mono=True)

    if y is None or len(y) == 0:
        raise ValueError("音频读取失败或音频为空")

    # === 针对真实麦克风的幅度自适应补偿 ===
    # 朋友模型训练时做了 y *= 32768，demo 样本幅度通常较高 (0.5~0.7)。
    # 实时麦克风输入经常偏弱，这里温和 boost，避免把纯噪声过度放大。
    peak = float(np.max(np.abs(y)) + 1e-9)
    if peak < 0.30:
        boost = min(3.0, 0.50 / peak)   # 把峰值尽量拉到 ~0.5 左右
        y = y * boost

    # 关键缩放，和其他人训练代码保持一致
    y = y.astype(np.float32) * 32768.0

    # 太短的音频至少填充到 0.5 秒
    min_samples = int(0.5 * MOBILENET_SR)
    if len(y) < min_samples:
        repeat_times = (min_samples + len(y) - 1) // len(y)
        y = np.tile(y, repeat_times)[:min_samples]

    # 提取 Mel 频谱 (参数必须和训练时一致)
    mel_spec = librosa.feature.melspectrogram(
        y=y,
        sr=MOBILENET_SR,
        n_fft=MOBILENET_N_FFT,
        hop_length=MOBILENET_HOP_LENGTH,
        n_mels=MOBILENET_N_MELS,
        power=2.0,
        htk=True,
        norm=None
    )

    log_mel = np.log(mel_spec + 1e-9)

    # [128, T] -> [1, 1, 128, T]
    log_mel = torch.tensor(log_mel, dtype=torch.float32).unsqueeze(0).unsqueeze(0)

    # 插值固定尺寸 [1, 1, 128, 256]
    log_mel = F.interpolate(
        log_mel,
        size=(MOBILENET_N_MELS, MOBILENET_TARGET_FRAMES),
        mode="bilinear",
        align_corners=False
    )

    return log_mel


@app.get("/")
def index():
    # 直接返回主页（使用绝对路径，防止 cwd 问题）
    index_path = BASE_DIR / "static" / "index.html"
    with open(index_path, "r", encoding="utf-8") as f:
        return HTMLResponse(f.read())

@app.post("/predict")
async def predict(
    audio: UploadFile = File(...),
    model_choice: str = Form(...),
    # 可从前端动态传入阈值，不传则使用后端默认值
    vad_threshold: Optional[float] = Form(None),
    conf_threshold: Optional[float] = Form(None),
):
    """
    接收前端传来的音频片段 (通常为 3 秒的 webm)，
    进行识别后返回概率大于阈值的类别。如果没有，则返回空列表。

    支持动态阈值（从前端传参）：
      - vad_threshold  : 静音检测阈值（峰值幅度），不传则使用默认 0.03
      - conf_threshold : 置信度阈值，不传则使用该模型的默认阈值

    支持的 model_choice:
      - "efficientat" : zyx 的 EfficientAT_Lite
      - "panns"       : zyx 的 PANNs_Cnn6
      - "mobilenet"   : jmy 在 listen_demo 训练的 MobileNetV1Audio
    """
    import tempfile
    audio_bytes = await audio.read()
    temp_path = None
    
    # 使用系统临时目录，兼容 Windows / Linux / macOS
    with tempfile.NamedTemporaryFile(suffix=".webm", delete=False) as tmp:
        tmp.write(audio_bytes)
        temp_path = tmp.name
        
    try:
        # librosa 配合 ffmpeg 可以直接读取 webm 文件并转换为单声道 16kHz
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            y, sr = librosa.load(temp_path, sr=16000, mono=True)
            
        # === 静音检测 (Voice Activity Detection) ===
        # 优先使用前端传来的 vad_threshold，否则使用默认值
        effective_vad = float(vad_threshold) if vad_threshold is not None else VAD_THRESHOLD
        effective_vad = max(0.0, min(0.5, effective_vad))   # 安全范围

        max_amplitude = np.max(np.abs(y))
        if max_amplitude < effective_vad:
            return {"status": "success", "detections": []}
        # =====================================================

        # === 核心改进：选择能量最高的 3 秒窗口 ===
        # 取代“永远取最后 3 秒”，显著提升事件不在尾部时的检出率
        y = select_best_3s_window(y, sr=16000)

        if model_choice == "mobilenet":
            # ==================== jmy 的 MobileNetV1 模型分支 ====================
            feature = preprocess_for_mobilenet(y=y)

            with torch.no_grad():
                output = mobilenet_model(feature.to(device))
                probs = torch.softmax(output, dim=1)[0].cpu().numpy()

            # 单标签 + 支持前端动态 conf_threshold
            results = []
            top_idx = int(np.argmax(probs))
            top_prob = float(probs[top_idx])
            effective_conf = float(conf_threshold) if conf_threshold is not None else CONF_THRESHOLDS["mobilenet"]
            effective_conf = max(0.0, min(1.0, effective_conf))
            if top_prob > effective_conf:
                results.append({"class": classes[top_idx], "prob": top_prob})

            return {"status": "success", "detections": results}

        else:
            # ==================== zyx 的两个模型分支 (efficientat / panns) ====================
            # 此时 y 已经是“能量最高”的 3 秒（或已 pad）
            target_samples = 16000 * 3
            if len(y) < target_samples:
                y = np.pad(y, (0, target_samples - len(y)), mode='constant')
            # 不再无脑 y[-target_samples:]，而是用能量最高段

            # 提取 Mel 频谱 (64 bins, power_to_db)
            S = librosa.feature.melspectrogram(y=y, sr=16000, n_fft=1024, hop_length=512, n_mels=64)
            S_dB = librosa.power_to_db(S, ref=np.max)

            # 对齐到 (64, 94)
            if S_dB.shape[1] < 94:
                S_dB = np.pad(S_dB, ((0, 0), (0, 94 - S_dB.shape[1])), mode='constant', constant_values=-80.0)
            else:
                S_dB = S_dB[:, :94]

            feature = torch.from_numpy(S_dB).float().unsqueeze(0).unsqueeze(0).to(device)

            # 选择模型
            model = eff_model if model_choice == "efficientat" else panns_model

            # 推理（这两个模型用 sigmoid，多标签风格）
            with torch.no_grad():
                output = model(feature)
                probs = torch.sigmoid(output)[0].cpu().numpy()

            # 筛选置信度（优先使用前端传入的 conf_threshold，否则使用模型默认）
            effective_conf = float(conf_threshold) if conf_threshold is not None else CONF_THRESHOLDS.get(model_choice, 0.60)
            effective_conf = max(0.0, min(1.0, effective_conf))
            results = []
            for i, cls in enumerate(classes):
                if probs[i] > effective_conf:
                    results.append({"class": cls, "prob": float(probs[i])})

            results.sort(key=lambda x: x["prob"], reverse=True)
            return {"status": "success", "detections": results}

    except Exception as e:
        return {"status": "error", "message": str(e)}

    finally:
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)

if __name__ == "__main__":
    import uvicorn
    import os

    # ========== 本地测试重要提示 ==========
    # 浏览器麦克风 API (getUserMedia) 只能在「安全上下文」中使用：
    #   - http://localhost
    #   - http://127.0.0.1
    #   - https://...
    # 
    # 如果你用 IP 地址 (如 192.168.1.x 或 0.0.0.0) 打开页面，会直接失败！
    #
    # 推荐本地测试方式：
    #   1. 直接在浏览器地址栏输入：http://localhost:8000
    #   2. 或者 http://127.0.0.1:8000
    # ========================================

    print("=" * 70)
    print("🎤 实时环境音识别系统")
    print("后端已启动！")
    print("")
    print("已加载的识别引擎：")
    print("  • efficientat  - EfficientAT V3 (zyx 的模型)")
    print("  • panns        - PANNs Cnn6 (zyx 的模型)")
    print("  • mobilenet    - MobileNetV1 (jmy 的模型)")
    print("")
    print("实时优化已启用：")
    print("  • 能量最高 3s 窗口定位（替代固定尾部截取）")
    print("  • MobileNetV1 麦克风幅度自适应补偿")
    print("  • VAD 阈值 = 0.03，模型专属置信度阈值")
    print("")
    print("【重要】本地测试麦克风必须满足以下两点：")
    print("  1. 浏览器地址必须是下面两个之一（不能用 IP）：")
    print("       http://localhost:8000")
    print("       http://127.0.0.1:8000")
    print("  2. 请在 webapp 目录下运行本脚本：")
    print("       cd webapp")
    print("       python app_zyx.py")
    print("")
    print("⚠️  如果你用 192.168.x.x 或 0.0.0.0 打开，麦克风会直接报错！")
    print("=" * 70)

    # 默认绑定 127.0.0.1（Windows 本地开发最稳定，无需管理员权限）
    # 如需从其他设备访问，可设置环境变量 HOST=0.0.0.0
    host = os.environ.get("HOST", "127.0.0.1")
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host=host, port=port)
