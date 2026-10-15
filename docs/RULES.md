# Rule coverage and fidelity

The target is **Artifact Classic (the first version)**. Foundry's unified mana, shared action phase and fixed five-slot lanes are not the target.

This file separates implemented mechanics from verified fidelity. The supported catalog contains 49 real Classic definitions with preserved Valve artwork. Card effects use Valve's localization/glossary, with Classic balance-patch corrections for Axe, Gust and equipment prices. Automated tests cover supported effects, three presets and every preset matchup. Exact Classic behavior still needs reference matches around deployment, combat targeting restrictions and unusual combinations.

Card rules are data: every card entry in `data/classic_cards.json` (schema 4) and `data/training_cards.json` (schema 2) carries its rules, which the rules engine in `scripts/core/rules/` runs (see "Rules engine" below and `docs/EFFECTS.md`). Open rules questions are numbered RQ-xx and listed under "Rules questions".

| Area | Prototype behavior | Fidelity status |
| --- | --- | --- |
| Lanes | Left → middle → right; no five-slot cap; one shared, index-aligned row of combat positions per lane | Implemented; see "Combat positions" below |
| Mana | Three initially, one more per round, refilled independently. Mana effects change the maximum through an exact base (`max_mana_base`); the derived maximum is floored at 0 and current mana follows the actual change (RQ-52) | Implemented and tested |
| Actions | Players alternate; legal commands validate before mutation | Implemented |
| Initiative | First consecutive passer opens next lane; playing resets passes; initiative effects keep the action | Implemented and tested; complex ability interactions absent |
| Color | A matching hero in the active lane that is neither silenced nor stunned (stun counts as silence and disarm) | Implemented and tested |
| Combat | Snapshot all attacks, reduce every incoming hit by armor, apply simultaneously. The combat plan also handles siege, cleave, retaliate, regeneration, piercing, Lethal and Damage Immunity, and records battle damage (RQ-45) | Implemented; the shipped cards use siege and the hero/tower bonuses, the other keywords are tested with fixture cards |
| Combat targets | A redirect may choose an enemy unit in the three positions across, or the tower only when the position directly across is empty (RQ-19, FX-2) | Implemented and tested |
| Structures | 40-health towers, then 80-health ancients; no tower-hit overflow | Implemented; verify special damage effects against Classic |
| Victory | Two towers or one ancient; simultaneous wins draw | Implemented and tested |
| Gold | Opponent receives bounty whenever a unit dies, including friendly spell damage and symmetric clears (RQ-02) | Implemented; bounty is the `bounty` keyword (5 for heroes, 1 for creeps) |
| Heroes | Original five plus Drow, Lycan, Phantom Assassin, Zeus and Rix | Ten supported heroes, five per chosen deck |
| Death | Normal heroes return after a full round; Rix returns next round; Fountain immediately heals and clears temporary effects (RQ-13) | Implemented and tested |
| Deployment | Lane creeps are assigned and shown to both players first; heroes are then assigned to lanes privately and may be moved to another lane or taken back until their player confirms; after both confirm, each player draws two cards, then all new units are placed in one shuffled order, deployment triggers run (RQ-23, RQ-49) and every unit's arrow is rolled | Implemented per the wiki Phases page and tested; changing a planned lane before confirming is an assumption (below) |
| Placement | Creep cards: the player chooses an empty own slot or a new position at either end. Summons, lane creeps and deployed heroes: a random empty own slot, otherwise a new position at a random end | Implemented and tested; random-placement details are an assumption (below) |
| Creeps | Round 1: one Melee Creep per lane per player. Later rounds: two per player, each in a random lane, revealed at the start of deployment | Implemented and tested |
| Combat arrows | Stored per unit as an offset -1/0/1. Blocked units attack forward. Otherwise 50% forward, 25% left, 25% right; a diagonal with no unit means forward. Rolled for every unit at the end of deployment, and only for the new unit when one enters during an action phase. Reset to forward when a unit is placed directly opposite, or when the attacker's target leaves play | Implemented per the wiki Pathing page and tested |
| Draw | Five opening cards, then two per later round after deployment choices are confirmed; empty deck draws nothing | Implemented; every hand card has a private instance id (`hand_state`) |
| Shop | Secret Shop, item-deck and consumable slots. The item deck is reshuffled every shopping phase; buying from it reveals the next card. Hold: pay 1 gold, once per shop phase, to keep the Secret Shop offer for the next shopping phase | Implemented per the wiki Item Shop page and tested; supported pools only |
| Equipment | Weapon, armor and accessory slots; replacement; retained through death. Equipping is legal while stunned (RQ-35) | Real printed effects implemented; each equipped item is an instance with its own id |
| Decks | Three presets; 5 unique heroes, 40 main cards with all signature copies, 9 equipment cards | Validated preset selection (only `verified`, non-token cards); custom deck editing and complete format rules absent |
| Cards | Ten heroes and 39 other definitions, all `verified`. Schema-4 drafts of all 303 counted Classic cards are in `tests/data/classic_rules_drafts.json` | Supported slice; drafts compile and are checked against Valve data, but are not playable |
| Auras | Farvhan and Prowler give adjacent allies +1 armor, Lycan +2 attack, Drow +1 attack to other allies in all lanes; item bonuses are auras on their hero. Auras are derived when read, and a unit projects its auras until the Pulse removes it (FX-3, RQ-15) | Implemented; removal, stacking and FX-3 tested |
| Debbi | +2 battle damage against heroes and structures, none against creeps | Implemented and tested |
| Drow / Lycan | Global +1 to other allies; adjacent +2 attack | Implemented; aura loss and stacking tested |
| Phantom Assassin | +4 battle damage to heroes only | Implemented and tested |
| Zeus | After a blue spell, deal 1 piercing to enemy neighbors; a dead Zeus does not trigger | Implemented as a `card_played` trigger; order with other triggers follows RQ-37 |
| Growth / siege | Savage Wolf grows after surviving lane combat; blocked siege adds tower damage | Implemented and tested |
| Silence | Prevents active abilities and hero casting color; passives remain; clears at round end/Fountain (RQ-31) | Implemented and tested |
| Cross lane | Pick Off pays source-lane mana and targets any lane; Wrath hits enemy heroes in all lanes | Implemented and tested |
| Consumables | Healing, draw and Portal return with no play-time mana cost | Implemented and tested |
| Condemn / discard | Slay, Coup de Grace and Annihilation; Coup discards one random remaining hand card; Annihilation condemns the active lane (RQ-04) | Implemented; Death Shields and Soulbound are implemented in the Pulse and tested with fixture cards |
| J'Muy | Draw one via active ability; four-round cooldown with round ticks; actives start ready (RQ-24) | Implemented; initial cooldown timing still needs reference-match verification |
| Signatures | Fighting Instinct permanent buffs, No Accident damage, Prowler aura, Battlefield Control redirection, Berserker's Call neighbor battles | Implemented and tested; full edge interactions require reference fixtures |
| Extra effects | Tower Barrage and Thunderstorm damage each enemy unit, never the tower (RQ-01, FX-1); Stars Align grants temporary mana; Dimensional Portal summons three creeps | Implemented and tested |
| Group damage | A damage effect on several units computes every amount from one board state, then applies them (FX-3, RQ-15) | Implemented and tested |
| Triggers | General event bus and trigger queue: triggers are collected from live sources when their event fires, filtered, then resolved in batches in one total order (RQ-37). A Pulse follows each batch; dying units leave look-back snapshots for Death Effects (RQ-43) | Implemented and tested with fixture cards; the shipped cards use Zeus's and Savage Wolf's triggers |
| Log events | Structured dictionaries (`{"k": key, ...}`) formatted by `scripts/core/event_text.gd` through `tr()` keys in en and zh_CN. Private fields (drawn cards) travel under `_s` and reach only their viewer | Implemented and tested |
| Replays | Seed, selected decks and validated commands restore state/RNG. Replays record protocol 7 and `RULES_VERSION`; a replay made with other rules fails clearly (`replay_rules`) | Implemented and tested; Steam protocol 8 adds `RULES_VERSION` to the content hash |

