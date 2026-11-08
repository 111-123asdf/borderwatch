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
try {
    $env:APPDATA=Join-Path $isolated 'Roaming'
    $env:LOCALAPPDATA=Join-Path $isolated 'Local'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA -Force | Out-Null
    $jobs=@()
    foreach($name in @('v06_rules','v06_layout','v06_combat','v06_assets','v06_outcome','v06_export_audit')) {
        $jobs+=,@($name,@())
    }
    if($FullPlaythrough) {
        foreach($heroKey in @('knight','ranger','mage')) {
            foreach($stageKey in @('forest','creek')) {
                $jobs+=,@('v06_playthrough',@(('--hero='+$heroKey),('--level='+$stageKey)))
            }
        }
    }
    foreach($job in $jobs) {
        $name=$job[0]
        $arguments=@('--headless','--path',$isolated,'--main-pack',$executable,'--script',(Join-Path $projectRoot ('tests\'+$name+'.gd')),'--fixed-fps','60')
        if($job[1].Count -gt 0) {$arguments+=@('--')+$job[1]}
        $previous=$ErrorActionPreference
        $ErrorActionPreference='Continue'
        $output=& $enginePath @arguments 2>&1
        $code=$LASTEXITCODE
        $ErrorActionPreference=$previous
        $logName='export-'+$name+('-'+($job[1] -join '-')).Replace('--','').Replace('=','-')+'.log'
        $output | Set-Content -LiteralPath (Join-Path $projectRoot ('test-results\'+$logName)) -Encoding utf8
        if($code -ne 0 -or ($output -match 'SCRIPT ERROR:|^ERROR:|FAILURES: [1-9]|FAIL:|instances were leaked')) {$output | Write-Output;throw ('Export validation failed: '+$name)}
        foreach($line in $output) {if("$line" -match 'CHECKS|NORMAL '){Write-Output "$line"}}
    }
} finally {
    $env:APPDATA=$savedAppData
    $env:LOCALAPPDATA=$savedLocalAppData
}
Write-Output ('ISOLATED EXPORT VERIFICATION PASSED: '+$isolated)
