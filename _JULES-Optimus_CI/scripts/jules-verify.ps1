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
#   1 = a command failed, reproducibly, and the failure is not on the base
#   2 = verification could not run (no clone, no commands, checkout failed)
#   3 = the failure did not reproduce, or it already existed on the base
#       (measured, but NOT attributable to the proposal)
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

# Runs the verification command set in a given tree and returns what each
# command measured. Used twice: once for the proposal head, and once for
# the BASE branch when the head fails - so a failure that already existed
# is not charged to the proposal.
#
# Each command is tried through a CHAIN of runners, and the first one
# that actually starts is the one that measures. Measured: pytest is
# not installed on this machine, so `python -m pytest` exits 1 with
# "No module named pytest" - a missing INSTRUMENT, not a failing test.
function Invoke-VerifyCommandSet {
    param(
        [Parameter(Mandatory = $true)][string[]]$Cmds,
        [Parameter(Mandatory = $true)][string]$Dir
    )
    $out = @()
    foreach ($c in $Cmds) {
        $chain = @(Get-JulesRunnerChain -Command $c -Dir $Dir)
        $measured = $false
        foreach ($cand in $chain) {
            $parts = Split-Command -Command $cand
            if ($parts.Count -eq 0) { continue }
            $prog = $parts[0]
            $rest = @()
            if ($parts.Count -gt 1) { $rest = $parts[1..($parts.Count - 1)] }
            Write-JulesLog -Message ('RUN: ' + $cand) -Level 'STEP'
            $runRes = Invoke-Native -Program $prog -Arguments $rest -WorkingDirectory $Dir
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
                Write-JulesLog -Message ('TOOL MISSING for: ' + $cand + ' - trying the next runner') -Level 'WARN'
                continue
            }
            Write-JulesLog -Message ('EXIT ' + $code + ' for: ' + $cand) -Level $(if ($ok) { 'INFO' } else { 'ERROR' })
            $out += [PSCustomObject]@{
                command     = $cand
                exitCode    = [int]$code
                ok          = $ok
                toolMissing = $false
                tail        = $tail
                text        = $text
            }
            $measured = $true
            break
        }
        if (-not $measured) {
            Write-JulesLog -Message ('no runner could launch: ' + $c) -Level 'ERROR'
            $out += [PSCustomObject]@{
                command     = $c
                exitCode    = 127
                ok          = $false
                toolMissing = $true
                tail        = 'no runner could launch this command'
                text        = ''
            }
        }
    }
    return $out
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
    $results = @(Invoke-VerifyCommandSet -Cmds $cmds -Dir $dir)
    $allOk = $true
    $anyMissing = $false
    foreach ($r in $results) {
        if ($r.toolMissing) { $anyMissing = $true; continue }
        if (-not $r.ok) { $allOk = $false }
    }

    # --- Attribution: is the failure the PROPOSAL's, or was it already there?
    #
    # MEASURED on SENTINEL_PRIME PR #3, same commit 6f0a391b in two clones:
    #   work/SENTINEL_PRIME   -> 62 passed / 1 failed / 1 not-run  (EXIT 1)
    #   clean clone            -> 63 passed / 0 failed / 1 not-run  (EXIT 0)
    # The same code, two trees, two different verdicts. A gate whose result
    # flips between identical checkouts is measuring the ENVIRONMENT, not the
    # proposal - and the direction it breaks in is the expensive one: it
    # REJECTS a proposal that is fine.
    #
    # And `test_suite.py` reports 479 passed / 6 failed on the BASE branch as
    # well, identically. Six failures that predate the proposal. Charging
    # them to it would reject every future proposal on that repo, forever.
    #
    # So a proposal may only be blamed for a failure that is
    #   (a) REPRODUCIBLE  - a second run in the same tree fails the same way
    #   (b) NOT PRE-EXISTING - the base branch does not fail the same way
    # Anything else is reported as UNVERIFIED, never as REJECT.
    #
    # The base run happens only after a failure, so the common path costs
    # nothing.
    $attribution = 'ATTRIBUTABLE'
    $baseResults = @()
    $baseRefUsed = ''
    $reproduced = $true
    $headSig = @()
    foreach ($r in $results) {
        if ($r.toolMissing) { continue }
        if (-not $r.ok) { $headSig += @(Get-JulesFailureSignature -Text $r.text) }
    }

    if (-not $allOk -and -not $anyMissing -and $headSig.Count -gt 0) {
        # (a) reproducibility: run the same commands again, in the same tree
        Write-JulesLog -Message 're-running the failed commands to test reproducibility' -Level 'STEP'
        $second = @(Invoke-VerifyCommandSet -Cmds $cmds -Dir $dir)
        $secondOk = $true
        $secondSig = @()
        foreach ($r in $second) {
            if ($r.toolMissing) { continue }
            if (-not $r.ok) { $secondOk = $false; $secondSig += @(Get-JulesFailureSignature -Text $r.text) }
        }
        if ($secondOk) {
            $reproduced = $false
            $attribution = 'FLAKY'
            Write-JulesLog -Message 'the failure did not reproduce on a second run in the same tree' -Level 'WARN'
        } else {
            # (b) pre-existing: run the same commands on the base branch
            $baseRef = 'origin/main'
            $baseExists = Invoke-Native -Program 'git' -Arguments @('rev-parse', '--verify', $baseRef) -WorkingDirectory $dir
            if ($baseExists.Ok) {
                Write-JulesLog -Message ('running the same commands on the base ref ' + $baseRef) -Level 'STEP'
                $null = Invoke-Native -Program 'git' -Arguments @('checkout', '--', '.') -WorkingDirectory $dir
                $toBase = Invoke-Native -Program 'git' -Arguments @('checkout', $baseRef) -WorkingDirectory $dir
                if ($toBase.Ok) {
                    $baseRefUsed = $baseRef
                    $baseResults = @(Invoke-VerifyCommandSet -Cmds $cmds -Dir $dir)
                    $null = Invoke-Native -Program 'git' -Arguments @('checkout', '--', '.') -WorkingDirectory $dir
                    $back = Invoke-Native -Program 'git' -Arguments @('checkout', $branchUsed) -WorkingDirectory $dir
                    if (-not $back.Ok) {
                        Write-JulesLog -Message ('could not restore the proposal branch: ' + $back.Err) -Level 'ERROR'
                    }
                    $basePassed = $true
                    $baseSig = @()
                    foreach ($r in $baseResults) {
                        if ($r.toolMissing) { $basePassed = $false; continue }
                        if (-not $r.ok) { $basePassed = $false; $baseSig += @(Get-JulesFailureSignature -Text $r.text) }
                    }
                    $attribution = Compare-JulesFailureSets -Head $headSig -Base $baseSig -BasePassed $basePassed
                    Write-JulesLog -Message ('attribution: ' + $attribution) -Level 'STEP'
                }
            }
        }
    }

    # --- Persist the verdict ---------------------------------------------
    $outDir = Join-Path (Get-JulesRoot) 'state\verify'
    if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $name = ($Repo + '-pr' + $Pr + '-' + $stamp + '.json')
    $outFile = Join-Path $outDir $name

    # Final exit code:
    #   0 = every command passed
    #   1 = a command FAILED, reproducibly, and the failure is not on the base
    #   2 = a tool was missing, so nothing could be measured (NOT a failure)
    #   3 = the failure did not reproduce, or it already existed on the base
    #       (NOT attributable to the proposal - reported, never blamed)
    $final = 0
    if (-not $allOk) { $final = 1 }
    if ($anyMissing) { $final = 2 }
    $verdictLabel = 'PASS'
    if ($final -eq 1) { $verdictLabel = 'FAIL' }
    elseif ($final -eq 2) { $verdictLabel = 'NO_MEASUREMENT' }
    if ($final -eq 1 -and $attribution -ne 'ATTRIBUTABLE') {
        $final = 3
        $verdictLabel = 'NOT_ATTRIBUTABLE'
    }

    $payload = [PSCustomObject]@{
        repo         = $Repo
        pr           = $Pr
        branch       = $branchUsed
        verifiedAt   = (Get-Date).ToString('s')
        allPassed    = $allOk
        attribution  = $attribution
        reproduced   = $reproduced
        baseRef      = $baseRefUsed
        headFailures = @($headSig)
        results      = $results
        baseResults  = $baseResults
    }
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($outFile, ($payload | ConvertTo-Json -Depth 6), $enc)
    Write-JulesLog -Message ('verdict file: ' + $outFile) -Level 'STEP'

    Write-JulesOut ('RESULT=' + $verdictLabel)
    Write-JulesOut ('REPO=' + $Repo)
    Write-JulesOut ('PR=' + $Pr)
    Write-JulesOut ('BRANCH=' + $branchUsed)
    Write-JulesOut ('ATTRIBUTION=' + $attribution)
    Write-JulesOut ('FILE=' + $outFile)
    foreach ($r in $results) {
        Write-JulesOut ('CMD=' + $r.command + ' EXIT=' + $r.exitCode + ' TOOLMISSING=' + $r.toolMissing)
    }
    foreach ($f in @($headSig)) { Write-JulesOut ('FAILED=' + $f) }
    if ($baseResults.Count -gt 0) {
        $basePassed = $true
        $baseSig = @()
        foreach ($r in $baseResults) {
            if ($r.toolMissing) { $basePassed = $false; continue }
            if (-not $r.ok) { $basePassed = $false; $baseSig += @(Get-JulesFailureSignature -Text $r.text) }
        }
        foreach ($f in @($headSig | Where-Object { $baseSig -notcontains $_ })) { Write-JulesOut ('NEWFAIL=' + $f) }
    }
    return $final
}

$code = Main
exit $code
