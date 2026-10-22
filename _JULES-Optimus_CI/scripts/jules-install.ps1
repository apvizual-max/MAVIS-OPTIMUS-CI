# jules-install.ps1
# Installs the Jules bridge into a repository.
#
# What it does, per repo:
#   1. creates the 'jules' label (or updates it)
#   2. installs .github/workflows/jules.yml   (the trigger)
#   3. installs .github/workflows/verify.yml  (the nightly verification)
#   4. installs JULES-CONTEXT.md at repo root (the rules, readable by Jules
#      on its own initiative, not only through our issue bodies)
#   5. checks whether JULES_API_KEY exists as a repo secret and reports the
#      exact command Popy must run if it does not
#
# IMPORTANT: steps 1-4 write to GitHub. That is a PUSH. It needs R0.
# The default mode is a PLAN. Use -Apply to execute.
#
# Usage:
#   powershell -NoProfile -File jules-install.ps1 -Repo MAVIS-OPTIMUS-CI
#   powershell -NoProfile -File jules-install.ps1 -Repo MAVIS-OPTIMUS-CI -Apply
#
# ASCII ONLY: executed by Windows PowerShell 5.1.

param(
    [Parameter(Mandatory = $true)][string]$Repo,
    [switch]$Apply,
    [switch]$SkipContext,
    [switch]$SkipVerifyWorkflow
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'jules-lib.ps1')

function Get-ContentSha {
    param([string]$RepoName, [string]$Path)
    $res = Invoke-Gh -GhArgs @('api', ('repos/apvizual-max/' + $RepoName + '/contents/' + $Path))
    if (-not $res.Ok) { return '' }
    try {
        $obj = $res.Out | ConvertFrom-Json
        return [string]$obj.sha
    } catch { return '' }
}

function Set-RepoFile {
    param(
        [string]$RepoName,
        [string]$Path,
        [string]$Content,
        [string]$Branch,
        [string]$Message
    )
    $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Content))
    $sha = Get-ContentSha -RepoName $RepoName -Path $Path
    $body = [PSCustomObject]@{
        message = $Message
        content = $b64
        branch  = $Branch
    }
    if ($sha) { $body | Add-Member -NotePropertyName 'sha' -NotePropertyValue $sha }

    $jsonFile = New-JulesTempFile -Suffix '.json'
    try {
        $enc = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($jsonFile, ($body | ConvertTo-Json -Depth 4), $enc)
        $res = Invoke-Gh -GhArgs @('api', '--method', 'PUT',
                                   ('repos/apvizual-max/' + $RepoName + '/contents/' + $Path),
                                   '--input', $jsonFile)
        if (-not $res.Ok) {
            Write-JulesLog -Message ('write failed for ' + $Path + ': ' + $res.Err) -Level 'ERROR'
            return $false
        }
        $verb = 'created'
        if ($sha) { $verb = 'updated' }
        Write-JulesLog -Message ($verb + ' ' + $Path + ' in ' + $RepoName) -Level 'STEP'
        return $true
    } finally {
        if (Test-Path -LiteralPath $jsonFile) { Remove-Item -LiteralPath $jsonFile -Force -ErrorAction SilentlyContinue }
    }
}

