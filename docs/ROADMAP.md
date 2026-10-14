# Roadmap

## 0.1 — First playable training slice (implemented)

Godot project, three-lane training matches, validated commands, seeded RNG, basic bot, local play, replay restoration, optional Steam adapter and automated rules/UI checks. Live Steam connectivity is pending two-account verification.

## 0.2 — Classic fidelity foundation

- Implemented starter slice: five real heroes, all five signatures, fourteen main-deck definitions, real equipment, original card images and readable inspection. Per-card checks and complete Classic bot/replay matches cover the implemented behavior.
- Establish reference fixtures from Artifact Classic for deployment, insertion, arrows, drawing, initiative and combat timing.
- Replace approximate placement, rerolling and training shopping with verified behavior.
- Introduce an ordered rules event queue, continuous modifiers and trigger sources with stable identifiers.
- Define a versioned Classic card schema, unsupported-card registry and effect coverage report.
- Extend the supported forty-card main deck with the full nine-item deck/shop and constructed validation.
- Preserve the original training pack as an engine-test pack.

## 0.3 — Playable deck variety (implemented)

49 real definitions, ten supported heroes, three deck presets, independent player/opponent choices, nine-card item decks, supported secret/consumable pools, silence, cross-lane damage, condemnation, siege, growth and Fountain return. Native archived-card overlays reflect verified Classic patches. Rule, privacy and UI tests include every preset matchup.

Remaining fidelity work: exact placement/targeting restrictions, general trigger queue, complete shops and custom deck editing.

## Next — Steam matches between friends

- Install and pin a compatible GodotSteam extension and record its version/license.
- Verify lobby creation, ID join and overlay invites with two distinct Steam accounts.
- Verify sender binding, stale command rejection, card privacy, equipment/shop actions and complete matches.
- Finish disconnect/pause/resume flow and original-opponent reconnect handling.
- Add build/content hashes to compatibility checks, deadlines and rate limits.
- Add a dedicated App ID for a public release; 480 is the development example target.

## 0.4 — Full Classic catalog and useful AI

- Implement original hero abilities, signatures, creeps, spells, improvements, items and cross-lane effects.
- Add differential/reference tests for each effect, plus interaction suites and generated legal-action games.
- Extend the bot with multi-action search, hidden-state sampling and deployment/deck strategy.
- Benchmark AI strength on held-out positions and human games; publish its limits and difficulty settings.
- Add deck building, legal deck validation and draft.

## 0.5 — Community alpha

- Better animation, audio, readable card text, keyboard controls and accessibility settings.
- Original or explicitly licensed visual/audio content with provenance records.
- Signed/reproducible Windows and Linux builds, crash diagnostics and packaging.
- Contributor onboarding, public issue templates, fidelity dashboard and a playable release announcement.

No milestone dates or full-fidelity claims are set yet. Progress should follow playable builds and verified card behavior.
