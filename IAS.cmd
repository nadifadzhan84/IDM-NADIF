@set iasver=1.9.5
@setlocal DisableDelayedExpansion
@echo off

::  Keep this script ASCII-only so cmd.exe parses it consistently across code pages.
::  Paksa code page menjadi 936 (GBK/Bahasa Mandarin Sederhana)
chcp 936 >nul 2>&1


::============================================================================
::
::   Skrip Aktivasi IDM (IAS)
::
::   Halaman proyek: https://github.com/tytsxai/IDM-Activation-Script-Chinese
::   Umpan balik masalah: https://github.com/tytsxai/IDM-Activation-Script-Chinese/issues
::   Lisensi  : GPL-3.0 (lihat LICENSE di root repo)
::   By       : Nadif Rizky
::
::   ----- Navigasi kode (untuk pemeliharaan berikutnya) -----
::   Baris 01-040 : metadata header, pengaturan code page, sakelar bawaan
::   Baris 040-110 : pengaturan PATH, re-entry arsitektur Sysnative / SysArm32, parsing parameter (/act /frz /res /silent /log)
::   Baris 110-150 : verifikasi mode senyap, pemeriksaan layanan Null, inisialisasi log
::   Baris 150-400 : deteksi lingkungan (hak administrator, jalur instalasi IDM, item registri CLSID, konektivitas jaringan)
::   Baris 400-600 : menu utama (pembekuan / aktivasi / reset / unduh / bantuan), pengarah interaktif
::   Baris 600-870 : alur inti aktivasi dan pembekuan, pencadangan registri, penyuntikan informasi registrasi acak
::   Baris 870-1017 : alur reset, penanganan kesalahan, penutupan log, kode keluar
::
::============================================================================



::  To activate, run the script with "/act" parameter or change 0 to 1 in below line
set _activate=0

::  To Freeze the 30 days trial period, run the script with "/frz" parameter or change 0 to 1 in below line
set _freeze=0

::  To reset the activation and trial, run the script with "/res" parameter or change 0 to 1 in below line
set _reset=0

::  If value is changed in above lines or parameter is used then script will run in unattended mode

::========================================================================================================================================

::  Set Path variable, it helps if it is misconfigured in the system

set "PATH=%SystemRoot%\System32;%SystemRoot%\System32\wbem;%SystemRoot%\System32\WindowsPowerShell\v1.0\"
if exist "%SystemRoot%\Sysnative\reg.exe" (
set "PATH=%SystemRoot%\Sysnative;%SystemRoot%\Sysnative\wbem;%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\;%PATH%"
)

:: Re-launch the script with x64 process if it was initiated by x86 process on x64 bit Windows
:: or with ARM64 process if it was initiated by x86/ARM32 process on ARM64 Windows

set "_cmdf=%~f0"
for %%# in (%*) do (
if /i "%%#"=="r1" set r1=1
if /i "%%#"=="r2" set r2=1
)

if exist %SystemRoot%\Sysnative\cmd.exe if not defined r1 (
setlocal EnableDelayedExpansion
start %SystemRoot%\Sysnative\cmd.exe /c ""!_cmdf!" %* r1"
exit /b
)

:: Re-launch the script with ARM32 process if it was initiated by x64 process on ARM64 Windows

if exist %SystemRoot%\SysArm32\cmd.exe if %PROCESSOR_ARCHITECTURE%==AMD64 if not defined r2 (
setlocal EnableDelayedExpansion
start %SystemRoot%\SysArm32\cmd.exe /c ""!_cmdf!" %* r2"
exit /b
)

::========================================================================================================================================

set "blank="
set "mas=ht%blank%tps%blank%://github.com/tytsxai/IDM-Activation-Script-Chinese"

set _args=
set _elev=
set _silent=0
set _log=0
set _log_enabled=0
set _unattended=0
set "log_file="
set "exit_code=0"

set _args=%*
if defined _args set _args=%_args:"=%
if defined _args (
for %%A in (%_args%) do (
if /i "%%A"=="-el"  set _elev=1
if /i "%%A"=="/res" set _reset=1
if /i "%%A"=="/frz" set _freeze=1
if /i "%%A"=="/act" set _activate=1
if /i "%%A"=="/silent" set _silent=1
if /i "%%A"=="/quiet" set _silent=1
if /i "%%A"=="/log" set _log=1
)
)

for %%A in (%_activate% %_freeze% %_reset%) do (if "%%A"=="1" set _unattended=1)
if %_silent%==1 set _unattended=1
if %_silent%==1 set _log=1

set "log_dir=%SystemRoot%\Temp"
if %_log%==1 (
if not exist "%log_dir%" md "%log_dir%"
set "_logstamp=%date%_%time%"
set "_logstamp=%_logstamp::=%"
set "_logstamp=%_logstamp: =0%"
set "_logstamp=%_logstamp:.=%"
set "_logstamp=%_logstamp:,=%"
set "_logstamp=%_logstamp:/=%"
set "_logstamp=%_logstamp:\=%"
set "log_file=%log_dir%\IAS-%_logstamp%.log"
set _log_enabled=1
call :log "IAS %iasver% dimulai, parameter: %_args%"
call :log "Output log: %log_file%"
if %_silent%==0 echo File log: %log_file%
)

if %_silent%==1 if %_activate%==0 if %_freeze%==0 if %_reset%==0 (
call :set_exit 2 "Mode senyap kekurangan parameter aksi, keluar"
goto done2
)

