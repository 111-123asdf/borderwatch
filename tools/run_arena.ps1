param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath = Resolve-GodotBinary $projectRoot
# Normal play uses the user's normal Godot data directory. Test runners set
# their own isolated APPDATA; keeping saves under test-results would lose them
# when test output is cleaned and differs from launching the project directly.
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
