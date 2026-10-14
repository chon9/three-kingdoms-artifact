# Starts the game. Extra arguments go to the game, for example
#   .\run.ps1 +connect_lobby <lobby id>   joins that Steam lobby on start
#   .\run.ps1 -NoSteam                    offline only, never starts Steam
[CmdletBinding(PositionalBinding = $false)]
param([string]$GodotPath = '', [switch]$Editor, [switch]$NoSteam,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$GameArgs)
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
if (-not $GodotPath) {
    $portableEngine = Join-Path $projectRoot '.tools\godot\Godot_v4.5.2-stable_win64_console.exe'
    if (Test-Path -LiteralPath $portableEngine) {
        $GodotPath = $portableEngine
    } else {
        $godotCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($godotCommand) { $GodotPath = $godotCommand.Source }
    }
}
if (-not $GodotPath) { throw 'Godot 4.5.2+ was not found. Pass -GodotPath with your Godot executable.' }
$engineArgs = @('--path', $projectRoot)
if ($Editor) { $engineArgs += '--editor' }
if ($NoSteam) { $engineArgs += '--no-steam' }
if ($GameArgs) { $engineArgs += $GameArgs }
& $GodotPath @engineArgs
exit $LASTEXITCODE
