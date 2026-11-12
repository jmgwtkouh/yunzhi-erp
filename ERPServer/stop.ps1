# 停止云智 ERP 服务（保留程序与数据）
$ErrorActionPreference = "SilentlyContinue"
$TaskName = "YunZhiERP"
Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*app\server.py*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Write-Host "已停止云智 ERP 服务。" -ForegroundColor Green
Write-Host "重新启动：双击 一键部署.bat 或 start.bat" -ForegroundColor DarkGray
