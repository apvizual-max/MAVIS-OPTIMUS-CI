# jules-lib.ps1
# Shared helpers for the Jules orchestration platform (Mavis Local).
#
# ASCII ONLY BY DESIGN: this file is executed by Windows PowerShell 5.1,
# whose parser breaks interpolated strings when the file carries non-ASCII
# bytes and no BOM. Keep every character in this file below 0x7F.
#
# Dot-source it:  . (Join-Path $PSScriptRoot 'jules-lib.ps1')

Set-StrictMode -Version 2.0

$script:JulesRoot = Split-Path -Parent $PSScriptRoot
$script:JulesLogFile = $null
$script:JulesLongPathsSet = $false

# Enables git long paths for every git invocation made by this process,
# including the ones `gh` makes internally.
#
# MEASURED on this machine: without it, `git clone` of pkms-vault-automation
# materializes 14 of 701 tracked files and dies with "Filename too long"
# (MAX_PATH 260). With it: 701 of 701 on disk, `git status` reports a clean
# tree, `git checkout -- .` succeeds. The setting travels through
# GIT_CONFIG_* so that gh - which shells out to git - inherits it too.
#
# It is set ONCE per process: GIT_CONFIG_COUNT is a counter, so appending on
# every call would grow it without bound.
function Enable-JulesLongPaths {
    if ($script:JulesLongPathsSet) { return }
    $script:JulesLongPathsSet = $true
    $count = 0
    if ($env:GIT_CONFIG_COUNT) {
        $parsed = 0
        if ([int]::TryParse($env:GIT_CONFIG_COUNT, [ref]$parsed)) { $count = $parsed }
    }
    $idx = $count
    $env:GIT_CONFIG_COUNT = [string]($count + 1)
    Set-Item -Path ('Env:GIT_CONFIG_KEY_' + $idx) -Value 'core.longpaths'
    Set-Item -Path ('Env:GIT_CONFIG_VALUE_' + $idx) -Value 'true'
}

# Checks that a clone is COMPLETE: every file the repository tracks is
# actually on disk.
#
# MEASURED on this machine: a clone of pkms-vault-automation made WITHOUT
# long paths materializes 14 of 701 tracked files and dies with "Filename
# too long". Measuring a pull request in that tree would have produced
# verdicts about 14 files while claiming to describe 701. A gate that
# cannot fail is not a gate, so this one fails loudly instead.
function Test-CloneIntegrity {
    param([Parameter(Mandatory = $true)][string]$Dir)
    $result = [PSCustomObject]@{
        Ok      = $false
        Tracked = 0
        OnDisk  = 0
        Reason  = ''
    }
    if (-not (Test-Path -LiteralPath (Join-Path $Dir '.git'))) {
        $result.Reason = 'not a git clone: ' + $Dir
        return $result
    }
    $ls = Invoke-Native -Program 'git' -Arguments @('-C', $Dir, 'ls-tree', '-r', 'HEAD', '--name-only')
    if (-not $ls.Ok) {
        $result.Reason = 'cannot read the HEAD tree: ' + $ls.Err
        return $result
    }
    $tracked = @($ls.Out -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 })
    $result.Tracked = $tracked.Count
    $onDisk = @(Get-ChildItem -LiteralPath $Dir -Recurse -File -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '\\\.git\\' })
    $result.OnDisk = $onDisk.Count
    if ($result.OnDisk -lt $result.Tracked) {
        $result.Reason = ('incomplete clone: ' + $result.OnDisk + ' of ' + $result.Tracked + ' tracked files are on disk')
        return $result
    }
    $result.Ok = $true
    $result.Reason = 'clone complete'
    return $result
}

function Get-JulesRoot {
    return $script:JulesRoot
}

function Write-JulesLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'STEP')][string]$Level = 'INFO'
    )
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = '{0} [{1}] {2}' -f $ts, $Level, $Message
    # Logs go to stderr so they never contaminate the function return value
    # that carries the exit code, and never mix with machine-readable output.
    [Console]::Error.WriteLine($line)
    if ($script:JulesLogFile) {
        Add-Content -LiteralPath $script:JulesLogFile -Value $line -Encoding ASCII
    }
}

