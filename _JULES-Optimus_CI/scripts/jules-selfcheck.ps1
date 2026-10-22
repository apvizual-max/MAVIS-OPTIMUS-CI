# jules-selfcheck.ps1
# The gate that must pass before anything in this platform runs.
#
# Three failures killed this platform before it worked, and all of them were
# invisible until something broke at run time:
#
#   1. A NON-ASCII byte in a .ps1 file. Windows PowerShell 5.1 parses
#      interpolated strings wrongly when the file carries bytes above 0x7F
#      and no BOM. The file "looks fine" in an editor and fails at run time.
#   2. A PARSE error. A stray ')' at the end of a line is enough to make the
#      whole script unusable - and the symptom shows up far from the cause.
#   3. AN EXIT CODE SWALLOWED BY ITS OWN OUTPUT. A script does `$code = Main`
#      and Main prints with Write-Output, so the printed lines become part of
#      Main's return value. Measured on this machine:
#          function F { Write-Output 'X'; return 3 }  ->  $c = F  ->  @('X', 3)
#          exit $c                                     ->  EXIT 0
#      Every gate that printed before returning a failure code returned
#      SUCCESS. A check that cannot fail is not a check.
#
# So the gate checks all four things, for every script:
#   - ASCII pur
#   - parse fara erori
#   - no Write-Output in a script whose exit code comes from a variable
#   - the platform idiom really does deliver the payload AND the exit code
#     (a probe that deliberately fails, so the gate is shown able to fail)
#
# Usage:
#   powershell -NoProfile -File jules-selfcheck.ps1
#
# Exit codes:
#   0 = all scripts clean
#   1 = at least one script has non-ASCII bytes, a parse error, a
#       contaminated exit code, or the idiom probe failed
#
# ASCII ONLY: executed by Windows PowerShell 5.1.

param(
    [string]$ScriptsDir = ''
)

$ErrorActionPreference = 'Stop'

if (-not $ScriptsDir) {
    $ScriptsDir = $PSScriptRoot
}

if (-not (Test-Path -LiteralPath $ScriptsDir)) {
    Write-Output ('EROARE: director inexistent: ' + $ScriptsDir)
    exit 2
}

$files = @(Get-ChildItem -LiteralPath $ScriptsDir -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
if ($files.Count -eq 0) {
    Write-Output ('EROARE: niciun .ps1 in ' + $ScriptsDir)
    exit 2
}

$problems = 0
foreach ($f in $files) {
    $p = $f.FullName
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Output ('FAIL ' + $f.Name + ' - fisier disparit in timpul verificarii')
        $problems++
        continue
    }

    $bytes = [System.IO.File]::ReadAllBytes($p)
    $nonAscii = 0
    $firstBad = -1
    for ($i = 0; $i -lt $bytes.Count; $i++) {
        if ($bytes[$i] -gt 127) {
            $nonAscii++
            if ($firstBad -lt 0) { $firstBad = $i }
        }
    }

    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$errs)
    $parseCount = 0
    if ($errs) { $parseCount = $errs.Count }

    # The exit-code contamination check.
    $raw = [System.IO.File]::ReadAllText($p)
    $exitVar = [regex]::Match($raw, '(?m)^\s*exit\s+\$(\w+)\s*$')
    $exitName = ''
    $contaminated = $false
    if ($exitVar.Success) {
        $exitName = $exitVar.Groups[1].Value
        $fromCall = [regex]::IsMatch($raw, ('(?m)^\s*\$' + $exitName + '\s*=\s*[A-Za-z_][A-Za-z0-9_\-]*\s*$'))
        $usesStream = [regex]::IsMatch($raw, '(?m)^\s*Write-Output\b')
        if ($fromCall -and $usesStream) { $contaminated = $true }
    }

    if ($nonAscii -gt 0 -or $parseCount -gt 0 -or $contaminated) {
        $problems++
        Write-Output ('FAIL ' + $f.Name + ' - bytes=' + $bytes.Count + ' nonascii=' + $nonAscii + ' parseErrors=' + $parseCount + ' exitContaminated=' + $contaminated)
        if ($nonAscii -gt 0) {
            Write-Output ('     primul octet > 0x7F la pozitia ' + $firstBad + ' (offset ' + $firstBad + ')')
        }
        if ($contaminated) {
            Write-Output ('     Write-Output contamineaza variabila de cod de iesire $' + $exitName + ' - foloseste Write-JulesOut')
        }
        if ($errs) {
            foreach ($e in $errs) {
                Write-Output ('     L' + $e.Extent.StartLineNumber + 'C' + $e.Extent.StartColumnNumber + ': ' + $e.Message)
                Write-Output ('        text: [' + $e.Extent.Text + ']')
            }
        }
    } else {
        Write-Output ('OK   ' + $f.Name + ' - bytes=' + $bytes.Count + ' nonascii=0 parseErrors=0 exitContaminated=false')
    }
}

