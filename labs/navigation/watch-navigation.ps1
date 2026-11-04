param([string]$RunName = 'navigation-v1-20261104')
$ErrorActionPreference = 'Stop'
$runPath = Join-Path $PSScriptRoot ('experiments/' + $RunName)
$previewTask = Get-Content (Join-Path $runPath 'preview-task.json') -Raw | ConvertFrom-Json
$godotPath = 'godot'
if ($env:GODOT_BIN) { $godotPath = $env:GODOT_BIN }
& $godotPath --path $PSScriptRoot -- --navigation --nav-mode replay --controller ffn --split test --task $previewTask.id --output $runPath
if ($LASTEXITCODE -ne 0) { throw "Godot failed: $LASTEXITCODE" }
