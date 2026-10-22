# jules-selfcheck.ps1
# The gate that must pass before anything in this platform runs.
#
# Two failures killed this platform before it worked, and both were invisible
# until something broke at run time:
#
#   1. A NON-ASCII byte in a .ps1 file. Windows PowerShell 5.1 parses
#      interpolated strings wrongly when the file carries bytes above 0x7F
#      and no BOM. The file "looks fine" in an editor and fails at run time.
#   2. A PARSE error. A stray ')' at the end of a line is enough to make the
#      whole script unusable - and the symptom shows up far from the cause.
#
# So the gate checks both, for every script, and reports the exact line.
# A gate that cannot fail is not a gate: this one exits non-zero on any
# violation, and it is itself ASCII-pure.
#
# Usage:
#   powershell -NoProfile -File jules-selfcheck.ps1
#
# Exit codes:
#   0 = all scripts clean
#   1 = at least one script has non-ASCII bytes or a parse error
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

    if ($nonAscii -gt 0 -or $parseCount -gt 0) {
        $problems++
        Write-Output ('FAIL ' + $f.Name + ' - bytes=' + $bytes.Count + ' nonascii=' + $nonAscii + ' parseErrors=' + $parseCount)
        if ($nonAscii -gt 0) {
            Write-Output ('     primul octet > 0x7F la pozitia ' + $firstBad + ' (offset ' + $firstBad + ')')
        }
        if ($errs) {
            foreach ($e in $errs) {
                Write-Output ('     L' + $e.Extent.StartLineNumber + 'C' + $e.Extent.StartColumnNumber + ': ' + $e.Message)
                Write-Output ('        text: [' + $e.Extent.Text + ']')
            }
        }
    } else {
        Write-Output ('OK   ' + $f.Name + ' - bytes=' + $bytes.Count + ' nonascii=0 parseErrors=0')
    }
}

Write-Output ('FILES=' + $files.Count + ' PROBLEMS=' + $problems)
if ($problems -gt 0) {
    Write-Output 'POARTA A BLOCAT. Nimic nu ruleaza pana nu se repara.'
    exit 1
}
Write-Output 'Toate scripturile sunt curate: ASCII pur, parse fara erori.'
exit 0
