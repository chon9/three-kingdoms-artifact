# Contributing

The target is Artifact Classic. Keep a clear distinction between original training content, supported Classic cards, unsupported cards, and approximate mechanics.

## A rule or card contribution

1. Record the exact reference behavior: game version, cards, board state, action sequence and outcome.
2. Add a failing fixture that captures a meaningful interaction or boundary.
3. Implement the behavior in the core. The UI, bot and transport should submit commands rather than mutate match state.
4. Confirm illegal commands leave state/RNG unchanged, the bot's observations contain no hidden opponent information, and serialized replay restoration stays deterministic.
5. Run `test.ps1` or the headless commands in the README. Update `docs/RULES.md` and the coverage registry when one exists.

Never label a partly implemented card supported. New card content needs stable IDs and explicit provenance. Include license information for external code or assets. Do not commit `.tools`, `.godot`, credentials, local replay files or unreviewed extracted game assets.

## Bug reports

Include the Godot version, source/content version, match seed, replay file after the match, steps to reproduce, expected Classic behavior and observed behavior. For Steam issues, include both players' extension versions and whether lobby join, message exchange or state validation failed. Share no access tokens or account credentials.

## Working locally

The engine in `scripts/core` should work headlessly. AI receives player observations and legal actions. Steam remains an optional transport: a standard Godot install must continue to boot and play offline. UI improvements should retain clear lane, initiative, mana, combat preview and targeting information.
