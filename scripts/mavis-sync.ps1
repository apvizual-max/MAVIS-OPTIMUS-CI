<#
    mavis-sync.ps1 - puntea Local <-> Cloud, forma ASIMETRICA.

    Legea, in trei randuri:
      1. Cloud impinge direct. Local doar CITe.
      2. Commitul local e automat.
      3. Impingerea nu exista in acest fisier. Nu ca o Promisiune - ca o
         ABSENTA verificabila: functia de mai jos isi citeste propriul cod
         sursa si se opreste daca gaseste un verb interzis.

    NOTA: fisierul e scris deliberat in ASCII pur. PowerShell 5.1 citeste
    UTF-8 fara BOM ca latin-1 si rupe orice linie cu diacritice sau linie
    lunga, ceea ce da un parser error imposibil de diagnosticat din continut.

    Rulat:  powershell -NoProfile -ExecutionPolicy Bypass -File mavis-sync.ps1 [-SelfTest] [-WhatIf]
#>

[CmdletBinding()]
param(
    [switch]$SelfTest,
    [switch]$WhatIf,
    # Test negativ fara executie: se verifica un TEXT, nu un fisier.
    # Injectarea unui verb interzis intr-un fisier temporar si rularea lui
    # EXECUTA verbul inainte de poarta - exact defectul documentat pe 2026-10-12.
    # Controlul negativ corect nu ruleaza nimic: verifica o valoare.
    [string]$TestSource
)

$ErrorActionPreference = 'Stop'

# Calea radacinii CI e DERIVATA din locul scriptului, nu hardcodata.
#
# MASURAT 2026-10-27: calea era hardcodata pe
# 'C:\Users\apviz\.minimax-agent\projects\Mavis-Optimus-Continuous-Integration'
# - folderul eliminat in consolidarea pe E:. Puntea zilnica (task 08:30) si-a
# raportat "clone-ul Cloud lipseste" si a iesit cu cod 1: un transport
# functional, cu o cale moarta in el. Repararea o singura data ar fi fost o
# poveste; de aceea exista acum o proba care verifica existenta clone-ului
# (mavis-sync-selfcheck.ps1).
$HQ    = Split-Path -Parent $PSScriptRoot
$CLOUD = Join-Path $HQ 'cloud-ingest\MAVIS-CLOUD'

# INCAPSULA - wrapper pentru apelurile native.
#
# Masurat 2026-10-12: cu $ErrorActionPreference='Stop' la nivel de script,
# PowerShell 5.1 transforma STREAMUL STDERR al unui executabil nativ intr-un
# error record terminal. `git pull` scrie raportul de progres pe stderr chiar
# si la un pull reusit ("Already up to date"), deci scriptul cadea cu EXIT=1
# fara nicio eroare reala. Verdictul era fals: scriptul raportat defect.
#
# Regula: pentru un binar nativ, stderr este DATE, nu ERORI. Verdictul vine
# din $LASTEXITCODE, singurul care apartine executabilului. Wrapperul izoleaza
# preferinta globala doar pe durata apelului si o restaureaza imediat.
function Invoke-Git {
    param([Parameter(Mandatory)][string[]]$Args)

    $precedent = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $rezultat = & git @Args 2>&1
        $cod = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $precedent
    }

    return [pscustomobject]@{
        Cod       = $cod
        Linie     = ($rezultat | ForEach-Object { "$_" }) -join "`n"
        Esuese    = ($rezultat | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
    }
}

# POARTA - construita ca sa POATA si sa esueze.
#
# Un control care nu poate esua nu e control. Aceasta citeste propriul fisier
# sursa, ignora liniile de comentariu si de configurare, si cauta verbii care ar
# ocoli poarta de acord sau ar atinge continutul local. Gaseste unul -> afiseaza
# si NU executa nimic, iesire 2.
#
# NOTE: cuvintele interzise sunt construite prin concatenare, ca sirul lor
# literal sa nu existe in codul executabil. Altfel poarta s-ar detecta pe
# sine si ar bloca intotdeauna, adica nu ar mai fi o poarta.
$VERB_INTERZIS = @(
    ('git' + '\s+pu' + 'sh'),
    ('\bpu' + 'sh\b'),
    ('--' + 'force'),
    ('git' + '\s+cl' + 'ean'),
    ('reset\s+--' + 'hard'),
    ('checkout\s+--\s'),
    ('git' + '\s+remote\s+add')
)

