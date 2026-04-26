@echo off
chcp 936 >nul 2>&1
setlocal EnableExtensions EnableDelayedExpansion

set "ERR_ADMIN=1"
set "ERR_PS_MISSING=2"
set "ERR_PS_MODE=4"
set "ERR_NULL_SERVICE=8"
set "ERR_NETWORK=16"
set "ERR_CODEPAGE=32"
set "ERR_IAS=64"
set "ERR_WMI=128"
set "ERR_IDM_PATH=256"
set "ERR_DIR_PERM=512"
set "ERR_HOSTS_BYPASS=1024"

set /a "issues=0"
set "firstFail="

echo ==========================================
echo Pemeriksaan Lingkungan IDM
echo ==========================================
echo:

fltmc >nul 2>&1 && (
    echo [OK] Hak administrator tersedia
) || (
    echo [X] Skrip ini belum dijalankan sebagai administrator
    set /a issues^|=ERR_ADMIN
    if not defined firstFail set "firstFail=Hak administrator belum tersedia ^| Klik kanan skrip lalu pilih Jalankan sebagai administrator. Lihat README bagian Q1."
)

where powershell.exe >nul 2>&1 && (
    echo [OK] PowerShell ditemukan
    for /f "delims=" %%a in ('powershell -NoProfile -Command "$ExecutionContext.SessionState.LanguageMode" 2^>nul') do set "psmode=%%a"
    if defined psmode (
        if /i "!psmode!"=="FullLanguage" (
            echo [OK] Mode bahasa PowerShell: !psmode!
        ) else (
            echo [X] Mode bahasa PowerShell adalah !psmode! ^(mungkin dibatasi kebijakan organisasi^)
            set /a issues^|=ERR_PS_MODE
            if not defined firstFail set "firstFail=Mode bahasa PowerShell tidak sesuai ^| Ada kemungkinan dibatasi kebijakan organisasi. Lihat README bagian Q6."
        )
    ) else (
        echo [X] Mode bahasa PowerShell tidak bisa dibaca
        set /a issues^|=ERR_PS_MODE
        if not defined firstFail set "firstFail=Mode bahasa PowerShell tidak bisa dibaca ^| PowerShell mungkin dibatasi atau tidak berjalan normal. Lihat README bagian Q6."
    )
) || (
    echo [X] PowerShell tidak ditemukan
    set /a issues^|=ERR_PS_MISSING
    if not defined firstFail set "firstFail=PowerShell tidak ditemukan ^| Periksa instalasi sistem atau kebijakan yang menonaktifkannya. Lihat README bagian Q6."
)

sc query Null | find /i "RUNNING" >nul 2>&1 && (
    echo [OK] Layanan Null berjalan
) || (
    echo [X] Layanan Null tidak berjalan; skrip batch bisa gagal
    set /a issues^|=ERR_NULL_SERVICE
    if not defined firstFail set "firstFail=Layanan Null tidak berjalan ^| Coba jalankan 'sc start Null' dari CMD administrator."
)

set "netok="
ping -4 -n 1 internetdownloadmanager.com >nul 2>&1 && set "netok=ping"
if not defined netok if defined psmode (
    for /f "delims=" %%a in ('powershell -NoProfile -Command "$c=New-Object Net.Sockets.TcpClient;try{$c.Connect(""internetdownloadmanager.com"",80)}catch{};$c.Connected" 2^>nul') do set "netok=%%a"
)
if /i "!netok!"=="True" (
    echo [OK] Koneksi ke internetdownloadmanager.com tersedia
) else if /i "!netok!"=="ping" (
    echo [OK] Ping gagal, tetapi jalur jaringan masih terdeteksi
) else (
    echo [X] Tidak bisa terhubung ke internetdownloadmanager.com
    set /a issues^|=ERR_NETWORK
    if not defined firstFail set "firstFail=Tidak bisa terhubung ke internetdownloadmanager.com ^| Periksa DNS, firewall, proxy, atau VPN. Lihat README bagian Q5."
)

