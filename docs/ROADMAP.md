# Roadmap

## 0.1 — First playable training slice (implemented)

Godot project, three-lane training matches, validated commands, seeded RNG, basic bot, local play, replay restoration, Steam lobbies with handshake, reconnect and concede (bundled GodotSteam 4.23.1) and automated rules/UI/Steam-boundary checks. A live two-account match is pending verification (docs/STEAM.md checklist).

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
- Classic-style board: one lane at a time with a sliding camera and an all-lanes overview, lane HUD, towers with mana and health, combat arrows and the live damage preview on every unit, drag-to-play with a target arrow (two stages for Battlefield Control), creep position ghosts, cross-lane aiming at the screen edge, the initiative coin, the shop chest with HOLD, deployment staging strips with re-planning until confirmation and an animated, skippable reveal with pathing slabs, inspection, event animations (casts, combat, deaths, lane changes), a match log in the HUD's player names, a main menu, settings and a hot-seat privacy screen.

Remaining: chess clocks, improvements, pets, deck trays, the round-one deployment reveal, timeline replay playback, music, and art for the reserve heroes. The animated presentation is checked by hand and by screenshots; the automated UI test runs with animations skipped.

## Next — Steam matches between friends

- Done: GodotSteam 4.23.1 bundled; friends-only/public lobbies; join by ID, overlay invite, `+connect_lobby` and lobby browser; protocol + content-hash handshake; heartbeat and connection quality; pause, rejoin by the same Steam account, claim victory; host-left handling; concede.
- Verify with two distinct Steam accounts using the checklist in docs/STEAM.md (lobby creation, all join paths, card privacy, shop/deployment, complete matches, disconnect/rejoin, version mismatch).
- Turn deadlines and command rate limits.
- Add a dedicated App ID for a public release; 480 is the development example target (invites to a closed game launch Spacewar).

## 0.4 — Full Classic catalog and useful AI

- Implement original hero abilities, signatures, creeps, spells, improvements, items and cross-lane effects. Done for red and green (M3 of `docs/design/EFFECT_SYSTEM_SPEC.md`: 92 cards, three signature improvements and five new presets), blue (M4: 44 cards, two signature improvements and three new presets), black (M5: 39 cards, two signature improvements and three new presets) and the items (M6: 40 cards, the full Classic shop pools and four new presets); the improvements follow (M7).
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
