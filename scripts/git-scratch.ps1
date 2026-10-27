# git-scratch.ps1
# Shared resolver for the scratch root used by the self-check gates.
#
# WHY THIS EXISTS
# Every self-check builds throwaway git repositories: a bare remote, a clone,
# a conflict copy. Each of those carries its own .git directory. When the
# fixture root was <project>\state\tmp\..., it sat INSIDE the Google Drive
# mirror (E:\Google\GDrive\...), the tree DriveFS administers while it
# synchronises. DriveFS may materialise, replace or remove files underneath
# a live git repository: the laboratory was standing in the battlefield.
#
# MEASURED 2026-10-27: 90+ .git directories inside the mirrored tree, every
# one of them a test fixture. The real repositories were already outside
# (E:\Google\GitData-Optimus-CI, -CD, -PKMS); the fixtures were not.
#
# The scratch root is derived from the repository's OWN gitdir, which lives
# outside the mirror (E:\Google\GitData-Optimus-CI). The laboratory follows
# the repository instead of hard-coding a machine path.
#
# Override with the environment variable MAVIS_CI_SCRATCH.
#
# ASCII ONLY: executed by Windows PowerShell 5.1.

function Get-GitScratchRoot {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [string]$Name = 'GitScratch-Optimus-CI'
    )

    $override = [Environment]::GetEnvironmentVariable('MAVIS_CI_SCRATCH')
    if ($override -and $override.Trim()) { return $override.Trim() }

    $gitDir = ''
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $gitDir = ((& git -C $ProjectRoot rev-parse --absolute-git-dir 2>$null) -join '').Trim()
    } catch {
        $gitDir = ''
    }
    $ErrorActionPreference = $prev

    $base = ''
    if ($gitDir) { $base = Split-Path -Parent $gitDir }
    if (-not $base) { $base = Join-Path ($env:SystemDrive) 'Google' }

    return (Join-Path $base $Name)
}

# The DriveFS mirror root, found by walking up from the project. On this
# machine the mirror is E:\Google\GDrive and the project lives under it.
function Get-DriveMirrorRoot {
    param([Parameter(Mandatory = $true)][string]$Path)

    $cur = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    while ($cur) {
        if ((Split-Path -Leaf $cur) -eq 'GDrive') { return $cur }
        $parent = Split-Path -Parent $cur
        if (-not $parent -or $parent -eq $cur) { break }
        $cur = $parent
    }
    return ''
}

# A fixture root inside the mirror is a defect, not a style choice: DriveFS
# administers that space while it synchronises. Refuse loudly rather than
# quietly building the laboratory in the battlefield again.
function Assert-ScratchOutsideMirror {
    param(
        [Parameter(Mandatory = $true)][string]$ScratchRoot,
        [Parameter(Mandatory = $true)][string]$ProjectRoot
    )

    $s = [System.IO.Path]::GetFullPath($ScratchRoot).TrimEnd('\')
    $p = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')

    $boundaries = @($p)
    $mirror = Get-DriveMirrorRoot -Path $p
    if ($mirror) { $boundaries += $mirror }

    foreach ($b in $boundaries) {
        if ($s.Equals($b, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw ('SCRATCH_ROOT_ON_BOUNDARY=' + $s)
        }
        if ($s.StartsWith($b + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
            throw ('SCRATCH_ROOT_INSIDE_MIRROR=' + $s + ' boundary=' + $b)
        }
    }

    return $s
}
