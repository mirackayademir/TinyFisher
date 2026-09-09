@echo off
setlocal
cd /d "%~dp0"

echo [TinyFisher] eski branch ZORUNLU senkronizasyon basliyor...
echo Yerel Godot degisiklikleri ve uretilen untracked dosyalar temizlenecek.
echo.

:: Bu proje klasoru GitHub'daki eski branch'in yerel aynasi olarak kullaniliyor.
:: Godot'un otomatik degistirdigi project.godot, *.import, *.uid vb. dosyalar
:: pull/merge'i engellemesin diye once yerel farklari temizliyoruz.
git reset --hard HEAD
if errorlevel 1 goto :error

git clean -fd
if errorlevel 1 goto :error

git fetch origin eski
if errorlevel 1 goto :error

git checkout eski
if errorlevel 1 goto :error

git reset --hard origin/eski
if errorlevel 1 goto :error

git clean -fd
if errorlevel 1 goto :error

echo.
echo TAMAM: Proje origin/eski ile birebir senkronize edildi.
echo Godot'u simdi acabilirsin.
echo.
git status --short
pause
exit /b 0

:error
echo.
echo HATA: Senkronizasyon tamamlanamadi. Yukaridaki Git mesajini kontrol et.
echo.
pause
exit /b 1