## Combat positions

Each lane holds one ordered list of combat positions. In the engine this is stored as `lanes[i].units[0]` and `lanes[i].units[1]`. These two rows always have the same length, and index `n` in both is the same position. "Neighbors" are the own-row units at `n - 1` and `n + 1`, and an empty slot means no neighbor on that side. "Enemy neighbors" are the enemy-row units at `n - 1`, `n` and `n + 1`. Static Field, Berserker's Call, Gust and arrows all read this aligned model.

A unit's legal combat targets (`combat_targets`, used by Battlefield Control) are its enemy neighbors, plus the enemy tower only when the position directly across (`n` in the enemy row) is empty (RQ-19). An empty diagonal alone does not open the tower, and a unit that later enters the position directly across ends a forced tower target.

Commands:

- `{"type": "play", "hand": i, "position": p}` plays a creep card. `p` is the index of an existing position whose own slot is empty, `-1` for a new position at the left end, or the current position count for a new position at the right end. An empty lane offers only `0`. `legal_actions` lists one action per choice.
- `{"type": "hold"}` is legal in the shop when the player has at least 1 gold, the Secret Shop slot is not sold, and nothing has been held yet this phase.

State:

- `state.pending_creeps` holds this round's lane-creep lanes, as `[[lane, lane], [lane, lane]]`. It is public and is cleared after placement.
- `players[p].held_secret` is the held Secret Shop card. It is hidden from the opponent.
- `state.event_seq` counts every event ever emitted.

