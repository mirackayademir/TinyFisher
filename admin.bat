@echo off
cd /d "%~dp0"

:: Yonetici yetkisi kontrolu
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell.exe -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Proje klasorunde tek PowerShell ac
powershell.exe -NoExit -Command "Set-Location -LiteralPath '%~dp0'"

exit /b