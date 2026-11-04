param([string]$GodotBinary = $env:GODOT_BIN)
$ErrorActionPreference = 'Stop'
if (-not $GodotBinary) {
    $installedGodot = Get-Command godot -ErrorAction SilentlyContinue
    if ($installedGodot) { $GodotBinary = $installedGodot.Source }
}

if (-not $GodotBinary) { throw 'Set GODOT_BIN or pass -GodotBinary with the Godot 4.7.2 executable path.' }
& $GodotBinary --path $PSScriptRoot --resolution 1280x800
exit $LASTEXITCODE
