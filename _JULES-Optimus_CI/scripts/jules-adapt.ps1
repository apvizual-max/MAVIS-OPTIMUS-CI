# jules-adapt.ps1
# Turns a Jules pull request into an ACCEPTABLE pull request.
#
# Mavis Local is the sovereign authority: Jules proposes, Local corrects.
# A proposal is acceptable when it has ONE objective, a test that fails before
# and passes after, measured numbers, and the canonical report format.
#
# This script does the MEASUREMENT half. It never invents the judgment half:
#
#   Ce am schimbat          <- built from the real diff (GitHub API)
#   Cum am verificat        <- built from commands actually run on this machine
#   De ce                   <- left for Mavis Local
#   Ce NU am facut si de ce <- left for Mavis Local
#   Riscuri                 <- left for Mavis Local
#
# A proposal is also checked against the OTHER open pull requests, because two
# proposals that touch the same file cannot both be merged. That is a fact
# about the repository, not a judgment, so it is measured too.
#
# Usage:
#   powershell -NoProfile -File jules-adapt.ps1 -Repo MAVIS-CLOUD -Pr 9
#
# Exit codes:
#   0 = the adaptation report was written
#   1 = the proposal could not be measured (no diff, no clone, checkout failed)
#   2 = the verification failed - this is a REJECT candidate, not an adaptation
#
# ASCII ONLY: executed by Windows PowerShell 5.1.

param(
    [Parameter(Mandatory = $true)][string]$Repo,
    [Parameter(Mandatory = $true)][int]$Pr,
    [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'jules-lib.ps1')

# Splits a command into program and arguments, honouring double quotes.
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

# Runs ONE command inside a given directory and returns a measurement record.
#
# The working directory is explicit, never inherited: a command that
# resolves relative paths must not silently run somewhere else.
#
# "toolMissing" means the INSTRUMENT did not start (python without pytest,
# node without a test runner). That is NOT a failing test. Conflating the
# two is how a good proposal gets rejected for a missing dependency.
function Invoke-MeasureCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string]$Dir
    )
    $parts = Split-Command -Command $Command
    if ($parts.Count -eq 0) { return $null }
    $prog = $parts[0]
    $rest = @()
    if ($parts.Count -gt 1) { $rest = $parts[1..($parts.Count - 1)] }
    $r = Invoke-Native -Program $prog -Arguments $rest -WorkingDirectory $Dir
    $text = ''
    if ($r.Out) { $text = $r.Out }
    if ($r.Err) { $text = $text + "`n" + $r.Err }
    $tail = ''
    $lines = @($text -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 })
    if ($lines.Count -gt 0) {
        $take = $lines[([Math]::Max(0, $lines.Count - 12))..($lines.Count - 1)]
        $tail = ($take -join "`n")
    }
    $toolMissing = $false
    if ([int]$r.ExitCode -ne 0) {
        $markers = @('is not recognized', 'command not found', 'No module named',
                     'cannot find the path specified', 'is not installed',
                     'Unable to locate executable', 'not found in PATH')
        foreach ($mk in $markers) {
            if ($text -match [regex]::Escape($mk)) { $toolMissing = $true; break }
        }
    }
    return [PSCustomObject]@{
        command     = $Command
        exitCode    = [int]$r.ExitCode
        toolMissing = $toolMissing
        tail        = $tail
    }
}

