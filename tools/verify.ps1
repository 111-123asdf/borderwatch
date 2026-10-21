$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath = Resolve-GodotBinary $projectRoot
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'test-results') -Force | Out-Null
function Invoke-CheckedGodot([string[]]$GodotArguments, [string]$LogName) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $enginePath @GodotArguments 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    $logPath = Join-Path $projectRoot ('test-results\' + $LogName)
    $output | Set-Content -LiteralPath $logPath -Encoding utf8
    $problem = $output | Where-Object { $_ -match 'SCRIPT ERROR:|Parse Error|^ERROR:|FAIL:' }
    if ($code -ne 0 -or $problem) {
        $output | Write-Output
        throw "Godot check failed: $LogName"
    }
    $output | Select-String 'CHECKS:|boss_defeated' | ForEach-Object { $_.Line }
}
Invoke-CheckedGodot @('--headless', '--editor', '--path', $projectRoot, '--import', '--quit') 'import.log'
Invoke-CheckedGodot @('--headless', '--path', $projectRoot, '--script', 'res://tests/game_tests.gd') 'rules.log'
Invoke-CheckedGodot @('--headless', '--path', $projectRoot, '--script', 'res://tests/combat_tests.gd') 'combat.log'
foreach ($hero in @('knight', 'ranger', 'mage')) {
    Invoke-CheckedGodot @('--headless', '--path', $projectRoot, '--fixed-fps', '60', '--script', 'res://tests/playthrough.gd', '--', "--hero=$hero") "playthrough-$hero.log"
}
Invoke-CheckedGodot @('--headless', '--path', $projectRoot, '--fixed-fps', '60', '--script', 'res://tests/defense_balance.gd') 'defense_balance.log'
Invoke-CheckedGodot @('--headless', '--path', $projectRoot, '--fixed-fps', '60', '--script', 'res://tests/loop_viability.gd', '--', '--mode=tower') 'loop-tower.log'
Invoke-CheckedGodot @('--headless', '--path', $projectRoot, '--fixed-fps', '60', '--script', 'res://tests/loop_viability.gd', '--', '--mode=hero') 'loop-hero.log'
Invoke-CheckedGodot @('--headless', '--path', $projectRoot, '--fixed-fps', '60', '--script', 'res://tests/loop_viability.gd', '--', '--mode=no_explore') 'loop-no-explore.log'
Invoke-CheckedGodot @('--headless', '--path', $projectRoot, '--fixed-fps', '60', '--script', 'res://tests/loop_viability.gd', '--', '--mode=minimal') 'loop-minimal.log'
