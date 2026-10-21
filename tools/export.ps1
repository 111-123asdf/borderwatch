$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath = Resolve-GodotBinary $projectRoot
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'test-results') -Force | Out-Null
$import = & $enginePath --headless --editor --path $projectRoot --import --quit 2>&1
$import | Set-Content -LiteralPath (Join-Path $projectRoot 'test-results\export-import.log') -Encoding utf8
if ($LASTEXITCODE -ne 0 -or ($import -match 'SCRIPT ERROR:|^ERROR:')) { $import | Write-Output; throw 'Asset import failed.' }
$preflight = & $enginePath --headless --path $projectRoot --quit-after 2 2>&1
if ($LASTEXITCODE -ne 0 -or ($preflight -match 'SCRIPT ERROR:|^ERROR:')) { $preflight | Write-Output; throw 'Startup validation failed.' }
$buildDirectory = Join-Path $projectRoot 'builds\windows-core-slice'
New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
$output = & $enginePath --headless --path $projectRoot --export-release 'Windows Desktop' (Join-Path $buildDirectory 'Borderwatch.exe') 2>&1
$code = $LASTEXITCODE
$output | Set-Content -LiteralPath (Join-Path $projectRoot 'test-results\export.log') -Encoding utf8
if ($code -ne 0 -or ($output -match 'SCRIPT ERROR:|^ERROR:')) { $output | Write-Output; throw 'Windows export failed.' }
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\playtest.txt') -Destination (Join-Path $buildDirectory 'playtest.txt') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\credits.txt') -Destination (Join-Path $buildDirectory 'credits.txt') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\godot-copyright.txt') -Destination (Join-Path $buildDirectory 'godot-copyright.txt') -Force
$zipPath = Join-Path $projectRoot 'builds\Borderwatch-core-slice-Windows.zip'
Compress-Archive -LiteralPath (Join-Path $buildDirectory 'Borderwatch.exe'), (Join-Path $buildDirectory 'playtest.txt'), (Join-Path $buildDirectory 'credits.txt'), (Join-Path $buildDirectory 'godot-copyright.txt') -DestinationPath $zipPath -Force
Get-Item -LiteralPath (Join-Path $buildDirectory 'Borderwatch.exe'), $zipPath | Select-Object FullName, Length
