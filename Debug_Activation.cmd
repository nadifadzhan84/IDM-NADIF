@echo off
::  Debug_Activation.cmd - DIAGNOSTIK
::
::  File ini berguna kalau konsol aktivasi normal menutup sendiri sebelum
::  kamu sempat membaca pesan error. Cara kerjanya:
::
::  1. Stream SEMUA output (stdout + stderr) dari Normal_Activation.cmd ke
::     sebuah file log `IAS-DEBUG-<timestamp>.log` di folder yang sama
::     dengan file ini, dan sekaligus menampilkannya di layar.
::  2. Tidak pernah auto-close apapun yang terjadi. Setelah selesai (atau
::     crash di tengah jalan), konsol menampilkan lokasi log dan menunggu
::     user mengetik `0` untuk menutup.
::  3. Juga melampirkan semua file `%SystemRoot%\Temp\IAS-*.log` yang
::     ditulis oleh IAS.cmd selama proses (flag `/log` di launcher).
::
::  Cara pakai:
::    Klik kanan file ini -> Run as administrator
::    Setelah proses selesai, ambil file IAS-DEBUG-*.log + file di
::    %SystemRoot%\Temp\IAS-*.log lalu kirim ke pengembang.
::
chcp 936 >nul 2>&1
setlocal EnableExtensions EnableDelayedExpansion

::  Self-elevate kalau belum admin.
fltmc >nul 2>&1
if %errorlevel% NEQ 0 (
    echo [PETUNJUK] Meminta hak administrator untuk Debug_Activation...
    where powershell.exe >nul 2>&1 || (
        echo [KESALAHAN] PowerShell tidak ditemukan.
        pause
        exit /b 1
    )
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath \"%~f0\" -Verb RunAs"
    exit /b
)

set "HERE=%~dp0"
set "NORMAL=%HERE%Normal_Activation.cmd"
if not exist "%NORMAL%" (
    echo [KESALAHAN] Normal_Activation.cmd tidak ditemukan di %HERE%
    goto :final_wait
)

::  Build timestamp tanpa karakter illegal di path.
for /f %%a in ('powershell -NoProfile -Command "(Get-Date).ToString('yyyyMMdd-HHmmss')"') do set "TS=%%a"
if not defined TS set "TS=nostamp"
set "DEBUG_LOG=%HERE%IAS-DEBUG-%TS%.log"

echo.
echo ============================================================
echo   IDM-NADIF Debug Activation Wrapper
echo ============================================================
echo   Script folder : %HERE%
echo   Debug log     : %DEBUG_LOG%
echo   IAS log folder: %SystemRoot%\Temp
echo ============================================================
echo.
echo [INFO] Menjalankan Normal_Activation.cmd dengan tee ke log file.
echo [INFO] Konsol TIDAK akan menutup otomatis walau Normal_Activation crash.
echo.

::  Jalankan Normal_Activation.cmd di konsol yang sama, capture stdout+stderr
::  ke log file dan juga tampilkan di layar pakai PowerShell Tee-Object.
::
::  `cmd /c` memastikan kalau Normal_Activation melakukan `exit` (bukan
::  `exit /b`) yang mati hanya cmd anak itu, BUKAN konsol Debug ini.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Continue';" ^
  "$log = '%DEBUG_LOG%';" ^
  "'== Debug_Activation.cmd started ' + (Get-Date).ToString('s') + ' ==' | Tee-Object -FilePath $log;" ^
  "try { cmd /c \"\"%NORMAL%\"\" 2>&1 | Tee-Object -FilePath $log -Append } catch { $_ | Tee-Object -FilePath $log -Append };" ^
  "'== Debug_Activation.cmd ended   ' + (Get-Date).ToString('s') + ' ==' | Tee-Object -FilePath $log -Append"
set "ret=%errorlevel%"

echo.
echo ============================================================
echo [INFO] Proses selesai dengan exit code: %ret%
echo [INFO] Debug log tersimpan di:
echo        %DEBUG_LOG%
echo.
if exist "%SystemRoot%\Temp\IAS-*.log" (
    echo [INFO] File log IAS.cmd juga tersedia di %%SystemRoot%%\Temp\IAS-*.log :
    dir /b /o-d "%SystemRoot%\Temp\IAS-*.log" 2>nul
) else (
    echo [INFO] Tidak ditemukan IAS-*.log di %%SystemRoot%%\Temp. Kemungkinan
    echo        IAS.cmd exit sebelum log file dibuat. Debug log di atas
    echo        seharusnya tetap berisi output lengkap.
)
echo ============================================================
echo.

:final_wait
echo Ketik 0 untuk menutup konsol Debug Activation.
:_debug_wait0
choice /c 0 /n
if errorlevel 2 goto _debug_wait0
if not errorlevel 1 goto _debug_wait0
endlocal & exit /b %ret%
