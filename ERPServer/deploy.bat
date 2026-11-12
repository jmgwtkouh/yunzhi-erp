@echo off
chcp 65001 >nul
title 云智 ERP - Windows Server 一键部署
cd /d "%~dp0"
echo.
echo   云智 ERP REST v1  一键部署
echo   ------------------------------------
echo   即将请求管理员权限，请在弹窗中点「是」。
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy.ps1" %*
echo.
pause
