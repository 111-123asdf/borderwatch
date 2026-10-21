$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath = Resolve-GodotBinary $projectRoot
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'test-results') -Force | Out-Null
$buildDirectory = Join-Path $projectRoot 'builds\windows-core-slice'
$executable = Join-Path $buildDirectory 'Borderwatch.exe'
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw 'Build not found. Run tools/export.ps1 first.' }
Push-Location -LiteralPath $buildDirectory
try {
    foreach ($test in @('export_audit', 'game_tests', 'combat_tests')) {
        $output = & $enginePath --headless --path $buildDirectory --main-pack $executable --script (Join-Path $projectRoot "tests\$test.gd") 2>&1
        $code = $LASTEXITCODE
        $output | Set-Content -LiteralPath (Join-Path $projectRoot "test-results\export-$test-0.3.log") -Encoding utf8
        if ($code -ne 0 -or ($output -match 'SCRIPT ERROR:|^ERROR:|FAIL:')) { $output | Write-Output; throw "Export check failed: $test" }
        $output | Write-Output
    }
    foreach ($hero in @('knight', 'ranger', 'mage')) {
        $output = & $enginePath --headless --path $buildDirectory --main-pack $executable --fixed-fps 60 --script (Join-Path $projectRoot 'tests\playthrough.gd') -- "--hero=$hero" --export-check 2>&1
        $code = $LASTEXITCODE
        $output | Set-Content -LiteralPath (Join-Path $projectRoot "test-results\export-full-$hero-0.3.log") -Encoding utf8
        if ($code -ne 0 -or ($output -match 'SCRIPT ERROR:|^ERROR:|FAIL:')) { $output | Write-Output; throw "Export playthrough failed: $hero" }
        $output | Write-Output
    }
} finally {
    Pop-Location
}
