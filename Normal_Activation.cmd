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

echo [INFO] Memanggil IAS.cmd /act (mode aktivasi normal dengan data registrasi acak)...
call "%IAS%" /act %*
set "ret=%errorlevel%"
if not "%ret%"=="0" (
    echo [PETUNJUK] IAS.cmd mengembalikan kode %ret%. Lihat output layar atau jalankan dulu "Test_Script.cmd" untuk memeriksa lingkungan.
)
::  IAS.cmd `:done` sekarang sudah menahan jendela dengan `cmd /k`
::  (untuk mode unattended-non-silent), jadi saat kontrol balik ke sini
::  user sudah eksplisit mengetik `exit` atau menutup jendela. Pause di
::  wrapper sini tidak diperlukan lagi, dan kalau dipasang justru bisa
::  exit instan karena stdin yang sama (`Start-Process -Verb RunAs` bikin
::  cmd elevated dengan handle stdin yang gampang ter-redirect). Tetap
::  pause hanya kalau IAS.cmd error & kita tidak masuk ke `cmd /k`
::  shell, supaya user sempat lihat pesan error.
if not "%ret%"=="0" (
    echo %* | find /i "/silent" >nul || pause <con
)
endlocal & exit /b %ret%