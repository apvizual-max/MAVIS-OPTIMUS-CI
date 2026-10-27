# queue-contract-check.ps1
# The gate for the SECONDARY channel (GitHub) of the Local<->Cloud bridge.
#
# What it checks, and why each one exists:
#
#   1. CONTRACT CONFORMITY: every ticket in QUEUE/TASKS-FOR-CLOUD.md must
#      carry the five fields the Cloud actually parses:
#      cerut de / data / scope / ce trebuie / livrare.
#      MEASURED 2026-10-27: the CI queue had ZERO of the five. The Cloud
#      executes only tickets with "scope: cloud" - so it would have
#      executed ZERO tickets and reported nothing wrong.
#   2. SCOPE VALUE: scope must be one of cloud / local / ambele. A ticket
#      with a scope the Cloud does not know is not executable either.
#   3. COMPLETENESS: the value of "ce trebuie" must not end mid-sentence.
#      MEASURED 2026-10-27: the last ticket in BOTH channels ended with
#      "Nu intai" - a half instruction - because the publisher accepted a
#      truncated body and wrote it to both channels, reporting success.
#   4. DELIVERY TARGET: QUEUE/DONE/ must exist. MEASURED 2026-10-27: it did
#      not exist in the CI repo, while the Cloud writes its results there.
#   5. DUAL CHANNEL PARITY: every ticket id in the queue must also appear
#      in the Drive channel file. That is the executable form of the rule
#      "same TASK_ID, two channels" - a rule in prose is not a rule.
#   6. CONTRACT DRIFT: the contract is read LIVE from the Cloud's own
#      files when they are reachable, and compared with the local snapshot
#      (docs/CONTRACT-CLOUD-QUEUE.md). If the Cloud changed its format and
#      nobody noticed, the snapshot would be a beautiful lie.
#
# Exit codes:
#   0 = measured and true: tickets conform, contract has not drifted
#   1 = at least one ticket breaks the contract, or the contract drifted
#   2 = the measurement is incomplete (the live contract is unreadable).
#       This is NOT a pass: an unmeasured state must never be reported as
#       a healthy one.
#
# ASCII ONLY: executed by Windows PowerShell 5.1.

param(
    [string]$Root = '',
    [string]$CloudRoot = '',
    [string]$QueueFile = '',
    [string]$DoneDir = '',
    [string]$DriveChannel = '',
    [string]$ContractSnapshot = ''
)

$ErrorActionPreference = 'Stop'

if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
if (-not $QueueFile) { $QueueFile = Join-Path $Root 'QUEUE\TASKS-FOR-CLOUD.md' }
if (-not $DoneDir) { $DoneDir = Join-Path $Root 'QUEUE\DONE' }
if (-not $DriveChannel) { $DriveChannel = Join-Path $Root 'BRIDGE-DRIVE\TASKURI-PENTRU-CLOUD.md' }
if (-not $ContractSnapshot) { $ContractSnapshot = Join-Path $Root 'docs\CONTRACT-CLOUD-QUEUE.md' }
if (-not $CloudRoot) { $CloudRoot = Join-Path $Root 'cloud-ingest\MAVIS-CLOUD' }

$LiveQueue = Join-Path $CloudRoot 'QUEUE\TASKS-FOR-CLOUD.md'
$LiveSkill = Join-Path $CloudRoot '.skills\mavis-cloud-to-local-reporting\SKILL.md'

function Write-Out {
    param([Parameter(Mandatory = $true)][string]$Message)
    [Console]::Out.WriteLine($Message)
}

