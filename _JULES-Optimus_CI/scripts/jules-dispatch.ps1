# jules-dispatch.ps1
# Sends one system-level task to Jules, on a given repo and axis.
#
# Mavis Local is the sovereign authority. Jules proposes. This script only
# creates the GitHub issue that wakes Jules up; it never merges, never pushes
# to main, never approves.
#
# Usage:
#   powershell -NoProfile -File jules-dispatch.ps1 -Repo MAVIS-CLOUD -Axis performance
#   powershell -NoProfile -File jules-dispatch.ps1 -Repo MAVIS-CLOUD -Axis design -DryRun
#
# ASCII ONLY: executed by Windows PowerShell 5.1.

param(
    [string]$Repo = '',
    [string]$Axis = '',
    [switch]$DryRun,
    [switch]$AllowMissingSecret
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'jules-lib.ps1')

function Main {
    Start-JulesLog -Name 'jules-dispatch'

    if (-not (Assert-Gh)) { return 2 }

    $registry = Get-RepoRegistry

    if (-not $Repo) {
        $enabled = @(Get-DispatchRepos -Registry $registry)
        Write-JulesLog -Message ('enabled repos: ' + (($enabled | ForEach-Object { $_.name }) -join ', ')) -Level 'STEP'
        Write-JulesLog -Message 'specify -Repo' -Level 'ERROR'
        return 2
    }

    $entry = Get-RepoEntry -Name $Repo -Registry $registry
    if (-not $entry) {
        Write-JulesLog -Message ('repo not in registry: ' + $Repo) -Level 'ERROR'
        return 2
    }

    $axes = $registry.defaults.axisRotation
    if (-not $Axis) {
        $ledger = Get-QuotaLedger
        $idx = [int]$ledger.tasksDispatched % $axes.Count
        $Axis = $axes[$idx]
    }
    if ($axes -notcontains $Axis) {
        Write-JulesLog -Message ('axis not allowed: ' + $Axis) -Level 'ERROR'
        return 2
    }

    Write-JulesLog -Message ('target repo=' + $Repo + ' axis=' + $Axis + ' branch=' + $entry.branch) -Level 'STEP'

    # --- Preconditions, measured, not assumed -----------------------------
    $labelRes = Invoke-Gh -GhArgs @('label', 'list', '-R', ('apvizual-max/' + $Repo), '--limit', '100', '--json', 'name')
    $hasLabel = $false
    if ($labelRes.Ok) {
        $labels = $labelRes.Out | ConvertFrom-Json
        foreach ($l in $labels) { if ($l.name -eq 'jules') { $hasLabel = $true } }
    }
    if (-not $hasLabel) {
        Write-JulesLog -Message ('label jules MISSING in ' + $Repo + ' - run jules-install.ps1') -Level 'ERROR'
        return 3
    }

    $secRes = Invoke-Gh -GhArgs @('secret', 'list', '-R', ('apvizual-max/' + $Repo), '--json', 'name')
    $hasSecret = $false
    if ($secRes.Ok) {
        $secs = $secRes.Out | ConvertFrom-Json
        foreach ($s in $secs) { if ($s.name -eq 'JULES_API_KEY') { $hasSecret = $true } }
    }
    if (-not $hasSecret) {
        if (-not $AllowMissingSecret) {
            Write-JulesLog -Message ('JULES_API_KEY MISSING in ' + $Repo) -Level 'ERROR'
            Write-JulesLog -Message ('Popy must run: gh secret set JULES_API_KEY -R apvizual-max/' + $Repo) -Level 'ERROR'
            return 3
        }
        Write-JulesLog -Message ('WARNING: JULES_API_KEY missing in ' + $Repo) -Level 'WARN'
    }

    $wfRes = Invoke-Gh -GhArgs @('api', ('repos/apvizual-max/' + $Repo + '/contents/.github/workflows'))
    $hasWorkflow = $false
    if ($wfRes.Ok) {
        try {
            $wfs = $wfRes.Out | ConvertFrom-Json
            foreach ($w in $wfs) { if ($w.name -eq 'jules.yml') { $hasWorkflow = $true } }
        } catch { }
    }
    if (-not $hasWorkflow) {
        Write-JulesLog -Message ('jules.yml MISSING in ' + $Repo + ' - run jules-install.ps1') -Level 'ERROR'
        return 3
    }

    # --- Quota ------------------------------------------------------------
    $ledger = Get-QuotaLedger
    $quota = [int]$registry.quotaPerDay
    $used = [int]$ledger.tasksDispatched
    $cap = [int]$registry.defaults.maxTasksPerDay
    if ($used -ge $cap) {
        Write-JulesLog -Message ('daily cap reached: ' + $used + '/' + $cap + ' (quota ceiling ' + $quota + '/day)') -Level 'WARN'
        return 4
    }
    Write-JulesLog -Message ('quota used today: ' + $used + '/' + $cap + ' dispatch cap, ' + $quota + ' total available') -Level 'STEP'

    # --- Target selection, measured on the repo tree ----------------------
    $history = @(Get-TargetHistory -Days 30)
    $exclude = @()
    foreach ($h in $history) {
        if ($h.StartsWith($Repo + '|')) { $exclude += $h.Substring($Repo.Length + 1) }
    }
    $target = Select-JulesTarget -Repo $Repo -Axis $Axis -Exclude $exclude
    if (-not $target) {
        Write-JulesLog -Message ('no target found for axis ' + $Axis + ' in ' + $Repo) -Level 'ERROR'
        return 5
    }
    Write-JulesLog -Message ('target selected: ' + $target.Path + ' (' + $target.Size + ' bytes)') -Level 'STEP'

    # --- Body -------------------------------------------------------------
    $context = Get-JulesContextText
    $card = Get-TaskCardText -Axis $Axis
    if (-not $card) {
        Write-JulesLog -Message ('no task card for axis ' + $Axis) -Level 'ERROR'
        return 5
    }

    $verifyCmds = @()
    if ($entry.verify.commands) { $verifyCmds = @($entry.verify.commands) }
    $verifyBlock = ''
    if ($verifyCmds.Count -gt 0) {
        $verifyBlock = "`n## Comenzi de verificare (ruleaza-le, raporteaza iesirea exacta)`n`n"
        foreach ($c in $verifyCmds) {
            $verifyBlock += ('- ' + "`n" + '  ```' + "`n" + '  ' + $c + "`n" + '  ```' + "`n")
        }
    }

    $head = @(
        '# Task Mavis Local -> Jules',
        '',
        ('Repo: **' + $Repo + '** - ramura: **' + $entry.branch + '** - axa: **' + $Axis + '**'),
        '',
        '## Context canonic (citeste tot, inainte de orice lucru)',
        ''
    ) -join "`n"

    $concrete = @(
        '## Concret pentru acest task',
        '',
        ('- **Fisierul tinta:** `' + $target.Path + '`'),
        ('- **Dimensiune masurata:** ' + $target.Size + ' octeti'),
        ('- **Ramura:** `' + $entry.branch + '`'),
        '- **Deschide pull request. Nu impinge pe main.**',
        ''
    ) -join "`n"

    $tail = @(
        '## Cum raportezi',
        '',
        'In descrierea PR-ului, cu formatul din sectiunea 6 a contextului canonic.',
        'Daca o verificare pica, nu continua: livreaza ce ai si spune-o.',
        ''
    ) -join "`n"

    $body = $head + "`n" + $context + "`n`n" + '## Cardul taskului' + "`n`n" + $card + "`n`n" + $concrete + $verifyBlock + "`n" + $tail

    $title = '[JULES-' + $Axis.ToUpper() + '] ' + $Repo + ' - ' + $target.Path

    if ($DryRun) {
        $outDir = Join-Path (Get-JulesRoot) 'state'
        if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
        $outFile = Join-Path $outDir ('draft-' + $Repo + '-' + $Axis + '.md')
        $enc = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($outFile, ('# ' + $title + "`n`n" + $body), $enc)
        Write-JulesLog -Message ('DRY RUN - body written to ' + $outFile + ' (' + $body.Length + ' chars)') -Level 'STEP'
        Write-JulesOut ('TITLE: ' + $title)
        return 0
    }

    # --- Create the issue -------------------------------------------------
    $titleFile = New-JulesTempFile -Suffix '.title.md'
    $bodyFile = New-JulesTempFile -Suffix '.body.md'
    try {
        $enc = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($titleFile, $title, $enc)
        [System.IO.File]::WriteAllText($bodyFile, $body, $enc)
        $res = Invoke-Gh -GhArgs @('issue', 'create', '-R', ('apvizual-max/' + $Repo),
                                   '--title-file', $titleFile, '--body-file', $bodyFile,
                                   '--label', 'jules')
        if (-not $res.Ok) {
            Write-JulesLog -Message ('issue create failed: ' + $res.Err) -Level 'ERROR'
            return 6
        }
        $issueUrl = $res.Out.Trim()
        $issueNumber = 0
        $m = [regex]::Match($issueUrl, '/issues/([0-9]+)')
        if ($m.Success) { $issueNumber = [int]$m.Groups[1].Value }
        Write-JulesLog -Message ('issue created: #' + $issueNumber + ' ' + $issueUrl) -Level 'STEP'

        $ledger = Add-QuotaTask -Ledger $ledger -Repo $Repo -Axis $Axis -Target $target.Path -IssueNumber $issueNumber
        $ledgerPath = Save-QuotaLedger -Ledger $ledger
        Write-JulesLog -Message ('quota ledger updated: ' + $ledgerPath + ' used=' + $ledger.tasksDispatched) -Level 'STEP'

        Write-JulesOut ('ISSUE=' + $issueNumber)
        Write-JulesOut ('URL=' + $issueUrl)
        Write-JulesOut ('TARGET=' + $target.Path)
        Write-JulesOut ('AXIS=' + $Axis)
        Write-JulesOut ('USED=' + $ledger.tasksDispatched)
        return 0
    } finally {
        if (Test-Path -LiteralPath $titleFile) { Remove-Item -LiteralPath $titleFile -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $bodyFile) { Remove-Item -LiteralPath $bodyFile -Force -ErrorAction SilentlyContinue }
    }
}

$code = Main
exit $code
