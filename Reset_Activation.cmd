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

echo [INFO] Memanggil IAS.cmd /res /log (reset aktivasi atau masa uji coba)...
echo [INFO] Log detail akan ditulis ke %%SystemRoot%%\Temp\IAS-*.log
echo.
call "%IAS%" /res /log %*
set "ret=%errorlevel%"
echo.
if not "%ret%"=="0" (
    echo [PETUNJUK] IAS.cmd mengembalikan kode %ret%. Lihat output layar atau jalankan dulu "Test_Script.cmd" untuk memeriksa lingkungan.
) else (
    echo [INFO] IAS.cmd selesai dengan kode 0 (sukses).
)

::  Safety net: `choice /c 0 /n` loop (bukan di dalam `if (...)` block).
echo %* | find /i "/silent" >nul && goto launcher_exit

echo.
echo Ketik 0 untuk menutup konsol launcher.
goto launcher_wait

:launcher_wait
choice /c 0 /n
if errorlevel 2 goto launcher_wait
if not errorlevel 1 goto launcher_wait

:launcher_exit
endlocal & exit /b %ret%
