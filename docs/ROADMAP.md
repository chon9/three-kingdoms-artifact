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

## Three Kingdoms theme and match interface (implemented)

- Bilingual (English / Simplified Chinese) interface and card text with live switching, subset fonts, and the Three Kingdoms card theme as the default (the Classic names remain an optional theme). Locale-independent state digests.
- Generated Three Kingdoms art for all 49 supported cards (512x768 JPEG in `assets/art/cards/`, masters kept outside the repository; see `docs/art/`).
- Classic-style board: one lane at a time with a sliding camera and an all-lanes overview, lane HUD, towers with mana and health, combat arrows and the live damage preview on every unit, drag-to-play with a target arrow (two stages for Battlefield Control), creep position ghosts, cross-lane aiming at the screen edge, the initiative coin, the shop chest with HOLD, drag-to-lane deployment with incoming creep ghosts, inspection, event animations (casts, combat, deaths, lane changes), a match log in the HUD's player names, a main menu, settings and a hot-seat privacy screen.

Remaining: chess clocks, improvements, pets, deck trays and pathing-card slabs at deployment, timeline replay playback, concede, music, and art for the board and UI elements (towers, coin, card back, menu key art) and the reserve heroes. The animated presentation is checked by hand and by screenshots; the automated UI test runs with animations skipped.

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

- Music and fuller sound, accessibility settings (text size, color-blind cues, reduced motion) and rebindable keys.
- Remaining original visual/audio content with provenance records (board and UI art, reserve heroes).
- Signed/reproducible Windows and Linux builds, crash diagnostics and packaging.
- Contributor onboarding, public issue templates, fidelity dashboard and a playable release announcement.

No milestone dates or full-fidelity claims are set yet. Progress should follow playable builds and verified card behavior.
