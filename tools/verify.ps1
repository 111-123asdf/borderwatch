$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath = Resolve-GodotBinary $projectRoot
$logs = Join-Path $projectRoot 'test-results\release'
$profile = Join-Path $projectRoot 'test-results\release-user'
New-Item -ItemType Directory -Force -Path $logs, (Join-Path $profile 'Roaming'), (Join-Path $profile 'Local') | Out-Null
Set-Content -LiteralPath (Join-Path $projectRoot 'test-results\.gdignore') -Value '' -Encoding ascii
$savedAppData = $env:APPDATA
$savedLocalAppData = $env:LOCALAPPDATA
$runTag=[guid]::NewGuid().ToString('N').Substring(0,8)
try {
    $env:APPDATA = Join-Path $profile 'Roaming'
    $env:LOCALAPPDATA = Join-Path $profile 'Local'
    $jobs = @()
    $jobs += ,@('--headless','--editor','--path',$projectRoot,'--import','--quit')
    $names = @('import')
    foreach ($test in @('v06_rules','v06_layout','v06_combat','v06_assets','v06_outcome','v08_doctrines','v08_economy','v08_waves','v08_integration','v09_campaign','v09_projectiles','v09_settlement_flow','v010_loadouts','v011_feel','v011_lab_cli','v012_feel','v012_lab_cli','v013_playtest','v013_playtest_cli','v015_stage3','v015_stage3_cli','v022_heroes','v023_monsters','v020_towers')) {
        $testArgs = @('--headless','--path',$projectRoot,'--script',"res://tests/$test.gd")
        if ($test -eq 'v013_playtest_cli') { $testArgs += @('--','--playtest') }
        if ($test -eq 'v015_stage3_cli') { $testArgs += @('--','--playtest','--stage=ruins') }
        if ($test -eq 'v06_outcome') { $testArgs += @('--fixed-fps','60') }
        if ($test -in @('v011_lab_cli','v012_lab_cli')) { $testArgs += @('--','--feel-lab') }
        if ($test -eq 'v020_towers') { $testArgs += @('--','--tower-lab') }
        $jobs += ,$testArgs
        $names += $test
    }
    $jobs += ,@('--headless','--path',$projectRoot,'--script','res://tests/v020_defense.gd','--fixed-fps','60')
    $names += 'v020_defense'
    $jobs += ,@('--headless','--path',$projectRoot,'--script','res://tests/v021_tower_roster.gd','--fixed-fps','60')
    $names += 'v021_tower_roster'
    $jobs += ,@('--headless','--path',$projectRoot,'--script','res://tests/v025_combat_and_vfx.gd','--fixed-fps','60')
    $names += 'v025_combat_and_vfx'
    $jobs += ,@('--headless','--path',$projectRoot,'--script','res://tests/v026_gameplay_and_polish.gd','--fixed-fps','60')
    $names += 'v026_gameplay_and_polish'
    $jobs += ,@('--headless','--path',$projectRoot,'--script','res://tests/v027_frontend_ui.gd','--fixed-fps','60')
    $names += 'v027_frontend_ui'
    $jobs += ,@('--headless','--path',$projectRoot,'--script','res://tests/v028_passive_system.gd','--fixed-fps','60')
    $names += 'v028_passive_system'
    $jobs += ,@('--headless','--path',$projectRoot,'--script','res://tests/v029_chapters_and_legions.gd','--fixed-fps','60')
    $names += 'v029_chapters_and_legions'
    $jobs += ,@('--headless','--path',$projectRoot,'--script','res://tests/v030_rift_and_passives.gd','--fixed-fps','60')
    $names += 'v030_rift_and_passives'
    $jobs += ,@('--headless','--path',$projectRoot,'--script','res://tests/v030_se_balance_proof.gd','--fixed-fps','60')
    $names += 'v030_se_balance_proof'
    for ($index = 0; $index -lt $jobs.Count; $index++) {
        $caseProfile=Join-Path $profile ($names[$index]+'-'+$runTag)
        $env:APPDATA=Join-Path $caseProfile 'Roaming'
        $env:LOCALAPPDATA=Join-Path $caseProfile 'Local'
        New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $arguments = $jobs[$index]
        $output = & $enginePath @arguments 2>&1
        $code = $LASTEXITCODE
        $ErrorActionPreference = $previous
        $output | Set-Content -LiteralPath (Join-Path $logs ($names[$index] + '.log')) -Encoding utf8
        # Godot prints a benign "Failed to read the root certificate store" warning on stderr
        # in restricted Windows sessions; it is not produced by project code.
        $errors = $output | Where-Object { "$_" -match 'SCRIPT ERROR:|Parse Error|FAIL:|FAILURES: [1-9]|instances were leaked' -or ("$_" -match '^ERROR:' -and "$_" -notmatch 'Failed to read the root certificate store') }
        if ($code -ne 0 -or $errors) { $output | Write-Output; throw "Verification failed: $($names[$index])" }
        $output | Select-String 'CHECKS' | Write-Output
    }
} finally {
    $env:APPDATA = $savedAppData
    $env:LOCALAPPDATA = $savedLocalAppData
}
Write-Output 'SOURCE VERIFICATION PASSED'