# Writes a machine-readable line to the real stdout.
#
# WHY NOT Write-Output: a script does `$code = Main`, and Write-Output inside
# Main is part of Main's return value. Measured on this machine:
#   function F { Write-Output 'X'; return 3 }   ->  $c = F  ->  $c = @('X', 3)
#   exit $c                                      ->  EXIT 0   (the 3 is lost)
# So every gate that printed a line before returning a failure code returned
# SUCCESS. That is a check that cannot fail. [Console]::Out.WriteLine writes
# straight to stdout, is not captured by the assignment, and leaves the exit
# code intact.
#
# Logs go to stderr (Write-JulesLog). Payload goes here. Nothing else may.
function Write-JulesOut {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Message)
    [Console]::Out.WriteLine($Message)
}

function Start-JulesLog {
    param([Parameter(Mandatory = $true)][string]$Name)
    $logDir = Join-Path (Get-JulesRoot) 'logs'
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $stamp = (Get-Date).ToString('yyyy-MM-dd')
    $script:JulesLogFile = Join-Path $logDir ('{0}-{1}.log' -f $Name, $stamp)
    Write-JulesLog -Message ('log opened: ' + $script:JulesLogFile) -Level 'STEP'
}

# Temporary files live in the project's own state/tmp directory.
# Path.GetTempFileName() is NOT used: it throws "The file exists" on this
# machine because the system temp dir rejects the generated name.
function New-JulesTempFile {
    param([string]$Suffix = '.tmp')
    $dir = Join-Path (Get-JulesRoot) 'state\tmp'
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $name = ([guid]::NewGuid().ToString('N')) + $Suffix
    return (Join-Path $dir $name)
}

# Runs a native command and captures stdout, stderr and exit code separately.
#
# CRITICAL: the caller often runs with $ErrorActionPreference = 'Stop'. In that
# mode PowerShell turns ANY stderr line from a native command into a
# terminating NativeCommandError - so "gh repo clone" (which writes progress to
# stderr) would kill the script before it could read the exit code. The
# preference is lowered for the duration of the call and restored after.
#
# Returns a hashtable: ExitCode (int), Out (string), Err (string), Ok (bool).
function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)][string]$Program,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = ''
    )
    $errFile = New-JulesTempFile -Suffix '.err'
    $prevEap = $ErrorActionPreference
    $prevDir = ''
    # Every git call made from here - directly, or through gh - gets long
    # paths. Measured: without it, a clone of pkms-vault-automation lands
    # 14 of 701 files on disk.
    Enable-JulesLongPaths
    try {
        $ErrorActionPreference = 'Continue'
        if ($WorkingDirectory) {
            # NEVER fall back to the current directory.
            #
            # MEASURED on this machine: `gh pr checkout 9 -R
            # apvizual-max/MAVIS-CLOUD` run inside an UNRELATED clone
            # created the pull request's branch THERE and exited 0. A
            # tool that acts on "the repository in the current directory"
            # reports success while doing the wrong thing. So the
            # directory is named explicitly, and if it does not exist
            # this fails loudly instead of running somewhere else.
            if (-not (Test-Path -LiteralPath $WorkingDirectory -PathType Container)) {
                return @{ ExitCode = 127; Out = ''; Err = ('working directory does not exist: ' + $WorkingDirectory); Ok = $false }
            }
            $prevDir = (Get-Location).Path
            Set-Location -LiteralPath $WorkingDirectory
        }
        $out = & $Program @Arguments 2> $errFile
        $code = $LASTEXITCODE
        if ($null -eq $code) { $code = 0 }
        $err = ''
        if (Test-Path -LiteralPath $errFile) {
            $err = (Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue)
            if ($null -eq $err) { $err = '' }
        }
        $outText = ''
        if ($out) { $outText = ($out -join "`n") }
        return @{
            ExitCode = [int]$code
            Out      = $outText
            Err      = [string]$err
            Ok       = ([int]$code -eq 0)
        }
    } finally {
        $ErrorActionPreference = $prevEap
        if ($prevDir) { Set-Location -LiteralPath $prevDir -ErrorAction SilentlyContinue }
        # Temp file created by this script, seconds ago. Safe to remove.
        if (Test-Path -LiteralPath $errFile) { Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue }
    }
}

