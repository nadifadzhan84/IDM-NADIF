# IAS-NADIF popup watcher
#
# Watches for the IDM nag dialogs and dismisses them automatically. Installed
# as a per-user scheduled task by IAS.cmd (:install_popup_watcher) and
# uninstalled by Reset_Activation.
#
# Targets three dialog families, all with class "#32770" and window title
# "Internet Download Manager":
#   1. "has been registered with a fake Serial Number" (fake-serial nag)
#   2. "Serial Number has been blocked" (blocked-serial nag)
#   3. "days left to use Internet Download Manager" / "trial period has
#      expired" / "trial version has expired" (trial-expiry nag)
#
# The main IDM application window and the benign "This product is licensed to
# ... This is a lifetime license" info dialog are never touched because their
# static text does not contain any of the trigger phrases above.
#
# Writes a small log at %LOCALAPPDATA%\IAS-NADIF\popup_watcher.log so the
# user can verify it actually closed something.

$ErrorActionPreference = 'Continue'

$logDir = Join-Path $env:LOCALAPPDATA 'IAS-NADIF'
if (-not (Test-Path -LiteralPath $logDir)) {
    [void](New-Item -ItemType Directory -Path $logDir -Force)
}
$logFile = Join-Path $logDir 'popup_watcher.log'
$stopFlag = Join-Path $env:ProgramData 'IAS-NADIF\stop.flag'

function Write-WatcherLog {
    param([string]$message)
    try {
        $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Add-Content -LiteralPath $logFile -Value "[$stamp] $message" -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch { }
}

Write-WatcherLog "popup_watcher started (PID $PID)"

$typeDef = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class IASPopup {
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumProc e, IntPtr l);

    [DllImport("user32.dll")]
    public static extern bool EnumChildWindows(IntPtr parent, EnumProc e, IntPtr l);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr h);

    [DllImport("user32.dll")]
    public static extern IntPtr PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);

    public const uint WM_CLOSE = 0x0010;

    private static string GetText(IntPtr h) {
        StringBuilder sb = new StringBuilder(1024);
        GetWindowTextW(h, sb, sb.Capacity);
        return sb.ToString();
    }

    private static string GetClass(IntPtr h) {
        StringBuilder sb = new StringBuilder(256);
        GetClassNameW(h, sb, sb.Capacity);
        return sb.ToString();
    }

    // Phrases yang hanya muncul di dialog nag IDM. Sengaja TIDAK menyertakan
    // "Lifetime license" karena teks itu juga muncul di dialog informasi
    // "This product is licensed to ... This is a lifetime license" yang benign
    // dan tidak boleh ditutup paksa.
    private static readonly string[] Triggers = new string[] {
        "fake Serial",
        "Serial Number has been blocked",
        "days left to use Internet Download Manager",
        "trial period has expired",
        "trial version has expired",
        "0 days left",
        "You may buy IDM to continue using it",
        "PLEASE ENTER YOUR SERIAL NUMBER",
        "ALREADY PURCHASED"
    };

    private static bool HasFakeSerialChild(IntPtr hWnd) {
        bool match = false;
        EnumChildWindows(hWnd, delegate(IntPtr c, IntPtr l) {
            string txt = GetText(c);
            if (!string.IsNullOrEmpty(txt)) {
                for (int i = 0; i < Triggers.Length; i++) {
                    if (txt.IndexOf(Triggers[i], StringComparison.OrdinalIgnoreCase) >= 0) {
                        match = true;
                        break;
                    }
                }
            }
            return true;
        }, IntPtr.Zero);
        return match;
    }

    public static IntPtr[] FindFakeSerialPopups() {
        List<IntPtr> hits = new List<IntPtr>();
        EnumWindows(delegate(IntPtr h, IntPtr l) {
            if (!IsWindowVisible(h)) return true;
            if (GetText(h) != "Internet Download Manager") return true;
            if (GetClass(h) != "#32770") return true;
            if (HasFakeSerialChild(h)) hits.Add(h);
            return true;
        }, IntPtr.Zero);
        return hits.ToArray();
    }

    public static int DismissAll() {
        IntPtr[] wins = FindFakeSerialPopups();
        foreach (IntPtr h in wins) {
            PostMessage(h, WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
        }
        return wins.Length;
    }
}
'@

try {
    Add-Type -TypeDefinition $typeDef -Language CSharp -ErrorAction Stop
} catch {
    Write-WatcherLog "Add-Type failed: $($_.Exception.Message)"
    Start-Sleep -Seconds 5
    exit 1
}

# Real-time trial-counter wipe untuk menutup celah race antara IDM membaca
# counter trial dan tools_nadif\trial_reset.ps1 menjalankan reset terjadwal.
# Tiap iterasi (~750 ms) kita hapus nilai trial-counter dari
# HKCU\Software\DownloadManager. IDM 6.42 akan otomatis menulis ulang
# counter "fresh trial" sehingga popup "0 days left" / "trial expired" tidak
# pernah punya peluang untuk muncul. Serial / FName / LName / Email TIDAK
# pernah disentuh sehingga registrasi normal tetap utuh.
$idmTrialKey  = 'HKCU:\Software\DownloadManager'
$idmTrialKeys = @(
    'tvfrdt',       # trial start date (binary)
    'radxcnt',      # radix count
    'ptrk_scdt',    # encrypted scheduled check date
    'LstCheck',     # last remote check
    'LastCheckQU',  # last quick-update check
    'scansk',       # scan key used during trial validation
    'FromVersion',  # trial upgrade tracker
    'toV'           # trial upgrade tracker
)

function Reset-TrialCounters {
    $removed = 0
    if (Test-Path -LiteralPath $idmTrialKey) {
        foreach ($v in $idmTrialKeys) {
            try {
                $null = Get-ItemProperty -LiteralPath $idmTrialKey -Name $v -ErrorAction Stop
                Remove-ItemProperty -LiteralPath $idmTrialKey -Name $v -Force -ErrorAction Stop
                $removed++
            } catch {
                # nilai memang tidak ada, abaikan saja
            }
        }
    }
    return $removed
}

$resetLogEvery   = 80   # log ringkasan tiap ~60 detik (80 * 750 ms)
$resetLogCounter = 0
$totalResets     = 0

while ($true) {
    try {
        if (Test-Path -LiteralPath $stopFlag) {
            Write-WatcherLog "stop.flag detected, exiting"
            try { Remove-Item -LiteralPath $stopFlag -Force -ErrorAction SilentlyContinue } catch { }
            exit 0
        }

        # Lapis 1: bersihkan counter trial supaya popup tidak pernah ter-trigger.
        $resetCount = Reset-TrialCounters
        $totalResets += $resetCount

        # Lapis 2: tutup popup nag yang sudah terlanjur muncul.
        $closed = [IASPopup]::DismissAll()
        if ($closed -gt 0) {
            Write-WatcherLog "Dismissed $closed nag popup(s)"
        }

        $resetLogCounter++
        if ($resetLogCounter -ge $resetLogEvery) {
            if ($totalResets -gt 0) {
                Write-WatcherLog "Trial-counter wipe aktif, $totalResets nilai dihapus dalam ~60 detik terakhir"
            }
            $resetLogCounter = 0
            $totalResets = 0
        }
    } catch {
        Write-WatcherLog "loop error: $($_.Exception.Message)"
    }
    Start-Sleep -Milliseconds 750
}
