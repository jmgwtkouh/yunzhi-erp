@echo off
chcp 65001 >nul
title 云智 ERP 服务 - 前台调试
cd /d "%~dp0"
echo.
echo   云智 ERP REST v1  前台调试模式
echo   端口与 Token 读取自 config.json
echo   关闭本窗口即停止服务（正式运行请用 一键部署.bat 注册为开机自启）
echo.
"%~dp0runtime\python.exe" "%~dp0app\server.py"
echo.
echo   服务已退出。
pause
