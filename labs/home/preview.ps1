$ErrorActionPreference = 'Stop'
$godotPath = 'godot'
if ($env:GODOT_BIN) { $godotPath = $env:GODOT_BIN }
& $godotPath --path $PSScriptRoot --script inspect.gd --rendering-method gl_compatibility --resolution 1280x720
exit $LASTEXITCODE
