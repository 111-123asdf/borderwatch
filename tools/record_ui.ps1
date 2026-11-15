param([switch]$Packed)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath=Resolve-GodotBinary $projectRoot
$work=Join-Path $projectRoot ('test-results\ui-v013-movie-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$savedAppData=$env:APPDATA;$savedLocalAppData=$env:LOCALAPPDATA
try {
  $env:APPDATA=Join-Path $work 'Roaming';$env:LOCALAPPDATA=Join-Path $work 'Local'
  New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
  $arguments=@('--path',$projectRoot,'--script',(Join-Path $projectRoot 'tests\v013_demo.gd'),'--resolution','1600x900','--fixed-fps','30','--write-movie',(Join-Path $work 'ui.avi'))
  if($Packed){$arguments[1]=Join-Path $projectRoot 'test-results\export-isolated';$arguments+=@('--main-pack',(Join-Path $arguments[1] 'Borderwatch.exe'))}
  $arguments+=@('--','--playtest')
  $previous=$ErrorActionPreference;$ErrorActionPreference='Continue'
  $output=& $enginePath @arguments 2>&1;$code=$LASTEXITCODE;$ErrorActionPreference=$previous
  $output | Set-Content -LiteralPath (Join-Path $work 'record.log') -Encoding utf8
  if($code -ne 0 -or $output -match 'SCRIPT ERROR:|^ERROR:|instances were leaked'){$output | Write-Output;throw 'UI recording failed'}
  & python (Join-Path $PSScriptRoot 'encode_demo.py') (Join-Path $work 'ui.avi') (Join-Path (Split-Path $projectRoot -Parent) '界面流程演示.mp4') --audio
  if($LASTEXITCODE -ne 0){throw 'UI video encoding failed'}
  $previews=Join-Path (Split-Path $projectRoot -Parent) '界面预览'
  New-Item -ItemType Directory -Force -Path $previews | Out-Null
  Copy-Item -LiteralPath (Join-Path $env:APPDATA 'Borderwatch\v013-preview') -Destination (Join-Path $work 'captured-preview') -Recurse
  Get-ChildItem -LiteralPath (Join-Path $work 'captured-preview') -File -Filter '*.png' | Copy-Item -Destination $previews -Force
  Write-Output ('PREVIEW CAPTURES: '+$previews)
  Write-Output ('RECORD WORK: '+$work)
} finally {$env:APPDATA=$savedAppData;$env:LOCALAPPDATA=$savedLocalAppData}
