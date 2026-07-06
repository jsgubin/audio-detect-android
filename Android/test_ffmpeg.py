import librosa, numpy as np, tempfile, os, shutil

# Test 1: check ffmpeg
print("=== Check ffmpeg ===")
try:
    y, sr = librosa.load("nonexistent.webm", sr=16000, mono=True)
except Exception as e:
    print(f"librosa webm error: {e}")

# Test 2: create test wav
print("\n=== Test audio loading ===")
sr = 16000
seconds = 3
t = np.linspace(0, seconds, sr * seconds)
y = np.sin(2 * np.pi * 880 * t) * 0.8

import soundfile as sf
with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
    wav_path = tmp.name
    sf.write(wav_path, y, sr)
    print(f"wav created: {wav_path}")

try:
    y2, sr2 = librosa.load(wav_path, sr=16000, mono=True)
    print(f"wav loaded OK: shape={y2.shape}, max_amp={np.max(np.abs(y2)):.4f}")
except Exception as e:
    print(f"wav load failed: {e}")

os.remove(wav_path)

# Test 3: ffmpeg installed?
print("\n=== ffmpeg check ===")
if shutil.which("ffmpeg"):
    print(f"ffmpeg found: {shutil.which('ffmpeg')}")
else:
    print("ffmpeg NOT installed!")
    print("Browser records webm audio, backend needs ffmpeg to decode.")
    print("Without ffmpeg, /predict will throw error, frontend shows nothing.")
