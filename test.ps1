param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
if (-not $GodotPath) {
    $GodotPath = Join-Path $PSScriptRoot '.tools\godot\Godot_v4.5.2-stable_win64_console.exe'
    if (-not (Test-Path -LiteralPath $GodotPath)) {
        $godotCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($godotCommand) { $GodotPath = $godotCommand.Source }
    }
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Pass -GodotPath with your Godot 4.5.2+ executable.' }
New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot '.tools') -Force | Out-Null
& $GodotPath --headless --path $PSScriptRoot --editor --import
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $GodotPath --headless --path $PSScriptRoot --script res://tests/run_tests.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $GodotPath --headless --path $PSScriptRoot --script res://tests/classic_cards_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $GodotPath --headless --path $PSScriptRoot --script res://tests/expanded_classic_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $GodotPath --headless --path $PSScriptRoot --script res://tests/i18n_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $GodotPath --headless --path $PSScriptRoot --script res://tests/steam_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $GodotPath --headless --path $PSScriptRoot --script res://tests/ui_smoke.gd
exit $LASTEXITCODE
