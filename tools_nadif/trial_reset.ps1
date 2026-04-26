# IAS-NADIF trial resetter
#
# Scheduled Task target that wipes IDM trial-tracking values from
# HKCU\Software\DownloadManager so the "You have N days left to use Internet
# Download Manager" nag and the eventual "0 days left" hard stop never fire
# on Normal-activated installs.
#
# Normal Activation writes a random Serial/FName/LName/Email; IDM 6.42 rejects
# the serial locally and quietly restarts its trial counter. By periodically
# deleting tvfrdt / radxcnt / ptrk_scdt / LstCheck / LastCheckQU / scansk we
# keep IDM from advancing the counter to zero. Serial/FName/LName/Email are
# NEVER touched so the registration form in IDM still looks "registered".
#
# A short log is written to %LOCALAPPDATA%\IAS-NADIF\trial_reset.log.

$ErrorActionPreference = 'SilentlyContinue'

$logDir = Join-Path $env:LOCALAPPDATA 'IAS-NADIF'
if (-not (Test-Path -LiteralPath $logDir)) {
    [void](New-Item -ItemType Directory -Path $logDir -Force)
}
$logFile = Join-Path $logDir 'trial_reset.log'

function Write-ResetLog {
    param([string]$message)
    try {
        $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Add-Content -LiteralPath $logFile -Value "[$stamp] $message" -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch { }
}

Write-ResetLog "trial_reset started (PID $PID)"

$key = 'HKCU:\Software\DownloadManager'
$trialValues = @(
    'tvfrdt',       # trial start date (binary)
    'radxcnt',      # radix count
    'ptrk_scdt',    # encrypted scheduled check date
    'LstCheck',     # last remote check
    'LastCheckQU',  # last quick-update check
    'scansk',       # scan key used during trial validation
    'FromVersion',  # trial upgrade tracker
    'toV'           # trial upgrade tracker
)

$removed = 0
if (Test-Path -LiteralPath $key) {
    foreach ($v in $trialValues) {
        try {
            $existing = Get-ItemProperty -LiteralPath $key -Name $v -ErrorAction Stop
            if ($null -ne $existing) {
                Remove-ItemProperty -LiteralPath $key -Name $v -Force -ErrorAction Stop
                $removed++
            }
        } catch {
            # value simply didn't exist; that's fine
        }
    }
    Write-ResetLog "removed $removed trial value(s) from $key"
} else {
    Write-ResetLog "$key not present, nothing to reset"
}

exit 0
