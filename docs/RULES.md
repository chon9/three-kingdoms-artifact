# Rule coverage and fidelity

The target is **Artifact Classic (the first version)**. Foundry's unified mana, shared action phase and fixed five-slot lanes are not the target.

This file separates implemented mechanics from verified fidelity. The supported catalog contains 49 real Classic definitions with preserved Valve artwork. Card effects use Valve's localization/glossary, with Classic balance-patch corrections for Axe, Gust and equipment prices. Automated tests cover supported effects, three presets and every preset matchup. Exact Classic behavior still needs reference matches around deployment, combat targeting restrictions, complete trigger ordering and unusual combinations.

| Area | Prototype behavior | Fidelity status |
| --- | --- | --- |
| Lanes | Left → middle → right; no five-slot cap; one shared, index-aligned row of combat positions per lane | Implemented; see "Combat positions" below |
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
| Deployment | Lane creeps are assigned and shown to both players first; heroes are then assigned to lanes privately; after both confirm, each player draws two cards, then all new units are placed in one shuffled order and every unit's arrow is rolled | Implemented per the wiki Phases page and tested |
| Placement | Creep cards: the player chooses an empty own slot or a new position at either end. Summons, lane creeps and deployed heroes: a random empty own slot, otherwise a new position at a random end | Implemented and tested; random-placement details are an assumption (below) |
| Creeps | Round 1: one Melee Creep per lane per player. Later rounds: two per player, each in a random lane, revealed at the start of deployment | Implemented and tested |
| Combat arrows | Stored per unit as an offset -1/0/1. Blocked units attack forward. Otherwise 50% forward, 25% left, 25% right; a diagonal with no unit means forward. Rolled for every unit at the end of deployment, and only for the new unit when one enters during an action phase. Reset to forward when a unit is placed directly opposite, or when the attacker's target leaves play | Implemented per the wiki Pathing page and tested |
| Draw | Five opening cards, then two per later round after deployment choices are confirmed; empty deck draws nothing | Implemented |
| Shop | Secret Shop, item-deck and consumable slots. The item deck is reshuffled every shopping phase; buying from it reveals the next card. Hold: pay 1 gold, once per shop phase, to keep the Secret Shop offer for the next shopping phase | Implemented per the wiki Item Shop page and tested; supported pools only |
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
| Log events | Structured dictionaries (`{"k": key, ...}`) formatted by `scripts/core/event_text.gd` | Implemented; English only, ready for `tr()` |
| Replays | Seed, selected decks and validated commands restore state/RNG | Protocol 5 (language-neutral state); previous replay protocols rejected clearly |

## Combat positions

Each lane holds one ordered list of combat positions. In the engine this is stored as `lanes[i].units[0]` and `lanes[i].units[1]`. These two rows always have the same length, and index `n` in both is the same position. "Neighbors" are the own-row units at `n - 1` and `n + 1`, and an empty slot means no neighbor on that side. "Enemy neighbors" are the enemy-row units at `n - 1`, `n` and `n + 1`. Static Field, Berserker's Call, Gust and arrows all read this aligned model.

Commands:

- `{"type": "play", "hand": i, "position": p}` plays a creep card. `p` is the index of an existing position whose own slot is empty, `-1` for a new position at the left end, or the current position count for a new position at the right end. An empty lane offers only `0`. `legal_actions` lists one action per choice.
- `{"type": "hold"}` is legal in the shop when the player has at least 1 gold, the Secret Shop slot is not sold, and nothing has been held yet this phase.

State:

- `state.pending_creeps` holds this round's lane-creep lanes, as `[[lane, lane], [lane, lane]]`. It is public and is cleared after placement.
- `players[p].held_secret` is the held Secret Shop card. It is hidden from the opponent.
- `state.event_seq` counts every event ever emitted.

Arrows are relative offsets. A new left-end position shifts both rows together, so no attacker changes target. Compaction removes only positions that are empty on both sides, so an attacker and its diagonal target stay adjacent.

## Assumptions pending verification

- **Compaction timing.** A position that is empty on both sides is removed as soon as units leave the lane. That covers death cleanup after spells, Static Field, Berserker's Call and combat, and a unit returned to the Fountain. Units killed together keep their positions until all of them are removed. No source states Classic's exact collapse timing.
- **Random placement.** Summons, lane creeps and deployed heroes prefer a random empty own slot, and open a new position at a random end only when none exists. As a result, round 1 always starts with every lane fully blocked (two positions, 2 v 2).
- **Fair reveal order.** Units placed at reveal (both players' heroes and creeps) are placed in one RNG-shuffled order. Classic's real interleaving is unknown.
- **Forced targets.** Battlefield Control's chosen target is not reset when a unit is placed in front of the redirected unit. It is reset when the chosen unit leaves play, and it ends at the next deployment.
- **Holding then buying.** Buying a held Secret Shop item in the same phase cancels the hold. The gold already paid is not refunded.
- **Ancient overflow** and the **J'Muy cooldown** timing remain as previously documented.

## Explicitly missing

The remaining original heroes/cards; improvements; other auras; stun, disarm, cleave, retaliation, regeneration, death shields and damage immunity; advanced movement; a general trigger queue; full shop pools/distribution; custom deck editing and full constructed/draft modes; concede, timers, spectators, replay playback and content migration.

Never add an unsupported original card to a playable deck with a partial effect. Record it as unsupported until its complete text and interactions are implemented with tests and a reference.

## Reference material

- [Valve's Classic/Foundry store description](https://store.steampowered.com/app/583950/Artifact/) distinguishes Classic's sequential lanes from Foundry's shared mana.
- [Valve's deck-code and card-set API specification](https://github.com/ValveSoftware/ArtifactDeckCode) documents five heroes, their deployment rounds, signature references and card data fields. The former `playartifact.com/cardset/00/` and `01/` endpoints redirected to the Steam store when checked during this implementation; do not assume they currently return JSON.
- Record exact Classic reference-match steps and observed results in future rule fixtures. Document unresolved behavior rather than relying on memory.

The supported card numbers and image URLs come from [preserved Valve API snapshots](https://github.com/chase-stevens/artifactAlmanac/tree/master/content). Names and effect terminology are checked against [Valve game localization/glossary files](https://github.com/SteamTracking/GameTracking-Artifact/tree/master/game/dcg/resource). Images are fetched directly from Valve's original public Steam CDN URLs; provenance and artists are in `assets/classic_cards/manifest.json`.

[Valve's balance notes](https://store.steampowered.com/news/posts/?appgroupname=Artifact&appids=583950&enddate=1587420571&feed=steam_community_announcements) specify Axe 6/2/10, Gust's hero-plus-neighbors target, Broadsword 6 gold and Claymore 14 gold. Native overlays correct the older displayed fronts. The glossary's bounty definition awards gold to the opponent on death; the prior friendly-damage exception has been removed.
