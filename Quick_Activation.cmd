@echo off
chcp 936 >nul 2>&1
setlocal EnableExtensions

set "IAS=%~dp0IAS.cmd"
if not exist "%IAS%" (
    echo [KESALAHAN] IAS.cmd tidak ditemukan. Pastikan file ini dan IAS.cmd berada di folder yang sama.
    pause
    exit /b 1
)

fltmc >nul 2>&1
if %errorlevel% NEQ 0 (
    echo [PETUNJUK] Mencoba menjalankan skrip ini lagi sebagai administrator...
    where powershell.exe >nul 2>&1 || (
        echo [KESALAHAN] PowerShell tidak ditemukan, jadi izin administrator tidak bisa diminta otomatis. Klik kanan file ini lalu pilih Jalankan sebagai administrator.
        pause
        exit /b 1
    )
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath \"%~f0\" -Verb RunAs"
    exit /b
)

echo [INFO] Memanggil IAS.cmd /frz (mode aktivasi beku)...
call "%IAS%" /frz %*
set "ret=%errorlevel%"
if not "%ret%"=="0" (
    echo [PETUNJUK] IAS.cmd mengembalikan kode %ret%. Lihat output layar atau jalankan dulu "Test_Script.cmd" untuk memeriksa lingkungan.
)
echo %* | find /i "/silent" >nul || pause
endlocal & exit /b %ret%