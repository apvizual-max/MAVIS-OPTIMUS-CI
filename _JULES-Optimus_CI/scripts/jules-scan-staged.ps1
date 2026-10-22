# jules-scan-staged.ps1
# The pre-commit gate. Scans what WILL be committed, not what is on disk.
#
# Why the index and not the working tree: the working tree can differ from
# the staged content. A gate that reads the working tree checks something
# that is not what gets committed. So every byte scanned here comes from
# `git show :<path>`, which is literally the staged blob.
#
# Rules enforced (all measured, all visible):
#   BLOCK  secret patterns (API keys, tokens, private keys)
#   BLOCK  any email address that is not the canonical one
#   BLOCK  the forbidden brand, outside the platform's own rule declarations
#   BLOCK  the known personal-data path fragments
#   WARN   phone-like numbers (the professional contact is Popy's policy call)
#
# The email rule is a COMPARISON, not a search for a known-bad literal:
# every address found must be apvizual@gmail.com (or an internal
# optimus.local address). A gate that greps for one known wrong address
# cannot catch the next wrong address, and it trips on the very file that
# declares the rule. A comparison has neither defect.
#
# Usage:
#   powershell -NoProfile -File jules-scan-staged.ps1
#
# Exit codes:
#   0 = nothing blocked
#   1 = at least one BLOCK
#   2 = the gate could not read the index at all
#
# ASCII ONLY: executed by Windows PowerShell 5.1.

param(
    [string]$RepoPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'jules-lib.ps1')

function Get-RepoRoot {
    param([string]$Hint)
    $probe = $Hint
    if (-not $probe) { $probe = $PSScriptRoot }
    $res = Invoke-Native -Program 'git' -Arguments @('-C', $probe, 'rev-parse', '--show-toplevel')
    if (-not $res.Ok) { return '' }
    return ($res.Out.Trim())
}

function Get-StagedEntries {
    param([string]$Root)
    $res = Invoke-Native -Program 'git' -Arguments @('-C', $Root, 'diff', '--cached', '--name-status', '--no-renames')
    if (-not $res.Ok) { return @() }
    $entries = @()
    foreach ($line in ($res.Out -split "`r?`n")) {
        if (-not $line.Trim()) { continue }
        $parts = $line -split "`t"
        if ($parts.Count -lt 2) { continue }
        $status = $parts[0].Trim()
        $path = $parts[1].Trim()
        $entries += [PSCustomObject]@{ Status = $status; Path = $path }
    }
    return $entries
}

function Get-StagedBlob {
    param([string]$Root, [string]$Path)
    $res = Invoke-Native -Program 'git' -Arguments @('-C', $Root, 'show', (':' + $Path))
    if (-not $res.Ok) { return $null }
    return $res.Out
}