::  Check if Null service is working, it's important for the batch script

sc query Null | find /i "RUNNING"
if %errorlevel% NEQ 0 (
call :log "Peringatan: layanan Null tidak berjalan, dapat menyebabkan skrip gagal"
echo:
echo Layanan Null tidak berjalan, skrip mungkin mengalami kesalahan...
echo:
echo:
echo Bantuan - %mas%
echo:
echo:
if %_silent%==1 (ping 127.0.0.1 -n 2 >nul) else ping 127.0.0.1 -n 10
)
cls
chcp 936 >nul 2>&1

::  Check LF line ending

pushd "%~dp0"
>nul findstr /v "$" "%~nx0" && (
echo:
echo Kesalahan: skrip berisi LF atau tidak memiliki baris kosong di akhir.
echo:
call :set_exit 2 "Kesalahan: terdeteksi LF atau tidak ada baris kosong di akhir"
if %_silent%==1 (ping 127.0.0.1 -n 2 >nul) else ping 127.0.0.1 -n 6 >nul
popd
exit /b %exit_code%
)
popd

::========================================================================================================================================

cls
chcp 936 >nul 2>&1
color 07
title  Skrip Aktivasi IDM %iasver% - By Nadif Rizky

::========================================================================================================================================

set "nul1=1>nul"
set "nul2=2>nul"
set "nul6=2^>nul"
set "nul=>nul 2>&1"

set psc=powershell.exe
set winbuild=1
for /f "tokens=6 delims=[]. " %%G in ('ver') do set winbuild=%%G

set _NCS=1
if %winbuild% LSS 10586 set _NCS=0
if %winbuild% GEQ 10586 reg query "HKCU\Console" /v ForceV2 %nul2% | find /i "0x0" %nul1% && (set _NCS=0)

if %_NCS% EQU 1 (
for /F %%a in ('echo prompt $E ^| cmd') do set "esc=%%a"
set     "Red="41;97m""
set    "Gray="100;97m""
set   "Green="42;97m""
set    "Blue="44;97m""
set  "_White="40;37m""
set   "_Cyan="40;96m""
set  "_Green="40;92m""
set "_Yellow="40;93m""
) else (
set     "Red="Red" "white""
set    "Gray="Darkgray" "white""
set   "Green="DarkGreen" "white""
set    "Blue="Blue" "white""
set  "_White="Black" "Gray""
set   "_Cyan="Black" "Cyan""
set  "_Green="Black" "Green""
set "_Yellow="Black" "Yellow""
)

set "nceline=echo: &echo ==== ERROR ==== &echo:"
set "eline=echo: &call :_color %Red% "==== ERROR ====" &echo:"
set "line===================================================================================================="
set "_buf={$W=$Host.UI.RawUI.WindowSize;$B=$Host.UI.RawUI.BufferSize;$W.Height=34;$B.Height=300;$Host.UI.RawUI.WindowSize=$W;$Host.UI.RawUI.BufferSize=$B;}"

::========================================================================================================================================

if %winbuild% LSS 7600 (
%nceline%
echo Terdeteksi versi sistem operasi yang tidak didukung [%winbuild%].
echo Skrip ini mendukung Windows 7/8/8.1/10/11 dan versi setelahnya.
call :set_exit 2 "Versi sistem operasi tidak didukung [%winbuild%]"
echo:
pause
goto done2
)

for %%# in (powershell.exe) do @if "%%~$PATH:#"=="" (
%nceline%
echo Sistem tidak dapat menemukan powershell.exe.
call :set_exit 2 "Sistem tidak dapat menemukan powershell.exe"
echo:
pause
goto done2
)

::========================================================================================================================================

::  Fix for the special characters limitation in path name

set "_work=%~dp0"
if "%_work:~-1%"=="\" set "_work=%_work:~0,-1%"

set "_batf=%~f0"
set "_batp=%_batf:'=''%"

set _PSarg="""%~f0""" -el %_args%
set _PSarg=%_PSarg:'=''%

set "_appdata=%appdata%"
set "_ttemp=%userprofile%\AppData\Local\Temp"

setlocal EnableDelayedExpansion

::========================================================================================================================================

echo "!_batf!" | find /i "!_ttemp!" %nul1% && (
if /i not "!_work!"=="!_ttemp!" (
%eline%
echo Skrip dijalankan dari folder sementara.
echo Anda mungkin menjalankan skrip dari penampil arsip.
echo:
echo Ekstrak arsip lalu jalankan skrip dari folder hasil ekstrak.
call :set_exit 2 "Skrip dijalankan dari folder sementara, diblokir"
echo:
pause
goto done2
)
)

::========================================================================================================================================

::  Check PowerShell

REM :PowerShellTest: $ExecutionContext.SessionState.LanguageMode :PowerShellTest:

%psc% "$f=[io.file]::ReadAllText('!_batp!') -split ':PowerShellTest:\s*';iex ($f[1])" | find /i "FullLanguage" %nul1% || (
%eline%
%psc% $ExecutionContext.SessionState.LanguageMode
echo:
echo PowerShell tidak dapat berjalan normal, proses diblokir...
echo Organisasi Anda mungkin menonaktifkan aplikasi PowerShell untuk mencegah hal ini.
echo:
echo Lihat halaman web untuk bantuan: %mas%
call :set_exit 2 "PowerShell diblokir"
echo:
pause
goto done2
)

::========================================================================================================================================

