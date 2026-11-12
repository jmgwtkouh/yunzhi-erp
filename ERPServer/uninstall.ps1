# 卸载云智 ERP 服务（可选保留数据）
param([string]$InstallDir = "C:\ERPServer", [switch]$RemoveAll)
$ErrorActionPreference = "SilentlyContinue"
$TaskName = "YunZhiERP"

Stop-ScheduledTask -TaskName $TaskName
Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" |
    Where-Object { $_.CommandLine -like "*app\server.py*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
Get-NetFirewallRule -DisplayName "云智 ERP REST v1*" | Remove-NetFirewallRule
Write-Host "已停止服务、移除开机自启与防火墙规则。" -ForegroundColor Green

if ($RemoveAll) {
    Remove-Item -Path $InstallDir -Recurse -Force
    Write-Host "已删除整个安装目录（含数据）：$InstallDir" -ForegroundColor Yellow
} else {
    Write-Host "程序与数据保留在 $InstallDir（如需彻底删除请加 -RemoveAll 参数）" -ForegroundColor DarkGray
}
