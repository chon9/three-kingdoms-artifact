# Card effects: contributor guide

Every card's rules are data. They live inside the card's entry in `data/classic_cards.json` (schema 4) or `data/training_cards.json` (schema 2), next to its cost and stats. The rules engine in `scripts/core/rules/` validates them when the pack loads and runs them during play. Display text stays in `data/locale/cards.json`.

This guide covers what you need to add or change a card: the workflow, the schema in brief, patterns copied from real cards, and the rules that keep games deterministic. The normative reference is `docs/design/EFFECT_SYSTEM_SPEC.md` (§3 schema, §4 kernel, §5 worked examples, Appendix B). Rules questions (RQ-xx) and fidelity status are in `docs/RULES.md`.

## Adding a card

1. **Scaffold it.** `python tools/new_card.py "<Valve name or id>"` (add `--dry-run` to only print). It writes:
   - a `draft` entry in `data/classic_cards.json` with Valve's metadata and `valve_text`, and rules taken from the schema-4 draft in `tests/data/classic_rules_drafts.json` (all 303 counted Classic cards have one);
   - locale entries for both skins in en and zh_CN: `three_kingdoms` from `data/catalog/catalog_mapping.json`, `classic` from Valve's localization. Numbers equal to a card parameter become `{placeholders}`; every replacement is printed for review;
   - `tests/cards/<id>.json`, one empty case per Valve clause, with `covers` from `tests/data/mechanics_tags.json`.
2. **Review the rules.** Compare them with the Valve text and copy the closest pattern below. Prefer shorthands and `filter` over raw selectors and `where`.
3. **Validate.** `python tools/rules_hash.py`, then `godot --headless --path . -s tests/rules_schema_test.gd`. Errors name the card, the JSON path (with each op's name) and the problem, e.g. `chain_frost.play.ops[2]:repeat.ops[1]:let.value.rel2: unknown selector key rel2`. A shipped card must be `verified`, or a `draft` that names the RQ keeping it a draft in `rq` (the scaffold copies the draft's RQs); a draft without one fails until step 5.
4. **Test it.** Fill in the spec cases (the runner, `tests/card_specs_test.gd`, arrives in M2; until then add the cases to `tests/rules_kernel_test.gd` or the card suites, and the reviewer checks them). Each Valve clause needs a positive case and a negative or edge case (no legal target, fizzle, silenced or stunned source, immunity or shield, Purge, Fountain).
5. **Verify it.** Set `"status": "verified"` only when its cases pass and its text matches Valve's (or keep it a `draft` with its RQ).
6. **Version and test it.** Run `python tools/rules_hash.py` after the last data or code edit (`RULES_VERSION` hashes the rules code and both data packs, so every edit changes it), then `test.ps1`. Only verified, non-token cards may enter a preset (`validate_preset`).

Rules of thumb:
- Numbers that appear in the card text are top-level ints, read with `{"param": "name"}`, so the locale `{name}` placeholder and the rules can never disagree.
- Every random choice goes through `pick` or `chance`.
- Put a `pulse` op wherever Valve's text has a □ marker.
- When the glossary is silent, add an RQ to `docs/RULES.md` and the card's `rq` list instead of guessing silently.

## The schema in brief

### Card entry

| Field | Meaning |
| --- | --- |
| `id`, `source_id`, `name`, `kind`, `color`, `cost`, `price`, `attack`, `armor`, `health`, `slot`, `signature`, `text`, `image`, `artist`, `consumable`, `cross_lane` | Metadata and stats. `kind`: `hero`, `creep`, `spell`, `improvement`, `item`. Items have `slot` `weapon`, `armor`, `accessory` or `deed`. |
| `status` | `verified` or `draft`. Drafts compile and can be tested but never enter a deck; a shipped draft names its RQ in `rq`. |
| `token` | Never allowed in a deck (Melee Creep, Zombie...). |
| `rq` | Rules questions this card depends on; each must be listed in `docs/RULES.md`. |
| any other top-level int | A parameter (`amount`, `repeat`, `chance`, `ability_cooldown`...). |
| `keywords` | Printed keywords of a unit, e.g. `{"siege": {"param": "siege"}}`; a flag uses 1. |
| `charges` | Starting charges (improvement, item instance, unit), or the default counter of a card in hand. Must equal Valve's `charges`. |
| `play` | A block: spells, consumables, and a creep's Play Effect (after placement). |
| `enter` | Ops run when an item or improvement enters play (Equip Effect). |
| `abilities` | Auras, triggers and active abilities, each with a unique `id`. |
| `grants` | Text this card can give to other objects, referenced by index. |
| `valve_text` | Valve's final English text, for review and the parity test. |