# Extract the contract field names from a queue file, by reading the fenced
# block under the "## Format" heading. The fields are declared in the
# Cloud's own file, so this is a measurement, not a constant: if Cloud
# renames a field, the extraction follows.
function Get-ContractFields {
    param([Parameter(Mandatory = $true)][string]$Text)
    $lines = $Text -split "`r?`n"
    $inFormat = $false
    $inFence = $false
    $block = New-Object System.Collections.Generic.List[string]
    foreach ($line in $lines) {
        if ($line -match '^#{2,3}\s*Format\b') { $inFormat = $true; continue }
        if ($inFormat -and $line -match '^##\s') { $inFormat = $false }
        if (-not $inFormat) { continue }
        if ($line -match '^\s*```') {
            if ($inFence) { break }
            $inFence = $true
            continue
        }
        if ($inFence) { $block.Add($line) }
    }
    if ($block.Count -eq 0) { return @() }
    $text = ($block -join "`n")
    $names = New-Object System.Collections.Generic.List[string]
    # A field may be declared at the start of a line or after a pipe:
    # "cerut de: local | data: YYYY-MM-DD" declares TWO fields.
    foreach ($m in [regex]::Matches($text, '(?m)(?:^|\|)\s*([a-z][a-z ]{1,14})\s*:')) {
        $n = $m.Groups[1].Value.Trim()
        if ($names -notcontains $n) { $names.Add($n) }
    }
    return $names.ToArray()
}

# A value is complete when its last visible character closes a thought.
# "Nu intai" is not complete; "si cum il accesezi." is.
function Test-CompleteValue {
    param([Parameter(Mandatory = $true)][string]$Value)
    $v = $Value.Trim()
    if (-not $v) { return $false }
    $lines = @($v -split "`r?`n" | Where-Object { $_.Trim() })
    if ($lines.Count -eq 0) { return $false }
    $last = $lines[$lines.Count - 1].TrimEnd()
    if ($last -match '^\s*[-*+]\s+(.*)$') { $last = $Matches[1].TrimEnd() }
    elseif ($last -match '^\s*\d+\.\s+(.*)$') { $last = $Matches[1].TrimEnd() }
    if (-not $last) { return $false }
    $c = $last[$last.Length - 1]
    $ok = ($c -eq '.' -or $c -eq '!' -or $c -eq '?' -or $c -eq [char]0x2026 -or
           $c -eq ')' -or $c -eq ']' -or $c -eq '}' -or $c -eq '"' -or
           $c -eq [char]0x201D -or $c -eq '`' -or $c -eq ':')
    return $ok
}

# Split one ticket line into field declarations. A line may declare more
# than one field ("cerut de: local | data: 2026-10-27"), and a value may
# itself contain a pipe. Only a KNOWN field name starts a new field;
# anything else is a continuation of the previous one.
function Split-FieldLine {
    param(
        [Parameter(Mandatory = $true)][string]$Line,
        [Parameter(Mandatory = $true)][string[]]$Known
    )
    $out = New-Object System.Collections.Generic.List[object]
    $parts = @($Line -split '\s\|\s')
    foreach ($part in $parts) {
        $m = [regex]::Match($part, '^\s*([a-z][a-z ]{1,14})\s*:\s*(.*)$')
        $isField = $false
        $name = ''
        if ($m.Success) {
            $name = $m.Groups[1].Value.Trim()
            $lower = $name.ToLower()
            foreach ($k in $Known) { if ($k.ToLower() -eq $lower) { $isField = $true } }
        }
        if ($isField) {
            $out.Add(@{ Name = $name; Value = $m.Groups[2].Value.Trim() })
        } elseif ($out.Count -gt 0) {
            $out[$out.Count - 1].Value = $out[$out.Count - 1].Value + "`n" + $part.Trim()
        }
    }
    return $out.ToArray()
}

$problems = 0
$unknown = 0

# --- 0. required inputs ---------------------------------------------------
foreach ($f in @(@{ P = $QueueFile; N = 'coada' }, @{ P = $ContractSnapshot; N = 'snapshot contract' })) {
    if (-not (Test-Path -LiteralPath $f.P)) {
        Write-Out ('EROARE: lipseste ' + $f.N + ': ' + $f.P)
        exit 2
    }
}

# --- 1. the contract, live and snapshotted --------------------------------
$snapshotText = [System.IO.File]::ReadAllText($ContractSnapshot)
$required = @(Get-ContractFields -Text $snapshotText)
if ($required.Count -eq 0) {
    Write-Out ('EROARE: snapshotul contractului nu are blocul "## Format": ' + $ContractSnapshot)
    exit 2
}
# "detalii" is the CI's own extension: it preserves the original body of a
# ticket and is not part of the Cloud's contract.
$known = @($required) + @('detalii')

