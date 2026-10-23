param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath = Resolve-GodotBinary $projectRoot
$userRoot = Join-Path $projectRoot 'test-results\arena-user'
New-Item -ItemType Directory -Force -Path (Join-Path $userRoot 'Roaming'), (Join-Path $userRoot 'Local') | Out-Null
$env:APPDATA = Join-Path $userRoot 'Roaming'
$env:LOCALAPPDATA = Join-Path $userRoot 'Local'
$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    & $enginePath --headless --editor --path $projectRoot --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Asset import failed. Open the editor and inspect errors.' }
    & $enginePath --path $projectRoot res://scenes/arena.tscn
    exit $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previous
}