::  Elevate script as admin and pass arguments and preventing loop

%nul1% fltmc || (
if not defined _elev %psc% "start cmd.exe -arg '/c \"!_PSarg!\"' -verb runas" && exit /b
%eline%
echo Skrip ini memerlukan hak administrator.
echo Klik kanan skrip ini lalu pilih "Jalankan sebagai administrator".
call :set_exit 2 "Hak administrator tidak tersedia"
echo:
pause
goto done2
)

::========================================================================================================================================

::  Disable QuickEdit and launch from conhost.exe to avoid Terminal app

set quedit=
set terminal=

if %_unattended%==1 (
set quedit=1
set terminal=1
)

for %%# in (%_args%) do (if /i "%%#"=="-qedit" set quedit=1)

if %winbuild% LSS 10586 (
reg query HKCU\Console /v QuickEdit %nul2% | find /i "0x0" %nul1% && set quedit=1
)

if %winbuild% GEQ 17763 (
set "launchcmd=start conhost.exe %psc%"
) else (
set "launchcmd=%psc%"
)

set "d1=$t=[AppDomain]::CurrentDomain.DefineDynamicAssembly(4, 1).DefineDynamicModule(2, $False).DefineType(0);"
set "d2=$t.DefinePInvokeMethod('GetStdHandle', 'kernel32.dll', 22, 1, [IntPtr], @([Int32]), 1, 3).SetImplementationFlags(128);"
set "d3=$t.DefinePInvokeMethod('SetConsoleMode', 'kernel32.dll', 22, 1, [Boolean], @([IntPtr], [Int32]), 1, 3).SetImplementationFlags(128);"
set "d4=$k=$t.CreateType(); $b=$k::SetConsoleMode($k::GetStdHandle(-10), 0x0080);"

if defined quedit goto :skipQE
%launchcmd% "%d1% %d2% %d3% %d4% & cmd.exe '/c' '!_PSarg! -qedit'" &exit /b
:skipQE

::========================================================================================================================================

::  Check for updates

set old=
if not %_unattended%==1 (
echo ________________________________________________
echo Versi saat ini: %iasver% ^(versi repositori lokal^)
echo Untuk memeriksa pembaruan, kunjungi halaman proyek: %mas%
echo ________________________________________________
echo:
)

::========================================================================================================================================

cls
chcp 936 >nul 2>&1
title  Skrip Aktivasi IDM %iasver% - By Nadif Rizky

echo:
echo Sedang menginisialisasi...

::  Check WMI

%psc% "Get-WmiObject -Class Win32_ComputerSystem | Select-Object -Property CreationClassName" %nul2% | find /i "computersystem" %nul1% || (
%eline%
%psc% "Get-WmiObject -Class Win32_ComputerSystem | Select-Object -Property CreationClassName"
echo:
echo WMI tidak berfungsi dengan benar, proses diblokir...
echo:
echo Lihat halaman web untuk bantuan: %mas%
call :set_exit 2 "Kueri WMI gagal"
echo:
pause
goto done2
)

::  Check user account SID

set _sid=
for /f "delims=" %%a in ('%psc% "([System.Security.Principal.NTAccount](Get-WmiObject -Class Win32_ComputerSystem).UserName).Translate([System.Security.Principal.SecurityIdentifier]).Value" %nul6%') do (set _sid=%%a)

reg query HKU\%_sid%\Software %nul% || (
for /f "delims=" %%a in ('%psc% "$explorerProc = Get-Process -Name explorer | Where-Object {$_.SessionId -eq (Get-Process -Id $pid).SessionId} | Select-Object -First 1; $sid = (gwmi -Query ('Select * From Win32_Process Where ProcessID=' + $explorerProc.Id)).GetOwnerSid().Sid; $sid" %nul6%') do (set _sid=%%a)
)

reg query HKU\%_sid%\Software %nul% || (
%eline%
echo:
echo [%_sid%]
echo SID akun pengguna tidak ditemukan, proses diblokir...
echo:
echo Lihat halaman web untuk bantuan: %mas%
call :set_exit 2 "Tidak dapat memperoleh SID pengguna saat ini"
echo:
pause
goto done2
)

::========================================================================================================================================

::  Check if the current user SID is syncing with the HKCU entries

%nul% reg delete HKCU\IAS_TEST /f
%nul% reg delete HKU\%_sid%\IAS_TEST /f

set HKCUsync=$null
%nul% reg add HKCU\IAS_TEST
%nul% reg query HKU\%_sid%\IAS_TEST && (
set HKCUsync=1
)

%nul% reg delete HKCU\IAS_TEST /f
%nul% reg delete HKU\%_sid%\IAS_TEST /f

::  Below code also works for ARM64 Windows 10 (including x64 bit emulation)

for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PROCESSOR_ARCHITECTURE') do set arch=%%b
if /i not "%arch%"=="x86" set arch=x64

if "%arch%"=="x86" (
set "CLSID=HKCU\Software\Classes\CLSID"
set "CLSID2=HKU\%_sid%\Software\Classes\CLSID"
set "HKLM=HKLM\Software\Internet Download Manager"
) else (
set "CLSID=HKCU\Software\Classes\Wow6432Node\CLSID"
set "CLSID2=HKU\%_sid%\Software\Classes\Wow6432Node\CLSID"
set "HKLM=HKLM\SOFTWARE\Wow6432Node\Internet Download Manager"
)