Arrows are relative offsets. A new left-end position shifts both rows together, so no attacker changes target. Compaction removes only positions that are empty on both sides, so an attacker and its diagonal target stay adjacent.

## Rules engine

Card rules are declarative JSON inside each card entry, validated at load against a closed vocabulary. The contributor guide is `docs/EFFECTS.md`; the full design is `docs/design/EFFECT_SYSTEM_SPEC.md`.

- **Modules.** `scripts/core/rules/`: `vocab.gd` (the vocabulary), `rules_db.gd` (compiler and validator), `select.gd` (selectors and canonical order), `stats.gd` (derived stats, auras, settle), `vm.gd` (ops, expressions, conditions), `kernel.gd` (randomness, event bus, trigger queue, the Pulse, damage, modifiers), `combat.gd`, `zones.gd`, `targeting.gd` (`legal_actions`), and `natives.gd` (empty). `match_engine.gd` keeps the public API and the phase flow.
- **The Pulse.** Settle continuous effects, collect dying units (0 health or condemned), close Soulbound, consume Death Shields, snapshot and remove the dead (bounty, Fountain, compaction), emit `death` and `unit_died`, then resolve the queued triggers as one batch. It repeats until nothing is queued and nothing died. Guards: 2048 ops per command, 16 nested Pulses, 64 loops per Pulse; overflow stops resolution deterministically with a `rules_overflow` event.
- **Modifiers.** A permanent Modify is written into the unit's fields and recorded with its source and player, so Purge can reverse the opponent's (RQ-12). Temporary effects (`give`) are read at read time and expire by duration: `round`, `next_combat`, `death`, `equip`, `used`.
- **Determinism.** Randomness only through `Kernel.rand_index` and `Kernel.chance`; candidates in one canonical order (player, lane, slot); integers only. Read-only functions (`legal_actions`, `combat_preview`, `player_view`, the `*_of` helpers) never change state or randomness.
- **Versions.** `RULES_VERSION` (`scripts/core/rules/rules_version.gd`, generated by `python tools/rules_hash.py`) hashes the rules code and both card data packs. It is recorded in replays and is part of the Steam content hash, so peers and replays with different rules refuse each other. `tests/rules_schema_test.gd` fails when it is stale.
- **Pending operations (M2).** `move`, `swap`, `control`, `lock`, `add_card` and `card_counter` are in the vocabulary and validate, but no `verified` card may use them until they are implemented.

Behaviour changes made on purpose after the migration (each re-recorded the golden games):

| Fix | Change | Rules question |
| --- | --- | --- |
| FX-1 | Tower Barrage and Thunderstorm no longer damage the enemy tower | RQ-01 |
| FX-2 | The tower is a legal combat target only when the position directly across is empty | RQ-19 |
| FX-3 | Group damage is computed from one board state; a lethally damaged unit's auras last until the Pulse removes it | RQ-15 |

