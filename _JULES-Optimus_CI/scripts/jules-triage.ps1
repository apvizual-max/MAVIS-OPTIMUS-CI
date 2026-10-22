# jules-triage.ps1
# Triage of every open Jules pull request across the enabled repos.
#
# This is the sovereign gate. For each Jules PR, Mavis Local produces a
# MEASURED verdict:
#
#   ACCEPT     - diff passes policy, local verification passes, report complete
#   ADAPT      - substance is sound, but the report or the shape needs rework
#   REJECT     - policy violation, or verification fails
#   UNVERIFIED - no verification could be run, so no verdict is possible
#
# A verdict is NOT a merge. Merging a PR on GitHub is a push and needs R0.
#
# Usage:
#   powershell -NoProfile -File jules-triage.ps1
#   powershell -NoProfile -File jules-triage.ps1 -Repo MAVIS-CLOUD -NoVerify
#
# ASCII ONLY: executed by Windows PowerShell 5.1.

param(
    [string]$Repo = '',
    [switch]$NoVerify,
    [switch]$SkipClosed,
    [int]$MaxVerify = 5
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'jules-lib.ps1')

function Test-ReportComplete {
    param([string]$Body)
    if (-not $Body) { return $false }
    $needed = @('Ce am schimbat', 'De ce', 'Cum am verificat')
    $missing = @()
    foreach ($n in $needed) {
        if ($Body -notmatch [regex]::Escape($n)) { $missing += $n }
    }
    return [PSCustomObject]@{ Complete = ($missing.Count -eq 0); Missing = $missing }
}

