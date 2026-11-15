param([switch]$Editor,[switch]$Playtest)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath = Resolve-GodotBinary $projectRoot
if (-not $Editor) {
    & $enginePath --headless --editor --path $projectRoot --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Asset import failed. Open the editor and inspect errors.' }
}
$arguments = @('--path', $projectRoot)
if ($Editor) { $arguments += '--editor' }
if ($Playtest -and -not $Editor) { $arguments += @('--','--playtest') }
& $enginePath @arguments
exit $LASTEXITCODE