# Runs gh and captures stdout, stderr and exit code separately.
# Returns a hashtable: ExitCode (int), Out (string), Err (string), Ok (bool).
function Invoke-Gh {
    param(
        [Parameter(Mandatory = $true)][string[]]$GhArgs,
        [int]$TimeoutSec = 120,
        [string]$WorkingDirectory = ''
    )
    return (Invoke-Native -Program 'gh' -Arguments $GhArgs -WorkingDirectory $WorkingDirectory)
}

# Parses a JSON payload that may be an ARRAY or a single OBJECT.
#
# MEASURED on Windows PowerShell 5.1: `@($text | ConvertFrom-Json)`
# returns ONE element when the payload is a top-level JSON array, because
# ConvertFrom-Json emits the whole array as a single pipeline object and
# the array subexpression does not unroll it. Measured on the real
# GitHub payload: 34 pull requests in, 1 element out, and every element
# then failed the type check - so the conflict scan reported
# "0 open PR examined" while the API was working perfectly.
#
# The fix is to ASSIGN first and wrap afterwards: `@($parsed)` DOES
# unroll an array held in a variable. Measured: 34 elements, 34 of them
# carrying a 'number'.
function ConvertFrom-JulesJson {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Json)
    if (-not $Json) { return @() }
    $parsed = $Json | ConvertFrom-Json
    return (@($parsed))
}

# Verifies that a checkout landed where it was supposed to land.
#
# WHY THIS EXISTS: `gh pr checkout <n> -R <repo>` exits 0 even when the
# current directory belongs to a DIFFERENT repository - it creates the
# pull request's branch there and reports success. Measured on this
# machine. The consequence was a FALSE REJECT: the clone stayed on an
# older pull request's branch, the new test file did not exist there,
# `node --test` exited 1, and the report called the proposal broken.
#
# A gate that cannot fail is not a gate, so this one is written to fail:
# a wrong directory, a wrong branch, or a missing test file all return
# Ok = $false with the reason.
function Test-CheckoutTarget {
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$ExpectedRef,
        [string]$ExpectedSha = '',
        [string[]]$OwnPaths = @()
    )
    $result = [PSCustomObject]@{
        Ok           = $false
        Branch       = ''
        HeadSha      = ''
        MissingPaths = @()
        Reason       = ''
    }
    if (-not (Test-Path -LiteralPath (Join-Path $Dir '.git'))) {
        $result.Reason = 'not a git clone: ' + $Dir
        return $result
    }
    $branchRes = Invoke-Native -Program 'git' -Arguments @('-C', $Dir, 'rev-parse', '--abbrev-ref', 'HEAD')
    if (-not $branchRes.Ok) {
        $result.Reason = 'cannot read HEAD: ' + $branchRes.Err
        return $result
    }
    $branch = $branchRes.Out.Trim()
    $result.Branch = $branch
    if ($ExpectedRef -and ($branch -ne $ExpectedRef)) {
        $result.Reason = ('HEAD is on ' + $branch + ', expected ' + $ExpectedRef)
        return $result
    }
    if ($ExpectedSha) {
        $shaRes = Invoke-Native -Program 'git' -Arguments @('-C', $Dir, 'rev-parse', 'HEAD')
        if (-not $shaRes.Ok) {
            $result.Reason = 'cannot read HEAD commit: ' + $shaRes.Err
            return $result
        }
        $sha = $shaRes.Out.Trim()
        $result.HeadSha = $sha
        if ($sha -ne $ExpectedSha) {
            $result.Reason = ('HEAD is at ' + $sha + ', expected ' + $ExpectedSha)
            return $result
        }
    }
    $missing = @()
    foreach ($p in $OwnPaths) {
        $full = Join-Path $Dir ($p.Replace('/', '\'))
        if (-not (Test-Path -LiteralPath $full)) { $missing += $p }
    }
    if ($missing.Count -gt 0) {
        $result.MissingPaths = $missing
        $result.Reason = ('missing on the checked out branch: ' + ($missing -join ', '))
        return $result
    }
    $result.Ok = $true
    $result.Reason = 'checkout verified'
    return $result
}

function Assert-Gh {
    $cmd = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Write-JulesLog -Message 'gh CLI not found on PATH' -Level 'ERROR'
        return $false
    }
    return $true
}