Item `attack`, `armor` and `health` become an implicit aura on the equipped hero (`health` grants `max_health`).

### Blocks and choices

```json
{"choices": [{"key": "target", "from": "units"}], "requires": {"has": "allied_heroes"}, "ops": [], "initiative": true}
```

- `initiative: true` is "Get initiative".
- `requires` is a pure condition checked by `legal_actions` with the mana, colour, lock and rules gates.
- A choice `key` is one of `target`, `destination`, `lane`, `position` (the command fields). `from` is a selector; `combat_target_of` lists a unit's legal combat targets (0 is the tower); `after` keeps candidates after another choice in canonical order (unordered pairs).
- Implicit choices are never written: a creep's `position`, an improvement's `lane`, an equipment's `target` hero.

### Abilities

| `kind` | Fields | Meaning |
| --- | --- | --- |
| `aura` | `affects`, `if`, `grant` | Continuous while the source is live. `grant` holds stats, keywords or `rules`. |
| `trigger` | `on`, `filter`, `where`, `lane` (`self`/`any`), `once_per` (`round`/`lane_round`), `ops` | Reacts to an event. |
| `active` | `cooldown` (≥ 1), `requires`, `choices`, `ops`, `quicken` | Used in the action phase from the active lane. |
| `hack` | `ops` | Only in `grants`: text appended to a card in hand. |

### Refs and context

| Ref | Meaning |
| --- | --- |
| `$self` | The source: the unit, the item instance, the improvement, the new creep. Not allowed in a spell's play block. |
| `$host` | The unit that carries the ability (the equipped hero for an item). |
| `$c.<key>` | A choice. |
| `$e.<field>` | A field of the trigger's event. |
| `$v.<name>` | A variable from `let` or `for_each`. |
| `$it` | The candidate inside a selector's `where`. |
| `$played` | The played card instance (play blocks). |
| `$self.lane`, `.owner`, `.card`, `.slot`, `.hero`, `.color`, `.uid` | Read-only unit fields. |

A unit that left play during the command resolves to its look-back snapshot: ops on it fizzle, but its lane, neighbors and stats can still be read (Death Effects).

### Selectors

A selector is a shorthand, a Ref, a dictionary or a list (a union in canonical order).

| Shorthand | Meaning |
| --- | --- |
| `units`, `heroes`, `creeps` | Units in the lane |
| `allies`, `enemies`, `other_allies`, `allied_heroes`, `enemy_heroes`, `allied_creeps`, `enemy_creeps` | By side and kind |
| `allied_neighbors`, `enemy_neighbors`, `blocker`, `attackers` | Relative to `$host` |
| `your_tower`, `enemy_tower`, `both_towers` | Towers (the standing structure of a lane) |
| `your_hand`, `opponent_hand`, `you`, `opponent`, `both_players` | Cards and players |

Dictionary keys: `s` (`units` `towers` `improvements` `items` `cards` `lanes` `positions` `players`), `side`, `lane` (`active` `self` `all` `other` `fountain` or a Ref; the default is the context lane, RQ-03/RQ-04), `kind`, `card`, `color`, `slot`, `rel` (`allied_neighbors` `enemy_neighbors` `across` `blocker` `attackers` `equipped_on`), `not`, `where`, `zone`, `player`, `pick` (`{"random": N}`), `after`, `use` (expand a shorthand, then override: `{"use": "other_allies", "lane": "all"}`).

### Expressions and conditions

Expressions are integers: literals, `{"param": p}`, `"$v.x"`, `{"count": Sel}`, `{"sum": Sel, "stat": S}`, `{"stat": S, "of": Ref}`, `{"charges": Ref}`, `{"card_counter": Ref, "counter": "charges"}`, `{"gold": "you"}`, `{"price": Ref}`, `{"half": X}` (rounds down, RQ-28), `add`, `sub`, `mul`, `neg`, `min`, `max`.