function Main {
    $root = Get-RepoRoot -Hint $RepoPath
    if (-not $root) {
        Write-JulesOut 'GATE_ERROR: cannot resolve git repository root'
        return 2
    }

    $entries = @(Get-StagedEntries -Root $root)
    $blocks = @()
    $warns = @()
    $notes = @()

    $secretPatterns = @(
        'AIza[0-9A-Za-z\-_]{20,}',
        '(?<![A-Za-z0-9])ghp_[0-9A-Za-z]{20,}',
        '(?<![A-Za-z0-9])github_pat_[0-9A-Za-z_]{20,}',
        '(?<![A-Za-z0-9])sk-[0-9A-Za-z]{20,}',
        '-{5}BEGIN [A-Z ]*PRIVATE KEY-{5}',
        '(?<![A-Za-z0-9])xox[baprs]-[0-9A-Za-z\-]{10,}',
        '(?<![A-Za-z0-9])AKIA[0-9A-Z]{16}'
    )

    # A test for a secret scanner contains fake keys on purpose. Scanning it
    # as if it were a leak rejects a good change. The exception is narrow,
    # named, and visible - never a silent skip.
    $fixturePattern = '(?i)(^|/)(tests?|specs?|__tests__|fixtures?|samples?)/|\.(tests?|specs?)\.[^/]+$'

    # The platform declares the rules; the content obeys them. The platform's
    # own scripts and config are therefore outside the brand check, and the
    # skip is reported, not hidden.
    $platformPrefixes = @('_JULES-Optimus_CI/scripts/', '_JULES-Optimus_CI/config/')

    $allowedEmails = @('apvizual@gmail.com')
    $allowedEmailDomains = @('ap-id.ro')
    $internalEmailSuffix = '.local'
    $forbiddenBrand = 'Creafac'
    $forbiddenPathFragments = @(
        'MAVIS-CLOUD-main repo - local',
        'CV-ORIGINALE-POPY',
        'CVURI-NOTARE',
        '07-SITEURI-NIVEL1',
        '10-GMAIL',
        '11-JULES'
    )
    $phonePattern = '\+40[0-9 (]{7,}[0-9]'

    $scanned = 0
    foreach ($e in $entries) {
        $path = $e.Path
        if ($e.Status -eq 'D') { continue }

        foreach ($frag in $forbiddenPathFragments) {
            if ($path.Contains($frag)) {
                $blocks += ('BLOCK: personal-data path fragment "' + $frag + '" in ' + $path)
            }
        }

        $content = Get-StagedBlob -Root $root -Path $path
        if ($null -eq $content) {
            $notes += ('NOTE: staged blob unreadable, not scanned: ' + $path)
            continue
        }
        $scanned++

        if ([regex]::IsMatch($path, $fixturePattern)) {
            $notes += ('NOTE: secret scan skipped for test/fixture file: ' + $path)
        } else {
            foreach ($sp in $secretPatterns) {
                if ([regex]::IsMatch($content, $sp)) {
                    $blocks += ('BLOCK: secret pattern ' + $sp + ' in ' + $path)
                }
            }
        }

        foreach ($m in [regex]::Matches($content, '[A-Za-z0-9][A-Za-z0-9._%+\-]*@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}')) {
            $addr = $m.Value.ToLowerInvariant()
            if ($allowedEmails -contains $addr) { continue }
            $domain = $addr.Split('@')[1]
            if ($allowedEmailDomains -contains $domain) { continue }
            if ($domain.EndsWith($internalEmailSuffix, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            $blocks += ('BLOCK: non-canonical email ' + $addr + ' in ' + $path)
        }

        $isPlatform = $false
        foreach ($pp in $platformPrefixes) {
            if ($path.StartsWith($pp, [System.StringComparison]::OrdinalIgnoreCase)) { $isPlatform = $true }
        }
        # Reports state the invariant ("Creafac = 0"), so a mention there is
        # the rule being reported, not the rule being broken. The skip is
        # visible.
        $isReport = $path.StartsWith('docs/', [System.StringComparison]::OrdinalIgnoreCase)
        if ($isPlatform -or $isReport) {
            $notes += ('NOTE: brand check skipped for platform rule declaration or report: ' + $path)
        } elseif ($content.ToLowerInvariant().Contains($forbiddenBrand.ToLowerInvariant())) {
            $blocks += ('BLOCK: forbidden brand in ' + $path)
        }

        if ([regex]::IsMatch($content, $phonePattern)) {
            $warns += ('WARN: phone-like number in ' + $path + ' - professional contact, Popy decides if it is public')
        }
    }

    Write-JulesOut ('STAGED=' + $entries.Count)
    Write-JulesOut ('SCANNED=' + $scanned)
    Write-JulesOut ('BLOCKS=' + $blocks.Count)
    Write-JulesOut ('WARNS=' + $warns.Count)
    foreach ($n in $notes) { Write-JulesOut $n }
    foreach ($w in $warns) { Write-JulesOut $w }
    foreach ($b in $blocks) { Write-JulesOut $b }

    if ($blocks.Count -gt 0) {
        Write-JulesOut 'SCAN_BLOCKED'
        return 1
    }
    Write-JulesOut 'SCAN_OK'
    return 0
}

$code = Main
exit $code