# The open pull requests of a repo that touch a given file.
function Get-ConflictingPrs {
    param(
        [Parameter(Mandatory = $true)][string]$RepoName,
        [Parameter(Mandatory = $true)][string[]]$Paths,
        [Parameter(Mandatory = $true)][int]$Exclude
    )
    $hits = @()
    if ($Paths.Count -eq 0) { return $hits }
    # The REST endpoint is used, not `gh pr list --json number`: that one
    # returns a JSON ARRAY OF NUMBERS, and reading `.number` off a scalar
    # yields nothing - the conflict scan then silently compares against PR
    # number 0 and reports no conflict at all.
    $res = Invoke-Gh -GhArgs @('api', ('repos/apvizual-max/' + $RepoName + '/pulls?state=open&per_page=100'))
    if (-not $res.Ok) { return $hits }
    $prs = @()
    # ConvertFrom-JulesJson, not a raw `@($res.Out | ConvertFrom-Json)`:
    # on PowerShell 5.1 that raw form collapses a top-level JSON array to
    # ONE element, so every pull request failed the type check and this
    # scan reported "0 open PR examined" while the API was working.
    # Measured: 34 pull requests in, 1 element out.
    try { $prs = @(ConvertFrom-JulesJson -Json $res.Out) } catch { return $hits }
    $seen = 0
    foreach ($p in $prs) {
        if ($p -isnot [PSCustomObject]) { continue }
        if (-not $p.PSObject.Properties['number']) { continue }
        $n = [int]$p.number
        $seen++
        if ($n -eq $Exclude) { continue }
        $fRes = Invoke-Gh -GhArgs @('api', ('repos/apvizual-max/' + $RepoName + '/pulls/' + $n + '/files?per_page=100'))
        if (-not $fRes.Ok) { continue }
        $arr = @()
        try { $arr = @(ConvertFrom-JulesJson -Json $fRes.Out) } catch { continue }
        foreach ($f in $arr) {
            if (-not $f.PSObject.Properties['filename']) { continue }
            $fn = [string]$f.filename
            if ($Paths -contains $fn) {
                $hits += [PSCustomObject]@{ Pr = $n; Path = $fn }
                break
            }
        }
    }
    Write-JulesLog -Message ('conflict scan: ' + $seen + ' open PR examined, ' + $hits.Count + ' overlapping file(s)') -Level 'STEP'
    return $hits
}

