param([switch]$Push)
$ErrorActionPreference='Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
function Git-Step([string[]]$Arguments) {
    & git @Arguments
    if ($LASTEXITCODE -ne 0) { throw ('Git failed: '+($Arguments -join ' ')) }
}
$audit=Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) '交付核对.json'
if (-not (Test-Path -LiteralPath $audit)) { throw 'Missing reviewed source manifest. Rebuild the closeout handoff first.' }
& python tools/audit_submission.py --verify $audit
if ($LASTEXITCODE -ne 0) { throw 'Source changed after review. Stop and re-audit.' }
Git-Step -Arguments @('fetch','origin')
$review=Get-Content -Raw -Encoding UTF8 -LiteralPath $audit | ConvertFrom-Json
$upstream=(& git rev-parse origin/main).Trim()
if ($upstream -ne $review.base_main) { throw 'Remote main changed after review. Stop and review the new changes.' }
$branch='work/stage-closeout-20261117'
$current=(& git branch --show-current).Trim()
if ($current -ne $branch) {
    & git diff --quiet HEAD origin/main
    if ($LASTEXITCODE -ne 0) { throw 'Base source trees differ. Review integration before switching branches.' }
    Git-Step -Arguments @('switch','-c',$branch,'origin/main')
}
Git-Step -Arguments @('add','--all')
& python tools/audit_submission.py --verify $audit --staged
if ($LASTEXITCODE -ne 0) { throw 'Staged tree differs from reviewed deliverable.' }
Git-Step -Arguments @('commit','-m','完成v0.19阶段收尾：统一版本、验证、精简工程与演示工具')
Git-Step -Arguments @('status','--short')
& python tools/package_source.py --audit $audit
if ($LASTEXITCODE -ne 0) { throw 'Commit succeeded, but source ZIP update failed. Do not send the old ZIP.' }
if ($Push) { Git-Step -Arguments @('push','-u','origin',$branch) }
Write-Output 'Commit and source ZIP complete. If pushed, create a PR to main in GitHub. No force push is used.'
