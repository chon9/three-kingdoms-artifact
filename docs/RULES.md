# Rule coverage and fidelity

The target is **Artifact Classic (the first version)**. Foundry's unified mana, shared action phase and fixed five-slot lanes are not the target.

This file separates implemented mechanics from verified fidelity. The supported catalog contains 49 real Classic definitions with preserved Valve artwork. Card effects use Valve's localization/glossary, with Classic balance-patch corrections for Axe, Gust and equipment prices. Automated tests cover supported effects, three presets and every preset matchup. Exact Classic behavior still needs reference matches around deployment, combat targeting restrictions, complete trigger ordering and unusual combinations.

| Area | Prototype behavior | Fidelity status |
| --- | --- | --- |
| Lanes | Left → middle → right; no five-slot cap | Basic structure implemented |
| Mana | Three initially, one more per round, refilled independently | Implemented; modifiers absent |
| Actions | Players alternate; legal commands validate before mutation | Implemented |
| Initiative | First consecutive passer opens next lane; playing resets passes; initiative effects keep the action | Implemented and tested; complex ability interactions absent |
| Color | A living, unsilenced matching hero must be in the active lane | Implemented; stun absent |
| Combat | Snapshot all attacks, reduce every incoming hit by armor, apply simultaneously | Implemented; advanced combat keywords absent |
| Structures | 40-health towers, then 80-health ancients; no tower-hit overflow | Implemented; verify special damage effects against Classic |
| Victory | Two towers or one ancient; simultaneous wins draw | Implemented and tested |
| Gold | Opponent receives bounty whenever a unit dies, including friendly spell damage and symmetric clears | Implemented; modifiers and special bounties absent |
| Heroes | Original five plus Drow, Lycan, Phantom Assassin, Zeus and Rix | Ten supported heroes, five per chosen deck |
| Death | Normal heroes return after a full round; Rix returns next round; Fountain immediately heals and clears temporary effects | Implemented and tested |
| Deployment | Choose lane, commit privately, reveal together; hero heals on return | Basic flow implemented |
| Placement | Seeded empty-slot selection or append; gaps retained | **Approximation**, not Classic's complete insertion/compaction algorithm |
| Creeps | One per lane initially; two random-lane creeps per subsequent round | Basic training flow; exact Classic placement distribution unverified |
| Combat arrows | Forced straight when blocked; 50% straight/25% each side when open, only redirect to an adjacent unit | **Approximation**; rerolls on summon and between rounds need fidelity work |
| Draw | Five opening cards, then two per later round; empty deck draws nothing | Implemented; draw-step timing still needs reference verification |
| Shop | Secret slot, equipment-deck slot, consumable slot; equipment purchases advance the nine-card item deck | Implemented using supported pools; full Classic pool/distribution unverified |
| Equipment | Weapon, armor and accessory slots; replacement; retained through death | Real printed effects implemented |
| Decks | Three presets; 5 unique heroes, 40 main cards with all signature copies, 9 equipment cards | Validated preset selection; custom deck editing and complete format rules absent |
| Cards | Ten heroes and 39 other definitions | Supported slice; full catalog absent |
| Auras | Farvhan and Prowler grant adjacent allies +1 armor while alive | Implemented and removal tested |
| Debbi | +2 battle damage against heroes and structures, none against creeps | Implemented and tested |
| Drow / Lycan | Global +1 to other allies; adjacent +2 attack | Implemented; aura loss and stacking tested |
| Phantom Assassin | +4 battle damage to heroes only | Implemented and tested |
| Zeus | After a blue spell, deal 1 piercing to enemy neighbors; dead Zeus does not trigger | Implemented; broader trigger ordering needs reference fixtures |
| Growth / siege | Savage Wolf grows after surviving lane combat; blocked siege adds tower damage | Implemented and tested |
| Silence | Prevents active abilities and hero casting color; passives remain; clears at round end/Fountain | Implemented and tested |
| Cross lane | Pick Off pays source-lane mana and targets any lane; Wrath hits enemy heroes in all lanes | Implemented and tested |
| Consumables | Healing, draw and Portal return with no play-time mana cost | Implemented and tested |
| Condemn / discard | Slay, Coup de Grace and Annihilation; Coup discards one random remaining hand card | Implemented; death shields not yet supported |
| J'Muy | Draw one via active ability; four-round cooldown with round ticks | Implemented; initial cooldown timing still needs reference-match verification |
| Signatures | Fighting Instinct permanent buffs, No Accident damage, Prowler aura, Battlefield Control redirection, Berserker's Call neighbor battles | Implemented and tested; full edge interactions require reference fixtures |
| Extra effects | Tower Barrage includes tower damage; Stars Align grants temporary mana; Dimensional Portal summons three creeps | Implemented and tested |
| Triggers | Supported continuous auras, Zeus post-spell trigger and Wolf post-combat growth | Complete general event queue absent |
| Replays | Seed, selected decks and validated commands restore state/RNG | Protocol 3; previous replay protocols rejected clearly |

## Explicitly missing

The remaining original heroes/cards; improvements; other auras; stun, disarm, cleave, retaliation, regeneration, death shields and damage immunity; advanced movement; a general trigger queue; full shop pools/distribution; custom deck editing and full constructed/draft modes; concede, timers, spectators, replay playback and content migration.

Never add an unsupported original card to a playable deck with a partial effect. Record it as unsupported until its complete text and interactions are implemented with tests and a reference.

## Reference material

- [Valve's Classic/Foundry store description](https://store.steampowered.com/app/583950/Artifact/) distinguishes Classic's sequential lanes from Foundry's shared mana.
- [Valve's deck-code and card-set API specification](https://github.com/ValveSoftware/ArtifactDeckCode) documents five heroes, their deployment rounds, signature references and card data fields. The former `playartifact.com/cardset/00/` and `01/` endpoints redirected to the Steam store when checked during this implementation; do not assume they currently return JSON.
- Record exact Classic reference-match steps and observed results in future rule fixtures. Document unresolved behavior rather than relying on memory.

The supported card numbers and image URLs come from [preserved Valve API snapshots](https://github.com/chase-stevens/artifactAlmanac/tree/master/content). Names and effect terminology are checked against [Valve game localization/glossary files](https://github.com/SteamTracking/GameTracking-Artifact/tree/master/game/dcg/resource). Images are fetched directly from Valve's original public Steam CDN URLs; provenance and artists are in `assets/classic_cards/manifest.json`.

[Valve's balance notes](https://store.steampowered.com/news/posts/?appgroupname=Artifact&appids=583950&enddate=1587420571&feed=steam_community_announcements) specify Axe 6/2/10, Gust's hero-plus-neighbors target, Broadsword 6 gold and Claymore 14 gold. Native overlays correct the older displayed fronts. The glossary's bounty definition awards gold to the opponent on death; the prior friendly-damage exception has been removed.