for /f "tokens=2*" %%a in ('reg query "HKU\%_sid%\Software\DownloadManager" /v ExePath %nul6%') do call set "IDMan=%%b"

if not exist "%IDMan%" (
if %arch%==x64 set "IDMan=%ProgramFiles(x86)%\Internet Download Manager\IDMan.exe"
if %arch%==x86 set "IDMan=%ProgramFiles%\Internet Download Manager\IDMan.exe"
)

if not exist %SystemRoot%\Temp md %SystemRoot%\Temp
set "idmcheck=tasklist /fi "imagename eq idman.exe" | findstr /i "idman.exe" %nul1%"

::  Check CLSID registry access

%nul% reg add %CLSID2%\IAS_TEST
%nul% reg query %CLSID2%\IAS_TEST || (
%eline%
echo Tidak dapat menulis %CLSID2%
echo:
echo Lihat halaman web untuk bantuan: %mas%
call :set_exit 2 "Tidak dapat menulis %CLSID2%"
echo:
pause
goto done2
)

%nul% reg delete %CLSID2%\IAS_TEST /f

::========================================================================================================================================

if %_reset%==1 goto :_reset
if %_activate%==1 (set frz=0&goto :_activate)
if %_freeze%==1 (set frz=1&goto :_activate)

:MainMenu

cls
chcp 936 >nul 2>&1
title  Skrip Aktivasi IDM %iasver% - By Nadif Rizky
if not defined terminal mode 98, 30

call :ui_banner "IDM ACTIVATION SUITE" "DIGITAL MODERN 2026"
echo:
call :ui_info "VERSION %iasver% BY NADIF RIZKY"
call :ui_info "Freeze mode adalah mode paling stabil untuk pemakaian harian"
echo:
call :ui_pick "1" "FREEZE ACTIVATION"
echo        Melindungi trial IDM dan menekan risiko warning
call :ui_pick "2" "NORMAL ACTIVATION"
echo        Menulis identitas registrasi acak dan uji unduhan
call :ui_pick "3" "RESET ACTIVATION"
echo        Membersihkan status aktivasi dan masa uji coba
echo:
call :ui_pick "4" "DOWNLOAD IDM"
echo        Membuka halaman unduh IDM resmi
call :ui_pick "5" "HELP CENTER"
echo        Membuka halaman bantuan proyek
call :ui_pick "0" "EXIT CONSOLE"
echo        Menutup konsol IAS
echo:
call :ui_line
call :ui_prompt "Tekan 1 2 3 4 5 0"
choice /C:123450 /N
set _erl=%errorlevel%

if %_erl%==6 exit /b
if %_erl%==5 start %mas% & goto MainMenu
if %_erl%==4 start https://www.internetdownloadmanager.com/download.html & goto MainMenu
if %_erl%==3 goto _reset
if %_erl%==2 (set frz=0&goto :_activate)
if %_erl%==1 (set frz=1&goto :_activate)
goto :MainMenu

::========================================================================================================================================

:_reset

call :log "Memulai alur reset"
cls
chcp 936 >nul 2>&1
if not %HKCUsync%==1 (
if not defined terminal mode 120, 35
) else (
if not defined terminal mode 110, 35
)
if not defined terminal %psc% "&%_buf%" %nul%

title  Skrip Aktivasi IDM %iasver% - By Nadif Rizky
call :ui_banner "RESET ACTIVATION" "DIGITAL RECOVERY FLOW"
echo:
call :ui_info "Mode ini menutup IDM lalu membersihkan status aktivasi"
echo:
call :ui_step "01" "Menutup proses IDM aktif"
%idmcheck% && taskkill /f /im idman.exe

set _time=
for /f %%a in ('%psc% "(Get-Date).ToString('yyyyMMdd-HHmmssfff')"') do set _time=%%a

echo:
call :ui_step "02" "Mencadangkan CLSID ke folder temp"

reg export %CLSID% "%SystemRoot%\Temp\_Backup_HKCU_CLSID_%_time%.reg"
if not %HKCUsync%==1 reg export %CLSID2% "%SystemRoot%\Temp\_Backup_HKU-%_sid%_CLSID_%_time%.reg"
call :log "Registri sudah dicadangkan: _Backup_HKCU_CLSID_%_time%.reg"
if not %HKCUsync%==1 call :log "Registri sudah dicadangkan: _Backup_HKU-%_sid%_CLSID_%_time%.reg"

call :ui_step "03" "Menghapus key registri lama"
call :delete_queue
%psc% "$sid = '%_sid%'; $HKCUsync = %HKCUsync%; $lockKey = $null; $deleteKey = 1; $f=[io.file]::ReadAllText('!_batp!') -split ':regscan\:.*';iex ($f[1])"

call :ui_step "04" "Menambahkan baseline key"
call :add_key

echo:
call :ui_line
echo:
call :ui_done "RESET ACTIVATION SELESAI"
call :ui_info "Anda dapat kembali ke dashboard untuk mode lain"

goto done

:delete_queue

echo:
call :ui_info "Menghapus nilai aktivasi lama dari registri IDM"
echo:
call :log "Memulai penghapusan kunci registri IDM"

