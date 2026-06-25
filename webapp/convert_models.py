#!/usr/bin/env python3
"""
模型转换脚本：将 PC 端的 .pth 权重转换为 Android PyTorch Lite 可用的 .pt 格式

关键：必须使用 traced._save_for_lite_interpreter() 而不是 traced.save()，
否则 Android 端 LiteModuleLoader 会因缺少 bytecode.pkl 而崩溃。

运行方式：
    cd webapp
    python convert_models.py

输出：
    android/app/src/main/assets/models/efficientat_lite.pt
    android/app/src/main/assets/models/panns_cnn6.pt
    android/app/src/main/assets/models/mobilenetv1.pt
"""

import sys
import os

# 修复 Windows 控制台 UTF-8
if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

from pathlib import Path
import torch
import torch.nn.functional as F

# 加载模型定义
from models import EfficientAT_Lite, PANNs_Cnn6, MobileNetV1Audio

device = torch.device("cpu")

# 路径解析（复用 app_zyx.py 的逻辑）
BASE_DIR = Path(__file__).resolve().parent

def resolve_model_path(relative_name: str) -> Path:
    candidates = [
        BASE_DIR / "models" / relative_name,
        BASE_DIR / relative_name,
    ]
    for p in candidates:
        if p.exists():
            return p
    return candidates[0]

OUTPUT_DIR = BASE_DIR.parent / "android" / "app" / "src" / "main" / "assets" / "models"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

classes = ['alarm', 'baby_cry', 'car_horn', 'doorbell', 'glass_shatter', 'gun_shot']

print("=" * 60)
print(" 模型转换工具：PC .pth → Android TorchScript .pt")
print("=" * 60)
print()

# =========================================================
# 1. EfficientAT_Lite
# =========================================================
eff_path = resolve_model_path("efficientat_lite_v3.pth")
print(f"[1/3] 转换 EfficientAT_Lite...")
print(f"      源: {eff_path}")

model1 = EfficientAT_Lite(num_classes=6)
model1.load_state_dict(torch.load(str(eff_path), map_location=device, weights_only=True))
model1.to(device).eval()

# 创建示例输入（注意：Android 上也是 1 channel, 64x94 的 Mel）
example_input = torch.randn(1, 1, 64, 94)

# 使用 torch.jit.trace（模型没有控制流，适合 trace）
try:
    traced = torch.jit.trace(model1, example_input)
    out_path = OUTPUT_DIR / "efficientat_lite.pt"
    traced._save_for_lite_interpreter(str(out_path))
    print(f"      ✅ 已保存: {out_path}")
    print(f"      验证输出: {traced(example_input).shape}")
except Exception as e:
    print(f"      ❌ 失败: {e}")

print()

# =========================================================
# 2. PANNs_Cnn6
# =========================================================
panns_path = resolve_model_path("panns_cnn6.pth")
print(f"[2/3] 转换 PANNs_Cnn6...")
print(f"      源: {panns_path}")

model2 = PANNs_Cnn6(num_classes=6)
model2.load_state_dict(torch.load(str(panns_path), map_location=device, weights_only=True))
model2.to(device).eval()

example_input2 = torch.randn(1, 1, 64, 94)

try:
    traced2 = torch.jit.trace(model2, example_input2)
    out_path2 = OUTPUT_DIR / "panns_cnn6.pt"
    traced2._save_for_lite_interpreter(str(out_path2))
    print(f"      ✅ 已保存: {out_path2}")
    print(f"      验证输出: {traced2(example_input2).shape}")
except Exception as e:
    print(f"      ❌ 失败: {e}")

print()

# =========================================================
# 3. MobileNetV1Audio (jmy 的模型)
# =========================================================
mb_path = resolve_model_path("best_model_v2.pth")
print(f"[3/3] 转换 MobileNetV1Audio...")
print(f"      源: {mb_path}")

model3 = MobileNetV1Audio(num_classes=6)
checkpoint = torch.load(str(mb_path), map_location=device, weights_only=True)
if isinstance(checkpoint, dict) and "model_state_dict" in checkpoint:
    model3.load_state_dict(checkpoint["model_state_dict"])
else:
    model3.load_state_dict(checkpoint)
model3.to(device).eval()

# MobileNet 输入是 [1, 1, 128, 256]
example_input3 = torch.randn(1, 1, 128, 256)

try:
    traced3 = torch.jit.trace(model3, example_input3)
    out_path3 = OUTPUT_DIR / "mobilenetv1.pt"
    traced3._save_for_lite_interpreter(str(out_path3))
    print(f"      ✅ 已保存: {out_path3}")
    print(f"      验证输出: {traced3(example_input3).shape}")
except Exception as e:
    print(f"      ❌ 失败: {e}")

print()
print("=" * 60)
print(" 转换完成！")
print(f" 输出目录: {OUTPUT_DIR}")
print("=" * 60)
print()
print("【Android 构建说明】")
print("  1. 确保 Android Studio 已安装")
print("  2. 打开 audio_demo_package/android 目录")
print("  3. 同步 Gradle，等待 PyTorch Android 依赖下载")
print("  4. Build → Build Bundle(s) / APK(s) → Build APK(s)")
print()
