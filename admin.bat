@echo off

:: Yönetici yetkisi kontrolü
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Aynı klasörde yönetici CMD aç
start "" cmd.exe /K "cd /d %~dp0"

:: Aynı klasörde yönetici PowerShell aç
start "" powershell.exe -NoExit -Command "Set-Location -LiteralPath '%~dp0'"

exit