for /f "tokens=2 delims=:." %%a in ('chcp') do set "cp=%%a"
set "cp=!cp: =!"
if "!cp!"=="936" (
    echo [OK] Code page aktif: !cp!
) else (
    echo [X] Code page aktif: !cp! ^| disarankan jalankan chcp 936
    set /a issues^|=ERR_CODEPAGE
    if not defined firstFail set "firstFail=Code page bukan 936 ^| Jalankan 'chcp 936' lalu coba lagi. Lihat README bagian Q4."
)

if exist "%~dp0IAS.cmd" (
    echo [OK] IAS.cmd ditemukan
) else (
    echo [X] IAS.cmd tidak ditemukan di folder ini
    set /a issues^|=ERR_IAS
    if not defined firstFail set "firstFail=IAS.cmd tidak ditemukan ^| Pastikan Test_Script.cmd berada di folder yang sama dengan IAS.cmd."
)

set "wmiok="
wmic path Win32_OperatingSystem get Caption /value >nul 2>&1 && set "wmiok=ok"
if not defined wmiok if defined psmode (
    for /f "delims=" %%a in ('powershell -NoProfile -Command "Try{Get-CimInstance Win32_OperatingSystem ^| Out-Null;$true}catch{$false}" 2^>nul') do if /i "%%a"=="True" set "wmiok=ok"
)
if defined wmiok (
    echo [OK] WMI tersedia
) else (
    echo [X] WMI tidak bisa digunakan
    set /a issues^|=ERR_WMI
    if not defined firstFail set "firstFail=WMI tidak tersedia ^| Periksa layanan Windows Management Instrumentation."
)

set "idmPath="
for /f "skip=2 tokens=3*" %%a in ('reg query "HKLM\SOFTWARE\Internet Download Manager" /v InstallFolder 2^>nul') do set "idmPath=%%a %%b"
if not defined idmPath (
    for /f "skip=2 tokens=3*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Internet Download Manager" /v InstallFolder 2^>nul') do set "idmPath=%%a %%b"
)
if defined idmPath (
    if exist "!idmPath!\IDMan.exe" (
        echo [OK] Jalur instalasi IDM ditemukan: !idmPath!
    ) else (
        echo [X] Jalur IDM di registri tidak valid: !idmPath!
        set /a issues^|=ERR_IDM_PATH
        if not defined firstFail set "firstFail=Jalur IDM tidak valid ^| Instal ulang IDM. Lihat README bagian Q2."
    )
) else (
    echo [X] Instalasi IDM tidak ditemukan di registri
    set /a issues^|=ERR_IDM_PATH
    if not defined firstFail set "firstFail=IDM belum terinstal ^| Instal IDM terlebih dahulu. Lihat README bagian Q2."
)

set "writeTest=%~dp0.__ias_write_test.tmp"
echo test>"!writeTest!" 2>nul
if exist "!writeTest!" (
    del /f /q "!writeTest!" >nul 2>&1
    echo [OK] Folder skrip bisa ditulis: %~dp0
) else (
    echo [X] Folder skrip tidak bisa ditulis: %~dp0
    set /a issues^|=ERR_DIR_PERM
    if not defined firstFail set "firstFail=Folder skrip tidak bisa ditulis ^| Pindahkan folder ini ke lokasi yang bisa ditulis, jangan di Program Files."
)

::  Verifikasi bypass popup fake-serial IDM pada hosts file
::  Hanya menandai OK apabila marker # IAS-NADIF-BLOCK START/END hadir dan
::  minimal registeridm.com serta tonec.com terblok. Tes ini tidak gagal bila
::  IAS.cmd belum pernah dijalankan; ia hanya memberi catatan informatif.