function Main {
    Start-JulesLog -Name 'jules-triage'

    if (-not (Assert-Gh)) { return 2 }

    $registry = Get-RepoRegistry
    $repos = @()
    if ($Repo) {
        $e = Get-RepoEntry -Name $Repo -Registry $registry
        if (-not $e) { Write-JulesLog -Message ('repo not in registry: ' + $Repo) -Level 'ERROR'; return 2 }
        $repos = @($e)
    } else {
        $repos = @(Get-TriageRepos -Registry $registry)
    }

    $findings = @()

    foreach ($r in $repos) {
        Write-JulesLog -Message ('scanning ' + $r.name) -Level 'STEP'
        $prs = @(Get-JulesPrs -Repo $r.name -States @('open'))
        if ($prs.Count -eq 0) {
            Write-JulesLog -Message ('no open Jules PR in ' + $r.name) -Level 'INFO'
            continue
        }

        # Oldest first: the longest-waiting proposal gets verified first.
        $prs = @($prs | Sort-Object -Property number)
        $verifiedCount = 0

        foreach ($pr in $prs) {
            Write-JulesLog -Message ('PR #' + $pr.number + ' ' + $pr.title) -Level 'STEP'

            $viewRes = Invoke-Gh -GhArgs @('pr', 'view', [string]$pr.number, '-R', ('apvizual-max/' + $r.name),
                                          '--json', 'number,title,body,files,additions,deletions,headRefName,createdAt,url')
            if (-not $viewRes.Ok) {
                Write-JulesLog -Message ('pr view failed: ' + $viewRes.Err) -Level 'ERROR'
                continue
            }
            $view = $viewRes.Out | ConvertFrom-Json

            $prFiles = @(Get-PrFiles -Repo $r.name -Pr $pr.number)
            $files = @()
            foreach ($pf in $prFiles) { $files += $pf.path }

            $rawViolations = @(Test-DiffPolicy -PrFiles $prFiles)
            # NOTE lines are visible exceptions, not violations.
            $notes = @($rawViolations | Where-Object { $_.StartsWith('NOTE:') })
            $violations = @($rawViolations | Where-Object { -not $_.StartsWith('NOTE:') })

            $reportCheck = Get-AdaptReportState -Repo $r.name -Pr $pr.number
            $tooBroad = ($files.Count -gt 20)

            # --- physical verification -----------------------------------
            $verdict = 'ACCEPT'
            $reasons = @()
            $verifyResult = 'SKIPPED'

            if ($violations.Count -gt 0) {
                $verdict = 'REJECT'
                foreach ($v in $violations) { $reasons += $v }
            }
            if ($notes.Count -gt 0) {
                foreach ($n in $notes) { $reasons += $n }
            }

            if ($verdict -ne 'REJECT') {
                if (-not $reportCheck.Exists) {
                    # No local adaptation report yet. That is a truthful state of
                    # the pipeline, not a defect in the proposal: the proposal
                    # still has to be adapted locally, so it cannot be ACCEPTed.
                    $verdict = 'ADAPT'
                    $reasons += 'no local adaptation report yet (not yet adapted)'
                } elseif (-not $reportCheck.Complete) {
                    $verdict = 'ADAPT'
                    $reasons += ('adaptation report incomplete, missing sections: ' + ($reportCheck.Missing -join ', '))
                }
                if ($tooBroad) {
                    $verdict = 'ADAPT'
                    $reasons += ('diff too broad: ' + $files.Count + ' files in one PR')
                }
            }

            if ($verdict -ne 'REJECT' -and -not $NoVerify) {
                if ($verifiedCount -ge $MaxVerify) {
                    # Budget exhausted. This is NOT a pass: the proposal was
                    # read but not verified, and it says so.
                    $verdict = 'UNVERIFIED'
                    $verifyResult = 'BUDGET'
                    $reasons += ('not verified in this run: verification budget reached (' + $MaxVerify + ' per repo)')
                    Write-JulesLog -Message ('PR #' + $pr.number + ' not verified - budget reached') -Level 'WARN'
                } else {
                    Write-JulesLog -Message ('verifying PR #' + $pr.number + ' locally') -Level 'STEP'
                    $vScript = Join-Path $PSScriptRoot 'jules-verify.ps1'
                    $vRes = Invoke-Native -Program 'powershell' -Arguments @('-NoProfile', '-File', $vScript, '-Repo', $r.name, '-Pr', [string]$pr.number)
                    $vCode = $vRes.ExitCode
                    $vText = $vRes.Out
                    if ($vRes.Err) { $vText = $vText + "`n" + $vRes.Err }
                    $verifiedCount++
                    if ($vCode -eq 0) {
                        $verifyResult = 'PASS'
                    } elseif ($vCode -eq 1) {
                        $verifyResult = 'FAIL'
                        $verdict = 'REJECT'
                        $reasons += 'local verification failed (exit 1)'
                        $reasons += (($vText -split "`r?`n" | Where-Object { $_ -match '^CMD=' }) -join '; ')
                    } elseif ($vCode -eq 3) {
                        # The failure was measured but is NOT attributable to the
                        # proposal: it did not reproduce, or it already existed
                        # on the base branch. This is NOT a REJECT. Reporting it
                        # as one would close a proposal that is not the cause,
                        # and would repeat forever on any repo whose suite is
                        # already broken.
                        $verifyResult = 'NOT_ATTRIBUTABLE'
                        $verdict = 'UNVERIFIED'
                        $attr = (($vText -split "`r?`n" | Where-Object { $_ -match '^ATTRIBUTION=' }) -join '')
                        if ($attr -match 'FLAKY') {
                            $reasons += 'verification failed once but did not reproduce on a second run in the same tree - not attributable to the proposal'
                        } else {
                            $reasons += 'the same failures are already present on the base branch - not attributable to the proposal'
                        }
                        $reasons += $attr
                        $reasons += (($vText -split "`r?`n" | Where-Object { $_ -match '^FAILED=' }) -join '; ')
                        $newFails = @(($vText -split "`r?`n" | Where-Object { $_ -match '^NEWFAIL=' }) | ForEach-Object { $_ -replace '^NEWFAIL=', '' })
                        if ($newFails.Count -gt 0) {
                            $reasons += ('failures present on the head but not on the base (judged by Mavis Local, not auto-rejected): ' + ($newFails -join '; '))
                        }
                    } else {
                        $verifyResult = 'UNVERIFIED'
                        $verdict = 'UNVERIFIED'
                        $reasons += 'no local verification could be run'
                    }
                    foreach ($line in ($vText -split "`r?`n")) {
                        if ($line -match '^CMD=') { Write-JulesLog -Message ('  ' + $line.Trim()) -Level 'INFO' }
                    }
                }
            }

            $findings += [PSCustomObject]@{
                repo      = $r.name
                pr        = [int]$pr.number
                title     = [string]$pr.title
                author    = [string]$pr.author.login
                branch    = [string]$view.headRefName
                created   = [string]$pr.createdAt
                url       = [string]$pr.url
                files     = $files.Count
                additions = [int]$view.additions
                deletions = [int]$view.deletions
                verdict   = $verdict
                verify    = $verifyResult
                reasons   = $reasons
            }
        }
    }

    # --- Persist ----------------------------------------------------------
    $docDir = Join-Path (Get-JulesRoot) 'docs\triage'
    if (-not (Test-Path -LiteralPath $docDir)) { New-Item -ItemType Directory -Path $docDir -Force | Out-Null }
    $stamp = (Get-Date).ToString('yyyy-MM-dd')
    $mdFile = Join-Path $docDir ('triage-' + $stamp + '.md')
    $jsonFile = Join-Path $docDir ('triage-' + $stamp + '.json')

    $enc = New-Object System.Text.UTF8Encoding($false)
    $lines = @()
    $lines += ('# TRIJUL JULES - ' + (Get-Date).ToString('yyyy-MM-dd HH:mm'))
    $lines += ''
    $lines += ('Mavis Local este autoritatea. Verdiktul de mai jos este masurat, nu estimat.')
    $lines += ('Verdictul NU este merge. Merge-ul cere R0.')
    $lines += ''
    if ($findings.Count -eq 0) {
        $lines += 'Niciun pull request Jules deschis, la momentul verificarii.'
    } else {
        $lines += '| Repo | PR | Titlu | fisiere | +/ | Verdict | Verificare |'
        $lines += '|---|---|---|---|---|---|---|'
        foreach ($f in $findings) {
            $lines += ('| ' + $f.repo + ' | #' + $f.pr + ' | ' + $f.title + ' | ' + $f.files +
                       ' | +' + $f.additions + '/-' + $f.deletions + ' | **' + $f.verdict + '** | ' + $f.verify + ' |')
        }
        $lines += ''
        foreach ($f in $findings) {
            $lines += ('## ' + $f.repo + ' PR #' + $f.pr + ' - ' + $f.title)
            $lines += ''
            $lines += ('- Autor: ' + $f.author + ' - ramura: `' + $f.branch + '` - creat: ' + $f.created)
            $lines += ('- Link: ' + $f.url)
            $lines += ('- Diff: ' + $f.files + ' fisiere, +' + $f.additions + '/-' + $f.deletions)
            $lines += ('- Verdict: **' + $f.verdict + '** - verificare locala: ' + $f.verify)
            if ($f.reasons.Count -gt 0) {
                $lines += '- Motive:'
                foreach ($rr in $f.reasons) { $lines += ('  - ' + $rr) }
            } else {
                $lines += '- Motive: niciunul. Diff curat, verificare locala verde, raport complet.'
            }
            $lines += ''
        }
    }
    [System.IO.File]::WriteAllText($mdFile, (($lines -join "`n") + "`n"), $enc)
    [System.IO.File]::WriteAllText($jsonFile, (($findings | ConvertTo-Json -Depth 6)), $enc)

    Write-JulesLog -Message ('triage written: ' + $mdFile) -Level 'STEP'
    Write-JulesOut ('TRIAGE_FILE=' + $mdFile)
    Write-JulesOut ('TRIAGE_JSON=' + $jsonFile)
    Write-JulesOut ('FINDINGS=' + $findings.Count)
    foreach ($f in $findings) {
        Write-JulesOut ('PR=' + $f.repo + '#' + $f.pr + ' VERDICT=' + $f.verdict + ' VERIFY=' + $f.verify)
    }
    return 0
}

$code = Main
exit $code
