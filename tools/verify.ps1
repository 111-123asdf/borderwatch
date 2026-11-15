$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath = Resolve-GodotBinary $projectRoot
$logs = Join-Path $projectRoot 'test-results\release'
$profile = Join-Path $projectRoot 'test-results\release-user'
New-Item -ItemType Directory -Force -Path $logs, (Join-Path $profile 'Roaming'), (Join-Path $profile 'Local') | Out-Null
$savedAppData = $env:APPDATA
$savedLocalAppData = $env:LOCALAPPDATA
$runTag=[guid]::NewGuid().ToString('N').Substring(0,8)
try {
    $env:APPDATA = Join-Path $profile 'Roaming'
    $env:LOCALAPPDATA = Join-Path $profile 'Local'
    $jobs = @()
    $jobs += ,@('--headless','--editor','--path',$projectRoot,'--import','--quit')
    $names = @('import')
    foreach ($test in @('v06_rules','v06_layout','v06_combat','v06_assets','v06_outcome','v07_perks','v08_doctrines','v08_camp','v08_economy','v08_waves','v08_integration','v09_campaign','v09_projectiles','v09_settlement_flow','v010_loadouts','v011_feel','v011_lab_cli','v012_feel','v012_lab_cli','v013_playtest','v013_playtest_cli')) {
        $testArgs = @('--headless','--path',$projectRoot,'--script',"res://tests/$test.gd")
        if ($test -eq 'v013_playtest_cli') { $testArgs += @('--','--playtest') }
        if ($test -eq 'v06_outcome') { $testArgs += @('--fixed-fps','60') }
        if ($test -in @('v011_lab_cli','v012_lab_cli')) { $testArgs += @('--','--feel-lab') }
        $jobs += ,$testArgs
        $names += $test
    }
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
