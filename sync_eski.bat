@echo off
setlocal
cd /d "%~dp0"

echo [TinyFisher] eski branch senkronizasyonu basliyor...

for /f "delims=" %%i in ('git status --porcelain 2^>nul') do set DIRTY=1
if defined DIRTY (
    echo Yerel degisiklikler bulundu. Guvenlik icin stash'e yedekleniyor...
    git stash push -u -m "auto-backup-before-sync"
    if errorlevel 1 goto :error
)

git fetch origin eski
if errorlevel 1 goto :error

git checkout eski
if errorlevel 1 goto :error

git reset --hard origin/eski
if errorlevel 1 goto :error

echo.
echo TAMAM: Proje origin/eski ile birebir senkronize edildi.
echo Godot'u simdi acabilirsin.
echo.
pause
exit /b 0

:error
echo.
echo HATA: Senkronizasyon tamamlanamadi. Yukaridaki Git mesajini kontrol et.
echo.
pause
exit /b 1
