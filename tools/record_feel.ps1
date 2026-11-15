param([switch]$Packed,[switch]$Battle,[ValidateSet('knight','ranger','mage')][string]$Hero='knight')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath=Resolve-GodotBinary $projectRoot
$work=Join-Path $projectRoot ('test-results\feel-'+$Hero+$(if($Battle){'-battle-movie'}else{'-movie'}))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$savedAppData=$env:APPDATA
$savedLocalAppData=$env:LOCALAPPDATA
try {
    $env:APPDATA=Join-Path $work 'Roaming'
    $env:LOCALAPPDATA=Join-Path $work 'Local'
    New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    $scriptName=if($Battle){'tests\v06_playthrough.gd'}else{'tests\v012_demo.gd'}
    $arguments=@('--path',$projectRoot,'--script',(Join-Path $projectRoot $scriptName),'--resolution','1280x720','--fixed-fps','30','--write-movie',(Join-Path $work 'feel.avi'))
    if($Packed){$arguments[1]=Join-Path $projectRoot 'test-results\export-isolated';$arguments+=@('--main-pack',(Join-Path $arguments[1] 'Borderwatch.exe'))}
    if($Battle){$arguments+=@('--',('--hero='+$Hero),'--level=forest','--hero-level=5','--preview')}
    else {$arguments+=@('--',('--demo-hero='+$Hero))}
    $previous=$ErrorActionPreference;$ErrorActionPreference='Continue'
    $output=& $enginePath @arguments 2>&1;$code=$LASTEXITCODE;$ErrorActionPreference=$previous
    $output | Set-Content -LiteralPath (Join-Path $work 'record.log') -Encoding UTF8
    if($code -ne 0 -or ($output -match 'SCRIPT ERROR:|^ERROR:|instances were leaked')){$output | Write-Output;throw 'Feel recording failed'}
    $heroName=@{knight='骑士';ranger='游侠';mage='法师'}[$Hero]
    $movieName=$heroName+$(if($Battle){'首关实战.mp4'}else{'手感对照.mp4'})
    $encodeArgs=@((Join-Path $PSScriptRoot 'encode_demo.py'),(Join-Path $work 'feel.avi'),(Join-Path (Split-Path $projectRoot -Parent) $movieName),'--audio')
    if($Battle){$encodeArgs+='--duration=30'}
    & python @encodeArgs
    if($LASTEXITCODE -ne 0){throw 'Audible MP4 encoding failed'}
} finally {$env:APPDATA=$savedAppData;$env:LOCALAPPDATA=$savedLocalAppData}