function Get-RepoRegistry {
    $path = Join-Path (Get-JulesRoot) 'config\repos.json'
    if (-not (Test-Path -LiteralPath $path)) {
        throw ('registry not found: ' + $path)
    }
    $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    return ($text | ConvertFrom-Json)
}

function Get-RepoEntry {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [object]$Registry
    )
    if (-not $Registry) { $Registry = Get-RepoRegistry }
    foreach ($r in $Registry.repos) {
        if ($r.name -eq $Name) { return $r }
    }
    return $null
}

function Get-TriageRepos {
    param([object]$Registry)
    if (-not $Registry) { $Registry = Get-RepoRegistry }
    $out = @()
    foreach ($r in $Registry.repos) {
        if ($r.triage -eq $true) { $out += $r }
    }
    return $out
}

function Get-DispatchRepos {
    param([object]$Registry)
    if (-not $Registry) { $Registry = Get-RepoRegistry }
    $out = @()
    foreach ($r in $Registry.repos) {
        if ($r.dispatch -eq $true) { $out += $r }
    }
    return $out
}

function Get-JulesContextText {
    $path = Join-Path (Get-JulesRoot) 'config\jules-context.md'
    if (-not (Test-Path -LiteralPath $path)) {
        throw ('context pack not found: ' + $path)
    }
    return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}

function Get-TaskCardText {
    param([Parameter(Mandatory = $true)][string]$Axis)
    $path = Join-Path (Get-JulesRoot) 'config\task-cards.md'
    if (-not (Test-Path -LiteralPath $path)) { return '' }
    $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    $marker = '<!-- AXIS:' + $Axis + ' -->'
    $start = $text.IndexOf($marker)
    if ($start -lt 0) { return '' }
    $next = $text.IndexOf('<!-- AXIS:', $start + $marker.Length)
    if ($next -lt 0) { $next = $text.Length }
    return $text.Substring($start + $marker.Length, $next - ($start + $marker.Length)).Trim()
}

# Returns the full file tree of a repo branch as an array of PSCustomObject
# with Path (string), Size (int), Type (string).
function Get-RepoTree {
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$Branch
    )
    $res = Invoke-Gh -GhArgs @('api', ('repos/apvizual-max/' + $Repo + '/git/trees/' + $Branch + '?recursive=1'))
    if (-not $res.Ok) {
        Write-JulesLog -Message ('tree read failed for ' + $Repo + ': ' + $res.Err) -Level 'ERROR'
        return @()
    }
    $json = $res.Out | ConvertFrom-Json
    $items = @()
    foreach ($t in $json.tree) {
        if ($t.type -ne 'blob') { continue }
        $items += [PSCustomObject]@{
            Path = [string]$t.path
            Size = [int]$t.size
            Type = [string]$t.type
        }
    }
    return $items
}

function Test-InterestingPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $p = $Path.ToLowerInvariant()
    $skip = @('node_modules/', 'vendor/', '.git/', 'dist/', 'docs/arhiva/', '.skills/', 'site/dist/')
    foreach ($s in $skip) {
        if ($p.Contains($s)) { return $false }
    }
    $skipExt = @('.png', '.jpg', '.jpeg', '.gif', '.svg', '.ico', '.pdf', '.zip', '.mp4', '.mp3', '.woff', '.woff2')
    foreach ($e in $skipExt) {
        if ($p.EndsWith($e)) { return $false }
    }
    return $true
}

