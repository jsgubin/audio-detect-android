#!/usr/bin/env python3
"""
模型转换脚本：将 EfficientAT 模型转换为 TorchScript，并预计算 Mel 滤波器参数
用于 Android 离线 APK 打包
"""
import os
import sys
import struct
import numpy as np
import torch
import torch.nn as nn

# 确保能 import models.py
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from models import EfficientAT_Lite

# =========================================================
# 1. 加载原始模型
# =========================================================
MODEL_PATH = "models/efficientat_lite_v3.pth"
OUTPUT_DIR = "android_offline/app/src/main/assets"
os.makedirs(OUTPUT_DIR, exist_ok=True)

print(f"正在加载模型: {MODEL_PATH}")
model = EfficientAT_Lite(num_classes=6)
model.load_state_dict(torch.load(MODEL_PATH, map_location="cpu", weights_only=True))
model.eval()
print("模型加载成功")

# =========================================================
# 2. 转换为 TorchScript（用于 PyTorch Mobile Android）
# =========================================================
# 输入形状: [batch=1, channel=1, n_mels=64, time_frames=94]
example_input = torch.randn(1, 1, 64, 94)

try:
    traced = torch.jit.trace(model, example_input)
    traced_script_path = os.path.join(OUTPUT_DIR, "efficientat_lite.pt")
    traced.save(traced_script_path)
    print(f"TorchScript 模型已保存: {traced_script_path}")
    print(f"  大小: {os.path.getsize(traced_script_path) / 1024 / 1024:.2f} MB")
except Exception as e:
    print(f"TorchScript 转换失败: {e}")
    sys.exit(1)

# =========================================================
# 3. 预计算 Mel 滤波器矩阵（替代 Android 上的 librosa）
# =========================================================
# 参数必须与训练时一致：
#   sr=16000, n_fft=1024, n_mels=64, fmin=0, fmax=8000
# =========================================================

SR = 16000
N_FFT = 1024
N_MELS = 64
F_MIN = 0.0
F_MAX = 8000.0  # Nyquist = sr/2 = 8000

# FFT bins 数量（只取正频率部分）
n_fft_bins = N_FFT // 2 + 1  # 513

# 1) Mel 刻度上的均匀点
# Hz to Mel: m = 2595 * log10(1 + f/700)
# Mel to Hz: f = 700 * (10^(m/2595) - 1)

def hz_to_mel(hz):
    return 2595.0 * np.log10(1.0 + hz / 700.0)

def mel_to_hz(mel):
    return 700.0 * (10.0 ** (mel / 2595.0) - 1.0)

mel_min = hz_to_mel(F_MIN)
mel_max = hz_to_mel(F_MAX)

# 在 Mel 刻度上均匀分布 N_MELS + 2 个点（用于三角滤波器）
mel_points = np.linspace(mel_min, mel_max, N_MELS + 2)
hz_points = mel_to_hz(mel_points)

# FFT 频率轴
fft_freqs = np.linspace(0, SR / 2, n_fft_bins)

# 2) 构建 Mel 滤波器矩阵 [N_MELS x n_fft_bins]
mel_filter_bank = np.zeros((N_MELS, n_fft_bins), dtype=np.float32)

for i in range(N_MELS):
    # 三角滤波器的三个顶点
    left = hz_points[i]
    center = hz_points[i + 1]
    right = hz_points[i + 2]
    
    for j in range(n_fft_bins):
        freq = fft_freqs[j]
        if freq >= left and freq <= center:
            if center - left > 0:
                mel_filter_bank[i, j] = (freq - left) / (center - left)
        elif freq > center and freq <= right:
            if right - center > 0:
                mel_filter_bank[i, j] = (right - freq) / (right - center)

# 3) 保存为二进制文件（float32，row-major）
# 格式: [4 bytes rows][4 bytes cols][rows*cols*4 bytes data]
mel_filter_path = os.path.join(OUTPUT_DIR, "mel_filter_bank.bin")
with open(mel_filter_path, "wb") as f:
    f.write(struct.pack("<II", N_MELS, n_fft_bins))  # little-endian uint32
    f.write(mel_filter_bank.astype(np.float32).tobytes())
print(f"Mel 滤波器矩阵已保存: {mel_filter_path}")
print(f"  形状: {N_MELS} x {n_fft_bins}")

# 4) 预计算 Hann 窗（1024 点）
hann_window = np.hanning(N_FFT).astype(np.float32)
hann_path = os.path.join(OUTPUT_DIR, "hann_window.bin")
with open(hann_path, "wb") as f:
    f.write(struct.pack("<I", N_FFT))
    f.write(hann_window.tobytes())
print(f"Hann 窗已保存: {hann_path}")

# 5) 保存类别标签
classes = ['alarm', 'baby_cry', 'car_horn', 'doorbell', 'glass_shatter', 'gun_shot']
label_path = os.path.join(OUTPUT_DIR, "labels.txt")
with open(label_path, "w", encoding="utf-8") as f:
    for c in classes:
        f.write(c + "\n")
print(f"类别标签已保存: {label_path}")

print("\n" + "=" * 60)
print("所有转换完成！")
print("=" * 60)
print(f"\n输出目录: {OUTPUT_DIR}")
print(f"  - efficientat_lite.pt       ({os.path.getsize(os.path.join(OUTPUT_DIR, 'efficientat_lite.pt')) / 1024 / 1024:.2f} MB)")
print(f"  - mel_filter_bank.bin       ({os.path.getsize(os.path.join(OUTPUT_DIR, 'mel_filter_bank.bin')) / 1024:.2f} KB)")
print(f"  - hann_window.bin           ({os.path.getsize(os.path.join(OUTPUT_DIR, 'hann_window.bin')) / 1024:.2f} KB)")
print(f"  - labels.txt")
print("\n接下来: 用 Android Studio 打开 android_offline 目录编译 APK")
