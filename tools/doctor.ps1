$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath = Resolve-GodotBinary $projectRoot
$version = (& $enginePath --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -notlike '4.7.2.stable*') { throw "Expected Godot 4.7.2 Standard; got $version" }
foreach ($relative in @('project.godot', 'scenes/main.tscn', 'scripts/game.gd', 'assets/ui/hero-run-0.3.png', 'docs/DEVELOPMENT.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $relative) -PathType Leaf)) { throw "Missing project file: $relative" }
}
$templates = Join-Path $projectRoot 'toolchain/godot/editor_data/export_templates/4.7.2.stable'
$bundledTemplates = (Test-Path -LiteralPath (Join-Path $templates 'windows_debug_x86_64.exe')) -and (Test-Path -LiteralPath (Join-Path $templates 'windows_release_x86_64.exe'))
Write-Output "Project: $projectRoot"
Write-Output "Engine: $enginePath"
Write-Output "Version: $version"
Write-Output "PowerShell: $($PSVersionTable.PSVersion)"
Write-Output "Bundled Windows x64 templates: $bundledTemplates"
if (-not $bundledTemplates) { Write-Warning 'Bundled templates absent. Configure templates for your external editor before exporting.' }
Write-Output 'Core environment OK. Run verify.ps1 to import assets and test source.'