# Picks a concrete file target for an axis, from the measured repo tree.
# Deterministic ranking: biggest first. Excludes paths already used.
function Select-JulesTarget {
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$Axis,
        [string[]]$Exclude = @()
    )
    $entry = Get-RepoEntry -Name $Repo
    if (-not $entry) { return $null }
    $tree = @(Get-RepoTree -Repo $Repo -Branch $entry.branch)
    if ($tree.Count -eq 0) { return $null }

    $candidates = @()
    foreach ($f in $tree) {
        if (-not (Test-InterestingPath -Path $f.Path)) { continue }
        if ($Exclude -contains $f.Path) { continue }
        $p = $f.Path.ToLowerInvariant()
        $score = 0
        switch ($Axis) {
            'performance' {
                if ($p.EndsWith('.js') -or $p.EndsWith('.mjs') -or $p.EndsWith('.cjs') -or $p.EndsWith('.ts') -or $p.EndsWith('.py')) {
                    $score = $f.Size
                }
            }
            'design' {
                if ($p.EndsWith('.html') -or $p.EndsWith('.css') -or $p.EndsWith('.md') -or $p.EndsWith('.jsx') -or $p.EndsWith('.tsx')) {
                    $score = $f.Size
                }
            }
            'security' {
                $hit = $p.Contains('secret') -or $p.Contains('token') -or $p.Contains('credential') -or
                       $p.Contains('auth') -or $p.Contains('password') -or $p.Contains('oauth') -or
                       $p.Contains('client.json') -or $p.EndsWith('.sh') -or $p.EndsWith('.ps1') -or
                       $p.EndsWith('.yml') -or $p.EndsWith('.yaml')
                if ($hit) { $score = $f.Size }
            }
            default { $score = $f.Size }
        }
        if ($score -gt 0) {
            $candidates += [PSCustomObject]@{ Path = $f.Path; Size = $f.Size; Score = $score }
        }
    }
    if ($candidates.Count -eq 0) { return $null }
    $sorted = $candidates | Sort-Object -Property @{ Expression = 'Score'; Descending = $true }, @{ Expression = 'Path'; Descending = $false }
    return $sorted[0]
}

# Quota ledger: state/quota-YYYY-MM-DD.json
function Get-QuotaLedgerPath {
    param([string]$Date)
    if (-not $Date) { $Date = (Get-Date).ToString('yyyy-MM-dd') }
    $dir = Join-Path (Get-JulesRoot) 'state'
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return (Join-Path $dir ('quota-' + $Date + '.json'))
}

function Get-QuotaLedger {
    param([string]$Date)
    $path = Get-QuotaLedgerPath -Date $Date
    if (-not (Test-Path -LiteralPath $path)) {
        return [PSCustomObject]@{
            date            = $(if ($Date) { $Date } else { (Get-Date).ToString('yyyy-MM-dd') })
            quotaPerDay     = 100
            tasksDispatched = 0
            perRepo         = @{}
            usedTargets     = @{}
        }
    }
    $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    return ($text | ConvertFrom-Json)
}

function Save-QuotaLedger {
    param(
        [Parameter(Mandatory = $true)][object]$Ledger,
        [string]$Date
    )
    $path = Get-QuotaLedgerPath -Date $Date
    $json = $Ledger | ConvertTo-Json -Depth 8
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $json, $enc)
    return $path
}

function Add-QuotaTask {
    param(
        [Parameter(Mandatory = $true)][object]$Ledger,
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$Axis,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][int]$IssueNumber,
        [string]$Date
    )
    $Ledger.tasksDispatched = [int]$Ledger.tasksDispatched + 1
    $key = $Repo
    if (-not $Ledger.perRepo.PSObject.Properties[$key]) {
        $Ledger.perRepo | Add-Member -NotePropertyName $key -NotePropertyValue ([PSCustomObject]@{ count = 0; axes = @(); issues = @() })
    }
    $entry = $Ledger.perRepo.$key
    $entry.count = [int]$entry.count + 1
    $entry.axes = @($entry.axes) + $Axis
    $entry.issues = @($entry.issues) + $IssueNumber

    $tkey = $Repo + '|' + $Target
    if (-not $Ledger.usedTargets.PSObject.Properties[$tkey]) {
        $Ledger.usedTargets | Add-Member -NotePropertyName $tkey -NotePropertyValue 1
    } else {
        $Ledger.usedTargets.$tkey = [int]$Ledger.usedTargets.$tkey + 1
    }
    return $Ledger
}

function Get-UsedTargets {
    param(
        [Parameter(Mandatory = $true)][object]$Ledger,
        [string]$Repo
    )
    $out = @()
    foreach ($p in $Ledger.usedTargets.PSObject.Properties) {
        if ($p.Name.StartsWith($Repo + '|')) {
            $out += $p.Name.Substring($Repo.Length + 1)
        }
    }
    return $out
}