Conditions: `all`, `any`, `not`, `{"cmp": [A, op, B]}`, `{"is": Ref, "in": Sel}`, `has`, `empty`, `in_play`, `unblocked`, `damaged`, `{"flag": [Ref, "stun"]}`, `{"log": "tower_hit" | "hit", ...}`, `{"active_lane": "self"}`. Conditions never use randomness.

### Ops

| Op | Fields | Notes |
| --- | --- | --- |
| `damage` | `to`, `amount`, `piercing` | Each unit takes `amount − armor` (≥ 0). All amounts are computed from one board state, then applied (FX-3). Not battle damage. |
| `damage_split` | `to`, `total` | `floor(total / N)` each (RQ-28). |
| `tower_damage` | `to`, `amount`, `piercing` | No overflow into the ancient. |
| `heal`, `tower_heal` | `to`, `amount` (or `"full"`) | Capped at max health. |
| `modify` | `to`, `stats`, `keywords`, `grant` | Permanent; written into the fields with provenance; survives the Fountain. |
| `give` | `to`, `stats`, `keywords`, `grant`, `until` | Temporary; `until` is `round`, `next_combat`, `death`, `equip` or `used`. |
| `purge` | `to`, `from` | Removes the opponent's modify and give entries (RQ-12). |
| `condemn` | `to` | The next Pulse destroys it (a Death Shield still saves). |
| `summon` | `card`, `count`, `lane`, `for`, `as` | Random empty position, then an arrow roll. |
| `retarget`, `taunt` | `unit`, `to` (uid, 0 for the tower, or `"across"`) | Forced combat targets. |
| `battle` | `a`, `b` | `a` battles every `b` at once; retaliate answers. |
| `to_fountain` | `unit` | A voluntary return: no bounty. |
| `draw`, `discard` | `player`/`n`, `cards` | Drawn cards get private instance ids. |
| `charges`, `gold`, `mana` | | Counters and resources. |
| `initiative`, `end_action_phase` | | Keep initiative; go straight to combat (RQ-20). |
| `let`, `if`, `repeat`, `for_each`, `chance`, `break` | | Control flow. `chance` is the only coin flip. |
| `pulse` | | Valve's □: settle, resolve triggers, remove the dead. |
| `move`, `swap`, `control`, `lock`, `add_card`, `card_counter` | | **Pending (M2):** they validate, so drafts compile, but a `verified` card may not use them. |
| `native` | `fn`, `args` | Escape hatch in `rules/natives.gd`; budget 5, used 0. |

Every op ignores objects that are no longer in play; a random pick over an empty set draws no randomness.

### Events and filters

| `on` | Payload (`$e.`) | Filter keys |
| --- | --- | --- |
| `before_action` | `lane` | — |
| `after_combat` | `lane` | — |
| `deployment` | — | — |
| `card_played` | `player card kind color cost lane target` | `player kind not_kind color cost_max` |
| `unit_died`, `death` | the dead unit's snapshot (`uid card owner hero color lane slot neighbors enemy_neighbors target attackers items attack armor max_health kw cause unit`) | `side kind card was` |
| `unit_entered` | `unit lane how` | `side how` |
| `improvement_entered` | `oid card owner lane` | `side` |
| `battle_damage` | `source target amount lane in_combat part` | `role target_kind source_kind in_combat` |
| `card_drawn` | `player card` | `player` |

Triggers listen in their source's lane unless `"lane": "any"`. `death` reaches only the dead unit's own abilities (its Death Effect); units dying in the same Pulse do not see each other's deaths (RQ-43).

### Keywords and statuses

Numbers: `siege`, `cleave`, `retaliate`, `regeneration`, `bounty`, `bonus_hero`, `bonus_tower`. Flags: `pierce`, `lethal`, `lethal_creeps`, `lethal_heroes`, `damage_immunity`, `rapid_deployment`, `soulbound`. Statuses (given, never from auras): `death_shield`, `stun`, `silence`, `disarm`. A keyword's value is its base (printed plus Modify) plus temporary entries plus auras. Towers hold `armor`, `mana`, `retaliate` and `regeneration`.

### Rules-layer grants

An aura whose `affects` is a player may grant `rules`: `round_draw`, `forbid_play`, `secret_shop_discount`, `creep_lane`.