set "hostsFile=%SystemRoot%\System32\drivers\etc\hosts"
set "hasStart="
set "hasEnd="
set "hasRegisterIdm="
set "hasTonec="
set /a "hostsScore=0"
if exist "!hostsFile!" (
    findstr /c:"# IAS-NADIF-BLOCK START" "!hostsFile!" >nul 2>&1 && set "hasStart=1"
    findstr /c:"# IAS-NADIF-BLOCK END"   "!hostsFile!" >nul 2>&1 && set "hasEnd=1"
    findstr /l /c:"0.0.0.0 registeridm.com" "!hostsFile!" >nul 2>&1 && set "hasRegisterIdm=1"
    findstr /l /c:"0.0.0.0 tonec.com"        "!hostsFile!" >nul 2>&1 && set "hasTonec=1"
    if defined hasStart        set /a "hostsScore+=1"
    if defined hasEnd          set /a "hostsScore+=1"
    if defined hasRegisterIdm  set /a "hostsScore+=1"
    if defined hasTonec        set /a "hostsScore+=1"
    if !hostsScore! EQU 4 (
        echo [OK] Bypass popup fake-serial IDM aktif di hosts file
    ) else if defined hasStart (
        echo [X] Marker IAS-NADIF-BLOCK ditemukan sebagian, blok hosts tidak lengkap
        set /a issues^|=ERR_HOSTS_BYPASS
        if not defined firstFail set "firstFail=Blok hosts IAS-NADIF-BLOCK tidak lengkap ^| Jalankan Quick_Activation.cmd atau Normal_Activation.cmd sekali lagi sebagai administrator agar blok ditulis ulang."
    ) else (
        echo [!] Bypass popup fake-serial belum terpasang ^(hosts belum pernah di-IAS^)
        echo     Jalankan Quick_Activation.cmd/Normal_Activation.cmd sebagai administrator untuk memasang bypass.
    )
) else (
    echo [X] Hosts file tidak ditemukan di !hostsFile!
    set /a issues^|=ERR_HOSTS_BYPASS
    if not defined firstFail set "firstFail=Hosts file tidak ditemukan ^| Periksa instalasi Windows, bypass popup fake-serial membutuhkan file ini."
)

::  Verifikasi lapisan kedua: Scheduled Task popup watcher.
::  Bersifat informatif - tidak menaikkan kode keluar. Watcher hanya dipasang
::  oleh alur Normal Activation, sehingga user yang hanya Freeze-activated
::  tidak perlu dibebani error.
schtasks /query /tn "IAS-NADIF-PopupWatcher" >nul 2>&1 && (
    echo [OK] Popup watcher scheduled task aktif ^(IAS-NADIF-PopupWatcher^)
) || (
    echo [!] Popup watcher scheduled task belum terpasang ^(normal jika hanya Freeze^)
    echo     Jalankan Normal_Activation.cmd sebagai administrator untuk lapisan kedua anti-popup.
)

::  Trial resetter Scheduled Task - mencegah popup "You have 0 days left" di mode Normal
schtasks /query /tn "IAS-NADIF-TrialResetter" >nul 2>&1 && (
    echo [OK] Trial resetter scheduled task aktif ^(IAS-NADIF-TrialResetter^)
) || (
    echo [!] Trial resetter scheduled task belum terpasang ^(normal jika hanya Freeze^)
    echo     Jalankan Normal_Activation.cmd sebagai administrator untuk mencegah popup trial expired.
)

echo:
echo ------------------------------------------
if !issues! EQU 0 (
    echo [SELESAI] Pemeriksaan lingkungan lolos. Anda bisa langsung menjalankan "Quick_Activation.cmd", "Normal_Activation.cmd", atau "Reset_Activation.cmd".
    echo:
    pause
    endlocal ^& exit /b 0
) else (
    echo [ITEM PERTAMA GAGAL] !firstFail!
    echo:
    echo [PETUNJUK] Perbaiki item yang gagal dulu sebelum menjalankan skrip aktivasi lagi. Kode keluar total: !issues!
    echo            Untuk penelusuran lebih rinci, lihat README.md bagian Pertanyaan Umum.
    echo:
    pause
    endlocal ^& exit /b !issues!
)
