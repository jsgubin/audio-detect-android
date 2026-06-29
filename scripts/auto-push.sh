#!/bin/bash
# Auto-push script for audio-detect-android

REPO_DIR="C:/Users/jsgub/Documents/GitHub/audio-detect-android"
LOG_FILE="$REPO_DIR/scripts/auto-push.log"

cd "$REPO_DIR" || {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: 无法进入目录 $REPO_DIR" >> "$LOG_FILE"
    exit 1
}

# 检查是否有变更（包括未跟踪文件）
CHANGES=$(git status --porcelain)

if [ -z "$CHANGES" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: 没有检测到变更，跳过推送。" | tee -a "$LOG_FILE"
    exit 0
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] INFO: 检测到变更：" | tee -a "$LOG_FILE"
echo "$CHANGES" | tee -a "$LOG_FILE"

# 自动 add 所有变更
git add -A
if [ $? -ne 0 ]; then
    echo "[$TIMESTAMP] ERROR: git add 失败" | tee -a "$LOG_FILE"
    exit 1
fi

# 提交，带时间戳
git commit -m "auto-push: $TIMESTAMP"
if [ $? -ne 0 ]; then
    echo "[$TIMESTAMP] ERROR: git commit 失败" | tee -a "$LOG_FILE"
    exit 1
fi

# 推送到 main 分支
git push origin main
if [ $? -ne 0 ]; then
    echo "[$TIMESTAMP] ERROR: git push 到 main 分支失败" | tee -a "$LOG_FILE"
    exit 1
fi

echo "[$TIMESTAMP] SUCCESS: 自动推送完成。" | tee -a "$LOG_FILE"
