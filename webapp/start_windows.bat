@echo off
chcp 65001 >nul
title 实时环境音识别系统 - Windows 启动器
echo.
echo ============================================
echo   实时环境音识别系统 - Windows 启动器
echo ============================================
echo.

set "PROJECT_DIR=%~dp0"
cd /d "%PROJECT_DIR%"

:: ========== 检查 Python ==========
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ 未检测到 Python！
    echo.
    echo 请按以下步骤安装 Python：
    echo    1. 访问 https://www.python.org/downloads/
    echo    2. 下载 Python 3.10 或 3.11 （推荐 3.11）
    echo    3. 安装时务必勾选 "Add Python to PATH"
    echo    4. 安装完成后重新运行本脚本
    echo.
    pause
    exit /b 1
)

echo ✅ Python 已安装
python --version

:: ========== 检查 ffmpeg ==========
ffmpeg -version >nul 2>&1
if %errorlevel% neq 0 (
    echo ⚠️  未检测到 ffmpeg！浏览器录制的 webm 音频需要 ffmpeg 解码。
    echo.
    echo 请按以下方式安装 ffmpeg：
    echo    1. 访问 https://github.com/BtbN/FFmpeg-Builds/releases
    echo    2. 下载 ffmpeg-master-latest-win64-gpl.zip
    echo    3. 解压后将 bin 目录添加到系统 PATH
    echo    4. 或者将 ffmpeg.exe 直接放到本目录下
    echo.
    echo 如果没有 ffmpeg，服务仍可启动，但识别功能可能无法正常工作。
    echo.
    pause
)

echo ✅ ffmpeg 已安装

:: ========== 创建虚拟环境（推荐） ==========
if not exist "venv" (
    echo.
    echo 📦 正在创建 Python 虚拟环境 venv...
    python -m venv venv
    if %errorlevel% neq 0 (
        echo ❌ 创建虚拟环境失败，将尝试使用全局 Python 环境...
        set "USE_GLOBAL=1"
    ) else (
        echo ✅ 虚拟环境创建成功
        set "USE_GLOBAL=0"
    )
) else (
    echo ✅ 虚拟环境 venv 已存在
    set "USE_GLOBAL=0"
)

:: ========== 激活环境并安装依赖 ==========
if "%USE_GLOBAL%"=="0" (
    call venv\Scripts\activate.bat
    echo 📦 正在安装依赖（这可能需要几分钟）...
    python -m pip install -r requirements.txt
) else (
    echo 📦 正在使用全局 Python 安装依赖...
    python -m pip install -r requirements.txt
)

if %errorlevel% neq 0 (
    echo ❌ 依赖安装失败！
    echo 请检查网络连接，或手动运行：pip install -r requirements.txt
    pause
    exit /b 1
)

echo ✅ 依赖安装完成

:: ========== 检查模型文件是否存在 ==========
set "MODELS_OK=1"
if not exist "models\efficientat_lite_v3.pth" set "MODELS_OK=0"
if not exist "models\panns_cnn6.pth" set "MODELS_OK=0"
if not exist "models\best_model_v2.pth" set "MODELS_OK=0"

if "%MODELS_OK%"=="0" (
    echo.
    echo ⚠️  模型文件缺失！请确认以下文件存在于 models\ 目录：
    echo    - efficientat_lite_v3.pth
    echo    - panns_cnn6.pth
    echo    - best_model_v2.pth
    echo.
    pause
)

:: ========== 启动服务 ==========
echo.
echo ============================================
echo   🚀 正在启动服务...
echo   地址：http://127.0.0.1:8000
echo ============================================
echo.

:: 自动打开浏览器（延迟2秒，等服务启动）
timeout /t 2 /nobreak >nul
start "" "http://127.0.0.1:8000"

:: 运行服务（使用127.0.0.1，Windows本地最稳定）
set HOST=127.0.0.1
set PORT=8000
python app_zyx.py

:: 服务停止后暂停
echo.
echo 服务已停止。
pause
