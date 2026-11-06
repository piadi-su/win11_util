
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] Please run this script as Administrator" -ForegroundColor Red
    Exit
}

Write-Host "=== Starting Optimization ===" -ForegroundColor Cyan

#Power Plan Optimization 
# not for laptop
# Write-Host "[*] Configuring High-Performance Power Plan..." -ForegroundColor Yellow
# $ultimateGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
# $existing = powercfg -l | Select-String $ultimateGuid
# if (-not $existing) {
#     powercfg -duplicatescheme $ultimateGuid | Out-Null
# }
# powercfg -s $ultimateGuid
# # Disable USB selective suspend to prevent latency/disconnects for mice/keyboards
# powercfg -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
# powercfg -setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
# powercfg -SetActive $ultimateGuid

#Network Latency & TCP/IP Tweaks
Write-Host "[*] Optimizing Network Settings & Reducing Ping..." -ForegroundColor Yellow
$netPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
if (Test-Path $netPath) {
    Set-ItemProperty -Path $netPath -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord
    Set-ItemProperty -Path $netPath -Name "SystemResponsiveness" -Value 0 -Type DWord
}

# TCPNoDelay and TcpAckFrequency on active adapters
$interfaces = Get-NetAdapter | Where-Object {$_.Status -eq 'Up'}
foreach ($nic in $interfaces) {
    $nicRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($nic.InterfaceGuid)"
    if (Test-Path $nicRegPath) {
        Set-ItemProperty -Path $nicRegPath -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $nicRegPath -Name "TCPNoDelay" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    }
}

# Windows Game Mode and Priority Tweaks
Write-Host "[*] Enabling Windows Game Mode & Priority..." -ForegroundColor Yellow
$gameModePath = "HKCU:\Software\Microsoft\GameBar"
if (-not (Test-Path $gameModePath)) { New-Item -Path $gameModePath -Force | Out-Null }
Set-ItemProperty -Path $gameModePath -Name "AutoGameModeEnabled" -Value 1 -Type DWord

$guxPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
if (Test-Path $guxPath) {
    Set-ItemProperty -Path $guxPath -Name "GPU Priority" -Value 8 -Type DWord
    Set-ItemProperty -Path $guxPath -Name "Priority" -Value 6 -Type DWord
    Set-ItemProperty -Path $guxPath -Name "Scheduling Category" -Value "High" -String
}

# 4. GPU Hardware Accelerated Scheduling (HAGS) & Visual Effects
Write-Host "[*] Optimizing GPU Scheduling & Visual Performance..." -ForegroundColor Yellow
$graphicsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
if (Test-Path $graphicsPath) {
    # Enable HAGS (Hardware Accelerated GPU Scheduling) if supported
    Set-ItemProperty -Path $graphicsPath -Name "HwSchMode" -Value 2 -Type DWord -ErrorAction SilentlyContinue
}

# Disable unnecessary visual effects for maximum performance
$perfPath = "HKCU:\Control Panel\Desktop"
Set-ItemProperty -Path $perfPath -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -ErrorAction SilentlyContinue

Write-Host "[*] Disabling Common Background Telemetry Services..." -Connected 2>/dev/null
$services = @("DiagTrack", "dmwappushservice")
foreach ($svc in $services) {
    if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
    }
}

# os clean and cache
Write-Host "[*] Cleaning Temporary Files and System Caches..." -ForegroundColor Yellow
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Clear-RecycleBin -Force -ErrorAction SilentlyContinue

Write-Host "===  Complete! Please restart your laptop to apply changes ===" -ForegroundColor Green