function Test-Poarta {
    param([string]$Cod)

    if (-not $Cod) {
        $Cod = (Get-Content -LiteralPath $PSCommandPath -Raw)
    }
    $doarCod = ($Cod -split "`n" |
               Where-Object { $_ -notmatch '^\s*#' } |
               Where-Object { $_ -notmatch '\$VERB_INTERZIS' }) -join "`n"

    $gasite = @()
    foreach ($v in $VERB_INTERZIS) {
        if ($doarCod -match $v) { $gasite += $v }
    }
    return $gasite
}

$violari = Test-Poarta -Cod $TestSource
if ($violari.Count -gt 0) {
    Write-Output ("POARTA|BLOCAT|verburi interzise: " + ($violari -join ', '))
    Write-Output "POARTA|efect=nimic nu s-a executat"
    exit 2
}

if ($TestSource) {
    Write-Output "POARTA|TRECUT|textul de proba nu contine verburi interzise"
    exit 0
}

if ($SelfTest) {
    Write-Output "POARTA|TRECUT|mavis-sync nu contine niciun verb interzis in codul executabil"
    exit 0
}

# PASUL 1 - citire din Cloud. Numai citire. Nimic nu se scrie acolo.
if (-not (Test-Path (Join-Path $CLOUD '.git'))) {
    Write-Output ("ERROR|clone-ul Cloud lipseste: " + $CLOUD)
    exit 1
}

Set-Location $CLOUD
$rHead = Invoke-Git @('rev-parse','--short','HEAD')
$cloudBefore = $rHead.Linie.Trim()
$rRemote = Invoke-Git @('ls-remote','origin','HEAD')
if ($rRemote.Cod -ne 0 -or -not $rRemote.Linie.Trim()) {
    Write-Output "ERROR|remote MAVIS-CLOUD inaccesibil"
    exit 1
}
$cloudRemoteShort = ($rRemote.Linie.Trim() -split '\s+')[0].Substring(0,8)

if ($WhatIf) {
    Write-Output ("CE_AR_FI|cloud_local=$cloudBefore|cloud_remote=$cloudRemoteShort")
    exit 0
}

$rPull = Invoke-Git @('pull','--ff-only')
$cloudAfter = (Invoke-Git @('rev-parse','--short','HEAD')).Linie.Trim()
$schimbat = ($cloudBefore -ne $cloudAfter)

Write-Output ("PAS1_CLOUD|exit_pull=" + $rPull.Cod + "|local_inainte=$cloudBefore|local_dupa=$cloudAfter|remote=$cloudRemoteShort|schimbat=$schimbat")
if ($rPull.Linie.Trim()) {
    Write-Output ("PULL|detail=" + ($rPull.Linie.Trim() -replace "`r?`n",' / '))
}

if ($schimbat) {
    Write-Output "--- commituri noi din Cloud ---"
    (Invoke-Git @('log','--oneline',"$cloudBefore..$cloudAfter")).Linie |
        ForEach-Object { if ($_.Trim()) { Write-Output ("  " + $_.Trim()) } }
    $handoffs = Get-ChildItem -LiteralPath (Join-Path $CLOUD 'docs') -File -Filter 'HANDOFF-*.md' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 3
    foreach ($h in $handoffs) {
        Write-Output ("HANDOFF|{0:yyyy-MM-dd HH:mm}|{1}" -f $h.LastWriteTime, $h.Name)
    }
}

# PASUL 2 - commit LOCAL, automat. Fara impingere.
# cloud-ingest\ este in .gitignore: nu se dubleaza continutul personal si nu
# se ingroapa un repo in alt repo. Se refera prin cale, nu prin copiere.
Set-Location $HQ
$modificari = @((Invoke-Git @('status','--porcelain')).Linie.Trim() -split "`n" |
                Where-Object { $_.Trim() })

if ($modificari.Count -eq 0) {
    Write-Output "PAS2_LOCAL|status=curat|nimic de comitat"
} else {
    Write-Output ("PAS2_LOCAL|modificari=" + $modificari.Count)
    [void](Invoke-Git @('add','-A'))
    $msg = "cloud: ingest " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + " (citire read-only din MAVIS-CLOUD)"
    [void](Invoke-Git @('commit','-m',$msg))
    Write-Output ("PAS2_LOCAL|commit=" + (Invoke-Git @('rev-parse','--short','HEAD')).Linie.Trim())
}

$ramase = (Invoke-Git @('rev-list','--count','@{u}..HEAD')).Linie.Trim()
if ($ramase -match '^\d+$' -and [int]$ramase -ge 50) {
    Write-Output ("REMINDER|" + $ramase + " commituri neimpinse - cere acord explicit lui Popy")
}

Write-Output ("FINAL|cloud=" + $cloudAfter + "|local=" + (Invoke-Git @('rev-parse','--short','HEAD')).Linie.Trim() + "|impingere=NEEXECUTATA|poarta_R0=ramane_la_Popy")