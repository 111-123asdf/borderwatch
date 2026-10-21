function Resolve-GodotBinary([string]$ProjectRoot) {
    if ($env:GODOT_BIN) {
        if (Test-Path -LiteralPath $env:GODOT_BIN -PathType Leaf) {
            return (Resolve-Path -LiteralPath $env:GODOT_BIN).Path
        }
        $command = Get-Command -Name $env:GODOT_BIN -CommandType Application -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
        throw 'GODOT_BIN is set but does not identify an executable. Set it to a full Godot executable path or clear it.'
    }
    foreach ($name in @('Godot_v4.7.2-stable_win64_console.exe', 'Godot_v4.7.2-stable_win64.exe')) {
        $candidate = Join-Path $ProjectRoot ('toolchain\godot\' + $name)
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    foreach ($name in @('godot_console', 'godot4_console', 'godot', 'godot4')) {
        $command = Get-Command -Name $name -CommandType Application -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }
    throw 'Godot was not found. Use the bundled developer handoff toolchain, install Godot 4.7.2 Standard on PATH, or set GODOT_BIN.'
}
