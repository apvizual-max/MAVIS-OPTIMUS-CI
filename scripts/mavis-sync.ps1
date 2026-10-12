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

$HQ    = 'C:\Users\apviz\.minimax-agent\projects\Mavis-Optimus-Continuous-Integration'
$CLOUD = Join-Path $HQ 'cloud-ingest\MAVIS-CLOUD'

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
$cloudBefore = (git rev-parse --short HEAD).Trim()
$cloudRemote = (git ls-remote origin HEAD)
if ($LASTEXITCODE -ne 0 -or -not $cloudRemote) {
    Write-Output "ERROR|remote MAVIS-CLOUD inaccesibil"
    exit 1
}
$cloudRemoteShort = ($cloudRemote -split '\s+')[0].Substring(0,8)

if ($WhatIf) {
    Write-Output ("CE_AR_FI|cloud_local=$cloudBefore|cloud_remote=$cloudRemoteShort")
    exit 0
}

git pull --ff-only 2>&1 | Select-Object -Last 2
$cloudAfter = (git rev-parse --short HEAD).Trim()
$schimbat = ($cloudBefore -ne $cloudAfter)

Write-Output ("PAS1_CLOUD|local_inainte=$cloudBefore|local_dupa=$cloudAfter|remote=$cloudRemoteShort|schimbat=$schimbat")

if ($schimbat) {
    Write-Output "--- commituri noi din Cloud ---"
    git log --oneline "$cloudBefore..$cloudAfter" | ForEach-Object { Write-Output ("  " + $_) }
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
$modificari = @(git status --porcelain)

if ($modificari.Count -eq 0) {
    Write-Output "PAS2_LOCAL|status=curat|nimic de comitat"
} else {
    Write-Output ("PAS2_LOCAL|modificari=" + $modificari.Count)
    git add -A
    git commit -m ("cloud: ingest " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + " (citire read-only din MAVIS-CLOUD)")
    Write-Output ("PAS2_LOCAL|commit=" + (git rev-parse --short HEAD))
}

$ramase = @(git rev-list --count '@{u}..HEAD' 2>$null)
if ($ramase.Count -gt 0 -and [int]$ramase[0] -ge 50) {
    Write-Output ("REMINDER|" + $ramase[0] + " commituri neimpinse - cere acord explicit lui Popy")
}

Write-Output ("FINAL|cloud=" + $cloudAfter + "|local=" + (git rev-parse --short HEAD) + "|impingere=NEEXECUTATA|poarta_R0=ramane_la_Popy")