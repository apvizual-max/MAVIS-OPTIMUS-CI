# jules-daily.ps1
# The daily loop. One run, one day, one ledger.
#
# Sequence:
#   1. read the registry and the quota ledger
#   2. rotate repo x axis, respecting the per-repo open-PR governor
#   3. dispatch each task to Jules (issue + label jules)
#   4. triage every open Jules PR with a measured verdict
#   5. write the daily report
#
# Usage:
#   powershell -NoProfile -File jules-daily.ps1
#   powershell -NoProfile -File jules-daily.ps1 -DispatchOnly
#   powershell -NoProfile -File jules-daily.ps1 -TriageOnly
#   powershell -NoProfile -File jules-daily.ps1 -DryRun
#
# Exit codes:
#   0 = loop completed (a per-repo failure is reported, not swallowed)
#   2 = the loop could not run at all
#
# ASCII ONLY: executed by Windows PowerShell 5.1.

param(
    [switch]$DispatchOnly,
    [switch]$TriageOnly,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'jules-lib.ps1')

function Main {
    Start-JulesLog -Name 'jules-daily'

    if (-not (Assert-Gh)) { return 2 }

    $registry = Get-RepoRegistry
    $axes = @($registry.defaults.axisRotation)
    $cap = [int]$registry.defaults.maxTasksPerDay
    $maxOpen = [int]$registry.defaults.maxOpenPrsPerRepo
    $ledger = Get-QuotaLedger
    $used = [int]$ledger.tasksDispatched

    Write-JulesLog -Message ('quota ledger: ' + $used + '/' + $cap + ' dispatched today, ceiling ' + $registry.quotaPerDay) -Level 'STEP'

    $dispatched = @()
    $skipped = @()

    if (-not $TriageOnly) {
        $repos = @(Get-DispatchRepos -Registry $registry)
        $combos = @()
        foreach ($r in $repos) {
            foreach ($a in $axes) { $combos += [PSCustomObject]@{ Repo = $r.name; Axis = $a } }
        }
        # rotate the starting point by the day's task count so consecutive days
        # do not hammer the same repo first
        $offset = $used % $combos.Count
        $ordered = @()
        for ($i = 0; $i -lt $combos.Count; $i++) {
            $ordered += $combos[(($i + $offset) % $combos.Count)]
        }

        foreach ($c in $ordered) {
            # Re-read the ledger every iteration. The dispatch subprocess
            # updates the file, so a copy taken before the loop is stale and
            # the cap check would lie about how much of the day is spent.
            $ledger = Get-QuotaLedger
            if ([int]$ledger.tasksDispatched -ge $cap) {
                $skipped += ($c.Repo + '/' + $c.Axis + ': daily cap reached (' + $cap + ')')
                continue
            }
            $open = @(Get-JulesPrs -Repo $c.Repo -States @('open'))
            if ($open.Count -ge $maxOpen) {
                $skipped += ($c.Repo + '/' + $c.Axis + ': already ' + $open.Count + ' open Jules PR (max ' + $maxOpen + ')')
                continue
            }

            $dispatchScript = Join-Path $PSScriptRoot 'jules-dispatch.ps1'
            $argsList = @('-NoProfile', '-File', $dispatchScript, '-Repo', $c.Repo, '-Axis', $c.Axis)
            if ($DryRun) { $argsList += '-DryRun' }
            $dRes = Invoke-Native -Program 'powershell' -Arguments $argsList
            $code = $dRes.ExitCode
            $text = $dRes.Out
            if ($dRes.Err) { $text = $text + "`n" + $dRes.Err }
            if ($code -eq 0) {
                $issue = 0
                foreach ($line in ($text -split "`r?`n")) {
                    if ($line -match '^ISSUE=(\d+)') { $issue = [int]$Matches[1] }
                }
                $dispatched += [PSCustomObject]@{ Repo = $c.Repo; Axis = $c.Axis; Issue = $issue }
                Write-JulesLog -Message ('dispatched ' + $c.Repo + '/' + $c.Axis + ' issue #' + $issue) -Level 'STEP'
            } else {
                $reason = 'exit ' + $code
                foreach ($line in ($text -split "`r?`n")) {
                    if ($line -match '\[ERROR\]|\[WARN\]') { $reason = $line.Trim(); break }
                }
                $skipped += ($c.Repo + '/' + $c.Axis + ': ' + $reason)
                Write-JulesLog -Message ('dispatch failed ' + $c.Repo + '/' + $c.Axis + ' - ' + $reason) -Level 'WARN'
            }
        }
    }

    # --- Triage -----------------------------------------------------------
    $triageFile = ''
    $findings = 0
    if (-not $DispatchOnly) {
        $triageScript = Join-Path $PSScriptRoot 'jules-triage.ps1'
        $tRes = Invoke-Native -Program 'powershell' -Arguments @('-NoProfile', '-File', $triageScript)
        $code = $tRes.ExitCode
        $text = $tRes.Out
        if ($tRes.Err) { $text = $text + "`n" + $tRes.Err }
        foreach ($line in ($text -split "`r?`n")) {
            if ($line -match '^TRIAGE_FILE=(.+)$') { $triageFile = $Matches[1].Trim() }
            if ($line -match '^FINDINGS=(\d+)$') { $findings = [int]$Matches[1] }
            if ($line -match '^PR=(\S+) VERDICT=(\S+) VERIFY=(\S+)$') {
                Write-JulesLog -Message ('triage ' + $Matches[1] + ' -> ' + $Matches[2] + ' (' + $Matches[3] + ')') -Level 'STEP'
            }
        }
        if ($code -ne 0) {
            Write-JulesLog -Message ('triage exited ' + $code) -Level 'WARN'
        }
    }

    # --- Daily report -----------------------------------------------------
    $docDir = Join-Path (Get-JulesRoot) 'docs\daily'
    if (-not (Test-Path -LiteralPath $docDir)) { New-Item -ItemType Directory -Path $docDir -Force | Out-Null }
    $stamp = (Get-Date).ToString('yyyy-MM-dd')
    $reportFile = Join-Path $docDir ('jules-daily-' + $stamp + '.md')

    $ledger = Get-QuotaLedger
    $L = @()
    $L += ('# Bucla Jules zilnica - ' + $stamp)
    $L += ''
    $L += '## SCOPUL'
    $L += ''
    $L += ('Trimite taskuri de nivel de sistem lui Jules, pe cele ' + $axes.Count +
           ' axe (' + ($axes -join ', ') + '), si triaza fiecare pull request deschis.')
    $L += ''
    $L += '## TIMELINE SCURT'
    $L += ''
    $L += ('- Taskuri trimise azi: ' + $ledger.tasksDispatched + ' ( plafon zilnic ' + $cap + ', cota Jules ' + $registry.quotaPerDay + '/zi )')
    $L += ('- Pull request-uri triate: ' + $findings)
    $L += ('- Raport de triaj: ' + $(if ($triageFile) { $triageFile } else { '(triaj neexecutat)' }))
    $L += ''
    if ($dispatched.Count -gt 0) {
        $L += '| Repo | Axa | Issue |'
        $L += '|---|---|---|'
        foreach ($d in $dispatched) { $L += ('| ' + $d.Repo + ' | ' + $d.Axis + ' | #' + $d.Issue + ' |') }
        $L += ''
    }
    if ($skipped.Count -gt 0) {
        $L += '### S-au sarit, cu motiv'
        $L += ''
        foreach ($s in $skipped) { $L += ('- ' + $s) }
        $L += ''
    }
    $L += '## CE RAMANE'
    $L += ''
    $L += '- Fiecare pull request cu verdict ACCEPT asteapta R0 pentru merge.'
    $L += '- Fiecare pull request cu verdict ADAPT sau REJECT cere interventia mea.'
    $L += '- Jules este async: un task trimis acum poate produce PR peste cateva minute.'
    $L += ''
    $L += '## DECIZII ALE LUI POPY'
    $L += ''
    $L += '- Merge pe main pentru pull request-urile cu verdict ACCEPT.'
    $L += '- Care este al 5-lea repo cu Jules instalat (OPTIMUS-Backbone e propunerea mea).'
    $L += '- Setarea secretului JULES_API_KEY in repo-urile fara Jules functional.'
    $L += ''
    $L += '## CONSIDERENTE'
    $L += ''
    $L += ('- Cota Jules este de ' + $registry.quotaPerDay + ' taskuri/zi. Platforma arde ' +
           $cap + '. Restul ramane ca rezerva pentru refactorizari mari, unde Jules chiar merita sandbox-ul lui.')
    $L += '- Taskurile sunt pe nivel de sistem, nu pe nivel de virgula: o tinta, un test, un PR.'
    $L += ''
    $L += '## VERDICT'
    $L += ''
    $L += $(if ($skipped.Count -eq 0 -and $findings -ge 0) { 'Bucla a rulat complet.' } else { 'Bucla a rulat cu sariri. Vezi motivele de mai sus.' })
    $L += ''
    $L += '## PASUL URMATOR'
    $L += ''
    $L += '- Local: triaza si decide fiecare PR nou.'
    $L += '- Popy: acorda R0 pe merge-urile ACCEPT, si pune secretul in celelalte repo-uri.'
    $L += ''

    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($reportFile, (($L -join "`n") + "`n"), $enc)
    Write-JulesLog -Message ('daily report: ' + $reportFile) -Level 'STEP'

    Write-JulesOut ('REPORT=' + $reportFile)
    Write-JulesOut ('DISPATCHED=' + $dispatched.Count)
    Write-JulesOut ('SKIPPED=' + $skipped.Count)
    Write-JulesOut ('FINDINGS=' + $findings)
    Write-JulesOut ('USED=' + $ledger.tasksDispatched)
    return 0
}

$code = Main
exit $code