$contractSource = 'LOCAL-SNAPSHOT'
$drift = 'UNKNOWN'
$liveFields = @()
if (Test-Path -LiteralPath $LiveQueue) {
    $contractSource = 'MAVIS-CLOUD-LIVE'
    $liveText = [System.IO.File]::ReadAllText($LiveQueue)
    $liveFields = @(Get-ContractFields -Text $liveText)
    if ($liveFields.Count -eq 0) {
        $drift = 'UNKNOWN'
    } else {
        $same = ($liveFields.Count -eq $required.Count)
        if ($same) {
            foreach ($f in $required) { if ($liveFields -notcontains $f) { $same = $false } }
        }
        if ($same) { $drift = 'NO' } else { $drift = 'YES' }
    }
}

Write-Out ('CONTRACT_SOURCE=' + $contractSource)
Write-Out ('CONTRACT_FIELDS=' + ($required -join '|'))
Write-Out ('CONTRACT_DRIFT=' + $drift)
if ($drift -eq 'YES') {
    $problems++
    Write-Out ('FAIL contract - contractul live al Cloud-ului difera de snapshot: live=[' + ($liveFields -join '|') + '] snapshot=[' + ($required -join '|') + ']')
} elseif ($drift -eq 'UNKNOWN') {
    $unknown++
    Write-Out 'UNKNOWN contract - contractul live al Cloud-ului nu a putut fi citit, deci driftul nu poate fi masurat'
}

# --- 2. the tickets -------------------------------------------------------
$queueText = [System.IO.File]::ReadAllText($QueueFile)
$qLines = $queueText -split "`r?`n"

$driveText = ''
if (Test-Path -LiteralPath $DriveChannel) {
    $driveText = [System.IO.File]::ReadAllText($DriveChannel)
} else {
    Write-Out ('FAIL canal primar lipsa: ' + $DriveChannel)
}

$tickets = New-Object System.Collections.Generic.List[object]
$current = $null
foreach ($line in $qLines) {
    if ($line -match '^###\s*\[([^\]]*)\]\s*(.*)$') {
        if ($null -ne $current) { $tickets.Add($current) }
        $current = [PSCustomObject]@{ Id = $Matches[1]; Title = $Matches[2]; Lines = New-Object System.Collections.Generic.List[string] }
        continue
    }
    if ($null -ne $current) { $current.Lines.Add($line) }
}
if ($null -ne $current) { $tickets.Add($current) }

$ticketProblems = 0
foreach ($t in $tickets) {
    $id = $t.Id
    $label = 'ticheta [' + $id + ']'
    $bad = $false

    if (-not $id) { Write-Out ('FAIL ' + $label + ' - id gol'); $bad = $true }
    if (-not $t.Title.Trim()) { Write-Out ('FAIL ' + $label + ' - titlu gol'); $bad = $true }

    # collect the fields, with continuations
    $fields = @{}
    $order = New-Object System.Collections.Generic.List[string]
    $lastName = ''
    foreach ($line in $t.Lines.ToArray()) {
        if ($line -match '^\s*###\s*\[') { break }
        if (-not $line.Trim()) { continue }
        $decls = @(Split-FieldLine -Line $line -Known $known)
        if ($decls.Count -eq 0) {
            if ($lastName) {
                $fields[$lastName] = $fields[$lastName] + "`n" + $line.Trim()
            }
            continue
        }
        foreach ($d in $decls) {
            $key = $d.Name.ToLower()
            if (-not $fields.ContainsKey($key)) {
                $fields[$key] = ''
                $order.Add($key)
            }
            if ($d.Value) { $fields[$key] = $fields[$key] + $d.Value }
            $lastName = $key
        }
    }

    foreach ($f in $required) {
        $key = $f.ToLower()
        if (-not $fields.ContainsKey($key) -or -not $fields[$key].Trim()) {
            Write-Out ('FAIL ' + $label + ' - campul obligatoriu "' + $f + '" lipseste sau e gol')
            $bad = $true
        }
    }

    if ($fields.ContainsKey('scope') -and $fields['scope'].Trim()) {
        $sv = ($fields['scope'] -split '\|')[0].Trim().ToLower()
        if ($sv -ne 'cloud' -and $sv -ne 'local' -and $sv -ne 'ambele') {
            Write-Out ('FAIL ' + $label + ' - valoarea scope necunoscuta: "' + $sv + '" (Cloud ruleaza doar cloud/local/ambele)')
            $bad = $true
        }
    }

    if ($fields.ContainsKey('ce trebuie') -and $fields['ce trebuie'].Trim()) {
        if (-not (Test-CompleteValue -Value $fields['ce trebuie'])) {
            Write-Out ('FAIL ' + $label + ' - valoarea "ce trebuie" se termina la mijlocul propozitiei (instructiune trunchiata)')
            $bad = $true
        }
    }
    if ($fields.ContainsKey('detalii') -and $fields['detalii'].Trim()) {
        if (-not (Test-CompleteValue -Value $fields['detalii'])) {
            Write-Out ('FAIL ' + $label + ' - valoarea "detalii" se termina la mijlocul propozitiei')
            $bad = $true
        }
    }

    if ($id -and $driveText) {
        if ($driveText -notmatch [regex]::Escape($id)) {
            Write-Out ('FAIL ' + $label + ' - idul nu apare in canalul primar (BRIDGE-DRIVE); regula "acelasi TASK_ID in ambele canale" e incalcata')
            $bad = $true
        }
    }

    if ($bad) { $ticketProblems++ }
}

