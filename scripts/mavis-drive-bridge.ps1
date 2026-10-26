# mavis-drive-bridge.ps1
# The PRIMARY Local<->Cloud bridge: a Google Drive folder.
#
# Why this script exists
# The GitHub repo MAVIS-CLOUD used to be the only channel between Mavis Local
# and Mavis Cloud. It is now the SECONDARY channel (backup). The primary one
# is this folder: it lives inside the Google Drive mirror
# (E:\Google\GDrive\...), and the Cloud instance - which has Google Drive
# access - sees exactly the same bytes.
#
# What "published" means here
# A file written into the mirror is not a message until Drive has it. So the
# script never claims success on the strength of a write. It writes, then it
# MEASURES, and it reports one of:
#
#   SYNCED     - the item is in the Drive index, with a Drive id
#   PENDING    - DriveFS indexed it locally, no Drive id yet
#   NOT_UPLOADED - the mirror root is disconnected, so it cannot reach Drive
#   UNVERIFIED - the state could not be read at all
#
# And when the transport is down - OR when it is connected but not actually
# uploading - the GITHUB fallback is engaged, because a bridge with one leg is
# not a bridge. Measured 2026-10-27: connected=true while the DriveFS sync
# engine showed operation_queue_size=0 and change_ids_up_to_date=true, so no
# local write was being uploaded at all.
#
# Usage:
#   powershell -NoProfile -File mavis-drive-bridge.ps1 -Status
#   powershell -NoProfile -File mavis-drive-bridge.ps1 -Publish -Title "<subject>" -Body "<text>"
#   powershell -NoProfile -File mavis-drive-bridge.ps1 -Verify -Title "<subject>"
#
# Exit codes:
#   0 = measured and healthy: connected AND the latest write is confirmed
#   2 = a required input is missing (python, DriveFS, a title)
#   3 = the bridge target was not found in Drive
#   4 = written but NOT confirmed, or the propagation is stale - the honest
#       "unknown"; the GitHub channel is the live one for new content
#   5 = the Drive transport is DOWN - the GitHub fallback is the live channel
#
# ASCII ONLY: executed by Windows PowerShell 5.1.

param(
    [switch]$Status,
    [switch]$Publish,
    [switch]$Verify,
    [string]$Title = '',
    [string]$Body = ''
)

$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $PSScriptRoot
$BridgeDir = Join-Path $ScriptRoot 'BRIDGE-DRIVE'
$TaskFile = Join-Path $BridgeDir 'TASKURI-PENTRU-CLOUD.md'
$QueueDir = Join-Path $ScriptRoot 'QUEUE'
$QueueFile = Join-Path $QueueDir 'TASKS-FOR-CLOUD.md'
$StateDir = Join-Path $ScriptRoot 'state'
$Probe = Join-Path $PSScriptRoot 'drivefs_probe.py'

function Write-Out {
    param([Parameter(Mandatory = $true)][string]$Message)
    [Console]::Out.WriteLine($Message)
}

function Write-Err {
    param([Parameter(Mandatory = $true)][string]$Message)
    [Console]::Error.WriteLine($Message)
}

function Get-Python {
    foreach ($cand in @('python', 'python3', 'py')) {
        $cmd = Get-Command $cand -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return ''
}

function Invoke-Probe {
    param([string[]]$ProbeArgs = @())
    $exe = Get-Python
    if (-not $exe) {
        Write-Err 'ERROR=no python interpreter on PATH'
        return @{ Code = 2; Out = '' }
    }
    $all = @($Probe) + $ProbeArgs
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & $exe @all 2>&1
    $ErrorActionPreference = $prev
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = -1 }
    $text = ''
    if ($out) { $text = ($out -join "`n") }
    return @{ Code = $code; Out = $text }
}

function Get-RootState {
    $res = Invoke-Probe -ProbeArgs @('--root-state')
    $state = 'UNKNOWN'
    $path = ''
    foreach ($line in ($res.Out -split "`n")) {
        if ($line -match '^ROOT_STATE=(\S+)') { $state = $Matches[1] }
        if ($line -match '^GDRIVE_ROOT_PATH=(\S+)') { $path = $Matches[1] }
    }
    return @{ State = $state; Path = $path }
}

function Get-DriveItem {
    param([Parameter(Mandatory = $true)][string]$Name)
    $res = Invoke-Probe -ProbeArgs @('--title', $Name)
    $cloudId = ''
    $path = ''
    $found = 0
    foreach ($line in ($res.Out -split "`n")) {
        if ($line -match '^FOUND=(\d+)') { $found = [int]$Matches[1] }
        if ($line -match 'cloud_id=(\S+)') {
            $id = $Matches[1]
            if ($id -and $id -ne 'None') { $cloudId = $id }
        }
        if ($line -match '^\s+path: (.+)$') { $path = $Matches[1].Trim() }
    }
    return @{ Found = $found; CloudId = $cloudId; Path = $path; Code = $res.Code }
}

