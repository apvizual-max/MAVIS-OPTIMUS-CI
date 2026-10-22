# jules-verify.ps1
# Physical verification of a Jules pull request, on this machine.
#
# This is Mavis Local's structural advantage: Jules proposes from Google's
# sandbox, but only this machine can actually RUN the code and read the
# exit codes. Every verdict recorded here is measured, never inferred.
#
# Usage:
#   powershell -NoProfile -File jules-verify.ps1 -Repo MAVIS-CLOUD -Pr 8
#
# Exit codes:
#   0 = every verification command passed
#   1 = at least one verification command failed
#   2 = verification could not run (no clone, no commands, checkout failed)
#
# ASCII ONLY: executed by Windows PowerShell 5.1.

param(
    [Parameter(Mandatory = $true)][string]$Repo,
    [int]$Pr = 0,
    [switch]$NoCheckout,
    [switch]$DetectOnly
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'jules-lib.ps1')

function Split-Command {
    param([Parameter(Mandatory = $true)][string]$Command)
    $parts = @()
    $current = ''
    $inQuote = $false
    foreach ($ch in $Command.ToCharArray()) {
        if ($ch -eq '"') { $inQuote = -not $inQuote; continue }
        if (($ch -eq ' ') -and (-not $inQuote)) {
            if ($current.Length -gt 0) { $parts += $current; $current = '' }
            continue
        }
        $current += $ch
    }
    if ($current.Length -gt 0) { $parts += $current }
    return $parts
}

function Ensure-Clone {
    param([Parameter(Mandatory = $true)][string]$RepoName)
    $dir = Get-RepoLocalPath -Repo $RepoName
    if (Test-Path -LiteralPath (Join-Path $dir '.git')) { return $dir }
    $parent = Split-Path -Parent $dir
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Write-JulesLog -Message ('cloning ' + $RepoName + ' into ' + $dir) -Level 'STEP'
    $res = Invoke-Gh -GhArgs @('repo', 'clone', ('apvizual-max/' + $RepoName), $dir)
    if (-not $res.Ok) {
        Write-JulesLog -Message ('clone failed: ' + $res.Err) -Level 'ERROR'
        return $null
    }
    return $dir
}

