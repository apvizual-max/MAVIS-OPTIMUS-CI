#!/usr/bin/env powershell
<#
.SYNOPSIS
    Wrapperul programat pentru bucla Jules zilnica. Ruleaza o data pe zi si
    lasa urma scrisa, ca o rulare sa nu poata fi ceva ce n-a fost vazut.

.DESCRIPTION
    jules-daily.ps1 face munca. Acest wrapper adauga ce lipseste la o rulare
    nesupravegheata:

    1. LOG DATAT - tot ce iese ajunge in logs\jules-daily-YYYY-MM-DD.log, cu
       timestamp. Fara log, o rulare reusita si una care a picat silentios
       arata la fel.
    2. HALT AND REPORT - daca codul de iesire este nenul, runnerul se opreste
       si scrie explicit ce a gasit. NU repara. NU sterge. NU face merge.
    3. INTERZIS ABSOLUT - reset --hard, checkout forcat, clean, force push,
       merge automat. Bucla trimite taskuri si citeste propuneri. Decizia de
       merge ramane a lui Popy, prin R0.

    ASCII PUR, din cauza parserului Windows PowerShell 5.1.

.PARAMETER DryRun
    Nu ruleaza nimic, doar arata ce ar face.
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$TriageOnly
)

$ErrorActionPreference = 'Continue'

$BASE   = Split-Path -Parent $PSScriptRoot
$LOGS   = Join-Path $BASE 'logs'
$DAILY  = Join-Path $PSScriptRoot 'jules-daily.ps1'

if (-not (Test-Path -LiteralPath $DAILY)) {
    Write-Output ("EROARE: nu exista " + $DAILY)
    exit 2
}

if (-not (Test-Path -LiteralPath $LOGS)) {
    New-Item -ItemType Directory -Force -Path $LOGS | Out-Null
}

$azi    = Get-Date -Format 'yyyy-MM-dd'
$logFis = Join-Path $LOGS ("jules-daily-{0}.log" -f $azi)
$stamp  = Get-Date -Format 'HH:mm:ss'

function Scrie([string]$t, [string]$nivel = 'INFO') {
    $linie = ('[{0}] [{1}] {2}' -f $stamp, $nivel, $t)
    Add-Content -Path $logFis -Value $linie -Encoding UTF8
    Write-Output $linie
}

Scrie ('=' * 60)
Scrie ("Rulare programata a buclelui Jules. DryRun={0} TriageOnly={1}" -f $DryRun, $TriageOnly)

if ($DryRun) {
    Scrie 'DryRun: NU ruleaza nimic. Iesire.'
    exit 0
}

Scrie 'Se ruleaza jules-daily.ps1 ...'

$argsDaily = @('-NoProfile', '-File', $DAILY)
if ($TriageOnly) { $argsDaily += '-TriageOnly' }
$output = & powershell @argsDaily 2>&1
$code   = $LASTEXITCODE

foreach ($l in $output) {
    $linie = [string]$l
    $nivel = 'INFO'
    if ($linie -match '\[ERROR\]') { $nivel = 'ERROR' }
    elseif ($linie -match '\[WARN\]|\[HALT\]') { $nivel = 'WARN' }
    Scrie $linie $nivel
}

Scrie ("Cod de iesire al buclelui: {0}" -f $code)

# Ce s-a trimis catre Jules, masurat, nu estimat.
foreach ($l in $output) {
    $linie = [string]$l
    if ($linie -match '^(DISPATCHED|SKIPPED|FINDINGS|USED|REPORT)=') {
        Scrie ('REZULTAT ' + $linie) 'STEP'
    }
}

if ($code -ne 0) {
    Scrie '' 'HALT'
    Scrie ("Cod de iesire nenul ({0}). Bucla s-a oprit cu problema." -f $code) 'HALT'
    Scrie ('Detalii in fisierul: {0}' -f $logFis) 'HALT'
    Scrie 'Actiune ceruta: interventa umana. Nu se repara automat.' 'HALT'
    exit $code
}

Scrie 'OK - bucla Jules s-a incheiat.'
Scrie ('Log: {0}' -f $logFis)
exit 0