for %%# in (
""HKCU\Software\DownloadManager" "/v" "FName""
""HKCU\Software\DownloadManager" "/v" "LName""
""HKCU\Software\DownloadManager" "/v" "Email""
""HKCU\Software\DownloadManager" "/v" "Serial""
""HKCU\Software\DownloadManager" "/v" "scansk""
""HKCU\Software\DownloadManager" "/v" "tvfrdt""
""HKCU\Software\DownloadManager" "/v" "radxcnt""
""HKCU\Software\DownloadManager" "/v" "LstCheck""
""HKCU\Software\DownloadManager" "/v" "ptrk_scdt""
""HKCU\Software\DownloadManager" "/v" "LastCheckQU""
"%HKLM%"
) do for /f "tokens=* delims=" %%A in ("%%~#") do (
set "reg="%%~A"" &reg query !reg! %nul% && call :del
)

if not %HKCUsync%==1 for %%# in (
""HKU\%_sid%\Software\DownloadManager" "/v" "FName""
""HKU\%_sid%\Software\DownloadManager" "/v" "LName""
""HKU\%_sid%\Software\DownloadManager" "/v" "Email""
""HKU\%_sid%\Software\DownloadManager" "/v" "Serial""
""HKU\%_sid%\Software\DownloadManager" "/v" "scansk""
""HKU\%_sid%\Software\DownloadManager" "/v" "tvfrdt""
""HKU\%_sid%\Software\DownloadManager" "/v" "radxcnt""
""HKU\%_sid%\Software\DownloadManager" "/v" "LstCheck""
""HKU\%_sid%\Software\DownloadManager" "/v" "ptrk_scdt""
""HKU\%_sid%\Software\DownloadManager" "/v" "LastCheckQU""
) do for /f "tokens=* delims=" %%A in ("%%~#") do (
set "reg="%%~A"" &reg query !reg! %nul% && call :del
)

exit /b

:del

reg delete %reg% /f %nul%

if "%errorlevel%"=="0" (
set "reg=%reg:"=%"
echo Dihapus - !reg!
call :log "Dihapus - !reg!"
) else (
set "reg=%reg:"=%"
call :_color2 %Red% "Gagal - !reg!"
call :set_exit 1 "Gagal menghapus - !reg!"
)

exit /b

::========================================================================================================================================

:_activate

if %frz%==1 (call :log "Memulai alur pembekuan masa uji coba") else (call :log "Memulai alur aktivasi")
cls
chcp 936 >nul 2>&1
if not %HKCUsync%==1 (
if not defined terminal mode 153, 35
) else (
if not defined terminal mode 113, 35
)
if not defined terminal %psc% "&%_buf%" %nul%

title  Skrip Aktivasi IDM %iasver% - By Nadif Rizky
if %frz%==1 (
call :ui_banner "FREEZE ACTIVATION" "DIGITAL SHIELD MODE"
call :ui_info "Mode ini paling stabil dan tidak menulis serial acak"
) else (
call :ui_banner "NORMAL ACTIVATION" "DIGITAL LICENSE MODE"
call :ui_info "Mode ini dapat memunculkan warning serial palsu"
)
echo:

if %frz%==0 if %_unattended%==0 (
echo:
call :ui_line
echo:
call :ui_alert "Normal activation dapat menampilkan warning serial"
call :ui_info "Gunakan freeze activation jika ingin hasil paling stabil"
echo:
call :ui_pick "1" "KEMBALI KE MENU"
call :ui_pick "9" "LANJUTKAN NORMAL ACTIVATION"
echo:
call :ui_prompt "Tekan 1 atau 9 untuk lanjut"
choice /C:19 /N /M ">    [1] Kembali [9] Lanjut : "
if !errorlevel!==1 goto :MainMenu
cls
chcp 936 >nul 2>&1
title  Skrip Aktivasi IDM %iasver% - By Nadif Rizky
call :ui_banner "NORMAL ACTIVATION" "DIGITAL LICENSE MODE"
call :ui_info "Mode ini dapat memunculkan warning serial palsu"
echo:
)

echo:
if not exist "%IDMan%" (
call :_color %Red% "IDM [Internet Download Manager] belum terpasang."
echo Anda bisa mengunduh dari alamat ini: https://www.internetdownloadmanager.com/download.html
call :set_exit 1 "Instalasi IDM tidak terdeteksi"
goto done
)

:: Internet check with internetdownloadmanager.com ping and port 80 test

set _int=
for /f "delims=[] tokens=2" %%# in ('ping -n 1 internetdownloadmanager.com') do (if not [%%#]==[] set _int=1)

