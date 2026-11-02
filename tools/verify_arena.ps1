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
    $importErrors = Select-String -Path (Join-Path $logDir 'import.log') -Pattern 'ERROR:|Parse Error' -ErrorAction SilentlyContinue | Where-Object { $_.Line -notmatch 'certificate store|CategoryInfo|RemoteException' }
    if ($importErrors) { throw 'Arena import log contains errors. See test-results/arena/import.log.' }
    & $enginePath --headless --path $projectRoot --script res://tests/arena_tests.gd *> (Join-Path $logDir 'tests.log')
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) {
        & $enginePath --headless --path $projectRoot --script res://tests/arena_visual_animation_tests.gd *> (Join-Path $logDir 'visual-tests.log')
        $exitCode = $LASTEXITCODE
    }
    if ($exitCode -eq 0) {
        & $enginePath --headless --path $projectRoot --script res://tests/arena_progression_tests.gd *> (Join-Path $logDir 'progression-tests.log')
        $exitCode = $LASTEXITCODE
    }
    if ($exitCode -eq 0) {
        & $enginePath --headless --path $projectRoot --script res://tests/arena_weapon_tests.gd *> (Join-Path $logDir 'weapon-tests.log')
        $exitCode = $LASTEXITCODE
    }
} finally {
    $ErrorActionPreference = $previous
}
$bad = Select-String -Path (Join-Path $logDir 'tests.log'), (Join-Path $logDir 'visual-tests.log'), (Join-Path $logDir 'progression-tests.log'), (Join-Path $logDir 'weapon-tests.log') -Pattern 'ERROR:|Parse Error|ARENA FAIL|VISUAL FAIL|PROGRESSION FAIL|WEAPON FAIL' -ErrorAction SilentlyContinue | Where-Object { $_.Line -notmatch 'certificate store|CategoryInfo|RemoteException' }
if ($bad) {
    $bad | ForEach-Object { Write-Host $_.Line }
    exit 1
}
Write-Host "Arena tests exit code: $exitCode"
exit $exitCode