function Main {
    Start-JulesLog -Name 'jules-install'

    if (-not (Assert-Gh)) { return 2 }

    $registry = Get-RepoRegistry
    $entry = Get-RepoEntry -Name $Repo -Registry $registry
    if (-not $entry) {
        Write-JulesLog -Message ('repo not in registry: ' + $Repo) -Level 'ERROR'
        return 2
    }
    $branch = $entry.branch
    Write-JulesLog -Message ('target: apvizual-max/' + $Repo + ' branch ' + $branch) -Level 'STEP'

    # --- 1. label --------------------------------------------------------
    $labelRes = Invoke-Gh -GhArgs @('label', 'list', '-R', ('apvizual-max/' + $Repo), '--limit', '100', '--json', 'name')
    $hasLabel = $false
    if ($labelRes.Ok) {
        $labels = $labelRes.Out | ConvertFrom-Json
        foreach ($l in $labels) { if ($l.name -eq 'jules') { $hasLabel = $true } }
    }
    Write-JulesLog -Message ('label jules: ' + $(if ($hasLabel) { 'exista' } else { 'LIPSASTE' })) -Level 'STEP'

    if ($Apply) {
        $argsLabel = @('label', 'create', 'jules', '-R', ('apvizual-max/' + $Repo),
                       '--color', '0E8A16', '--description', 'declanseaza Jules: eticheta porneste agentul',
                       '--force')
        $lr = Invoke-Gh -GhArgs $argsLabel
        if ($lr.Ok) { Write-JulesLog -Message 'label jules asigurat' -Level 'STEP' }
        else { Write-JulesLog -Message ('label create failed: ' + $lr.Err) -Level 'ERROR' }
    } else {
        Write-JulesLog -Message 'PLAN: would create/update label jules' -Level 'STEP'
    }

    # --- 2. jules.yml ----------------------------------------------------
    $wfSrc = Join-Path (Get-JulesRoot) 'workflows\jules.yml'
    $verifySrc = Join-Path (Get-JulesRoot) 'workflows\verify.yml'
    $ctxSrc = Join-Path (Get-JulesRoot) 'config\jules-context.md'

    $wf = [System.IO.File]::ReadAllText($wfSrc, [System.Text.Encoding]::UTF8)
    if ($Apply) {
        if (-not (Set-RepoFile -RepoName $Repo -Path '.github/workflows/jules.yml' -Content $wf -Branch $branch -Message 'Jules: workflow de declansare cu garduri de cota')) {
            return 6
        }
    } else {
        Write-JulesLog -Message ('PLAN: would write .github/workflows/jules.yml (' + $wf.Length + ' chars)') -Level 'STEP'
    }

    # --- 3. verify.yml ---------------------------------------------------
    if (Test-Path -LiteralPath $verifySrc) {
        $vw = [System.IO.File]::ReadAllText($verifySrc, [System.Text.Encoding]::UTF8)
        if ($Apply) {
            if (-not (Set-RepoFile -RepoName $Repo -Path '.github/workflows/verify.yml' -Content $vw -Branch $branch -Message 'Jules: verificare nocturna cu porti reale')) {
                return 6
            }
        } else {
            Write-JulesLog -Message ('PLAN: would write .github/workflows/verify.yml (' + $vw.Length + ' chars)') -Level 'STEP'
        }
    }
    if ($SkipVerifyWorkflow) { Write-JulesLog -Message 'verify.yml skipped by flag' -Level 'WARN' }

    # --- 4. context pack -------------------------------------------------
    if (-not $SkipContext) {
        $ctx = [System.IO.File]::ReadAllText($ctxSrc, [System.Text.Encoding]::UTF8)
        $ctxHeader = '# JULES-CONTEXT.md' + "`n`n" + 'Regulile canonice ale proiectului, pentru Jules.' + "`n" +
                     'Sursa unica: MAVIS-OPTIMUS-CI/_JULES-Optimus_CI/config/jules-context.md' + "`n" +
                     'Regenerat de jules-install.ps1. Nu edita aici - edita la sursa.' + "`n`n"
        if ($Apply) {
            if (-not (Set-RepoFile -RepoName $Repo -Path 'JULES-CONTEXT.md' -Content ($ctxHeader + $ctx) -Branch $branch -Message 'Jules: contextul canonic al proiectului')) {
                return 6
            }
        } else {
            Write-JulesLog -Message ('PLAN: would write JULES-CONTEXT.md (' + $ctx.Length + ' chars)') -Level 'STEP'
        }
    }

    # --- 5. secret -------------------------------------------------------
    $secRes = Invoke-Gh -GhArgs @('secret', 'list', '-R', ('apvizual-max/' + $Repo), '--json', 'name')
    $hasSecret = $false
    if ($secRes.Ok) {
        $secs = $secRes.Out | ConvertFrom-Json
        foreach ($s in $secs) { if ($s.name -eq 'JULES_API_KEY') { $hasSecret = $true } }
    }
    if ($hasSecret) {
        Write-JulesLog -Message 'JULES_API_KEY: prezent' -Level 'STEP'
    } else {
        Write-JulesLog -Message ('JULES_API_KEY: LIPSASTE. Popy trebuie sa ruleze:') -Level 'ERROR'
        Write-JulesLog -Message ('  gh secret set JULES_API_KEY -R apvizual-max/' + $Repo) -Level 'ERROR'
    }

    $mode = 'PLAN'
    if ($Apply) { $mode = 'APPLIED' }
    Write-Output ('MODE=' + $mode)
    Write-Output ('REPO=' + $Repo)
    Write-Output ('BRANCH=' + $branch)
    Write-Output ('LABEL=' + $(if ($hasLabel) { 'exista' } else { 'creat' }))
    Write-Output ('SECRET=' + $(if ($hasSecret) { 'prezent' } else { 'LIPSASTE' }))
    return 0
}

$code = Main
exit $code