if not defined _int (
%psc% "$t = New-Object Net.Sockets.TcpClient;try{$t.Connect("""internetdownloadmanager.com""", 80)}catch{};$t.Connected" | findstr /i "true" %nul1% || (
call :_color %Red% "Tidak dapat terhubung ke internetdownloadmanager.com, proses diblokir..."
call :set_exit 1 "Tidak dapat terhubung ke internetdownloadmanager.com"
goto done
)
call :_color %Gray% "Uji ping ke internetdownloadmanager.com gagal"
echo:
)

for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName 2^>nul') do set "regwinos=%%b"
for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PROCESSOR_ARCHITECTURE') do set "regarch=%%b"
for /f "tokens=6-7 delims=[]. " %%i in ('ver') do if "%%j"=="" (set fullbuild=%%i) else (set fullbuild=%%i.%%j)
for /f "tokens=2*" %%a in ('reg query "HKU\%_sid%\Software\DownloadManager" /v idmvers %nul6%') do set "IDMver=%%b"

echo Informasi terdeteksi - [%regwinos% ^| %fullbuild% ^| %regarch% ^| IDM: %IDMver%]
call :log "Informasi terdeteksi - [%regwinos% | %fullbuild% | %regarch% | IDM: %IDMver%]"

%idmcheck% && (echo: & taskkill /f /im idman.exe)

set _time=
for /f %%a in ('%psc% "(Get-Date).ToString('yyyyMMdd-HHmmssfff')"') do set _time=%%a

echo:
echo Sedang mencadangkan registri CLSID ke %SystemRoot%\Temp

reg export %CLSID% "%SystemRoot%\Temp\_Backup_HKCU_CLSID_%_time%.reg"
if not %HKCUsync%==1 reg export %CLSID2% "%SystemRoot%\Temp\_Backup_HKU-%_sid%_CLSID_%_time%.reg"

call :delete_queue
call :add_key

%psc% "$sid = '%_sid%'; $HKCUsync = %HKCUsync%; $lockKey = 1; $deleteKey = $null; $toggle = 1; $f=[io.file]::ReadAllText('!_batp!') -split ':regscan\:.*';iex ($f[1])"

if %frz%==0 call :register_IDM

call :download_files
if not defined _fileexist (
%eline%
echo Kesalahan: tidak dapat mengunduh file melalui IDM.
echo:
echo Bantuan: %mas%
call :set_exit 1 "Uji unduhan IDM gagal"
goto :done
)

%psc% "$sid = '%_sid%'; $HKCUsync = %HKCUsync%; $lockKey = 1; $deleteKey = $null; $f=[io.file]::ReadAllText('!_batp!') -split ':regscan\:.*';iex ($f[1])"

echo:
echo %line%
echo:
if %frz%==0 (
call :ui_done "NORMAL ACTIVATION SELESAI"
call :ui_info "Jika muncul warning serial gunakan freeze activation"
) else (
call :ui_done "FREEZE ACTIVATION SELESAI"
call :ui_info "Jika IDM masih meminta registrasi instal ulang IDM"
)

::========================================================================================================================================

:done

call :ui_line
echo:
echo:
call :log "Alur selesai, kode keluar %exit_code%"
if %_unattended%==1 (
if %_silent%==1 exit /b %exit_code%
timeout /t 2 & exit /b %exit_code%
)

if defined terminal (
call :ui_prompt "Tekan 0 untuk kembali ke dashboard"
choice /c 0 /n
) else (
call :ui_prompt "Tekan sembarang tombol untuk kembali ke dashboard"
pause
)
goto MainMenu

:done2

call :log "Alur selesai, kode keluar %exit_code%"
if %_unattended%==1 (
if %_silent%==1 exit /b %exit_code%
timeout /t 2 & exit /b %exit_code%
)

if defined terminal (
call :ui_prompt "Tekan 0 untuk keluar dari konsol"
choice /c 0 /n
) else (
	call :ui_prompt "Tekan sembarang tombol untuk keluar dari konsol"
	pause
	)
	exit /b %exit_code%

::========================================================================================================================================

:_rcont

reg add %reg% %nul%
call :add
exit /b

:register_IDM

echo:
call :ui_info "Menulis nama email dan serial acak ke registri"
echo:

set /a fname = %random% %% 9999 + 1000
set /a lname = %random% %% 9999 + 1000
set email=%fname%.%lname%@tonec.com

for /f "delims=" %%a in ('%psc% "$key = -join ((Get-Random -Count  20 -InputObject ([char[]]('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'))));$key = ($key.Substring(0,  5) + '-' + $key.Substring(5,  5) + '-' + $key.Substring(10,  5) + '-' + $key.Substring(15,  5) + $key.Substring(20));Write-Output $key" %nul6%') do (set key=%%a)

set "reg=HKCU\SOFTWARE\DownloadManager /v FName /t REG_SZ /d "%fname%"" & call :_rcont
set "reg=HKCU\SOFTWARE\DownloadManager /v LName /t REG_SZ /d "%lname%"" & call :_rcont
set "reg=HKCU\SOFTWARE\DownloadManager /v Email /t REG_SZ /d "%email%"" & call :_rcont
set "reg=HKCU\SOFTWARE\DownloadManager /v Serial /t REG_SZ /d "%key%"" & call :_rcont

if not %HKCUsync%==1 (
set "reg=HKU\%_sid%\SOFTWARE\DownloadManager /v FName /t REG_SZ /d "%fname%"" & call :_rcont
set "reg=HKU\%_sid%\SOFTWARE\DownloadManager /v LName /t REG_SZ /d "%lname%"" & call :_rcont
set "reg=HKU\%_sid%\SOFTWARE\DownloadManager /v Email /t REG_SZ /d "%email%"" & call :_rcont
set "reg=HKU\%_sid%\SOFTWARE\DownloadManager /v Serial /t REG_SZ /d "%key%"" & call :_rcont
)
exit /b

:download_files

echo:
call :ui_info "Menjalankan verifikasi unduhan IDM"
echo:
call :log "Memulai pengunduhan sumber uji"

set "file=%SystemRoot%\Temp\temp.png"
set _fileexist=

set link=https://www.internetdownloadmanager.com/images/idm_box_min.png
call :download
set link=https://www.internetdownloadmanager.com/register/IDMlib/images/idman_logos.png
call :download
set link=https://www.internetdownloadmanager.com/pictures/idm_about.png
call :download

echo:
timeout /t 3 %nul1%
%idmcheck% && taskkill /f /im idman.exe
if exist "%file%" del /f /q "%file%"
if defined _fileexist (call :log "Pengunduhan sumber uji berhasil") else (call :log "Pengunduhan sumber uji gagal")
exit /b

:download

set /a attempt=0
set "current_link=%link%"
if exist "%file%" del /f /q "%file%"
start "" /B "%IDMan%" /n /d "%link%" /p "%SystemRoot%\Temp" /f temp.png

:check_file

timeout /t 1 %nul1%
set /a attempt+=1
if exist "%file%" (set _fileexist=1&call :log "Unduh berhasil: %current_link%"&exit /b)
if %attempt% GEQ 20 (call :log "Unduh gagal: %current_link%"&exit /b)
goto :Check_file

::========================================================================================================================================

:add_key

echo:
call :ui_info "Menambahkan key utama untuk proteksi aktivasi"
echo:
call :log "Memulai penambahan kunci registri"

set "reg="%HKLM%" /v "AdvIntDriverEnabled2""

reg add %reg% /t REG_DWORD /d "1" /f %nul%

:add

if "%errorlevel%"=="0" (
set "reg=%reg:"=%"
echo Ditambahkan - !reg!
call :log "Ditambahkan - !reg!"
) else (
set "reg=%reg:"=%"
call :_color2 %Red% "Gagal - !reg!"
call :set_exit 1 "Gagal menambahkan - !reg!"
)
exit /b

::========================================================================================================================================

:regscan:
$finalValues = @()

$arch = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment').PROCESSOR_ARCHITECTURE
if ($arch -eq "x86") {
  $regPaths = @("HKCU:\Software\Classes\CLSID", "Registry::HKEY_USERS\$sid\Software\Classes\CLSID")
} else {
  $regPaths = @("HKCU:\Software\Classes\WOW6432Node\CLSID", "Registry::HKEY_USERS\$sid\Software\Classes\Wow6432Node\CLSID")
}

foreach ($regPath in $regPaths) {
    if (($regPath -match "HKEY_USERS") -and ($HKCUsync -ne $null)) {
        continue
    }

	Write-Host
	Write-Host "Sedang memindai kunci registri IDM CLSID di $regPath"
	Write-Host

    $subKeys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue -ErrorVariable lockedKeys | Where-Object { $_.PSChildName -match '^\{[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}\}$' }

    foreach ($lockedKey in $lockedKeys) {
        $leafValue = Split-Path -Path $lockedKey.TargetObject -Leaf
        $finalValues += $leafValue
        Write-Output "$leafValue - dilewati karena terkunci"
    }

    if ($subKeys -eq $null) {
	continue
	}

	$subKeysToExclude = "LocalServer32", "InProcServer32", "InProcHandler32"

    $filteredKeys = $subKeys | Where-Object { !($_.GetSubKeyNames() | Where-Object { $subKeysToExclude -contains $_ }) }

    foreach ($key in $filteredKeys) {
        $fullPath = $key.PSPath
        $keyValues = Get-ItemProperty -Path $fullPath -ErrorAction SilentlyContinue
        $defaultValue = $keyValues.PSObject.Properties | Where-Object { $_.Name -eq '(default)' } | Select-Object -ExpandProperty Value

        if (($defaultValue -match "^\d+$") -and ($key.SubKeyCount -eq 0)) {
            $finalValues += $($key.PSChildName)
            Write-Output "$($key.PSChildName) - nilai default numerik tanpa subkey"
            continue
        }
        if (($defaultValue -match "\+|=") -and ($key.SubKeyCount -eq 0)) {
            $finalValues += $($key.PSChildName)
            Write-Output "$($key.PSChildName) - nilai default berisi + atau = tanpa subkey"
            continue
        }
        $versionValue = Get-ItemProperty -Path "$fullPath\Version" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty '(default)' -ErrorAction SilentlyContinue
        if (($versionValue -match "^\d+$") -and ($key.SubKeyCount -eq 1)) {
            $finalValues += $($key.PSChildName)
            Write-Output "$($key.PSChildName) - nilai numerik ditemukan di \\Version dengan satu subkey"
            continue
        }
        $keyValues.PSObject.Properties | ForEach-Object {
            if ($_.Name -match "MData|Model|scansk|Therad") {
                $finalValues += $($key.PSChildName)
                Write-Output "$($key.PSChildName) - ditemukan thread pemindaian model MData"
                continue
            }
        }
        if (($key.ValueCount -eq 0) -and ($key.SubKeyCount -eq 0)) {
            $finalValues += $($key.PSChildName)
            Write-Output "$($key.PSChildName) - sepenuhnya kosong"
            continue
        }
    }
}

$finalValues = @($finalValues | Select-Object -Unique)

if ($finalValues -ne $null) {
    Write-Host
    if ($lockKey -ne $null) {
        Write-Host "Sedang mengunci kunci registri IDM CLSID..."
    }
    if ($deleteKey -ne $null) {
        Write-Host "Sedang menghapus kunci registri IDM CLSID..."
    }
    Write-Host
} else {
    Write-Host "Kunci registri IDM CLSID tidak ditemukan"
	Exit
}

if (($finalValues.Count -gt 20) -and ($toggle -ne $null)) {
	$lockKey = $null
	$deleteKey = 1
    Write-Host "Jumlah kunci IDM lebih dari 20, hapus saja alih-alih menguncinya..."
	Write-Host
}

function Take-Permissions {
    param($rootKey, $regKey)
    $AssemblyBuilder = [AppDomain]::CurrentDomain.DefineDynamicAssembly(4, 1)
    $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule(2, $False)
    $TypeBuilder = $ModuleBuilder.DefineType(0)

    $TypeBuilder.DefinePInvokeMethod('RtlAdjustPrivilege', 'ntdll.dll', 'Public, Static', 1, [int], @([int], [bool], [bool], [bool].MakeByRefType()), 1, 3) | Out-Null
    9,17,18 | ForEach-Object { $TypeBuilder.CreateType()::RtlAdjustPrivilege($_, $true, $false, [ref]$false) | Out-Null }

    $SID = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $IDN = ($SID.Translate([System.Security.Principal.NTAccount])).Value
    $Admin = New-Object System.Security.Principal.NTAccount($IDN)

    $everyone = New-Object System.Security.Principal.SecurityIdentifier('S-1-1-0')
    $none = New-Object System.Security.Principal.SecurityIdentifier('S-1-0-0')

    $key = [Microsoft.Win32.Registry]::$rootKey.OpenSubKey($regkey, 'ReadWriteSubTree', 'TakeOwnership')

    $acl = New-Object System.Security.AccessControl.RegistrySecurity
    $acl.SetOwner($Admin)
    $key.SetAccessControl($acl)

    $key = $key.OpenSubKey('', 'ReadWriteSubTree', 'ChangePermissions')
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule($everyone, 'FullControl', 'ContainerInherit', 'None', 'Allow')
    $acl.ResetAccessRule($rule)
    $key.SetAccessControl($acl)

    if ($lockKey -ne $null) {
        $acl = New-Object System.Security.AccessControl.RegistrySecurity
        $acl.SetOwner($none)
        $key.SetAccessControl($acl)

        $key = $key.OpenSubKey('', 'ReadWriteSubTree', 'ChangePermissions')
        $rule = New-Object System.Security.AccessControl.RegistryAccessRule($everyone, 'FullControl', 'Deny')
        $acl.ResetAccessRule($rule)
        $key.SetAccessControl($acl)
    }
}

foreach ($regPath in $regPaths) {
    if (($regPath -match "HKEY_USERS") -and ($HKCUsync -ne $null)) {
        continue
    }
    foreach ($finalValue in $finalValues) {
        $fullPath = Join-Path -Path $regPath -ChildPath $finalValue
        if ($fullPath -match 'HKCU:') {
            $rootKey = 'CurrentUser'
        } else {
            $rootKey = 'Users'
        }

        $position = $fullPath.IndexOf("\")
        $regKey = $fullPath.Substring($position + 1)

        if ($lockKey -ne $null) {
            if (-not (Test-Path -Path $fullPath -ErrorAction SilentlyContinue)) { New-Item -Path $fullPath -Force -ErrorAction SilentlyContinue | Out-Null }
            Take-Permissions $rootKey $regKey
            try {
                Remove-Item -Path $fullPath -Force -Recurse -ErrorAction Stop
                Write-Host -back 'DarkRed' -fore 'white' "Gagal - $fullPath"
            }
            catch {
                Write-Host "Terkunci - $fullPath"
            }
        }

        if ($deleteKey -ne $null) {
            if (Test-Path -Path $fullPath) {
                Remove-Item -Path $fullPath -Force -Recurse -ErrorAction SilentlyContinue
                if (Test-Path -Path $fullPath) {
                    Take-Permissions $rootKey $regKey
                    try {
                        Remove-Item -Path $fullPath -Force -Recurse -ErrorAction Stop
                        Write-Host "Dihapus - $fullPath"
                    }
                    catch {
                        Write-Host -back 'DarkRed' -fore 'white' "Gagal - $fullPath"
                    }
                }
                else {
                    Write-Host "Dihapus - $fullPath"
                }
            }
        }
    }
}
:regscan:

::========================================================================================================================================

:ui_line
echo %line%
exit /b

:ui_banner
echo:
call :ui_line
call :_color2 %Blue% "  %~1  " %_Cyan% "  %~2  "
call :ui_line
exit /b

:ui_pick
call :_color2 %Blue% "  %~1  " %_White% " %~2"
exit /b

:ui_step
call :_color2 %Blue% " STEP %~1 " %_White% " %~2"
exit /b

:ui_info
call :_color2 %Gray% "  INFO  " %_White% " %~1"
exit /b

:ui_done
call :_color2 %Green% "  DONE  " %_White% " %~1"
exit /b

:ui_alert
call :_color2 %Red% " ALERT " %_Yellow% " %~1"
exit /b

:ui_prompt
call :_color2 %_White% " INPUT " %_Green% " %~1"
exit /b

:set_exit
if "%~1"=="" exit /b
if "%exit_code%"=="0" set "exit_code=%~1"
if not "%~2"=="" call :log %~2
exit /b

:log
if not "%_log_enabled%"=="1" exit /b
set "_log_now=%date% %time%"
>>"%log_file%" echo [%_log_now%] %*
exit /b

::========================================================================================================================================

:_color

if %_NCS% EQU 1 (
echo %esc%[%~1%~2%esc%[0m
) else (
%psc% write-host -back '%1' -fore '%2' '%3'
)
exit /b

:_color2

if %_NCS% EQU 1 (
echo %esc%[%~1%~2%esc%[%~3%~4%esc%[0m
) else (
%psc% write-host -back '%1' -fore '%2' '%3' -NoNewline; write-host -back '%4' -fore '%5' '%6'
)
exit /b

::========================================================================================================================================
:: Leave empty line below

