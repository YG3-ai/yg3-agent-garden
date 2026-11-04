param(
    [int]$Samples = 12000,
    [int]$Seed = 20261104,
    [string]$RunDirectory,
    [string]$GodotBinary = $env:GODOT_BIN,
    [string]$PythonBinary = 'python'
)
$ErrorActionPreference = 'Stop'
if ($Samples -lt 1000) { throw 'Use at least 1000 samples so each split can contain collision examples.' }
if (-not $GodotBinary) {
    $installedGodot = Get-Command godot -ErrorAction SilentlyContinue
    if ($installedGodot) { $GodotBinary = $installedGodot.Source }
}

if (-not $GodotBinary) { throw 'Set GODOT_BIN or pass -GodotBinary.' }
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'cache/lobby-colliders.tscn'))) { throw 'Run play.cmd once to bake the visible collision geometry.' }
if (-not $RunDirectory) { $RunDirectory = Join-Path $PSScriptRoot ('experiments/ffn-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$resolvedRun = [System.IO.Path]::GetFullPath($RunDirectory)
if (Test-Path -LiteralPath (Join-Path $resolvedRun 'attempts.jsonl')) { throw 'That run already has data. Choose a new directory to preserve it.' }
New-Item -ItemType Directory -Path $resolvedRun -Force | Out-Null
& $PythonBinary (Join-Path $PSScriptRoot 'training/snapshot_sources.py') $resolvedRun
if ($LASTEXITCODE -ne 0) { throw 'Source snapshot failed.' }
& $GodotBinary --headless --fixed-fps 60 --path $PSScriptRoot -- --collect --samples $Samples --seed $Seed --output $resolvedRun
if ($LASTEXITCODE -ne 0) { throw 'Collection failed; existing output is preserved.' }
& $PythonBinary (Join-Path $PSScriptRoot 'training/train_ffn.py') $resolvedRun
if ($LASTEXITCODE -ne 0) { throw 'Training failed; data is preserved.' }
Write-Host ('Finished. Report: ' + (Join-Path $resolvedRun 'REPORT.md'))
