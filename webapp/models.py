import torch
import torch.nn as nn
import torch.nn.functional as F
import torchvision.models as models

# ==========================================
# EfficientAT 模型定义
# ==========================================
class EfficientAT_Lite(nn.Module):
    def __init__(self, num_classes=6, dropout_rate=0.5):
        super(EfficientAT_Lite, self).__init__()
        self.backbone = models.mobilenet_v3_small(weights=None)
        original_conv = self.backbone.features[0][0]
        new_conv = nn.Conv2d(1, original_conv.out_channels, 
                             kernel_size=original_conv.kernel_size, 
                             stride=original_conv.stride, 
                             padding=original_conv.padding, 
                             bias=False)
        self.backbone.features[0][0] = new_conv
        
        # 加强 Dropout 机制
        self.backbone.classifier[2] = nn.Dropout(p=dropout_rate, inplace=True)
        
        in_features = self.backbone.classifier[3].in_features
        self.backbone.classifier[3] = nn.Linear(in_features, num_classes)
        
    def forward(self, x):
        return self.backbone(x)

# ==========================================
# PANNs Cnn6 模型定义
# ==========================================
class ConvBlock(nn.Module):
    def __init__(self, in_channels, out_channels):
        super(ConvBlock, self).__init__()
        self.conv1 = nn.Conv2d(in_channels=in_channels, out_channels=out_channels,
                               kernel_size=(3, 3), stride=(1, 1), padding=(1, 1), bias=False)
        self.bn1 = nn.BatchNorm2d(out_channels)
        self.conv2 = nn.Conv2d(in_channels=out_channels, out_channels=out_channels,
                               kernel_size=(3, 3), stride=(1, 1), padding=(1, 1), bias=False)
        self.bn2 = nn.BatchNorm2d(out_channels)

    def forward(self, input, pool_size=(2, 2), pool_type='avg'):
        x = input
        x = F.relu_(self.bn1(self.conv1(x)))
        x = F.relu_(self.bn2(self.conv2(x)))
        if pool_type == 'max':
            x = F.max_pool2d(x, kernel_size=pool_size)
        elif pool_type == 'avg':
            x = F.avg_pool2d(x, kernel_size=pool_size)
        return x

class PANNs_Cnn6(nn.Module):
    def __init__(self, num_classes=6):
        super(PANNs_Cnn6, self).__init__()
        self.bn0 = nn.BatchNorm2d(64)
        self.conv_block1 = ConvBlock(in_channels=1, out_channels=64)
        self.conv_block2 = ConvBlock(in_channels=64, out_channels=128)
        self.conv_block3 = ConvBlock(in_channels=128, out_channels=256)
        self.conv_block4 = ConvBlock(in_channels=256, out_channels=512)
        self.fc1 = nn.Linear(512, 512, bias=True)
        self.fc_audioset = nn.Linear(512, num_classes, bias=True)

    def forward(self, x):
        x = x.transpose(1, 2)
        x = self.bn0(x)           
        x = x.transpose(1, 2)
        x = self.conv_block1(x, pool_size=(2, 2), pool_type='avg')
        x = self.conv_block2(x, pool_size=(2, 2), pool_type='avg')
        x = self.conv_block3(x, pool_size=(2, 2), pool_type='avg')
        x = self.conv_block4(x, pool_size=(2, 2), pool_type='avg')
        x = torch.mean(x, dim=3)
        x = torch.max(x, dim=2)[0]
        x = F.relu_(self.fc1(x))
        output = self.fc_audioset(x)
        return output


# =========================================================
# MobileNetV1Audio —— 来自其他人的 listen_demo 训练模型
# 结构必须与 listen_demo/inference.py 中的 MobileNetV1Audio 完全一致
# =========================================================

def conv_bn(in_c, out_c, stride):
    return nn.Sequential(
        nn.Conv2d(in_c, out_c, 3, stride, padding=1, bias=False),
        nn.BatchNorm2d(out_c),
        nn.ReLU6(inplace=True),
    )


def conv_dw(in_c, out_c, stride):
    return nn.Sequential(
        nn.Conv2d(in_c, in_c, 3, stride, padding=1, groups=in_c, bias=False),
        nn.BatchNorm2d(in_c),
        nn.ReLU6(inplace=True),

        nn.Conv2d(in_c, out_c, 1, 1, 0, bias=False),
        nn.BatchNorm2d(out_c),
        nn.ReLU6(inplace=True),
    )


class MobileNetV1Audio(nn.Module):
    def __init__(self, num_classes=6, input_channels=1):
        super().__init__()

        self.features = nn.Sequential(
            conv_bn(input_channels, 32, 2),
            conv_dw(32, 64, 1),
            conv_dw(64, 128, 2),
            conv_dw(128, 128, 1),
            conv_dw(128, 256, 2),
            conv_dw(256, 256, 1),
            conv_dw(256, 512, 2),
            conv_dw(512, 512, 1),
            conv_dw(512, 512, 1),
            conv_dw(512, 512, 1),
            conv_dw(512, 512, 1),
            conv_dw(512, 512, 1),
            conv_dw(512, 1024, 2),
            conv_dw(1024, 1024, 1),
        )

        self.global_avg_pool = nn.AdaptiveAvgPool2d(1)
        self.fc = nn.Linear(1024, num_classes)

    def forward(self, x):
        x = self.features(x)
        x = self.global_avg_pool(x)
        x = x.view(x.size(0), -1)
        x = self.fc(x)
        return x

