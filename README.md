# Three Kingdoms: Three Lanes (三国·三路争锋)

**An open-source, bilingual (English / 简体中文) card game that plays exactly like Artifact Classic, retold in China's Three Kingdoms era.**

Three lanes. Alternating actions. Heroes that return to the fight. Guan Yu holds the left lane while Cao Cao schemes in the middle and Sun Quan's fleet presses on the right. The rules are Valve's Artifact Classic rules, implemented in Godot; the names, text and artwork are our own Three Kingdoms theme. An optional **Classic** card theme shows the original card names for players who know the old game.

The game currently supports **49 card definitions**: ten heroes (Guan Yu, Zhang Fei, Cao Cao, Sima Yi, Sun Quan, Gan Ning, Zhou Yu, Lü Meng, Lü Bu and Jia Xu), their signature cards, creeps, spells, equipment and consumables, in three preset decks. Play against the AI, pass the device to a friend, or (experimentally) over Steam, and save deterministic replays. The full Classic catalog and some placement and trigger details are still unfinished. This project is not affiliated with or endorsed by Valve.

## Run

Open `project.godot` with **Godot 4.5.2 or later**, then press **F5**. Standard Godot works for offline play; no Steam extension or account is needed.

On this Windows workspace, a checksum-verified portable Godot 4.5.2 is in the ignored `.tools/godot` folder:

```powershell
.\run.ps1
.\run.ps1 -Editor
.\run.ps1 -GodotPath 'C:\Tools\Godot\godot.exe'   # any other Godot executable
```

The main menu offers **Play against AI**, **Local two-player**, **Online (Steam)**, **Decks**, **Replays**, **Settings** and **Quit**, plus a 中文 / English toggle that applies immediately. **Decks** picks a preset for each player, shows its heroes and card lists, and starts that matchup: **Contest of Warlords** (群雄逐鹿, all four factions), **Jiangdong Vanguard** (江东劲旅, Wu board pressure) and **Schemes of Chaos** (乱世权谋, removal and control). Each preset has five heroes, forty main cards including every signature, and nine equipment cards. Custom deck editing is not implemented yet.

**Local two-player** shows the board from the acting player's side and puts a pass-the-device screen between turns, so neither player sees the other's hand.

## How to play

**Goal:** destroy two enemy towers, or one tower and the capital (ancient) behind it.

**The board.** One lane fills the screen: the enemy wall and tower at the top, your units and tower at the bottom, the river between them. Each tower shows its mana (current over maximum) on the left and its health on the right, with a red tag for the damage it will take in combat. Lanes resolve left, middle, right, and each has its own mana.

| Action | Mouse | Keyboard |
|---|---|---|
| Switch lane | Edge chevrons, or click a lane in the top-left lane HUD | **1** **2** **3**, **Left** / **Right** |
| All three lanes | Double-click the board | **Tab** |
| Play a card | Drag it out of your hand (or click it, then click the target) | |
| Cancel a held card | Right-click, or drop it back on the hand | **Esc** |
| Pass / done / confirm | Click the initiative coin (bottom right) | **Space** / **Enter** |
| Hero ability | Click the ability badge on the hero | |
| Inspect a card or unit | Right-click, or press and hold | |
| Match log | Menu button (top right) | **L** |
| Menu | Menu button | **Esc** |

**Playing cards.** Glowing cards are playable; the others are dimmed and their tooltip says why (a colored card needs a hero of its color in the active lane, and enough mana). Untargeted spells drop anywhere on the board. Targeted cards draw an arrow: legal targets light up, releasing over one plays the card, releasing elsewhere cancels. Creeps drop into a highlighted combat position (an empty slot or a new position at either end). Equipment drops on an allied hero. Cross-lane cards switch lanes while you aim: hold the card at the screen edge (once per visit) or click a chevron. **Command Through the Emperor** (Battlefield Control) has two stages: drop it on the unit to redirect, then pick that unit's new target (a highlighted opposing unit or tower) with the second arrow.

**Initiative and combat.** The coin glows when you may act; passing hands the initiative over. Two passes in a row resolve simultaneous combat in the lane, and the first of those passers acts first in the next lane. Every unit shows its combat arrow on the river-facing edge (straight ahead or diagonal, gold when it will hit the tower) and a live damage preview: a red tag with the damage it will take, and a grey card with a red cross when it will die.

