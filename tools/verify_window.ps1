$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath=Resolve-GodotBinary $projectRoot
$profile=Join-Path $projectRoot 'test-results\window-user'
$savedAppData=$env:APPDATA
$savedLocalAppData=$env:LOCALAPPDATA
try {
    $env:APPDATA=Join-Path $profile 'Roaming'
    $env:LOCALAPPDATA=Join-Path $profile 'Local'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA -Force | Out-Null
    foreach($size in @('1600x900','1024x576')) {
        $arguments=@('--path',$projectRoot,'--resolution',$size,'--script','res://tests/v06_window.gd')
        if($size -eq '1024x576') {$arguments+=@('--','--small')}
        $output=& $enginePath @arguments 2>&1
        $code=$LASTEXITCODE
        $output | Set-Content -LiteralPath (Join-Path $projectRoot ('test-results\window-'+$size+'.log')) -Encoding utf8
        if($code -ne 0 -or ($output -match 'SCRIPT ERROR:|^ERROR:|FAILURES: [1-9]')) {$output | Write-Output;throw ('Window check failed: '+$size)}
        foreach($line in $output) {if("$line" -match 'CHECKS'){Write-Output "$line"}}
    }
} finally {
    $env:APPDATA=$savedAppData
    $env:LOCALAPPDATA=$savedLocalAppData
}
