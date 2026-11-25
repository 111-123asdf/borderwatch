param([switch]$Editor,[switch]$Playtest,[switch]$FeelLab,[string]$Stage="",[switch]$TowerLab)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath = Resolve-GodotBinary $projectRoot
$savedAppData = $env:APPDATA
$savedLocalAppData = $env:LOCALAPPDATA
try {
    if ($TowerLab -and -not $Editor) {
        try {
            $userDirectory = Join-Path $env:APPDATA 'Borderwatch'
            New-Item -ItemType Directory -Force -Path $userDirectory | Out-Null
            $probePath = Join-Path $userDirectory ([guid]::NewGuid().ToString('N') + '.tmp')
            $probe = [IO.File]::Open($probePath, 'CreateNew', 'Write', 'None', 4096, 'DeleteOnClose')
            $probe.Dispose()
        } catch {
            $localProfile = Join-Path $projectRoot '_local/tower-lab'
            $env:APPDATA = Join-Path $localProfile 'Roaming'
            $env:LOCALAPPDATA = Join-Path $localProfile 'Local'
            New-Item -ItemType Directory -Force -Path (Join-Path $env:APPDATA 'Borderwatch'), $env:LOCALAPPDATA | Out-Null
            [IO.File]::WriteAllText((Join-Path $localProfile '.gdignore'), '')
            Write-Warning "System save directory is unavailable. Using the project-local profile at $localProfile."
        }
    }
    if (-not $Editor) {
        & $enginePath --headless --editor --path $projectRoot --import --quit
        if ($LASTEXITCODE -ne 0) { throw 'Asset import failed. Open the editor and inspect errors.' }
    }
    $arguments = @('--path', $projectRoot)
    if ($Editor) { $arguments += '--editor' }
    $userArgs = @()
    if ($Playtest -and -not $Editor) { $userArgs += '--playtest' }
    if ($FeelLab -and -not $Editor) { $userArgs += '--feel-lab' }
    if ($TowerLab -and -not $Editor) {
        $userArgs += '--tower-lab'
        if (-not $Stage) { $Stage = 'forest' }
    }
    if ($Stage -and -not $Editor) { $userArgs += "--stage=$Stage" }
    if ($userArgs.Count -gt 0) {
        $arguments += '--'
        $arguments += $userArgs
    }
    & $enginePath @arguments
    $exitCode = $LASTEXITCODE
} finally {
    $env:APPDATA = $savedAppData
    $env:LOCALAPPDATA = $savedLocalAppData
}
exit $exitCode