**Shop and deployment.** After the right lane the shop chest opens: buy from the Secret Shop (or HOLD it for 1 gold), your item deck or the consumable slot, then click the coin. In deployment, drag each ready hero onto a lane (or click a hero, then a lane) and confirm with the coin; both players' plans reveal together, and each lane's new creeps appear as ghost cards before they arrive.

**Replays.** *Save replay* writes the complete command journal to the Godot user-data directory. **Replays** lists saved replays and restores the final state for local inspection or continuation. Replays reveal both players' cards, so do not share one during a live game. There is no timeline playback yet.

## Languages and card themes

The game is fully bilingual. Language and card theme switch live from the main menu or **Settings** and are saved in `user://settings.cfg`; the first run follows the system language.

- Match state, replays and network packets contain only ids and numbers, so the state digest is the same in every language.
- Interface text: `i18n/ui.csv` (`keys,en,zh_CN`, named `{placeholders}`), imported by Godot as translations. `scripts/core/event_text.gd` formats event-log entries, engine error codes and Steam statuses through it.
- Card text: `data/locale/cards.json`, per theme and locale, read with `CardLibrary.loc(card_id, field)`; numbers in rules text are filled from the card definition. Glossary: `data/locale/glossary.json`.
- Fonts are subsets of Noto Sans SC and LXGW WenKai (renamed "Sanguo Kai"). Chinese headings use Sanguo Kai; English headings use Noto Sans SC Bold. After adding text with new characters, run `python tools/build_fonts.py --src <full fonts folder> --download`; `tests/i18n_test.gd` fails when a used character is missing.

**Classic theme.** The optional Classic theme shows the original Artifact card names and text. If you have downloaded the original card renders locally with `.\tools\fetch_classic_art.ps1`, that theme shows them (cropped to the art window); otherwise it uses the Three Kingdoms art. The renders are Valve's, are never committed (they are gitignored) and are not needed to play; see [the notice](assets/classic_cards/NOTICE.md).

## Artwork

Card art lives in `assets/art/cards/<card id>.jpg` (the id is the original Artifact id, so Guan Yu is `keefe`); board and UI art goes to `assets/art/ui/`. The prompts, style bible and crop rules for every image are in [docs/art/ART_PROMPTS.md](docs/art/ART_PROMPTS.md), with progress in [docs/art/GENERATION_STATUS.md](docs/art/GENERATION_STATUS.md).

The game never draws art taller than 768 px, so commit reductions, not masters: save the PNG master under the path from the prompt list, then run

```text
python tools/optimize_art.py
```

which writes a 512x768 JPEG next to it (about 120 KB) and moves the master to the ignored `.tools/art_masters/`. The loader accepts `.png`, `.jpg` or `.webp`, and a card without art gets a generated ink-wash placeholder with its name in calligraphy. Optional UI files are picked up when present: `assets/art/ui/main_menu.png`, `card_back.png`, `initiative_token.png`, `splash_victory.png` / `splash_defeat.png` and `tower_ally.png` / `tower_enemy.png` / `ancient_ally.png` / `ancient_enemy.png`.

Fonts, textures, icons, particles, sounds and the artwork's provenance are credited in [CREDITS.md](CREDITS.md).

## What exists

- UI-independent command validation and seeded match state.
- Three sequential lanes, separate mana, color requirements, passing and initiative.
- Simultaneous combat, per-hit armor, structure damage, kill gold, hero reserves and respawn delays.
- Forty-nine Classic definitions: ten heroes and 39 spells, creeps, equipment, consumables and tokens. Original training fixtures remain available only for engine regression tests.
- Neighbor armor and attack, hero and tower damage bonuses, draw and cooldown abilities, permanent modifications, battles, combat redirection, tower damage, temporary mana, creep summoning, global attack, post-spell piercing damage, rapid deployment, growth, siege, silence, condemnation, random discard and cross-lane damage.
- Healing, card draw and return-to-Fountain consumables, including Fountain healing and temporary-effect cleanup.
- Three validated deck presets, independent deck choices for each player, nine-card item decks, Secret Shop / item / consumable shopping, and a gallery of every supported card.
- A one-ply heuristic opponent that uses public board information and its own hand, without reading enemy cards or future random rolls.
- A Classic-style match screen: sliding lane camera and overview, combat arrows and damage preview, drag-to-play with target arrows, the initiative coin, the shop chest, drag-to-lane deployment, inspection, event animations (casts, combat lunges and damage numbers, deaths, tower falls, lane changes), a match log and a game-over screen.
- Local play and reproducible command-journal replay restoration.
- Optional GodotSteam Spacewar 480 lobbies and reliable packets with host-side action validation and redacted guest snapshots. **The adapter has mock boundary tests; live two-account Steam play is not yet verified.**