function Get-TargetHistory {
    # Reads every quota ledger from the last N days, to avoid reusing targets.
    param([int]$Days = 30)
    $out = @()
    $dir = Join-Path (Get-JulesRoot) 'state'
    if (-not (Test-Path -LiteralPath $dir)) { return $out }
    $files = Get-ChildItem -LiteralPath $dir -Filter 'quota-*.json' -File -ErrorAction SilentlyContinue |
             Sort-Object Name -Descending | Select-Object -First $Days
    foreach ($f in $files) {
        try {
            $text = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
            $l = $text | ConvertFrom-Json
            foreach ($p in $l.usedTargets.PSObject.Properties) {
                $out += $p.Name
            }
        } catch {
            Write-JulesLog -Message ('ledger unreadable: ' + $f.Name) -Level 'WARN'
        }
    }
    return $out
}

function Get-JulesPrs {
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [string[]]$States = @('open')
    )
    $stateArg = ($States -join ',')
    $res = Invoke-Gh -GhArgs @('pr', 'list', '-R', ('apvizual-max/' + $Repo), '--state', $stateArg,
                               '--limit', '50', '--json', 'number,title,author,headRefName,createdAt,url,body')
    if (-not $res.Ok) {
        Write-JulesLog -Message ('pr list failed for ' + $Repo + ': ' + $res.Err) -Level 'ERROR'
        return @()
    }
    $arr = @(ConvertFrom-JulesJson -Json $res.Out)
    $out = @()
    foreach ($p in $arr) {
        if ($p.author.login -match 'jules|google-labs') { $out += $p }
    }
    return $out
}

function Get-RepoLocalPath {
    param([Parameter(Mandatory = $true)][string]$Repo)
    $base = Join-Path (Get-JulesRoot) 'work'
    return (Join-Path $base $Repo)
}

# Detects the verification commands a repo actually has, from its own tree.
# Never invents a command: if nothing is found, the result is an empty list
# and the caller reports "no verification available" instead of a false pass.
function Detect-VerifyCommands {
    param([Parameter(Mandatory = $true)][string]$Dir)
    $cmds = @()
    if (-not (Test-Path -LiteralPath $Dir)) { return $cmds }

    $pkg = Join-Path $Dir 'package.json'
    if (Test-Path -LiteralPath $pkg) {
        try {
            $enc = New-Object System.Text.UTF8Encoding($false)
            $raw = [System.IO.File]::ReadAllText($pkg, $enc)
            $p = $raw | ConvertFrom-Json
            if ($p.scripts -and $p.scripts.test) { $cmds += 'npm test' }
        } catch {
            Write-JulesLog -Message ('package.json unreadable: ' + $_.Exception.Message) -Level 'WARN'
        }
    }

    # Deterministic order, and a preference for conventional test locations.
    # Get-ChildItem returns filesystem order, so the same repo could produce
    # different commands on different machines - a measurement that does not
    # reproduce is not a measurement.
    $nodeTests = @(Get-ChildItem -Path (Join-Path $Dir '*') -Recurse -File -Filter '*.test.js' -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch 'node_modules|vendor|dist|arhiva' } |
            ForEach-Object {
                $rel = $_.FullName.Substring($Dir.Length).TrimStart([char[]]"\/").Replace('\', '/')
                [PSCustomObject]@{ Rel = $rel; Conventional = [bool]($rel -match '(^|/)(tests?|specs?)/') }
            } |
            Sort-Object -Property @{ Expression = { -not $_.Conventional } }, Rel |
            Select-Object -First 3)
    foreach ($t in $nodeTests) {
        # The path is QUOTED. A repository can contain a directory whose name
        # has spaces in it - one measured here was
        # "copy, MINIMAX, agentic, autonomous, operating system, plan" - and an
        # unquoted path is split into several arguments, so the runner fails on
        # a path it was given whole. That produced a FALSE REJECT on a pull
        # request that had never been tested.
        $cmds += ('node --test "' + $t.Rel + '"')
    }

    $pyA = @(Get-ChildItem -Path (Join-Path $Dir '*') -Recurse -File -Filter 'test_*.py' -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch 'node_modules|vendor|dist|arhiva|\.venv' } |
            ForEach-Object { $_.FullName.Substring($Dir.Length).TrimStart([char[]]"\/").Replace('\', '/') } |
            Sort-Object | Select-Object -First 2)
    $pyB = @(Get-ChildItem -Path (Join-Path $Dir '*') -Recurse -File -Filter '*_test.py' -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch 'node_modules|vendor|dist|arhiva|\.venv' } |
            ForEach-Object { $_.FullName.Substring($Dir.Length).TrimStart([char[]]"\/").Replace('\', '/') } |
            Sort-Object | Select-Object -First 2)
    foreach ($rel in ($pyA + $pyB)) {
        $cmds += ('python -m pytest "' + $rel + '"')
    }

    return $cmds
}

# Forbidden paths and patterns in a Jules diff.
# Reads the changed files of a pull request, with the added lines kept
# attached to their own file. Using the API instead of `gh pr diff` matters:
# `gh pr diff` truncates long diffs, and without per-file context a secret
# scanner cannot tell a real leak from a test fixture.
function Get-PrFiles {
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][int]$Pr
    )
    $res = Invoke-Gh -GhArgs @('api', ('repos/apvizual-max/' + $Repo + '/pulls/' + $Pr + '/files?per_page=100'))
    if (-not $res.Ok) {
        Write-JulesLog -Message ('pr files failed for ' + $Repo + ' PR ' + $Pr + ': ' + $res.Err) -Level 'ERROR'
        return @()
    }
    $arr = @(ConvertFrom-JulesJson -Json $res.Out)
    $out = @()
    foreach ($f in $arr) {
        $added = @()
        # The GitHub API OMITS the 'patch' field for large diffs and for
        # binary files. Under StrictMode, touching a missing property throws,
        # so the field is probed before it is read.
        if ($f.PSObject.Properties['patch']) {
            $patch = [string]$f.patch
            if ($patch.Length -gt 0) {
                $added = @($patch -split "`r?`n" |
                           Where-Object { $_.StartsWith('+') -and (-not $_.StartsWith('+++')) })
            }
        }
        $add = 0
        $del = 0
        if ($f.PSObject.Properties['additions']) { $add = [int]$f.additions }
        if ($f.PSObject.Properties['deletions']) { $del = [int]$f.deletions }
        $out += [PSCustomObject]@{
            path      = [string]$f.filename
            additions = $add
            deletions = $del
            added     = $added
        }
    }
    return $out
}

