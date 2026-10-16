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
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
# Players' own decks: deck codes (Valve's format), deck rules, store, builder edits, replays.
& $GodotPath --headless --path $PSScriptRoot --script res://tests/deck_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
# Card rules (docs/EFFECTS.md): schema, lint, RULES_VERSION, Valve parity; then the rules kernel.
& $GodotPath --headless --path $PSScriptRoot --script res://tests/rules_schema_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $GodotPath --headless --path $PSScriptRoot --script res://tests/rules_kernel_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
# Golden gate (docs/design/EFFECT_SYSTEM_SPEC.md 13.5): recorded bot matches must replay identically.
& $GodotPath --headless --path $PSScriptRoot --script res://tests/golden_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
# The rules engine against the frozen pre-migration engine (tests/legacy), then the performance budgets.
& $GodotPath --headless --path $PSScriptRoot --script res://tests/differential_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $GodotPath --headless --path $PSScriptRoot --script res://tests/perf_test.gd
exit $LASTEXITCODE
