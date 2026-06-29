import os
import time
import subprocess
import sys

REPO_DIR = r"C:\Users\jsgub\Documents\GitHub\audio-detect-android"
BRANCH = "main"
INTERVAL = 1  # 检查间隔：1 秒

def run_git(*args):
    return subprocess.run(
        ["git"] + list(args),
        cwd=REPO_DIR,
        capture_output=True,
        text=True,
        encoding="utf-8"
    )

def has_changes():
    """检查工作区是否有未提交的变更（包括未暂存和已暂存）"""
    r = run_git("status", "--porcelain")
    return r.stdout.strip() != ""

def get_current_branch():
    r = run_git("rev-parse", "--abbrev-ref", "HEAD")
    return r.stdout.strip()

def main():
    os.chdir(REPO_DIR)

    # 检查是否在 git 仓库中
    r = run_git("rev-parse", "--git-dir")
    if r.returncode != 0:
        print("❌ 错误：不是 Git 仓库，请检查 REPO_DIR 路径")
        sys.exit(1)

    current = get_current_branch()
    print(f"📡 开始监听文件变更...")
    print(f"📁 仓库: {REPO_DIR}")
    print(f"🌿 当前分支: {current}")
    print(f"⏱️  检查间隔: {INTERVAL} 秒")
    print(f"🛑 按 Ctrl+C 停止\n")

    last_push = 0
    PUSH_COOLDOWN = 3  # 两次推送之间至少间隔 3 秒，避免过于频繁

    while True:
        try:
            if has_changes():
                now = time.time()
                if now - last_push < PUSH_COOLDOWN:
                    time.sleep(INTERVAL)
                    continue

                timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
                print(f"[{timestamp}] 检测到变更，正在提交...")

                # add
                r1 = run_git("add", ".")
                if r1.returncode != 0:
                    print(f"  ⚠️ git add 失败: {r1.stderr}")
                    time.sleep(INTERVAL)
                    continue

                # commit
                r2 = run_git("commit", "-m", f"auto-commit: {timestamp}")
                if r2.returncode != 0:
                    print(f"  ⚠️ git commit 失败: {r2.stderr}")
                    time.sleep(INTERVAL)
                    continue

                # push
                r3 = run_git("push", "origin", BRANCH)
                if r3.returncode == 0:
                    print(f"  ✅ 推送成功 ({timestamp})")
                    last_push = now
                else:
                    print(f"  ❌ 推送失败: {r3.stderr}")

            time.sleep(INTERVAL)

        except KeyboardInterrupt:
            print("\n👋 监听器已停止")
            break
        except Exception as e:
            print(f"  ❌ 异常: {e}")
            time.sleep(INTERVAL)

if __name__ == "__main__":
    main()
