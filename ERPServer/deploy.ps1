# ===========================================================
#  云智 ERP · Windows Server 一键部署
#  零安装：随包自带 Python 绿色运行时，不需要装 Python / IIS / 数据库
#
#  用法（右键「使用 PowerShell 运行」，或双击 一键部署.bat）：
#     .\deploy.ps1
#     .\deploy.ps1 -Port 9000
#     .\deploy.ps1 -Port 8080 -Token "your-secret-token"
#
#  脚本会完成：复制程序、写配置、放行防火墙、注册开机自启、启动服务、健康检查
# ===========================================================
param(
    [int]$Port = 8080,
    [string]$Token = "",
    [string]$InstallDir = "C:\ERPServer",
    [switch]$NoAutoStart,
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"
$TaskName = "YunZhiERP"
$RuleName = "云智 ERP REST v1 (TCP $Port)"

# --- 自动请求管理员权限 ---
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "需要管理员权限，正在提权..." -ForegroundColor Yellow
    $argLine = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Port $Port -Token `"$Token`" -InstallDir `"$InstallDir`""
    if ($NoAutoStart) { $argLine += " -NoAutoStart" }
    if ($NoPause) { $argLine += " -NoPause" }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argLine
    exit
}

function Info($m) { Write-Host "[*] $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[OK] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "[X] $m" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "  云智 ERP REST v1 · Windows Server 部署" -ForegroundColor White
Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
Write-Host ""

$src = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = [System.IO.Path]::GetFullPath($src)
$dst = [System.IO.Path]::GetFullPath($InstallDir)

# --- 1. 检查随包运行时 ---
$srcPython = Join-Path $src "runtime\python.exe"
if (-not (Test-Path $srcPython)) { Fail "找不到 runtime\python.exe，请确认解压了完整部署包。" }

# --- 2. 复制程序（保留已有 data 数据） ---
Info "安装目录: $dst"
if ($src.TrimEnd('\') -ne $dst.TrimEnd('\')) {
    New-Item -ItemType Directory -Path $dst -Force | Out-Null
    foreach ($item in @("app", "runtime")) {
        $from = Join-Path $src $item
        if (-not (Test-Path $from)) { Fail "缺少 $item 目录" }
        Copy-Item -Path $from -Destination (Join-Path $dst $item) -Recurse -Force
    }
    Get-ChildItem -Path $src -Filter "*.ps1" | ForEach-Object { Copy-Item $_.FullName -Destination $dst -Force }
    Get-ChildItem -Path $src -Filter "*.bat" | ForEach-Object { Copy-Item $_.FullName -Destination $dst -Force }
    Ok "程序已复制到 $dst"
} else {
    Ok "已在安装目录内运行，跳过复制"
}
New-Item -ItemType Directory -Path (Join-Path $dst "data") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $dst "logs") -Force | Out-Null

# --- 3. 写配置（重复部署时保留已设置的 Token） ---
$cfgPath = Join-Path $dst "config.json"
$finalToken = $Token
if (-not $finalToken -and (Test-Path $cfgPath)) {
    try {
        $old = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($old.token) { $finalToken = $old.token }
    } catch { }
}
$cfg = [ordered]@{ port = $Port; host = "0.0.0.0"; token = $finalToken; dataDir = "data"; logDir = "logs" }
$json = $cfg | ConvertTo-Json
[System.IO.File]::WriteAllText($cfgPath, $json, (New-Object System.Text.UTF8Encoding($false)))
Ok "配置已写入: 端口 $Port / Token $(if ($finalToken) { '已启用' } else { '未启用' })"

$pythonExe = Join-Path $dst "runtime\python.exe"
$serverPy  = Join-Path $dst "app\server.py"
if (-not (Test-Path $pythonExe)) { Fail "运行时复制失败: $pythonExe" }
if (-not (Test-Path $serverPy))  { Fail "服务程序复制失败: $serverPy" }

# --- 4. 停止旧实例 ---
$oldTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($oldTask) {
    Info "停止已有服务实例..."
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like "*app\server.py*" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
}

# --- 5. 防火墙 ---
Info "放行防火墙入站 TCP $Port ..."
try {
    Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -LocalPort $Port -Protocol TCP -Action Allow -Profile Any | Out-Null
    Ok "防火墙规则已创建"
} catch {
    Warn "防火墙规则创建失败，可手动放行 TCP $Port ：$($_.Exception.Message)"
}

# --- 6. 开机自启 + 启动 ---
$arg = "`"$serverPy`" --port $Port"
if ($NoAutoStart) {
    Warn "已跳过自启动注册，可用 start.bat 手动启动"
} else {
    Info "注册开机自启任务并启动服务..."
    try {
        $action = New-ScheduledTaskAction -Execute $pythonExe -Argument $arg -WorkingDirectory $dst
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principalObj = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principalObj -Settings $settings -Force | Out-Null
        Start-ScheduledTask -TaskName $TaskName
        Ok "开机自启任务已注册并启动"
    } catch {
        Warn "计划任务注册失败，改为直接后台启动：$($_.Exception.Message)"
        Start-Process -FilePath $pythonExe -ArgumentList $arg -WorkingDirectory $dst -WindowStyle Hidden
    }
}

# --- 7. 健康检查 ---
Info "等待服务就绪..."
$healthy = $false
for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Seconds 1
    try {
        $r = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2
        if ($r.status -eq "ok") { $healthy = $true; break }
    } catch { }
}
if (-not $healthy) {
    $logFile = Join-Path $dst "logs\server.log"
    Warn "健康检查未通过，请查看日志：$logFile"
    if (Test-Path $logFile) { Get-Content $logFile -Tail 20 }
    Fail "服务未成功启动"
}
Ok "服务运行中 (REST v1)"

# --- 8. 输出访问信息 ---
$ips = @()
try {
    $ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -ne "127.0.0.1" -and $_.PrefixOrigin -ne "WellKnown" } |
        Select-Object -ExpandProperty IPAddress
} catch { }
Write-Host ""
Write-Host "  ==================== 部署完成 ====================" -ForegroundColor Green
Write-Host "  管理台:      http://localhost:$Port/" -ForegroundColor White
Write-Host "  健康检查:    http://localhost:$Port/health" -ForegroundColor White
Write-Host "  接口清单:    http://localhost:$Port/v1/meta" -ForegroundColor White
foreach ($ip in $ips) { Write-Host "  局域网访问:  http://${ip}:$Port/" -ForegroundColor White }
Write-Host ""
Write-Host "  【重要】腾讯云控制台 → 实例 → 安全组 → 入站规则" -ForegroundColor Yellow
Write-Host "          放行 TCP $Port （来源可先填 0.0.0.0/0，上线后建议收紧）" -ForegroundColor Yellow
Write-Host ""
Write-Host "  iOS App 联云: 我的 → 配置云服务器 → Base URL 填 http://<公网IP>:$Port" -ForegroundColor Cyan
if ($finalToken) { Write-Host "                 Token 填 $finalToken" -ForegroundColor Cyan }
Write-Host ""
Write-Host "  运维: 前台调试 start.bat | 停止 stop.ps1 | 卸载 uninstall.ps1" -ForegroundColor DarkGray
Write-Host "  日志: $dst\logs\server.log    数据: $dst\data\db.json" -ForegroundColor DarkGray
Write-Host ""
if (-not $NoPause) { Read-Host "按回车键关闭本窗口" | Out-Null }
