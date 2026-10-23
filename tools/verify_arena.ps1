$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath = Resolve-GodotBinary $projectRoot
$logDir = Join-Path $projectRoot 'test-results\arena'
$userRoot = Join-Path $projectRoot 'test-results\arena-user'
New-Item -ItemType Directory -Force -Path $logDir, (Join-Path $userRoot 'Roaming'), (Join-Path $userRoot 'Local') | Out-Null
$env:APPDATA = Join-Path $userRoot 'Roaming'
$env:LOCALAPPDATA = Join-Path $userRoot 'Local'
$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    & $enginePath --headless --editor --path $projectRoot --import --quit *> (Join-Path $logDir 'import.log')
    if ($LASTEXITCODE -ne 0) { throw 'Arena import failed.' }
    & $enginePath --headless --path $projectRoot --script res://tests/arena_tests.gd *> (Join-Path $logDir 'tests.log')
    $exitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previous
}
$bad = Select-String -Path (Join-Path $logDir 'tests.log') -Pattern 'SCRIPT ERROR:|Parse Error|ARENA FAIL' -ErrorAction SilentlyContinue
if ($bad) {
    $bad | ForEach-Object { Write-Host $_.Line }
    exit 1
}
Write-Host "Arena tests exit code: $exitCode"
exit $exitCode