# --- 2b. headers the Cloud's contract does not recognize -----------------
# A ticket written in the old "## TASK-..." style is INVISIBLE to the
# Cloud: the contract only recognizes "### [id] titlu". MEASURED
# 2026-10-27: the whole CI queue was written that way - two tickets,
# both invisible - so a queue that "looks full" can be empty for the only
# reader that matters. Counting them is the only way to see it.
$legacy = 0
foreach ($line in $qLines) {
    if ($line -match '^\#{1,6}\s+TASK-') { $legacy++ }
}
if ($legacy -gt 0) {
    $problems++
    Write-Out ('FAIL coada - ' + $legacy + ' antet( uri) de ticheta in format pe care contractul Cloud-ului nu-l recunoaste ("## TASK-..."): invizibile pentru Cloud')
}
Write-Out ('UNRECOGNISED_HEADERS=' + $legacy)

Write-Out ('TICKETS=' + $tickets.Count)
Write-Out ('TICKET_PROBLEMS=' + $ticketProblems)
$problems += $ticketProblems

# --- 3. the delivery target ----------------------------------------------
if (Test-Path -LiteralPath $DoneDir) {
    Write-Out ('DONE_DIR=present ' + $DoneDir)
} else {
    Write-Out ('FAIL DONE_DIR lipseste: ' + $DoneDir + ' - Cloud-ul scrie rezultatele acolo')
    $problems++
}

# --- 4. the file must not be cut mid-write -------------------------------
$raw = [System.IO.File]::ReadAllBytes($QueueFile)
if ($raw.Length -gt 0 -and $raw[$raw.Length - 1] -ne 10) {
    Write-Out 'FAIL coada - fisierul nu se termina cu newline (scriere trunchiata la mijlocul unei linii)'
    $problems++
}
$lastLine = ''
foreach ($l in $qLines) { if ($l.Trim()) { $lastLine = $l.Trim() } }
if ($lastLine) {
    $m = [regex]::Match($lastLine, '^\s*([a-z][a-z ]{1,14})\s*:\s*(.*)$')
    if ($m.Success -and -not $m.Groups[2].Value.Trim()) {
        Write-Out ('FAIL coada - ultima linie declara campul "' + $m.Groups[1].Value.Trim() + '" cu valoare goala (scriere trunchiata)')
        $problems++
    }
}

# --- verdict --------------------------------------------------------------
Write-Out ('QUEUE_PROBLEMS=' + $problems + ' UNKNOWN=' + $unknown)
if ($problems -gt 0) {
    Write-Out 'POARTA A BLOCAT. Coada secundara nu e executabila de Cloud pana nu se repara.'
    exit 1
}
if ($unknown -gt 0) {
    Write-Out 'Porta a trecut pe masuratorile care au putut rula, dar contractul live nu a putut fi comparat. Necunoscutul se raporteaza, nu se presupune.'
    exit 2
}
Write-Out 'Coada secundara e executabila de Cloud: toate tichetele au cele cinci campuri, scopul, instructiunea completa si tinta de livrare.'
exit 0
