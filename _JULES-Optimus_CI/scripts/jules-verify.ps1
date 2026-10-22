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

    # The clone must be COMPLETE before anything is measured in it.
    # Measured: a clone made without long paths holds 14 of 701 tracked
    # files, and a verdict produced in that tree describes 14 files while
    # claiming to describe 701.
    $integrity = Test-CloneIntegrity -Dir $dir
    if (-not $integrity.Ok) {
        Write-JulesLog -Message ('clone is incomplete: ' + $integrity.Reason) -Level 'ERROR'
        Write-JulesOut 'RESULT=INCOMPLETE_CLONE'
        Write-JulesOut ('REASON=' + $integrity.Reason)
        Write-JulesOut ('REPO=' + $Repo)
        Write-JulesOut ('PR=' + $Pr)
        return 2
    }
    Write-JulesLog -Message ('clone integrity: ' + $integrity.Tracked + ' tracked files, all present') -Level 'STEP'

    $branchUsed = $entry.branch

    if ($Pr -gt 0 -and -not $NoCheckout) {
        Write-JulesLog -Message ('checking out PR #' + $Pr) -Level 'STEP'
        # The checkout runs in an EXPLICIT directory. `gh pr checkout` acts
        # on the repository in the current directory and exits 0 even when
        # that repository is not the one named by --repo.
        $co = Invoke-Gh -GhArgs @('pr', 'checkout', [string]$Pr, '--repo', ('apvizual-max/' + $Repo), '--force') -WorkingDirectory $dir
        if (-not $co.Ok) {
            Write-JulesLog -Message ('pr checkout failed: ' + $co.Err) -Level 'ERROR'
            Write-JulesOut 'RESULT=NO_CHECKOUT'
            Write-JulesOut ('REPO=' + $Repo)
            Write-JulesOut ('PR=' + $Pr)
            return 2
        }
        # Verify where the checkout landed, against the branch the API
        # names. A checkout that reports success on the wrong branch turns
        # a missing test file into a FALSE REJECT.
        $expectedRef = ''
        $prRes = Invoke-Gh -GhArgs @('api', ('repos/apvizual-max/' + $Repo + '/pulls/' + $Pr))
        if ($prRes.Ok) {
            $prArr = @(ConvertFrom-JulesJson -Json $prRes.Out)
            if ($prArr.Count -ge 1) {
                $head = $prArr[0].PSObject.Properties['head']
                if ($head) {
                    $refProp = $head.Value.PSObject.Properties['ref']
                    if ($refProp) { $expectedRef = [string]$refProp.Value }
                }
            }
        }
        $ownPaths = @()
        foreach ($f in @(Get-PrFiles -Repo $Repo -Pr $Pr)) {
            $ownPaths += [string]$f.path
        }
        $checkout = Test-CheckoutTarget -Dir $dir -ExpectedRef $expectedRef -OwnPaths $ownPaths
        if (-not $checkout.Ok) {
            Write-JulesLog -Message ('checkout not verified: ' + $checkout.Reason) -Level 'ERROR'
            Write-JulesOut 'RESULT=NO_CHECKOUT'
            Write-JulesOut ('REASON=' + $checkout.Reason)
            Write-JulesOut ('REPO=' + $Repo)
            Write-JulesOut ('PR=' + $Pr)
            return 2
        }
        $branchUsed = $checkout.Branch
        Write-JulesLog -Message ('checked out branch: ' + $branchUsed + ' (verified)') -Level 'STEP'
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
        Write-JulesOut 'RESULT=NO_VERIFICATION'
        Write-JulesOut ('REPO=' + $Repo)
        return 2
    }

    if ($DetectOnly) {
        Write-JulesOut 'RESULT=DETECT_ONLY'
        Write-JulesOut ('REPO=' + $Repo)
        Write-JulesOut ('COMMANDS=' + ($cmds -join ' ;; '))
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

    Write-JulesOut ('RESULT=' + $(if ($final -eq 0) { 'PASS' } elseif ($final -eq 1) { 'FAIL' } else { 'NO_MEASUREMENT' }))
    Write-JulesOut ('REPO=' + $Repo)
    Write-JulesOut ('PR=' + $Pr)
    Write-JulesOut ('BRANCH=' + $branchUsed)
    Write-JulesOut ('FILE=' + $outFile)
    foreach ($r in $results) {
        Write-JulesOut ('CMD=' + $r.command + ' EXIT=' + $r.exitCode + ' TOOLMISSING=' + $r.toolMissing)
    }
    return $final
}

$code = Main
exit $code
