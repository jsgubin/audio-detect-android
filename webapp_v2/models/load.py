import torch

# 1. 把 .pth 文件加载成 Python 对象
ckpt = torch.load(
    '/home/zuoyx/Desktop/科研项目/Audio_Project/audio_demo_package/webapp/models/best_model_v2.pth',
    map_location='cpu',          # 不依赖 GPU / CUDA
    weights_only=True,           # 安全加载，只反序列化张量，避免执行任意 pickle 代码
)

print(type(ckpt))                # <class 'collections.OrderedDict'>
print(len(ckpt))                 # 164

# 2. 如果是纯 state_dict，遍历每个参数张量
if isinstance(ckpt, dict) and 'model_state_dict' not in ckpt:
    for name, tensor in ckpt.items():
        print(name, tuple(tensor.shape), tensor.dtype)
else:
    # 如果是带元信息的 checkpoint
    print('keys:', ckpt.keys())
    for name, tensor in ckpt['model_state_dict'].items():
        print(name, tuple(tensor.shape), tensor.dtype)