## Rules questions

Each question has one default, one place in the code or data, and (where implemented) a named test. RQ-01 to RQ-36 come from the mechanics inventory (`docs/design/MECHANICS.md`, regenerate with `python tools/mechanics.py`); RQ-37 to RQ-52 from the effect system design. In the last column, "cards:" names the shipped cards whose `rq` field lists the question. Questions whose cards are not in the pack yet keep the inventory's best answer until their milestone.

| RQ | Question | Default | Where | Test or status |
| --- | --- | --- | --- | --- |
| RQ-01 | Does "each enemy" include the enemy tower? | No: towers are not units (Tower Barrage, Thunderstorm) | FX-1, card data | `rq_01_each_enemy_excludes_tower`; cards: Tower Barrage, Thunderstorm |
| RQ-02 | Who gets bounty when a unit dies to its owner's effect? | Always the dying unit's opponent | `Kernel._remove` | `rq_02` (rules kernel test); cards: Annihilation |
| RQ-03 | Lane scope of "after you play" triggers | The source's lane, unless the text says "any lane" | trigger `lane` | Zeus scans the active lane |
| RQ-04 | Default scope of "allies", "enemies", "all units" | The active lane (spells) or the source's lane | selector `lane` | cards: Annihilation (condemns the active lane) |
| RQ-05 | Who are a unit's attackers? | Enemy units whose combat target is it and that are not disarmed | `attackers` relation | M2 |
| RQ-06 | When does Retaliate apply? | In any battle, once per attacker, even when stunned; reduced by armor | `Combat` | fixture-tested |
| RQ-07 | Siege and Cleave when disarmed or unblocked | Neither applies; siege counts for diagonal targets; tower armor reduces siege | `Combat.plan` | tested |
| RQ-08 | Cleave targets and armor | The target's allied neighbors, each reduced by its armor | `Combat.plan` | fixture-tested |
| RQ-09 | Regeneration timing | In the combat phase, before the death check, capped at max health | `Combat.plan` | fixture-tested |
| RQ-10 | Damage Immunity against condemn and Lethal | Immune units take no damage but die to condemn; Lethal needs damage dealt | `Kernel` | `rq_10` |
| RQ-11 | Death Shield stacking | At most one; it saves at 1 health once | `Kernel.give`, `_consume_death_shields` | `rq_11` |
| RQ-12 | What does Purge remove? | Modify and temporary entries from the opponent; not auras, items or damage | `Kernel.purge` | tested (modifier provenance) |
| RQ-13 | What survives the Fountain? | Items and Modify effects; temporary and "until death" effects end | `Kernel` Fountain entry | `rq_13_fountain` |
| RQ-14 | Lock details | Stacks; each locked card loses 1 lock per round | `lock` op | pending op (M2) |
| RQ-15 | Pulse semantics inside multi-step effects | A Pulse updates continuous effects, resolves triggers and removes the dead; auras last until removal; group damage is simultaneous | FX-3, `Kernel.pulse`, `SIMULTANEOUS_DAMAGE`, `AURAS_NEED_HEALTH` | `fx3_aura_persists_until_pulse` |
| RQ-16 | Chain Frost bounce target | Neighbors of the previous unit; with none, the bounces fizzle (low confidence) | Chain Frost draft | draft (M5) |
| RQ-17 | Where do summoned, moved and stolen units go? | A random empty position on the owner's side, then an arrow roll | `Zones.spawn` | summons tested; moves M2 |
| RQ-18 | Taunt scope | The taunting unit's enemy neighbors retarget to it | `taunt` op | M2 |
| RQ-19 | Legal choices for "choose a combat target" | Enemy units in the three positions across; the tower only when the position directly across is empty | FX-2, `combat_targets` | `rq_19_tower_needs_empty_across`; cards: Battlefield Control |
| RQ-20 | Initiative after Enough Magic! | The caster's opponent gets initiative | `_end_action_phase` | draft |
| RQ-21 | What counts as entering a lane (Glyph of Confusion)? | Every placement into the lane, not swaps | `unit_entered` | M2 |
| RQ-22 | Kanna's lane creeps | Into her lane when she is in play or deploying | `creep_lane` rules key | M2 (draft) |
| RQ-23 | Order of deployment-phase summons | At the reveal, after heroes are placed, before arrows | `deployment` event | lane hooks test (rules kernel test) |
| RQ-24 | Do active abilities start ready? | Yes | `HERO_ACTIVE_START_COOLDOWN = 0` in `kernel.gd` | J'Muy tests |
| RQ-25 | Quicken | The cooldown is set, then reduced by 1, not below 1 | `active.quicken` | M2 |
| RQ-26 | Shop Deed and negative prices | Each deed subtracts the base cost; prices may pay gold | `secret_shop_discount` | M2 |
| RQ-27 | Starting charges | Valve's `charges` field (March of the Machines and Bitter Enemies 3) | `charges` param | schema test (Valve parity) |
| RQ-28 | Rounding of "half" and of evenly divided damage | Round down; the remainder is lost | `half`, `damage_split` | M2 |
| RQ-29 | Summoned Meepo | A hero outside the roster that does not return from the Fountain | `summon` (`roster: false`) | draft |
| RQ-30 | Swaps and pathing | Arrows stay with positions | `swap` op | pending op (M2) |
| RQ-31 | Silence against passives and colour | Silence stops actives and colour, not passives; stun is silence plus disarm | `Stats` | tested |
| RQ-32 | Battle-damage triggers with 0 damage | Do not fire | `battle_damage` event | fixture-tested |
| RQ-33 | Cross Lane cards | Mana and colour from the active lane; target in any lane | `cross_lane` | tested with Pick Off |
| RQ-34 / RQ-47 | Improvements per lane | At most 16 per side of a lane; a 17th condemns a random one | `IMPROVEMENT_CAP` in `kernel.gd`, `Zones.add_improvement` | M2 |
| RQ-35 | Caught Unprepared duration | Until that hero equips an item or enters the Fountain; equipping is legal while stunned | `equip` duration | `rq_35_equip_while_stunned` |
| RQ-36 | Hacks and base copies | A base copy has no locks, charges or hacks; hacks run after the card | `hand_state` | M2 |
| RQ-37 | Order of simultaneous triggers | One batch per Pulse loop, no Pulse inside a batch; order: event, initiative side, lane, zone, position, ability, id | `Kernel.key_less`, `BATCH_MODE` | `rq_37_order`, `rq_37_batch_mode` |
| RQ-38 | Item triggers and actives while the host is in the Fountain | No; host stat auras still apply | `Stats`, `Targeting` | M2 |
| RQ-39 | Does a Death Shield save a Soulbound partner? | Yes; shields apply after the Soulbound closure | `_consume_death_shields` | `rq_39_soulbound_shield` |
| RQ-40 | Can losing a +Health aura kill? | Yes, through the settle delta, in the same Pulse | `Stats.settle`, `Kernel.pulse` | `rq_40_aura_loss_kills` |
| RQ-41 | Where does a Deed go? | Played free into a public `deeds` zone; permanent | `Zones.add_deed` | M2 |
| RQ-42 | What is an empty combat position for moves? | The `creep_positions` set | `positions` selector | M2 |
| RQ-43 | Do units dying in the same Pulse see each other's deaths? | No, except their own Death Effect | `Kernel._live_listeners` | `rq_43_simultaneous_death` |
| RQ-44 | Does a granted "after you play" trigger see its granting card? | Yes: `card_played` is emitted after resolution | `_play` order | M2 |
| RQ-45 | What is battle damage? | Attack, cleave, retaliate and siege hits | `Combat.plan` parts | fixture-tested |
| RQ-46 | Does "a tower" include a lane's ancient? | Yes: the standing structure of each lane | `towers` selector | M2 |
| RQ-48 | Centaur Hunter is a Valve token but a preset creep | Keep it deckable (5 mana) until the presets are revised in M3 | `data/classic_cards.json` | presets validate; cards: Centaur Hunter |
| RQ-49 | Is round 1's placement a deployment phase? | Yes (low confidence) | `ROUND1_DEPLOYMENT_HOOKS` in `kernel.gd` | `rq_49_round1_deployment` |
| RQ-50 | Does "for each ally" count the unit itself? | Yes: `allies` includes the source, `other_allies` does not | shorthands | M2 |
| RQ-51 | Hourglass and the round draw | The round draw happens before placement | `_reveal_deployment` order | M2 |
| RQ-52 | Losing a −Mana effect at 0 current mana | Current mana follows the actual change of the maximum | `Stats.settle` | `rq_52_mana_floor` |

