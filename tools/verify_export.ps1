param([switch]$FullPlaythrough)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath=Resolve-GodotBinary $projectRoot
$sourceExecutable=Join-Path $projectRoot 'builds\windows\Borderwatch.exe'
if (-not (Test-Path -LiteralPath $sourceExecutable)) {throw 'Run tools/export.ps1 first.'}
$isolated=Join-Path $projectRoot 'test-results\export-isolated'
New-Item -ItemType Directory -Path $isolated -Force | Out-Null
$executable=Join-Path $isolated 'Borderwatch.exe'
Copy-Item -LiteralPath $sourceExecutable -Destination $executable -Force
$savedAppData=$env:APPDATA
$savedLocalAppData=$env:LOCALAPPDATA
$runTag=[guid]::NewGuid().ToString('N').Substring(0,8)
try {
    $env:APPDATA=Join-Path $isolated 'Roaming'
    $env:LOCALAPPDATA=Join-Path $isolated 'Local'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA -Force | Out-Null
    $jobs=@()
    foreach($name in @('v06_rules','v06_layout','v06_combat','v06_assets','v06_outcome','v07_perks','v08_doctrines','v08_camp','v08_economy','v08_waves','v08_integration','v09_campaign','v09_projectiles','v09_settlement_flow','v010_loadouts','v011_feel','v011_lab_cli','v012_feel','v012_lab_cli','v013_playtest','v013_playtest_cli','v015_stage3','v015_stage3_cli','v017_rules','v06_export_audit')) {
        $jobs+=,@($name,@())
    }
    if($FullPlaythrough) {
      foreach($rank in @(1,5)) {
        foreach($heroKey in @('knight','ranger','mage')) {
            foreach($stageKey in @('forest','creek','ruins')) {
                $jobs+=,@('v06_playthrough',@(('--hero='+$heroKey),('--level='+$stageKey),('--hero-level='+$rank)))
            }
        }
      }
    }
    foreach($job in $jobs) {
        $name=$job[0]
        $caseName=($name+'-'+($job[1] -join '-')).Replace('--','').Replace('=','-')
        $caseProfile=Join-Path $isolated ('profiles\'+$caseName+'-'+$runTag)
        $env:APPDATA=Join-Path $caseProfile 'Roaming'
        $env:LOCALAPPDATA=Join-Path $caseProfile 'Local'
        New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
        $arguments=@('--headless','--path',$isolated,'--main-pack',$executable,'--script',(Join-Path $projectRoot ('tests\'+$name+'.gd')),'--fixed-fps','60')
        if($job[1].Count -gt 0) {$arguments+=@('--')+$job[1]}
        if($name -eq 'v013_playtest_cli') {$arguments+=@('--','--playtest')}
        if($name -eq 'v015_stage3_cli') {$arguments+=@('--','--playtest','--stage=ruins')}
        if($name -in @('v011_lab_cli','v012_lab_cli')) {$arguments+=@('--','--feel-lab')}
        $previous=$ErrorActionPreference
        $ErrorActionPreference='Continue'
        $output=& $enginePath @arguments 2>&1
        $code=$LASTEXITCODE
        $ErrorActionPreference=$previous
        $logName='export-'+$name+('-'+($job[1] -join '-')).Replace('--','').Replace('=','-')+'.log'
        $output | Set-Content -LiteralPath (Join-Path $projectRoot ('test-results\'+$logName)) -Encoding utf8
        # Ignore only the OS certificate-store warning; game and script errors still fail.
        $errors=$output | Where-Object { "$_" -match 'SCRIPT ERROR:|Parse Error|FAILURES: [1-9]|FAIL:|instances were leaked' -or ("$_" -match '^ERROR:' -and "$_" -notmatch 'Failed to read the root certificate store') }
        if($code -ne 0 -or $errors) {$output | Write-Output;throw ('Export validation failed: '+$name)}
        foreach($line in $output) {if("$line" -match 'CHECKS|NORMAL '){Write-Output "$line"}}
    }
} finally {
    $env:APPDATA=$savedAppData
    $env:LOCALAPPDATA=$savedLocalAppData
}
Write-Output ('ISOLATED EXPORT VERIFICATION PASSED: '+$isolated)
