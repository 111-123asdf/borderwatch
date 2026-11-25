$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath=Resolve-GodotBinary $projectRoot
$profile=Join-Path $projectRoot 'test-results\window-user'
New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot 'test-results') | Out-Null
Set-Content -LiteralPath (Join-Path $projectRoot 'test-results\.gdignore') -Value '' -Encoding ascii
$savedAppData=$env:APPDATA
$savedLocalAppData=$env:LOCALAPPDATA
try {
    $env:APPDATA=Join-Path $profile 'Roaming'
    $env:LOCALAPPDATA=Join-Path $profile 'Local'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA -Force | Out-Null
    foreach($size in @('1600x900','1024x576')) {
      foreach($testName in @('v06_window','v08_integration_window','v09_window','v010_window','v011_window','v012_window','v013_window','v015_window','saltport_window','v021_tower_roster')) {
        $arguments=@('--path',$projectRoot,'--resolution',$size,'--script',('res://tests/'+$testName+'.gd'))
        if($size -eq '1024x576') {$arguments += @('--','--small')}
        $previous=$ErrorActionPreference
        $ErrorActionPreference='Continue'
        $output=& $enginePath @arguments 2>&1
        $code=$LASTEXITCODE
        $ErrorActionPreference=$previous
        $output | Set-Content -LiteralPath (Join-Path $projectRoot ('test-results\'+$testName+'-'+$size+'.log')) -Encoding utf8
        $errors=$output | Where-Object { "$_" -match 'SCRIPT ERROR:|Parse Error|FAIL:|FAILURES: [1-9]|instances were leaked' -or ("$_" -match '^ERROR:' -and "$_" -ne 'ERROR: Failed to read the root certificate store.') }
        if($code -ne 0 -or $errors) {$output | Write-Output;throw ('Window check failed: '+$testName+' '+$size)}
        foreach($line in $output) {if("$line" -match 'CHECKS'){Write-Output "$line"}}
      }
    }
} finally {
    $env:APPDATA=$savedAppData
    $env:LOCALAPPDATA=$savedLocalAppData
}