## Assumptions pending verification

- **Compaction timing.** A position that is empty on both sides is removed as soon as units leave the lane. That covers death cleanup after spells, Static Field, Berserker's Call and combat, and a unit returned to the Fountain. Units killed together keep their positions until all of them are removed. No source states Classic's exact collapse timing.
- **Random placement.** Summons, lane creeps and deployed heroes prefer a random empty own slot, and open a new position at a random end only when none exists. As a result, round 1 always starts with every lane fully blocked (two positions, 2 v 2).
- **Fair reveal order.** Units placed at reveal (both players' heroes and creeps) are placed in one RNG-shuffled order. Classic's real interleaving is unknown.
- **Changing plans.** Until a player confirms deployment, a planned hero can be moved to another lane or taken back. Classic was not recorded doing either; both are private and draw no randomness.
- **Forced targets.** A unit Battlefield Control sent at an enemy unit keeps that target when another unit is placed in front of it; the target is reset when the chosen unit leaves play, and it ends at the next deployment. A unit sent at the tower is different: the tower is a combat target only while the position directly across is empty (RQ-19), so a unit that enters that position blocks it and becomes its target (`Zones.place`; `rq_19_tower_needs_empty_across`).
- **Holding then buying.** Buying a held Secret Shop item in the same phase cancels the hold. The gold already paid is not refunded.
- **Ancient overflow** and the **J'Muy cooldown** timing remain as previously documented.
- **Low-confidence rules defaults** (RQ-16, RQ-20, RQ-22, RQ-24, RQ-28, RQ-29, RQ-37, RQ-49 to RQ-52) each sit behind one constant or data entry, so a reference match can flip them without code changes.

## Explicitly missing

The remaining original heroes/cards (drafted in `tests/data/classic_rules_drafts.json`, not playable); the pending operations (moving, swapping and stealing units, locks, adding cards to hands, card counters) and hacks; improvement and Deed play with real cards; full shop pools/distribution; custom deck editing and full constructed/draft modes; concede, timers, spectators, replay playback and content migration.

Never add an unsupported original card to a playable deck with a partial effect. Record it as a `draft` until its complete text and interactions are implemented with tests and a reference (`docs/EFFECTS.md`).

## Reference material

- [Valve's Classic/Foundry store description](https://store.steampowered.com/app/583950/Artifact/) distinguishes Classic's sequential lanes from Foundry's shared mana.
- [Valve's deck-code and card-set API specification](https://github.com/ValveSoftware/ArtifactDeckCode) documents five heroes, their deployment rounds, signature references and card data fields. The former `playartifact.com/cardset/00/` and `01/` endpoints redirected to the Steam store when checked during this implementation; do not assume they currently return JSON.
- Record exact Classic reference-match steps and observed results in future rule fixtures. Document unresolved behavior rather than relying on memory.

The supported card numbers and image URLs come from [preserved Valve API snapshots](https://github.com/chase-stevens/artifactAlmanac/tree/master/content). Names and effect terminology are checked against [Valve game localization/glossary files](https://github.com/SteamTracking/GameTracking-Artifact/tree/master/game/dcg/resource). Images are fetched directly from Valve's original public Steam CDN URLs; provenance and artists are in `assets/classic_cards/manifest.json`.

[Valve's balance notes](https://store.steampowered.com/news/posts/?appgroupname=Artifact&appids=583950&enddate=1587420571&feed=steam_community_announcements) specify Axe 6/2/10, Gust's hero-plus-neighbors target, Broadsword 6 gold and Claymore 14 gold. Native overlays correct the older displayed fronts. The glossary's bounty definition awards gold to the opponent on death; the prior friendly-damage exception has been removed.