# --- The idiom probe -----------------------------------------------------
# A gate that has never been shown able to fail is a gate of unknown quality.
# The probe writes a payload to stdout AND returns a failure code, exactly as
# the platform scripts do. If the payload is lost or the code is swallowed,
# the platform's own contract is broken and the probe says so.
$probeDir = Join-Path (Split-Path -Parent $ScriptsDir) 'state\tmp'
if (-not (Test-Path -LiteralPath $probeDir)) {
    New-Item -ItemType Directory -Path $probeDir -Force | Out-Null
}
$probeFile = Join-Path $probeDir ('selfcheck-probe-' + [guid]::NewGuid().ToString('N') + '.ps1')
$probeLib = Join-Path $ScriptsDir 'jules-lib.ps1'
$libLiteral = $probeLib.Replace("'", "''")
$probeSrc = @(
    '$ErrorActionPreference = ''Stop''',
    ('. ''' + $libLiteral + ''''),
    'function ProbeMain {',
    '    Write-JulesOut ''PROBE_PAYLOAD_OK''',
    '    return 3',
    '}',
    '$code = ProbeMain',
    'exit $code'
) -join "`n"

$probeCode = -1
$probeText = ''
try {
    [System.IO.File]::WriteAllText($probeFile, ($probeSrc + "`n"), (New-Object System.Text.UTF8Encoding($false)))
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $probeOut = & powershell -NoProfile -File $probeFile 2>&1
    $ErrorActionPreference = $prevEap
    $probeCode = $LASTEXITCODE
    if ($null -eq $probeCode) { $probeCode = -1 }
    if ($probeOut) { $probeText = ($probeOut -join "`n") }
} catch {
    $probeText = [string]$_
} finally {
    $ErrorActionPreference = 'Continue'
    if (Test-Path -LiteralPath $probeFile) { Remove-Item -LiteralPath $probeFile -Force -ErrorAction SilentlyContinue }
    $ErrorActionPreference = $prevEap
}

if ($probeCode -ne 3) {
    $problems++
    Write-Output ('FAIL proba-idiom - cod de iesire ' + $probeCode + ', asteptat 3 (payload + cod de esec)')
} elseif ($probeText -notmatch 'PROBE_PAYLOAD_OK') {
    $problems++
    Write-Output 'FAIL proba-idiom - payload absent pe stdout (codul a fost corect, payload-ul nu)'
} else {
    Write-Output ('OK   proba-idiom - payload pe stdout SI cod de iesire ' + $probeCode + ' (proba esueaza intentionat)')
}

Write-Output ('FILES=' + $files.Count + ' PROBLEMS=' + $problems)
if ($problems -gt 0) {
    Write-Output 'POARTA A BLOCAT. Nimic nu ruleaza pana nu se repara.'
    exit 1
}
Write-Output 'Toate scripturile sunt curate: ASCII pur, parse fara erori, cod de iesire necontaminat.'
exit 0