### What the validator rejects

Unknown keys anywhere; fractions; unbound refs (`$c` not chosen earlier, `$v` not bound, `$e` fields of another event, `$self` in a spell); randomness in choices, conditions (an `if` op's `cond` included), auras and filters; an op without a field it needs (`Vocab.OP_REQUIRED`: `damage` and `heal` need `to` and `amount`, `retarget` needs `unit` and `to`, `if` needs `cond`, `chance` needs `pct`, `give` needs `until`...); a number written as a string; a hero or creep without `attack` or `health`; a `summon` of a card that is not a hero or creep of the pack, and a `signature` that is not a card of the pack; stat auras that read derived stats, keyword auras that read keywords, and auras granting statuses; missing params; bad `grant` indexes; actives without a cooldown; tower keywords other than armor, mana, retaliate and regeneration; `health` in a Grant (use `max_health`); a verified card using a pending op. A card with any error is not playable, and `tests/rules_schema_test.gd` requires zero errors.

It warns (and the pack test requires zero warnings) when a top-level parameter is read by no `{"param": ...}` and no locale `{placeholder}`: that is usually a typo such as `amout` or `atack`.

## Patterns from real cards

Each pattern is the actual entry (rules only). Draft patterns come from `tests/data/classic_rules_drafts.json`.

**Aura on neighbors** (Prowler Vanguard; Farvhan and Lycan alike):
```json
"neighbor_armor": 1,
"abilities": [{"id": "vanguard", "kind": "aura", "affects": "allied_neighbors", "grant": {"armor": {"param": "neighbor_armor"}}}]
```

**Aura on other allies in every lane** (Drow Ranger):
```json
"abilities": [{"id": "precision_aura", "kind": "aura", "affects": {"use": "other_allies", "lane": "all"}, "grant": {"attack": {"param": "global_attack"}}}]
```

**Trigger after you play a card** (Zeus, Static Field):
```json
"abilities": [{"id": "static_field", "kind": "trigger", "on": "card_played", "filter": {"player": "you", "kind": "spell", "color": "blue"},
  "ops": [{"op": "damage", "to": "enemy_neighbors", "amount": {"param": "static_field"}, "piercing": true}]}]
```

**Trigger after combat, permanent growth** (Savage Wolf):
```json
"abilities": [{"id": "growth", "kind": "trigger", "on": "after_combat",
  "ops": [{"op": "modify", "to": "$self", "stats": {"attack": {"param": "combat_growth_attack"}, "max_health": {"param": "combat_growth_health"}}}]}]
```

**Active ability** (J'Muy, Wisdom of the Elders):
```json
"ability_cooldown": 4,
"abilities": [{"id": "wisdom_of_the_elders", "kind": "active", "cooldown": {"param": "ability_cooldown"}, "ops": [{"op": "draw", "player": "you", "n": 1}]}]
```

**Targeted damage with initiative** (Hip Fire; Pick Off adds `"lane": "all"` to the choice and `"cross_lane": true`):
```json
"play": {"choices": [{"key": "target", "from": "units"}], "ops": [{"op": "damage", "to": "$c.target", "amount": {"param": "amount"}}], "initiative": true}
```

**Every enemy unit** (Tower Barrage, Thunderstorm; the tower is not a unit, RQ-01):
```json
"play": {"ops": [{"op": "damage", "to": "enemies", "amount": {"param": "amount"}}]}
```

**Every enemy hero in all lanes, piercing** (Thundergod's Wrath):
```json
"play": {"ops": [{"op": "damage", "to": {"s": "units", "side": "enemy", "kind": "hero", "lane": "all"}, "amount": {"param": "amount"}, "piercing": true}]}
```

**A target and its neighbors, this round** (Gust: a list is a union):
```json
"play": {"choices": [{"key": "target", "from": "enemy_heroes"}],
  "ops": [{"op": "give", "to": ["$c.target", {"s": "units", "rel": {"allied_neighbors": "$c.target"}}], "keywords": {"silence": 1}, "until": "round"}]}
```

**Permanent and temporary buffs** (Fighting Instinct, Defensive Stance):
```json
"play": {"choices": [{"key": "target", "from": {"s": "units", "kind": "hero", "color": "red"}}],
  "ops": [{"op": "modify", "to": "$c.target", "stats": {"attack": {"param": "attack"}, "armor": {"param": "armor"}}}]}
"play": {"choices": [{"key": "target", "from": "heroes"}], "ops": [{"op": "give", "to": "$c.target", "stats": {"armor": {"param": "armor"}}, "until": "round"}]}
```

**Battles** (Berserker's Call):
```json
"play": {"choices": [{"key": "target", "from": {"s": "units", "side": "ally", "kind": "hero", "color": "red"}}],
  "ops": [{"op": "battle", "a": "$c.target", "b": {"s": "units", "rel": {"enemy_neighbors": "$c.target"}}}]}
```

**Choose a combat target** (Battlefield Control; the tower is offered only when the position directly across is empty, RQ-19):
```json
"play": {"choices": [{"key": "target", "from": "units"}, {"key": "destination", "combat_target_of": "$c.target"}],
  "ops": [{"op": "retarget", "unit": "$c.target", "to": "$c.destination"}]}
```

**Temporary keyword and forced targets** (Forward Charge):
```json
"play": {"ops": [{"op": "give", "to": "allies", "keywords": {"siege": {"param": "siege"}}, "until": "round"}, {"op": "retarget", "unit": "allies", "to": "across"}]}
```

**Summon** (Dimensional Portal) and **tower mana** (Stars Align):
```json
"play": {"ops": [{"op": "summon", "card": "melee_creep", "count": {"param": "amount"}}]}
"play": {"ops": [{"op": "give", "to": "your_tower", "stats": {"mana": {"param": "amount"}}, "until": "round"}]}
```

**Random discard, then condemn** (Coup de Grace):
```json
"play": {"choices": [{"key": "target", "from": "heroes"}],
  "ops": [{"op": "discard", "cards": {"use": "your_hand", "pick": {"random": 1}}}, {"op": "condemn", "to": "$c.target"}]}
```

**Keywords on a unit** (Thunderhide Pack siege, Debbi's bonuses, Rix):
```json
"keywords": {"siege": {"param": "siege"}}
"keywords": {"bonus_hero": {"param": "hero_tower_bonus"}, "bonus_tower": {"param": "hero_tower_bonus"}}
"keywords": {"rapid_deployment": 1}
```

**Equipment and consumables** (Short Sword is just `"attack": 2`; Healing Salve):
```json
"amount": 6, "consumable": true,
"play": {"choices": [{"key": "target", "from": "units"}], "ops": [{"op": "heal", "to": "$c.target", "amount": {"param": "amount"}}]}
```

**An independent roll per unit** (Tidehunter, draft):
```json
"ops": [{"op": "let", "name": "near", "value": "enemy_neighbors"},
        {"op": "give", "to": "$v.near", "until": "round", "keywords": {"stun": 1}},
        {"op": "for_each", "in": {"use": "enemies", "not": "$v.near"}, "as": "u",
         "ops": [{"op": "chance", "pct": {"param": "chance"}, "then": [{"op": "give", "to": "$v.u", "until": "round", "keywords": {"stun": 1}}]}]}]
```

**Repeat with Pulses and a random bounce** (Chain Frost, draft, RQ-15/RQ-16):
```json
"play": {"choices": [{"key": "target", "from": "units"}], "initiative": true,
  "ops": [{"op": "damage", "to": "$c.target", "amount": {"param": "amount"}},
          {"op": "let", "name": "prev", "value": "$c.target"},
          {"op": "repeat", "times": {"param": "repeat"}, "ops": [
            {"op": "pulse"},
            {"op": "let", "name": "next", "value": {"s": "units", "rel": {"allied_neighbors": "$v.prev"}, "pick": {"random": 1}}},
            {"op": "if", "cond": {"empty": "$v.next"}, "then": [{"op": "break"}]},
            {"op": "damage", "to": "$v.next", "amount": {"param": "amount"}},
            {"op": "let", "name": "prev", "value": "$v.next"}]}]}
```

**Read a value before condemning** (Lich, draft): `let` the attack first, because the target is gone after the Pulse.
```json
"ops": [{"op": "let", "name": "atk", "value": {"stat": "attack", "of": "$c.target"}},
        {"op": "condemn", "to": "$c.target"}, {"op": "draw", "player": "you", "n": 1},
        {"op": "if", "cond": {"cmp": ["$v.atk", ">=", {"param": "threshold"}]}, "then": [{"op": "draw", "player": "you", "n": 1}]}]
```

**Charges on an improvement** (March of the Machines, draft):
```json
"charges": 3,
"abilities": [{"id": "march", "kind": "trigger", "on": "before_action", "where": {"cmp": [{"charges": "$self"}, ">", 0]},
  "ops": [{"op": "charges", "on": "$self", "add": -1}, {"op": "tower_damage", "to": "enemy_tower", "amount": {"param": "amount"}},
          {"op": "damage", "to": "enemies", "amount": {"param": "amount"}}]}]
```

**Granted text** (Heartstopper Aura, draft): the granted trigger runs with the bearer as `$self` and the granting card's params.
```json
"grants": [{"kind": "trigger", "on": "before_action", "ops": [{"op": "damage", "to": "enemy_neighbors", "amount": 2, "piercing": true}]}],
"play": {"choices": [{"key": "target", "from": {"s": "units", "kind": "hero", "color": "black"}}], "ops": [{"op": "modify", "to": "$c.target", "grant": 0}]}
```

**Rules layer** (Shop Deed, draft):
```json
"abilities": [{"id": "deed", "kind": "aura", "affects": "you", "grant": {"rules": {"secret_shop_discount": 1}}}]
```

## How the kernel runs it

- **One command.** `apply_action` validates against `legal_actions`, runs the card's ops, then a Pulse, then emits `card_played` and pulses again. An ability emits `ability` before its ops.
- **Triggers.** When an event fires, live listeners are collected and checked (`filter`, `where`, `once_per`), then queued. A Pulse resolves the queue as one batch, sorted by event, the initiative player's side first, lane, zone, position, ability and id (RQ-37). Events raised during a batch wait for the next batch.
- **The Pulse.** Settle continuous effects (a max-health change moves current health, RQ-40), collect units at 0 health or condemned, condemn Soulbound partners, consume Death Shields, snapshot and remove the dead, emit `death` and `unit_died`, resolve the batch, and repeat until nothing is queued and nothing died. A unit projects its auras until it is removed (FX-3).
- **Stats.** `attack_of`, `armor_of`, `max_health_of` and `keyword_of` derive values at read time: base fields (with Modify written in), temporary entries, item auras, stat auras, then keyword auras.
- **Guards.** 2048 ops per command, 16 nested Pulses, 64 loops per Pulse. Overflow stops resolution and logs `rules_overflow` the same way on every peer.

## Determinism checklist

The rules scripts are static functions over the engine; `tests/rules_schema_test.gd` lints them.

1. Randomness only through `Kernel.rand_index` and `Kernel.chance`. No `randf`, `randi`, `shuffle`, `pick_random`, `Time`, `OS` or `hash`.
2. Never let dictionary iteration order decide state. Iterate arrays in canonical order: player 0 then 1, lanes ascending, slots ascending.
3. Every sort uses a total key ending in a uid or oid (`sort_custom` is not stable).
4. Integers only; "half" rounds down.
5. No instance or static variables in `scripts/core/rules/`.
6. Read-only functions (`legal_actions`, `combat_preview`, `player_view`, the `*_of` helpers) never change state or randomness.
7. Hidden information (hand and deck contents, drawn cards) never reaches public state or public event fields; private event fields go under `_s`.
8. Any rules change changes `RULES_VERSION` (`python tools/rules_hash.py`); replays and online peers with a different version refuse each other.

## Changing behaviour on purpose

The golden games (`tests/golden/`, data in `tests/data/goldens/`) replay 54 recorded bot games and compare every step. A refactor must keep them byte-identical. A deliberate rules change (like FX-1 to FX-3) re-records them with `godot --headless --path . --script res://tools/record_goldens.gd`; list which games changed and why. `tests/differential_test.gd` compares the engine with a frozen copy of the pre-migration engine (`tests/legacy/`), which receives the same deliberate fixes.

## Not yet supported (M2)

- The pending ops above, and hacks on cards in hand.
- Improvement and Deed play, and item or improvement actives and triggers with real cards.
- The per-card spec runner (`tests/card_specs_test.gd`), generated card checks and fuzzing.
- The generic target stepper, ability buttons for items and improvements, the improvement row, hand badges and event animations.
