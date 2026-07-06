import numpy as np, soundfile as sf, requests, tempfile, os

sr = 16000
seconds = 3
t = np.linspace(0, seconds, sr * seconds)
# 高能量正弦波
y = np.sin(2 * np.pi * 880 * t) * 0.8

with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
    wav_path = tmp.name
    sf.write(wav_path, y, sr)

url = "http://localhost:8000/predict"
for model in ["efficientat", "mobilenet", "ast"]:
    with open(wav_path, "rb") as f:
        files = {"audio": ("chunk.wav", f, "audio/wav")}
        data = {"model_choice": model, "vad_threshold": "0.01", "conf_threshold": "0.30"}
        try:
            resp = requests.post(url, files=files, data=data, timeout=30)
            j = resp.json()
            print(f"[{model}] status={j.get('status')} detections={j.get('detections', [])}")
        except Exception as e:
            print(f"[{model}] ERROR: {e}")

os.remove(wav_path)