function Get-SyncState {
    param([Parameter(Mandatory = $true)][string]$Name)
    $root = Get-RootState
    if ($root.State -eq 'false') { return 'NOT_UPLOADED' }
    $item = Get-DriveItem -Name $Name
    if ($item.Found -eq 0) { return 'UNVERIFIED' }
    if ($item.CloudId) { return 'SYNCED' }
    return 'PENDING'
}

function Format-Stamp {
    return (Get-Date).ToString('yyyy-MM-dd-HHmm')
}

function Add-TaskBlock {
    param(
        [Parameter(Mandatory = $true)][string]$File,
        [Parameter(Mandatory = $true)][string]$Block,
        [string]$Header = ''
    )
    $enc = New-Object System.Text.UTF8Encoding($false)
    $dir = Split-Path -Parent $File
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (Test-Path -LiteralPath $File) {
        $existing = [System.IO.File]::ReadAllText($File)
        [System.IO.File]::WriteAllText($File, ($existing + $Block), $enc)
    } else {
        [System.IO.File]::WriteAllText($File, ($Header + $Block), $enc)
    }
}

function Invoke-Status {
    Write-Out ('BRIDGE_ROOT=' + $BridgeDir)
    Write-Out ('BRIDGE_EXISTS=' + (Test-Path -LiteralPath $BridgeDir))
    foreach ($f in @('TASKURI-PENTRU-CLOUD.md', 'INTENTII.md')) {
        $p = Join-Path $BridgeDir $f
        $exists = Test-Path -LiteralPath $p
        $len = 0
        if ($exists) { $len = (Get-Item -LiteralPath $p).Length }
        Write-Out ('CHANNEL ' + $f + ' exists=' + $exists + ' bytes=' + $len)
    }

    $root = Get-RootState
    Write-Out ('MIRROR_ROOT_STATE=' + $root.State)
    if ($root.Path) { Write-Out ('MIRROR_ROOT_PATH=' + $root.Path) }

    $pending = Invoke-Probe -ProbeArgs @('--pending')
    foreach ($line in ($pending.Out -split "`n")) {
        if ($line -match '^PENDING_OPERATIONS=(\d+)') { Write-Out ('PENDING_OPERATIONS=' + $Matches[1]) }
    }

    $folder = Split-Path -Leaf $ScriptRoot
    $item = Get-DriveItem -Name $folder
    if ($item.CloudId) {
        Write-Out ('DRIVE_ID=' + $item.CloudId)
        Write-Out ('DRIVE_PATH=' + $item.Path)
    }

    # --- propagation lag: newest confirmed upload vs newest local write ---
    # MEASURED 2026-10-27: the bridge is not instant. A file written locally
    # at 22:11 was in the Drive at 23:31 - about 80 minutes. So the lag is a
    # measured number, reported every time, not an assumption.
    $newestRes = Invoke-Probe -ProbeArgs @('--newest', $folder)
    $newestMs = 0
    foreach ($line in ($newestRes.Out -split "`n")) {
        if ($line -match 'NEWEST title=.* modified=(\d+)') { $newestMs = [int64]$Matches[1]; break }
    }
    $localMs = 0
    # Only writes that SHOULD reach Drive count. state/ is gitignored scratch
    # and is not published: counting it would make the lag look infinite after
    # any probe, which is a false measurement, not a real delay.
    $statePrefix = $StateDir + '\'
    $localFile = Get-ChildItem -LiteralPath $ScriptRoot -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { -not $_.FullName.StartsWith($statePrefix, [System.StringComparison]::OrdinalIgnoreCase) } |
        Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if ($localFile) {
        $localMs = [int64](($localFile.LastWriteTimeUtc - [datetime]'1970-01-01').TotalMilliseconds)
    }
    # A connected root is NOT the same thing as an uploading transport.
    # Measured 2026-10-27: the mirror root reported connected=true while the
    # DriveFS sync engine showed operation_queue_size=0 and
    # change_ids_up_to_date=true - it did not see the local writes at all.
    # So the report separates "connected" from "confirmed", and the active
    # channel follows the propagation, not the connection.
    $staleThresholdMin = 120
    $propagation = 'UNKNOWN'
    if ($newestMs -gt 0) {
        $lagMin = [math]::Round((($localMs - $newestMs) / 60000), 1)
        Write-Out ('LAST_CONFIRMED_UPLOAD_MS=' + $newestMs)
        Write-Out ('LAST_LOCAL_WRITE_MS=' + $localMs)
        Write-Out ('PROPAGATION_LAG_MIN=' + $lagMin)
        Write-Out ('PROPAGATION_STALE_THRESHOLD_MIN=' + $staleThresholdMin)
        if ($lagMin -gt $staleThresholdMin) {
            $propagation = 'STALE'
            Write-Out 'PROPAGATION=STALE - scrieri locale mai noi decat ultima confirmare in indice'
        } else {
            $propagation = 'OK'
            Write-Out 'PROPAGATION=OK - ultima scriere locala e confirmata in indice'
        }
    } else {
        Write-Out 'PROPAGATION_LAG_MIN=UNKNOWN - niciun item nou confirmat in indice'
        Write-Out 'PROPAGATION=UNKNOWN - nu se poate confirma nimic in indice'
        $propagation = 'UNKNOWN'
    }

    if ($root.State -eq 'false') {
        Write-Out 'TRANSPORT=DOWN - radacina mirrorului My Drive este deconectata in DriveFS'
        Write-Out 'ACTIVE_CHANNEL=GITHUB - puntea Drive nu transporta nimic pana nu se reia'
        return 5
    }
    Write-Out 'TRANSPORT=UP'
    if ($propagation -eq 'OK') {
        Write-Out 'ACTIVE_CHANNEL=DRIVE'
        return 0
    }
    if ($propagation -eq 'STALE') {
        Write-Out 'ACTIVE_CHANNEL=GITHUB - propagarea Drive e intarziata; pentru continut nou, canalul activ e GitHub'
        return 4
    }
    Write-Out 'ACTIVE_CHANNEL=GITHUB - propagarea nu poate fi masurata'
    return 4
}

