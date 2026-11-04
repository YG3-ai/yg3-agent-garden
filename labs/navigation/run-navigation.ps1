param([string]$RunName = ('navigation-' + (Get-Date -Format 'yyyyMMdd-HHmmss')))
$ErrorActionPreference = 'Stop'
$rootPath = $PSScriptRoot
$godotPath = 'godot'
$pythonPath = 'python'
if ($env:PYTHON_BIN) { $pythonPath = $env:PYTHON_BIN }
if ($env:GODOT_BIN) { $godotPath = $env:GODOT_BIN }
$runPath = Join-Path $rootPath ('experiments/' + $RunName)
if (Test-Path $runPath) { throw "Refusing to overwrite an existing run: $runPath" }
function Invoke-Checked([string]$Program, [string[]]$Arguments) {
 & $Program @Arguments
 if ($LASTEXITCODE -ne 0) { throw "$Program failed with exit code $LASTEXITCODE" }
}
function Invoke-Navigation([string[]]$Extra) {
 Invoke-Checked $godotPath (@('--headless','--fixed-fps','60','--path',$rootPath,'--','--navigation','--output',$runPath) + $Extra)
}
if (-not (Test-Path (Join-Path $rootPath 'cache/lobby-colliders.tscn'))) { throw 'Download assets and run play.cmd once with graphics to bake collision geometry.' }
if (-not (Test-Path (Join-Path $rootPath 'cache/lobby-navigation.tres'))) {
 Invoke-Checked $godotPath @('--headless','--path',$rootPath,'--script','res://training/bake_navigation.gd')
}
Invoke-Navigation @('--nav-mode','collect')
Invoke-Checked $pythonPath @((Join-Path $rootPath 'navigation/train_policy.py'),$runPath)
Invoke-Navigation @('--nav-mode','evaluate','--controller','ffn','--split','validation')
$initialPath = Join-Path $runPath 'initial'
New-Item -ItemType Directory $initialPath | Out-Null
foreach ($name in @('policy.json','policy.pt','training.json','evaluate-ffn-validation.json')) { Copy-Item (Join-Path $runPath $name) $initialPath }
Invoke-Navigation @('--nav-mode','dagger','--controller','ffn','--split','train','--episodes','100')
Invoke-Checked $pythonPath @((Join-Path $rootPath 'navigation/train_policy.py'),$runPath,'--dagger','--rotate')
Invoke-Navigation @('--nav-mode','evaluate','--controller','ffn','--split','validation')
Invoke-Checked $pythonPath @((Join-Path $rootPath 'navigation/select_policy.py'),$runPath)
foreach ($controllerName in @('ffn','goal','teacher')) {
 Invoke-Navigation @('--nav-mode','evaluate','--controller',$controllerName,'--split','test')
}
Invoke-Checked $godotPath @('--headless','--path',$rootPath,'--script','res://navigation/verify_policy.gd','--',$runPath)
Invoke-Checked $pythonPath @((Join-Path $rootPath 'navigation/summarize.py'),$runPath)
Write-Host "Navigation experiment saved to $runPath"