See [rule coverage](docs/RULES.md), [Steam setup](docs/STEAM.md) and the [roadmap](docs/ROADMAP.md). The supported cards have effect tests; this does not establish complete Classic fidelity across every card, trigger or board arrangement.

## Tests

```powershell
.\test.ps1
```

Or with any supported Godot executable:

```text
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/classic_cards_test.gd
godot --headless --path . --script res://tests/expanded_classic_test.gd
godot --headless --path . --script res://tests/i18n_test.gd
godot --headless --path . --script res://tests/ui_smoke.gd
```

The suites check rules, card effects, deck validation, privacy, shop resources, translations and UI interactions. They include 24 complete training bot matches, 12 Classic starter matches and 18 seeded matchups covering all nine combinations of the three presets; every complete match round-trips through replay serialization. The UI smoke test drives the real scene with mouse events: drag-play (untargeted, targeted, creep positions), Battlefield Control's two stages, edge lane switching, a 14-card hand, ability badges, the initiative coin, shop hold and buy, deployment drags (including a state update mid-drag), inspection, dialogs, deck selection, live language and card-theme switching, an AI turn and replay restoration.

Screenshots of the main UI states need a real renderer (not `--headless`); they are written to `.tools/shots/`:

```text
godot --path . -s res://tests/capture_preview.gd
godot --path . -s res://tests/capture_preview.gd -- --size=1280x720 --only=lane_action,shop
```

## Source layout

```text
data/classic_cards.json           Supported catalog and three deck presets (rules data)
data/locale/cards.json            Card names and text per theme and language
i18n/ui.csv                       Interface text (English, Simplified Chinese)
data/training_cards.json          Original engine-test fixtures
assets/art/                       Three Kingdoms card and UI art
assets/classic_cards/manifest.json Valve CDN render URLs and artist credits (optional local download)
tools/                            Font subsetting, art optimization, Classic render download
scripts/core/card_library.gd      Versioned content packs, decks and localized card text
scripts/core/match_engine.gd      State, legal actions, rules, observations, journals
scripts/core/event_text.gd        Event, error and Steam status text
scripts/ai/heuristic_bot.gd       Public-information one-ply opponent
scripts/network/steam_bridge.gd   Optional Steam lobby/message adapter
scripts/game/match_controller.gd  Engine, bot, play modes, replays and Steam for the UI
scripts/game/animation_queue.gd   Plays event animations before input resumes
scripts/ui/main.gd                App root: main menu, match screen, dialogs, settings
scripts/ui/match_screen.gd        Board, hand, HUD, coin, overlays and drag-to-play
scripts/ui/board_view.gd          Lane camera (lane view, overview) and display models
scripts/ui/lane_view.gd           One lane: walls, towers, river, unit rows
scripts/ui/unit_card.gd           Board unit with combat arrow and damage preview
scripts/ui/card_view.gd           Full card face drawn in code
scripts/ui/card_art.gd            Card art lookup and generated placeholder art
scripts/ui/*_overlay.gd           Shop, deployment, inspect and game-over overlays
scripts/ui/*_dialog.gd            Settings, decks, catalog, replays and Steam dialogs
tests/                            Rule, protocol, i18n, UI and preview checks
docs/                             Rule coverage, Steam instructions, roadmap, art prompts
```

## Community and license

Source code, the Three Kingdoms text and artwork, and the original training content in this repository use the [MIT license](LICENSE). Third-party fonts and assets keep their own licenses, listed in [CREDITS.md](CREDITS.md). Artifact's card identities and rules are documented for compatibility; the original card names, text and images remain Valve's and the artists'. The MIT license does not cover Valve or artist content, and no Valve images or Steamworks SDK binaries are included.

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add rule fixtures and report fidelity gaps. The repository is prepared for sharing, but has not been published or announced anywhere.