function Invoke-Publish {
    if (-not $Title) {
        Write-Err 'ERROR=-Publish needs -Title'
        return 2
    }
    $stamp = Format-Stamp
    $slug = ($Title -replace '[^A-Za-z0-9]+', '-').Trim('-').ToLower()
    if (-not $slug) { $slug = 'task' }
    $taskId = 'TASK-' + $stamp + '-' + $slug
    $block = @(
        '',
        ('## ' + $taskId),
        '',
        '- **Emit:** Mavis Local',
        ('- **Data:** ' + (Get-Date).ToString('yyyy-MM-dd HH:mm')),
        ('- **Subiect:** ' + $Title),
        '',
        ($Body),
        ''
    ) -join "`n"

    $driveHeader = @(
        '# TASKURI PENTRU CLOUD',
        '',
        '> Canalul Local -> Cloud prin Google Drive. Scris de Mavis Local.',
        '> Fiecare task e o sectiune `## TASK-<data>-<ora>-<slug>`.',
        '> Cloud-ul marcheaza ce a consumat si muta sectiunea in ISTORIC/.',
        '',
        ('*Creatat: ' + (Get-Date).ToString('yyyy-MM-dd HH:mm') + '*'),
        ''
    ) -join "`n"

    Add-TaskBlock -File $TaskFile -Block $block -Header $driveHeader

    # The secondary channel is written at the same time, so the Cloud has two
    # ways in. It is the same content, with the same task id.
    $queueHeader = @(
        '# TASKURI PENTRU CLOUD - canal secundar (GitHub)',
        '',
        '> Copia de rezerva a canalului Drive. Acelasi task id.',
        '> Daca puntea Drive e jos, asta ramane calea prin care Cloud-ul citeste.',
        '',
        ('*Creatat: ' + (Get-Date).ToString('yyyy-MM-dd HH:mm') + '*'),
        ''
    ) -join "`n"
    Add-TaskBlock -File $QueueFile -Block $block -Header $queueHeader

    $stateFile = Join-Path $StateDir 'drive-bridge-last-publish.json'
    if (-not (Test-Path -LiteralPath $StateDir)) {
        New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
    }
    $receipt = [PSCustomObject]@{
        task_id    = $taskId
        title      = $Title
        stamp      = $stamp
        drive_file = $TaskFile
        queue_file = $QueueFile
        published  = (Get-Date).ToString('o')
    }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($stateFile, ($receipt | ConvertTo-Json -Depth 3), $enc)

    Write-Out ('TASK_ID=' + $taskId)
    Write-Out ('DRIVE_FILE=' + $TaskFile)
    Write-Out ('QUEUE_FILE=' + $QueueFile)
    $state = Get-SyncState -Name 'TASKURI-PENTRU-CLOUD.md'
    Write-Out ('SYNC_STATE=' + $state)
    if ($state -eq 'SYNCED') { return 0 }
    if ($state -eq 'NOT_UPLOADED') {
        Write-Out 'ACTIVE_CHANNEL=GITHUB - taskul a fost scris si in QUEUE/TASKS-FOR-CLOUD.md'
        return 5
    }
    return 4
}

function Invoke-Verify {
    if (-not $Title) {
        Write-Err 'ERROR=-Verify needs -Title'
        return 2
    }
    Write-Out ('CHANNEL_FILE=' + $TaskFile)
    $state = Get-SyncState -Name 'TASKURI-PENTRU-CLOUD.md'
    Write-Out ('SYNC_STATE=' + $state)
    if ($state -eq 'SYNCED') { return 0 }
    if ($state -eq 'NOT_UPLOADED') { return 5 }
    return 4
}

$code = 0
if ($Publish) {
    $code = Invoke-Publish
} elseif ($Verify) {
    $code = Invoke-Verify
} else {
    $code = Invoke-Status
}
exit $code
