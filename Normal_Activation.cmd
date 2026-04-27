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

echo [INFO] Memanggil IAS.cmd /act /log (mode aktivasi normal dengan data registrasi acak)...
echo [INFO] Log detail akan ditulis ke %%SystemRoot%%\Temp\IAS-*.log
echo.
call "%IAS%" /act /log %*
set "ret=%errorlevel%"
echo.
if not "%ret%"=="0" (
    echo [PETUNJUK] IAS.cmd mengembalikan kode %ret%. Lihat output layar atau jalankan dulu "Test_Script.cmd" untuk memeriksa lingkungan.
) else (
    echo [INFO] IAS.cmd selesai dengan kode 0 (sukses).
)

::  IAS.cmd v1.9.13+ sudah menahan konsol dengan `choice /c 0 /n` di
::  :done_unattended / :done2_unattended, jadi kontrol tidak akan
::  sampai ke sini kecuali IAS exit lewat jalur yang tidak terduga.
::
::  Tetapi sebagai safety net TAMBAHAN, kita pasang `choice /c 0 /n`
::  (bukan `pause`) sebelum endlocal. `choice` baca lewat Win32
::  Console API ke handle console langsung, bukan stdin, sehingga
::  selalu menahan konsol walau stdin ter-redirect oleh elevasi
::  `Start-Process -Verb RunAs`.
echo %* | find /i "/silent" >nul
if errorlevel 1 (
    echo.
    echo Ketik 0 untuk menutup konsol launcher.
    :_launcher_wait0
    choice /c 0 /n
    if errorlevel 2 goto _launcher_wait0
    if not errorlevel 1 goto _launcher_wait0
)
endlocal & exit /b %ret%