function Main {
    $registry = Get-RepoRegistry
    $entry = Get-RepoEntry -Name $Repo -Registry $registry
    if (-not $entry) {
        Write-JulesLog -Message ('repo not in registry: ' + $Repo) -Level 'ERROR'
        return 1
    }

    $files = @(Get-PrFiles -Repo $Repo -Pr $Pr)
    if ($files.Count -eq 0) {
        Write-JulesLog -Message ('no diff read for ' + $Repo + ' PR ' + $Pr) -Level 'ERROR'
        Write-JulesOut 'RESULT=NO_DIFF'
        return 1
    }

    $paths = @()
    foreach ($f in $files) { $paths += [string]$f.path }

    # --- Commands ---------------------------------------------------------
    # The baseline the repo declares, plus a command that exercises the tests
    # THIS pull request adds. Without the second one, a proposal that adds
    # tests is "verified" by a test suite that never runs its own new code.
    $ownSpecs = @()
    $ownTestPaths = @()
    foreach ($f in $files) {
        $p = [string]$f.path
        if ($p -match '\.test\.js$') {
            $ownTestPaths += $p
            $ownSpecs += [PSCustomObject]@{ Path = $p; Candidates = @(('node --test "' + $p + '"')) }
        } elseif ($p -match '(^|/)(test_[^/]+\.py|[^/]+_test\.py)$') {
            $ownTestPaths += $p
            $cands = @(('python -m pytest "' + $p + '"'))
            # The standard library fallback is added ONLY when the file
            # really has a runner entry point. A pytest-style file invoked
            # directly exits 0 having run NOTHING - a false pass, which is
            # worse than no measurement at all.
            $abs = Join-Path $dir ($p.Replace('/', '\'))
            if (Test-JulesStdlibRunnable -Path $abs) {
                $cands += ('python "' + $p + '"')
            }
            $ownSpecs += [PSCustomObject]@{
                Path       = $p
                Candidates = $cands
            }
        }
    }

    # --- The branch this pull request actually points to --------------------
    # Read from the API, not assumed. The checkout is verified against it
    # afterwards, because a checkout that lands on the wrong branch turns a
    # missing test file into a FALSE REJECT.
    $expectedRef = ''
    $expectedSha = ''
    $prRes = Invoke-Gh -GhArgs @('api', ('repos/apvizual-max/' + $Repo + '/pulls/' + $Pr))
    if ($prRes.Ok) {
        $prArr = @(ConvertFrom-JulesJson -Json $prRes.Out)
        if ($prArr.Count -ge 1) {
            $head = $prArr[0].PSObject.Properties['head']
            if ($head) {
                $refProp = $head.Value.PSObject.Properties['ref']
                if ($refProp) { $expectedRef = [string]$refProp.Value }
                $shaProp = $head.Value.PSObject.Properties['sha']
                if ($shaProp) { $expectedSha = [string]$shaProp.Value }
            }
        }
    }
    if (-not $expectedRef) {
        Write-JulesLog -Message ('cannot read the head branch of ' + $Repo + ' PR ' + $Pr) -Level 'ERROR'
        Write-JulesOut 'RESULT=NO_HEAD_REF'
        return 1
    }

    # --- Clone and checkout ----------------------------------------------
    $dir = Get-RepoLocalPath -Repo $Repo
    if (-not (Test-Path -LiteralPath (Join-Path $dir '.git'))) {
        $parent = Split-Path -Parent $dir
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        $clone = Invoke-Native -Program 'gh' -Arguments @('repo', 'clone', ('apvizual-max/' + $Repo), $dir)
        if (-not $clone.Ok) {
            Write-JulesLog -Message ('clone failed: ' + $clone.Err) -Level 'ERROR'
            Write-JulesOut 'RESULT=NO_CLONE'
            return 1
        }
    }

    # The clone must be a clone OF THIS REPO. A directory that happens to
    # be a git repository is not enough.
    $originRes = Invoke-Native -Program 'git' -Arguments @('-C', $dir, 'remote', 'get-url', 'origin')
    if ($originRes.Ok) {
        if ($originRes.Out -notmatch [regex]::Escape($Repo)) {
            Write-JulesLog -Message ('clone origin does not match ' + $Repo + ': ' + $originRes.Out.Trim()) -Level 'ERROR'
            Write-JulesOut 'RESULT=WRONG_CLONE'
            return 1
        }
    }

    # The clone must be COMPLETE before anything is measured in it.
    # Measured: a clone made without long paths holds 14 of 701 tracked
    # files, and a verdict produced in that tree describes 14 files while
    # claiming to describe 701.
    $integrity = Test-CloneIntegrity -Dir $dir
    if (-not $integrity.Ok) {
        Write-JulesLog -Message ('clone is incomplete: ' + $integrity.Reason) -Level 'ERROR'
        Write-JulesOut 'RESULT=INCOMPLETE_CLONE'
        Write-JulesOut ('REASON=' + $integrity.Reason)
        return 1
    }
    Write-JulesLog -Message ('clone integrity: ' + $integrity.Tracked + ' tracked files, all present') -Level 'STEP'

    # A verification clone must measure the pull request's CODE, not a
    # locally modified tree. The repositories' own scripts append to log
    # files, so a previous run leaves the clone dirty. Measured: two
    # `decisions.jsonl` files in OPTIMUS-Backbone.
    $dirty = Invoke-Native -Program 'git' -Arguments @('-C', $dir, 'status', '--porcelain')
    if ($dirty.Ok -and $dirty.Out.Trim().Length -gt 0) {
        $restore = Invoke-Native -Program 'git' -Arguments @('-C', $dir, 'checkout', '--', '.')
        if ($restore.Ok) {
            Write-JulesLog -Message 'clone had local modifications; restored to HEAD before measuring' -Level 'STEP'
        } else {
            Write-JulesLog -Message ('clone is dirty and could not be restored: ' + $restore.Err) -Level 'WARN'
        }
    }

    # The checkout runs WITH AN EXPLICIT WORKING DIRECTORY.
    #
    # MEASURED on this machine: `gh pr checkout <n> -R <repo>` acts on the
    # repository in the CURRENT directory and exits 0 even when that
    # repository is not the one named by -R. It created the pull
    # request's branch inside an unrelated clone, reported success, and
    # the clone stayed on an older branch - which turned a missing test
    # file into a FALSE REJECT.
    $co = Invoke-Native -Program 'gh' -Arguments @('pr', 'checkout', [string]$Pr, '-R', ('apvizual-max/' + $Repo)) -WorkingDirectory $dir
    if (-not $co.Ok) {
        Write-JulesLog -Message ('checkout failed: ' + $co.Err) -Level 'ERROR'
        Write-JulesOut 'RESULT=NO_CHECKOUT'
        Write-JulesOut ('REASON=' + $co.Err.Trim())
        return 1
    }

    # Verify WHERE the checkout landed. A checkout that reports success but
    # sits on the wrong branch, or on a branch where the pull request's own
    # test file does not exist, is a MEASUREMENT FAILURE - never a verdict
    # on the proposal.
    $checkout = Test-CheckoutTarget -Dir $dir -ExpectedRef $expectedRef -ExpectedSha $expectedSha -OwnPaths $ownTestPaths
    $branch = $checkout.Branch
    if (-not $checkout.Ok) {
        Write-JulesLog -Message ('checkout not verified: ' + $checkout.Reason) -Level 'ERROR'
        Write-JulesOut 'RESULT=NO_CHECKOUT'
        Write-JulesOut ('REASON=' + $checkout.Reason)
        Write-JulesOut ('BRANCH=' + $branch)
        Write-JulesOut ('EXPECTED_REF=' + $expectedRef)
        return 1
    }

    # --- The baseline commands ---------------------------------------------
    # What the repo DECLARES. If it declares nothing, the commands are
    # DETECTED from the repository itself - never invented. The registry
    # declares nothing for OPTIMUS-Backbone, yet that repository has its own
    # test suite, and without this the proposal would be judged with zero
    # measurements and no verdict at all.
    $cmds = @()
    if ($entry.verify.commands) { $cmds += @($entry.verify.commands) }
    if ($cmds.Count -eq 0) {
        $detected = @(Detect-VerifyCommands -Dir $dir)
        foreach ($d in $detected) {
            $own = $false
            foreach ($spec in $ownSpecs) {
                foreach ($cand in $spec.Candidates) {
                    if ($cand -eq $d) { $own = $true }
                }
            }
            if (-not $own) { $cmds += $d }
        }
        if ($cmds.Count -gt 0) {
            Write-JulesLog -Message ('baseline detected from the repository: ' + ($cmds -join ' | ')) -Level 'STEP'
        }
    }

    # --- Run the commands -------------------------------------------------
    $runs = @()
    $failed = $false
    $unmeasured = 0

    foreach ($c in $cmds) {
        $r = Invoke-MeasureCommand -Command $c -Dir $dir
        if (-not $r) { continue }
        if (-not $r.toolMissing -and [int]$r.exitCode -ne 0) { $failed = $true }
        $runs += $r
    }

    # The tests THIS pull request adds, each through its runner chain: the
    # first runner that actually starts is the one that measures.
    #
    # MEASURED on this machine: pytest is not installed, so `python -m
    # pytest` exits 1 with "No module named pytest" - a missing INSTRUMENT,
    # not a failing test. The test file is plain unittest with a
    # `unittest.main()` block, so the standard library runner measures it
    # without installing anything.
    foreach ($spec in $ownSpecs) {
        $measured = $false
        $tried = @()
        foreach ($cand in $spec.Candidates) {
            $r = Invoke-MeasureCommand -Command $cand -Dir $dir
            if (-not $r) { continue }
            $tried += $cand
            if ($r.toolMissing) { continue }
            if ([int]$r.exitCode -ne 0) { $failed = $true }
            $runs += $r
            $measured = $true
            break
        }
        if (-not $measured) {
            $unmeasured++
            $runs += [PSCustomObject]@{
                command     = $spec.Candidates[0]
                exitCode    = 127
                toolMissing = $true
                tail        = ('no runner could launch it; tried: ' + ($tried -join ' | '))
            }
        }
    }

    # No command ran at all: there is no measurement, so there is no verdict.
    if ($runs.Count -eq 0) { $unmeasured = 1 }

    # --- Conflicts --------------------------------------------------------
    $conflicts = @(Get-ConflictingPrs -RepoName $Repo -Paths $paths -Exclude $Pr)

    # --- Write the report -------------------------------------------------
    if (-not $OutDir) { $OutDir = Split-Path -Parent (Get-AdaptReportPath -Repo $Repo -Pr $Pr) }
    if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
    $outFile = Get-AdaptReportPath -Repo $Repo -Pr $Pr

    $L = @()
    $L += ('# JULES ' + $Repo + ' #' + $Pr)
    $L += ''
    $L += ('Ramura: `' + $branch + '` - masurat pe aceasta masina: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
    $L += ''
    $L += '## Ce am schimbat'
    $L += ''
    foreach ($f in $files) {
        $p = [string]$f.path
        $first = ''
        foreach ($ln in @($f.added)) {
            $t = $ln.TrimStart('+').Trim()
            if ($t.Length -eq 0) { continue }
            if ($t.StartsWith('+++')) { continue }
            $first = $t
            break
        }
        if ($first.Length -gt 96) { $first = $first.Substring(0, 96) + '...' }
        $L += ('- `' + $p + '` (+' + $f.additions + '/-' + $f.deletions + ') - ' + $first)
    }
    $L += ''
    $L += '## De ce'
    $L += ''
    $L += '<!-- MAVIS-LOCAL: motivul, cu referire la issue-ul initial -->'
    $L += ''
    $L += '## Cum am verificat'
    $L += ''
    if ($runs.Count -eq 0) {
        $L += '- FARA MASURATOARE: nicio comanda de verificare nu a putut rula. Nu e ACCEPT.'
    } else {
        foreach ($r in $runs) {
            $L += ('### `' + $r.command + '`')
            $L += ''
            $L += ('- cod de iesire: **' + $r.exitCode + '**')
            if ($r.toolMissing) { $L += '- instrument lipsa: nu a masurat nimic (nu e test picat)' }
            $L += ''
            $L += '```'
            $L += $r.tail
            $L += '```'
            $L += ''
        }
    }
    $L += '## Ce NU am facut si de ce'
    $L += ''
    $L += '<!-- MAVIS-LOCAL: limitele atinse -->'
    $L += ''
    $L += '## Riscuri'
    $L += ''
    $L += '<!-- MAVIS-LOCAL: ce ar putea sa se rupe -->'
    $L += ''
    if ($conflicts.Count -gt 0) {
        $L += '## Conflict de fisiere cu alte PR-uri deschise'
        $L += ''
        foreach ($c in $conflicts) {
            $L += ('- PR #' + $c.Pr + ' atinge acelasi fisier: `' + $c.Path + '` - cele doua nu pot fi merge-uite amandoua')
        }
        $L += ''
    }
    $L += '---'
    $L += ''
    $verdict = 'ADAPT - asteapta decizia de merge a lui Popy'
    if ($failed) {
        $verdict = 'FAIL - REJECT, nu ADAPT'
    } elseif ($unmeasured -gt 0) {
        $verdict = 'ADAPT FARA MASURATOARE PROPRIE - runnerul nu a pornit; nu e ACCEPT'
    }
    $L += ('Verdict local: ' + $verdict)
    $L += ''
    if ($unmeasured -gt 0) {
        $L += ('Testele proprii ale PR-ului: ' + $unmeasured + ' fara runner disponibil. Masuratoare incompleta, nu respingere.')
        $L += ''
    }

    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($outFile, (($L -join "`n") + "`n"), $enc)

    $result = 'ADAPT'
    if ($failed) { $result = 'FAIL' }
    elseif ($unmeasured -gt 0) { $result = 'ADAPT_NO_MEASUREMENT' }
    Write-JulesOut ('RESULT=' + $result)
    Write-JulesOut ('REPO=' + $Repo)
    Write-JulesOut ('PR=' + $Pr)
    Write-JulesOut ('BRANCH=' + $branch)
    Write-JulesOut ('FILES=' + $files.Count)
    Write-JulesOut ('COMMANDS=' + $runs.Count)
    Write-JulesOut ('CONFLICTS=' + $conflicts.Count)
    Write-JulesOut ('FILE=' + $outFile)
    foreach ($r in $runs) {
        Write-JulesOut ('CMD=' + $r.command + ' EXIT=' + $r.exitCode + ' TOOLMISSING=' + $r.toolMissing)
    }
    if ($failed) { return 2 }
    return 0
}

$code = Main
exit $code