# Policy gate on a diff: forbidden paths and leaked secrets.
#
# $PrFiles is the output of Get-PrFiles: one entry per changed file, with
# that file's added lines attached to it.
#
# DOCUMENTED EXCEPTION - test fixtures: a test for a secret scanner contains
# fake keys on purpose. Scanning it as if it were a leak rejects a good PR.
# So secret patterns are only checked on files that are not test/fixture
# files. The exception is narrow, named, and visible - not a silent skip.
function Test-DiffPolicy {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$PrFiles
    )
    $violations = @()

    $forbiddenPath = @('node_modules/', 'vendor/', '/dist/', 'package-lock.json', 'yarn.lock', '.env')
    $fixturePattern = '(?i)(^|/)(tests?|specs?|__tests__|fixtures?|samples?)/|\.(tests?|specs?)\.[^/]+$'

    $secretPatterns = @(
        'AIza[0-9A-Za-z\-_]{20,}',
        'ghp_[0-9A-Za-z]{20,}',
        'github_pat_[0-9A-Za-z_]{20,}',
        'sk-[0-9A-Za-z]{20,}',
        '-----BEGIN [A-Z ]*PRIVATE KEY-----',
        'xox[baprs]-[0-9A-Za-z\-]{10,}'
    )

    foreach ($f in $PrFiles) {
        $path = [string]$f.path
        foreach ($p in $forbiddenPath) {
            if ($path.Contains($p)) { $violations += ('path forbidden: ' + $path + ' (matches ' + $p + ')') }
        }
        $isFixture = [regex]::IsMatch($path, $fixturePattern)
        if ($isFixture) {
            $violations += ('NOTE: secret scan skipped for test/fixture file: ' + $path)
            continue
        }
        foreach ($line in @($f.added)) {
            foreach ($sp in $secretPatterns) {
                $m = [regex]::Match([string]$line, $sp)
                if ($m.Success) { $violations += ('secret pattern in diff: ' + $sp + ' in ' + $path) }
            }
        }
    }

    return $violations
}