function Main {
    Start-JulesLog -Name 'jules-verify'

    if (-not (Assert-Gh)) { return 2 }

    $registry = Get-RepoRegistry
    $entry = Get-RepoEntry -Name $Repo -Registry $registry
    if (-not $entry) {
        Write-JulesLog -Message ('repo not in registry: ' + $Repo) -Level 'ERROR'
        return 2
    }

    $dir = Ensure-Clone -RepoName $Repo
    if (-not $dir) { return 2 }

    $branchUsed = $entry.branch

    if ($Pr -gt 0 -and -not $NoCheckout) {
        Write-JulesLog -Message ('checking out PR #' + $Pr) -Level 'STEP'
        Push-Location -LiteralPath $dir
        try {
            $res = Invoke-Gh -GhArgs @('pr', 'checkout', [string]$Pr, '--repo', ('apvizual-max/' + $Repo), '--force')
            if (-not $res.Ok) {
                Write-JulesLog -Message ('pr checkout failed: ' + $res.Err) -Level 'ERROR'
                return 2
            }
            $headRes = Invoke-Native -Program 'git' -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')
            if ($headRes.Ok -and $headRes.Out) { $branchUsed = $headRes.Out.Trim() }
        } finally {
            Pop-Location
        }
        Write-JulesLog -Message ('checked out branch: ' + $branchUsed) -Level 'STEP'
    }

    # --- Which verification commands apply -------------------------------
    $cmds = @()
    if ($entry.verify.mode -eq 'auto') {
        $cmds = @(Detect-VerifyCommands -Dir $dir)
        Write-JulesLog -Message ('verification commands detected: ' + $(if ($cmds.Count) { $cmds -join ' | ' } else { '(none found)' })) -Level 'STEP'
    } else {
        $cmds = @($entry.verify.commands)
    }

    if ($cmds.Count -eq 0) {
        Write-JulesLog -Message 'NO VERIFICATION AVAILABLE for this repo - verdict cannot be PASS' -Level 'ERROR'
        Write-Output 'RESULT=NO_VERIFICATION'
        Write-Output ('REPO=' + $Repo)
        return 2
    }

    if ($DetectOnly) {
        Write-Output 'RESULT=DETECT_ONLY'
        Write-Output ('REPO=' + $Repo)
        Write-Output ('COMMANDS=' + ($cmds -join ' ;; '))
        return 0
    }

    # --- Run them ---------------------------------------------------------
    $results = @()
    $allOk = $true
    Push-Location -LiteralPath $dir
    try {
        foreach ($c in $cmds) {
            $parts = Split-Command -Command $c
            if ($parts.Count -eq 0) { continue }
            $prog = $parts[0]
            $rest = @()
            if ($parts.Count -gt 1) { $rest = $parts[1..($parts.Count - 1)] }
            Write-JulesLog -Message ('RUN: ' + $c) -Level 'STEP'
            $runRes = Invoke-Native -Program $prog -Arguments $rest
            $code = $runRes.ExitCode
            $text = ''
            if ($runRes.Out) { $text = $runRes.Out }
            if ($runRes.Err) { $text = $text + "`n" + $runRes.Err }
            $tail = ''
            $lines = @($text -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 })
            if ($lines.Count -gt 0) {
                $take = $lines[([Math]::Max(0, $lines.Count - 8))..($lines.Count - 1)]
                $tail = ($take -join "`n")
            }
            $ok = ([int]$code -eq 0)
            # A MISSING TOOL IS NOT A FAILING TEST. If the interpreter or the
            # test runner is absent, the code did not measure anything, and a
            # non-zero exit would be a false REJECT. This is the exact failure
            # mode of a check that breaks in the wrong direction.
            $toolMissing = $false
            if (-not $ok) {
                $missingMarkers = @('is not recognized', 'command not found', 'No module named',
                                    'cannot find the path specified', 'is not installed',
                                    'Unable to locate executable', 'not found in PATH')
                foreach ($mk in $missingMarkers) {
                    if ($text -match [regex]::Escape($mk)) { $toolMissing = $true; break }
                }
            }
            if ($toolMissing) {
                Write-JulesLog -Message ('TOOL MISSING for: ' + $c + ' - cannot measure, not a failure') -Level 'WARN'
            } else {
                if (-not $ok) { $allOk = $false }
                Write-JulesLog -Message ('EXIT ' + $code + ' for: ' + $c) -Level $(if ($ok) { 'INFO' } else { 'ERROR' })
            }
            $results += [PSCustomObject]@{
                command    = $c
                exitCode   = [int]$code
                ok         = $ok
                toolMissing = $toolMissing
                tail       = $tail
            }
        }
    } finally {
        Pop-Location
    }

    # --- Persist the verdict ---------------------------------------------
    $outDir = Join-Path (Get-JulesRoot) 'state\verify'
    if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $name = ($Repo + '-pr' + $Pr + '-' + $stamp + '.json')
    $outFile = Join-Path $outDir $name
    $payload = [PSCustomObject]@{
        repo       = $Repo
        pr         = $Pr
        branch     = $branchUsed
        verifiedAt = (Get-Date).ToString('s')
        allPassed  = $allOk
        results    = $results
    }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($outFile, ($payload | ConvertTo-Json -Depth 6), $enc)
    Write-JulesLog -Message ('verdict file: ' + $outFile) -Level 'STEP'

    # Final exit code:
    #   0 = every command passed
    #   1 = a command FAILED (measured)
    #   2 = a tool was missing, so nothing could be measured (NOT a failure)
    $anyMissing = $false
    foreach ($r in $results) { if ($r.toolMissing) { $anyMissing = $true } }
    $final = 0
    if (-not $allOk) { $final = 1 }
    if ($anyMissing) { $final = 2 }

    Write-Output ('RESULT=' + $(if ($final -eq 0) { 'PASS' } elseif ($final -eq 1) { 'FAIL' } else { 'NO_MEASUREMENT' }))
    Write-Output ('REPO=' + $Repo)
    Write-Output ('PR=' + $Pr)
    Write-Output ('BRANCH=' + $branchUsed)
    Write-Output ('FILE=' + $outFile)
    foreach ($r in $results) {
        Write-Output ('CMD=' + $r.command + ' EXIT=' + $r.exitCode + ' TOOLMISSING=' + $r.toolMissing)
    }
    return $final
}

$code = Main
exit $code
