$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath=Resolve-GodotBinary $projectRoot
$isolated=Join-Path $projectRoot 'test-results\export-isolated'
$pack=Join-Path $isolated 'Borderwatch.exe'
if (-not (Test-Path -LiteralPath $pack)) { throw 'Export and verify the isolated executable first.' }
$work=Join-Path $projectRoot 'test-results\closeout-movie'
New-Item -ItemType Directory -Force -Path $work | Out-Null
$savedAppData=$env:APPDATA
$savedLocalAppData=$env:LOCALAPPDATA
try {
    foreach ($segment in @(@('ranger','creek'),@('knight','ruins'),@('mage','ruins'))) {
        $name=$segment[0]+'-'+$segment[1]
        $env:APPDATA=Join-Path $work ($name+'\Roaming')
        $env:LOCALAPPDATA=Join-Path $work ($name+'\Local')
        New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
        $arguments=@('--path',$isolated,'--main-pack',$pack,'--script',(Join-Path $projectRoot 'tests\closeout_demo.gd'),'--resolution','1280x720','--fixed-fps','30','--write-movie',(Join-Path $work ($name+'.avi')),'--',('--hero='+$segment[0]),('--level='+$segment[1]),'--hero-level=5')
        $output=& $enginePath @arguments 2>&1
        $code=$LASTEXITCODE
        $output | Set-Content -LiteralPath (Join-Path $work ($name+'.log')) -Encoding utf8
        if ($code -ne 0 -or ($output -match 'SCRIPT ERROR:|^ERROR:|instances were leaked')) { throw ('Recording failed: '+$name) }
        $output | Select-String 'CLOSEOUT DEMO' | Write-Output
    }
    & python (Join-Path $PSScriptRoot 'encode_closeout.py')
    if ($LASTEXITCODE -ne 0) { throw 'Short video encoding failed.' }
} finally { $env:APPDATA=$savedAppData; $env:LOCALAPPDATA=$savedLocalAppData }
