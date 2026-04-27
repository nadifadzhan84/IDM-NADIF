@echo off
::  Debug_Activation.cmd - DIAGNOSTIK
::
::  Wrapper ini stream SEMUA output dari Normal_Activation.cmd ke file log
::  `IAS-DEBUG-<timestamp>.log` (di folder yang sama), sekaligus menampilkan
::  di layar, dan TIDAK PERNAH auto-close apapun yang terjadi. Dipakai
::  untuk capture log kalau konsol aktivasi normal masih menutup sendiri.
::
::  Cara pakai: klik kanan file ini -> Run as administrator.
::  Setelah selesai, kirim IAS-DEBUG-*.log + %%SystemRoot%%\Temp\IAS-*.log
::  ke pengembang.
::
chcp 936 >nul 2>&1
setlocal EnableExtensions

::  Self-elevate.
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
    goto final_wait
)

::  Build timestamp tanpa karakter illegal di path.
set "TS="
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

::  PENTING: path NORMAL dan DEBUG_LOG kemungkinan mengandung spasi
::  (mis. "C:\Users\John Doe\..."). Di v1.9.13 kita pakai `cmd /c "..."`
::  di dalam argumen PowerShell, yang ternyata merusak quoting path
::  ber-spasi (error "'C:\Users\Yoyong' is not recognized").
::
::  v1.9.14: generate script .ps1 sementara yang menerima path sebagai
::  $args[0]/$args[1]. PowerShell `&` operator spawn cmd.exe internal
::  dengan quoting argv yang benar, tanpa kita harus escape manual.
set "DEBUG_PS1=%HERE%_debug_run.ps1"
>"%DEBUG_PS1%" echo $ErrorActionPreference = 'Continue'
>>"%DEBUG_PS1%" echo $log  = $args[0]
>>"%DEBUG_PS1%" echo $norm = $args[1]
>>"%DEBUG_PS1%" echo ('== Debug_Activation.cmd started ' + (Get-Date).ToString('s') + ' ==') ^| Tee-Object -FilePath $log
>>"%DEBUG_PS1%" echo ('Normal_Activation path: ' + $norm) ^| Tee-Object -FilePath $log -Append
>>"%DEBUG_PS1%" echo ('Debug log path       : ' + $log) ^| Tee-Object -FilePath $log -Append
>>"%DEBUG_PS1%" echo '---- Normal_Activation output ----' ^| Tee-Object -FilePath $log -Append
>>"%DEBUG_PS1%" echo try { ^& $norm 2^>^&1 ^| Tee-Object -FilePath $log -Append } catch { $_.Exception.Message ^| Tee-Object -FilePath $log -Append }
>>"%DEBUG_PS1%" echo ('---- Exit code: ' + $LASTEXITCODE + ' ----') ^| Tee-Object -FilePath $log -Append
>>"%DEBUG_PS1%" echo ('== Debug_Activation.cmd ended   ' + (Get-Date).ToString('s') + ' ==') ^| Tee-Object -FilePath $log -Append
>>"%DEBUG_PS1%" echo exit $LASTEXITCODE

powershell -NoProfile -ExecutionPolicy Bypass -File "%DEBUG_PS1%" "%DEBUG_LOG%" "%NORMAL%"
set "ret=%errorlevel%"

del /f /q "%DEBUG_PS1%" >nul 2>&1

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
goto debug_wait

:debug_wait
choice /c 0 /n
if errorlevel 2 goto debug_wait
if not errorlevel 1 goto debug_wait
endlocal & exit /b %ret%
