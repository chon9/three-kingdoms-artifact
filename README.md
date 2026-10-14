# Classic Revival

**A community project working toward a faithful, playable recreation of Artifact Classic in Godot.**

Three lanes. Alternating actions. Heroes that return to the fight. We want the original game's kind of strategy to have a future that its community can help maintain.

The game now uses **49 real Artifact Classic definitions with original artwork**, including ten heroes and their signature cards. Choose a deck for each player, play against AI or locally, and save deterministic replays. The full Classic catalog and exact placement/trigger fidelity remain unfinished. This project is not affiliated with or endorsed by Valve.

## Run

Open `project.godot` with **Godot 4.5.2 or later**, then press **F6** on `scenes/main.tscn` or **F5** to play the project. Standard Godot works for offline play; no Steam extension or account is needed.

On this Windows workspace, a checksum-verified portable Godot 4.5.2 is in the ignored `.tools/godot` folder:

```powershell
.\run.ps1
.\run.ps1 -Editor
```

On another machine, install Godot separately or supply the executable:

```powershell
.\run.ps1 -GodotPath 'C:\Tools\Godot\godot.exe'
```

The main screen defaults to **Play against AI**, using Classic Starter against Green Assault. Click **Decks** to choose each player's preset, see its heroes and card lists, and start that matchup. Presets are **Classic Starter**, **Green Assault** (Drow/Lycan board pressure), and **Blue / Black Control** (Zeus/Phantom Assassin removal). Each preset has five unique heroes, forty main cards with all signatures, and nine equipment cards. The selector provides presets; custom deck editing is not implemented yet.

Use the mode selector for **Local two-player**. Local play automatically shows the player whose action it is; there is no privacy handoff screen yet. The Decks dialog also provides the current hero roster and a gallery of all supported cards.

All 49 card images are already downloaded in this workspace. On a fresh clone, fetch them from the original Steam CDN URLs, then open the project so Godot imports them:

```powershell
.\tools\fetch_classic_art.ps1
```

The image manifest records source URLs and artists. The PNGs are local third-party content and are excluded from Git; see [the artwork notice](assets/classic_cards/NOTICE.md).

## Play the prototype

1. Play through the left, middle, then right lane. Every lane has its own mana pool.
2. Click a card in your hand. Targeted cards highlight legal units; click one to resolve the effect. Untargeted spells and creeps resolve when clicked.
3. You need a matching hero color in the active lane to play a colored card.
4. Click **Pass / resolve combat**. Two consecutive passes resolve simultaneous combat. The first of those passers opens the next lane.
5. After the right lane, buy from the secret shop, your equipment deck, or the consumable slot. Buying equipment reveals the next item-deck card. Finish shopping, plan available heroes' lanes, then confirm deployment. Both players' plans reveal together.
6. Destroy two enemy towers, or a tower and the ancient behind it, to win.

Hover a card to see its artwork and readable effect in the right-hand panel. Click that artwork to enlarge it. The hand labels playable cards **PLAY**, and other cards explain the missing mana, hero color or turn. **Decks** provides roster/deck inspection; **Log** shows the match history. Rows scroll horizontally as lanes grow. Silenced units show **S** and cannot provide casting color or use active abilities; their passive auras continue to work.

Some CDN fronts predate Classic's balance patches. The renderer overlays updated Axe stats, Gust text and equipment prices without modifying the original image files. [Valve's December 2018 and January 2019 notes](https://store.steampowered.com/news/posts/?appgroupname=Artifact&appids=583950&enddate=1587420571&feed=steam_community_announcements) are the reference for those corrections.

Battlefield Control takes two clicks after selecting the card: choose the unit to redirect, then choose its highlighted opposing unit or tower. J'Muy's draw ability appears in the action panel when J'Muy is in the active lane; its cooldown is automatic.

**Save replay** writes a complete command journal to the project's Godot user-data directory. **Load replay** restores the final state and switches to local two-player inspection/continuation. Replays disclose both players' cards after the match; they should not be shared during a live game. This version has no timeline playback UI.

## What exists

- UI-independent command validation and seeded match state.
- Three sequential lanes, separate mana, color requirements, passing and initiative.
- Simultaneous combat, per-hit armor, structure damage, kill gold, hero reserves and respawn delays.
- Forty-nine real Classic definitions: ten heroes and 39 spells, creeps, equipment, consumables and tokens. Original training fixtures remain available only for engine regression tests.
- Farvhan/Prowler neighbor armor, Debbi's hero/tower damage bonus, J'Muy's draw/cooldown, permanent modifications, Berserker's Call battles, combat redirection, Tower Barrage including the tower, temporary mana and creep summoning.
- Original Steam CDN card fronts in the hand, artwork thumbnails on the board, and readable card details with enlarged inspection.
- Three validated deck presets, independent deck choices for each player, nine-card item decks, secret/item/consumable shopping, and a supported-card gallery.
- Drow global attack, Lycan neighbor attack, Phantom Assassin hero damage, Zeus post-spell piercing damage, Rix rapid deployment, Savage Wolf growth, siege, silence, condemnation, random discard and cross-lane damage.
- Healing Salve, Potion of Knowledge and Town Portal Scroll, including Fountain healing and temporary-effect cleanup.
- A one-ply heuristic opponent that uses public board information and its own hand, without reading enemy cards or future random rolls.
- Local play and reproducible command-journal replay restoration.
- Optional GodotSteam Spacewar 480 lobbies and reliable packets with host-side action validation and redacted guest snapshots. **The adapter has mock boundary tests; live two-account Steam play is not yet verified.**

See [rule coverage](docs/RULES.md), [Steam setup](docs/STEAM.md), and the [roadmap](docs/ROADMAP.md). The supported starter cards have effect tests; this does not establish complete Classic fidelity across every card, trigger or board arrangement.

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
godot --headless --path . --script res://tests/ui_smoke.gd
```

The suites check rules, card effects, deck validation, privacy, shop resources and UI interactions. They include 24 complete training bot matches, 12 Classic starter matches, and 18 seeded matchups covering all nine combinations of the three presets. Every complete match round-trips through replay serialization. UI checks exercise deck selection, catalog browsing, card inspection, combat, targeting, shopping, deployment and replay restoration.

## Source layout

```text
data/classic_cards.json           Supported Classic catalog and three deck presets
data/training_cards.json          Original engine-test fixtures
assets/classic_cards/manifest.json Valve CDN artwork URLs and artist credits
tools/fetch_classic_art.ps1       Reproducible local artwork download
scripts/core/card_library.gd      Versioned content packs and decks
scripts/core/match_engine.gd      State, legal actions, rules, observations, journals
scripts/ai/heuristic_bot.gd       Public-information one-ply opponent
scripts/network/steam_bridge.gd  Optional Steam lobby/message adapter
scripts/ui/main.gd               Board and interaction controls
scripts/ui/card_face.gd          Native corrections for archived card fronts
tests/                           Rule, protocol, UI and preview checks
docs/                            Rule coverage, Steam instructions and milestones
```

## Community and license

Source code and the original training content in this repository use the [MIT license](LICENSE). The name **Classic Revival** is a working title. Classic card identities/statistics are documented in the supported catalog; original card images are downloaded locally from the public Steam CDN and retain their separate ownership. The MIT license does not cover Valve/artist content. No Steamworks SDK binaries are included.

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add rule fixtures and report fidelity gaps. The repository is prepared for sharing, but has not been published to GitHub or announced anywhere.
