$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath = Resolve-GodotBinary $projectRoot
$savedAppData=$env:APPDATA
$savedLocalAppData=$env:LOCALAPPDATA
try {
$profile=Join-Path $projectRoot 'test-results\export-user'
$env:APPDATA=Join-Path $profile 'Roaming'
$env:LOCALAPPDATA=Join-Path $profile 'Local'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'test-results') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $projectRoot 'test-results\.gdignore') -Value '' -Encoding ascii
$import = & $enginePath --headless --editor --path $projectRoot --import --quit 2>&1
$import | Set-Content -LiteralPath (Join-Path $projectRoot 'test-results\export-import.log') -Encoding utf8
if ($LASTEXITCODE -ne 0 -or ($import -match 'SCRIPT ERROR:|^ERROR:')) { $import | Write-Output; throw 'Asset import failed.' }
$preflight = & $enginePath --headless --path $projectRoot --quit-after 2 2>&1
if ($LASTEXITCODE -ne 0 -or ($preflight -match 'SCRIPT ERROR:|^ERROR:')) { $preflight | Write-Output; throw 'Startup validation failed.' }
$buildDirectory = Join-Path $projectRoot 'builds\windows'
New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
Set-Content -LiteralPath (Join-Path $projectRoot 'builds\.gdignore') -Value '' -Encoding ascii
$output = & $enginePath --headless --path $projectRoot --export-release 'Windows Desktop' (Join-Path $buildDirectory 'Borderwatch.exe') 2>&1
$code = $LASTEXITCODE
$output | Set-Content -LiteralPath (Join-Path $projectRoot 'test-results\export.log') -Encoding utf8
if ($code -ne 0 -or ($output -match 'SCRIPT ERROR:|^ERROR:')) { $output | Write-Output; throw 'Windows export failed.' }
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\playtest.txt') -Destination (Join-Path $buildDirectory 'playtest.txt') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\credits.txt') -Destination (Join-Path $buildDirectory 'credits.txt') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\godot-copyright.txt') -Destination (Join-Path $buildDirectory 'godot-copyright.txt') -Force
[IO.File]::WriteAllText((Join-Path $buildDirectory 'Play.bat'), "@echo off`r`nstart `"`" `"%~dp0Borderwatch.exe`" -- --playtest`r`n", [Text.Encoding]::ASCII)
$heroLabLauncher = Join-Path $buildDirectory 'Play-HeroLab.bat'
[IO.File]::WriteAllText($heroLabLauncher, "@echo off`r`nstart `"`" `"%~dp0Borderwatch.exe`" -- --feel-lab`r`n", [Text.Encoding]::ASCII)
$zipPath = Join-Path $projectRoot 'builds\Borderwatch-v0.23-Windows.zip'
Compress-Archive -LiteralPath (Join-Path $buildDirectory 'Borderwatch.exe'), (Join-Path $buildDirectory 'Play.bat'), (Join-Path $buildDirectory 'playtest.txt'), (Join-Path $buildDirectory 'credits.txt'), (Join-Path $buildDirectory 'godot-copyright.txt'), $heroLabLauncher -DestinationPath $zipPath -Force
Get-Item -LiteralPath (Join-Path $buildDirectory 'Borderwatch.exe'), $zipPath | Select-Object FullName, Length
} finally {
    $env:APPDATA=$savedAppData
    $env:LOCALAPPDATA=$savedLocalAppData
}
