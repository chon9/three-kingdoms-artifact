# Effect system specification: data-driven Classic card rules

Project: Three Kingdoms: Three Lanes (`K:/Project/Mini2`), Godot 4.5.2, GDScript.
Status: final design, ready to implement. It was written read-only against commit `1f724a0` (engine `PROTOCOL_VERSION = 6`, Steam `PROTOCOL = 7`).
Scope: one effect system that can implement all 303 Artifact Classic cards (plus 75 abilities) faithfully and test them, without breaking determinism, replays, Steam play, privacy or the current UI.

Sources:
- `effects/MECHANICS.md` and `effects/mechanics.json`: the mechanics inventory, RQ-01 to RQ-36.
- Valve set 00 and 01 data: texts, `Active N` cooldowns and Pulse markers `[g:608]`.
- `.tools/valve_glossary.txt` and the wiki pages: Phases, Improvements, Heroes, Pathing and Fountains.
- The engine, UI, bot, network code and the tests.
- The three candidate designs: declarative, scripted and hybrid.

How to read this document:
- §0 scores the candidates and records the decisions.
- §1 to §4 are the normative design.
- §5 gives 27 worked examples covering 43 real cards written in the schema.
- §6 to §10 cover the consumers: engine API, targeting, UI, bot, network.
- §11 to §13 cover migration, the plan and the tests.
- Appendix A assigns every card to a milestone.
- "Coverage fixes" (the last section) records the completeness review of all 303 cards against this schema, the fixes CF-1 to CF-12 that are already folded into §2 to §14 (each edited place carries a `[CF-n]` tag), and the questions that remain open.

Words in this spec:
- "must" means a test enforces it.
- "Pulse" means `Kernel.pulse(e)`.
- `e` is the `MatchEngine` instance.

---

## 0. Evaluation and verdict

### 0.1 Scores (1 = poor, 5 = excellent; for migration risk, 5 = lowest risk)

| Criterion | Declarative (JSON + VM) | Scripted (a GDScript file per card) | Hybrid (JSON + static kernel + handlers) |
|---|---|---|---|
| Coverage of every mechanic in MECHANICS.md | **5**. Every verb, target and trigger in the inventory maps to an op, selector or rules grant. It claims no natives are needed. Two gaps: no `sum` expression (needed by Lodestone Demolition) and no lane-0 hook in `start()`. | **5**. A Turing-complete script per card plus about 20 hooks covers everything by construction. The design shows hooks, not a per-mechanic mapping. | **4**. The vocabulary is complete, but plan-then-apply forbids Pulses inside reactive abilities. Text such as Self Sabotage's hack (which starts with a Pulse) therefore has to become a handler. |
| Faithfulness to Classic timing | **4**. Pulse loop, look-back snapshots, round log and the full set of durations. It misses the "before the action phase" of round 1, lane 0, and it pulses after every trigger. | **4**. It has the `start()` hook, strike-level combat and Kanna privacy. It pulses after every trigger, which contradicts "all triggers happen simultaneously". | **4**. Plan-then-apply is the closest reading of "simultaneous", and it adds RQ-37 to RQ-40. It misses `start()`, and plans go stale for ops that do not commute (summon, move, charges). |
| Simplicity and maintainability | **4**. One interpreter and uniform data, so fixing an op fixes every card. The cost is a small expression language to learn. | **3**. There is no VM, but there are about 190 card scripts (4,000 to 5,000 lines), standard scripts and a generated registry. A rules fix has to be repeated across files. | **3**. Its static modules are clean. But plan/apply doubles every op, and path-encoded choices change the network format, the UI and validation at the same time. |
| Determinism and network/replay safety | **5**. No floats, total orders, private event fields, `rules_hash`, privacy taint fuzzing, and commands unchanged. | **3**. Free-form code can break determinism or privacy; only lint and parity tests guard against it. Script code also has to be hashed. | **4**. Strong rules, but it changes the guest action format to paths and adds a second validation path. |
| Testability | **5**. A schema lint (the prototype runs), a JSON scenario DSL, generated invariants, a differential test, fuzzing, goldens and performance budgets. | **4**. Fluent GDScript specs, recordings and meta tests. Scripts cannot be checked statically against card clauses. | **5**. JSON specs with a clause-coverage gate, a hidden-swap privacy test, a mirror test and legacy projections. |
| Migration risk | **4**. A per-card switch plus a differential test. Its pull-only Modify forces test edits (`wolf.attack`, `temp_siege`). | **5**. Write-through Modify keeps every assertion, effect branches move verbatim, and recordings gate each step. | **3**. The byte-identical first phase is good. But the state shape, choice paths, the UI step machine and batch semantics all land together. |
| Contributor-friendliness | **4**. A card is a JSON entry plus a JSON test, with lint feedback and scaffolds. The `$c.` / `$e.` / `$v.` refs take some learning. | **3**. GDScript is familiar to Godot contributors. But they must learn the `Rules`/`Query` facades and invariants such as no vars and no `randi`, and regenerate the registry. | **4**. A readable selector grammar and a stub generator; handlers are rare. |
| **Total (of 35)** | **31** | **27** | **27** |

### 0.2 Verdict: declarative base, grafts from the other two

**The base is the declarative design.** It has the most complete and verifiable vocabulary, and the safest determinism and privacy model. It also has a working lint prototype and examples.

**Grafts from the scripted design:**
1. **Permanent Modify writes through.** It changes the unit's own fields, as the engine's `modify` branch does today (`match_engine.gd:347`), and records a provenance entry so Purge can reverse it. Every existing assertion keeps passing, for example `wolf.attack == 4` at `expanded_classic_test.gd:161`.
2. **Round 1, lane 0, gets a before-the-action phase** at the end of `start()`.
3. **Rules code is part of the network content hash and the replay identity.** A generated `RULES_VERSION` is needed because exported builds use `script_export_mode=2` (binary tokens), so the scripts cannot be hashed at runtime.
4. **Recordings of today's behaviour** (goldens) gate every refactor step.
5. **Kanna's pending lane creeps are published as `-1`,** so her private lane plan never leaks.
6. **Natives are stateless static handlers** with a lint, capped at 5 and planned at 0.
7. **A spec text-drift meta test:** spec text must equal the Valve text.

**Grafts from the hybrid design:**
1. **Rules modules are static-function scripts that take `e`** and hold no RefCounted back-references. GDScript leaks reference cycles, and the bot creates one simulation engine per candidate action (`simulation_from_view`).
2. **Rules live inline in `data/classic_cards.json` (schema 4),** one entry per card. That file is already in `CONTENT_FILES` and in the export `include_filter`. Numbers stay top-level, so locale `{placeholders}` keep filling.
3. **Death snapshots carry relational lists:** `neighbors`, `enemy_neighbors`, `attackers` and `target`. Condemn is a flag, and Soulbound closes over the dying set.
4. **Trigger batches resolve without a Pulse between triggers.** This simplifies plan-then-apply, can be switched off, and has one canonical order function.
5. **RQ-37 to RQ-40,** the mirror (symmetry) test, the hidden-swap privacy test, and the `has_active` / `has_passive` library helpers.
6. **A behaviour-preserving refactor step** with byte-identical digests comes before any behaviour change.

**New in this synthesis:**
- selector shorthands and trigger `filter` sugar
- relations that take a set
- list-union targets
- the `sum` expression
- write-through tower mana that generalizes the existing `mana_bonus`
- per-hit strikes in the `combat` event
- the deeds zone
- card instance ids
- an aura-liveness compatibility rule in M1, replaced by fix FX-3
- milestone card lists (Appendix A)

**Rejected:**

| Idea | From | Reason |
|---|---|---|
| Plan-then-apply batches | hybrid | Batch-then-pulse gives the same result for every commuting op at a fraction of the code. |
| Path-encoded actions on the network | hybrid | Flat `legal_actions` stays the network format. Its size is measured, and paths are kept in reserve as protocol 9. |
| A GDScript file per card by default | scripted | Spreads rules across about 200 files and weakens determinism guarantees. |
| A separate rules file | declarative | A second file per card to keep in sync, and a second content hash. |
| A second validator in Python | declarative | It would drift from the authoritative GDScript validator. |
| Pull-only Modify | declarative | Forces test edits and splits "base" into two representations. |

### 0.3 Key decisions (K1 to K15)

- **K1. One rules representation.** Card behaviour is JSON inside the card's entry in `data/classic_cards.json`. GDScript is used only through the native registry, capped at 5 entries and targeted at 0.
- **K2. Command shapes are unchanged.**
  - Choices use the existing integer fields `target`, `destination`, `lane` and `position`.
  - An ability command is `{"type":"ability","unit":<source id>}`, where the source is a unit uid, an item instance id or an improvement id. The existing canonicalization at `match_engine.gd:203` already covers every field.
- **K3. Stats are partly stored and partly derived.**
  - Stored: printed values plus permanent Modify (written through).
  - Derived on read: temporary effects, granted text, and every aura, item and improvement contribution.
- **K4. The Pulse is the only place** where units, items and improvements leave play because of death or condemn.
- **K5. Triggers are collected when their event is emitted,** from live sources only. They resolve in batches in one total order, with one Pulse after each batch.
- **K6. All randomness goes through `Kernel.rand_*` on `e.rng`.** It happens at resolution, in canonical candidate order, and never inside `legal_actions`, previews, auras or conditions.
- **K7. Hidden state lives in `hand_state` and `deck_state`,** arrays parallel to `hand` and `deck`. `hand` stays `Array[String]`. Views redact this state and private event fields.
- **K8. Rules modules are static.**
  - Transient queues live on the engine instance and never in `state`.
  - `apply_action` returns with them empty; this is asserted.
- **K9. Integer arithmetic only.** "Half" rounds down (RQ-28). JSON numbers are normalized to int at compile time, and fractions are rejected.
- **K10. Each rules-question decision** lives in one constant or data field and one named test.
- **K11. Versions:**
  - Replay format goes from 6 to 7.
  - Steam protocol goes from 7 to 8.
  - `RULES_VERSION` (a code hash) is added to the content hash and to replays.
- **K12. Migration happens in behaviour-preserving steps** gated by goldens. Deliberate fidelity fixes are separate commits.
- **K13. Unimplemented cards never enter decks.**
  - `status:"draft"` cards compile and can be tested.
  - `validate_preset` requires `status:"verified"`.
- **K14. A card becomes `verified` only** when a passing spec covers every Valve clause.
- **K15. Measure first.** There are no caches until a perf test misses its budget.

---

## 1. Architecture

### 1.1 Layers

```
 UI (match_screen, board_view, lane_view, unit_card, hand_view) ── reads player_view + legal_actions + engine read helpers
 Bot (heuristic_bot) ─────────────── simulation_from_view + legal_actions + combat_preview
 Network (steam_bridge) ──────────── player_view(1) + legal_actions(1) (flat, unchanged shape)
                    │
 MatchEngine (facade; public API unchanged; phases, commands, views, replays)
   ├─ Targeting   choice specs → legal commands; is_legal(command); choice_steps (UI)
   ├─ Kernel      primitives, event bus, trigger queue, Pulse, deaths, lane_open, end_of_round, rand_*
   ├─ VM          ops / expressions / conditions over a ctx
   ├─ Select      selectors, relations, canonical order, random picks, look-back
   ├─ Stats       derived stats/keywords/flags, tower stats, rules layer, settle (health/mana deltas, mirrors)
   ├─ Combat      strikes (plan → apply), battles outside combat, preview
   └─ Zones       hand/deck state, draw/lock/hack, items, improvements, deeds, summon/move/swap/control/fountain
 CardLibrary (+ RulesDB): load packs, normalize, expand shorthands, validate, compile, listener index
 data/classic_cards.json (schema 4: metadata + numbers + rules)    data/locale/cards.json (text)
```

### 1.2 Modules

Every new file under `scripts/core/rules/` is a script of `static func`s whose first parameter is `e`. These scripts have no instance members (a lint test enforces this) and no `class_name` cycles.

| File | Responsibility | Main functions |
|---|---|---|
| `scripts/core/match_engine.gd` | Facade: phase flow, commands, views, replays. Keeps every public function and the test-facing wrappers `_clean_dead`, `_begin_deployment`, `_reveal_deployment`, `_make_unit`, `_place`, `_spawn`, `_remove_from_lane`, `_damage_structure`, `_check_winner`, `_max_health`, `_event` | `start`, `legal_actions`, `apply_action`, `player_view`, `simulation_from_view`, `combat_preview`, `attack_of`, `armor_of`, `max_health_of`, `keyword_of`, `badges`, `abilities_of`, `choice_steps` |
| `scripts/core/card_library.gd` | Loads the pack and calls `RulesDB.compile`. Exposes compiled rules | `rules(id)`, `listeners(event)`, `has_active(id)`, `has_passive(id)`, `choice_spec(id)`, `errors` |
| `rules/vocab.gd` | Constants: ops and their fields, selector keys, events, filter keys, keywords, durations, rules keys | — |
| `rules/rules_db.gd` | Normalizes ints, expands shorthands, validates against the vocabulary, compiles abilities and blocks, indexes listeners and choices. Errors make the card unplayable and are listed | `compile(card)`, `validate(card)` |
| `rules/vm.gd` | Runs ops, evaluates expressions and conditions, resolves refs, fizzles ops, enforces the op budget | `run(e, ops, ctx)`, `expr(e, x, ctx)`, `cond(e, c, ctx)`, `ref(e, r, ctx)` |
| `rules/select.gd` | Enumerates selectors and tests membership, evaluates relations, defines canonical order, makes random picks, reads look-back snapshots | `enumerate(e, sel, ctx)`, `includes(e, sel, ctx, obj)` |
| `rules/stats.gd` | Derived stats, keywords and flags; tower stats; the rules layer; settle | `derive(e, u)`, `kw(e, u, k)`, `flag(e, u, f)`, `tower(e, l, p)`, `rules_of(e, p)`, `settle(e)` |
| `rules/kernel.gd` | Damage, heal, condemn, modify, give, purge, the event bus, the trigger queue, the Pulse, deaths and snapshots, lane opening, end of round, randomness | `emit`, `pulse`, `damage`, `lane_open`, `end_of_round`, `rand_index`, `chance` |
| `rules/combat.gd` | Strikes (plan, then apply); battles outside combat; the preview | `plan(e, lane)`, `resolve(e, lane)`, `battle(e, a, bs)` |
| `rules/zones.gd` | Hand and deck state, draw, discard, lock, hack, `add_card`; items; improvements; deeds; summon, move, swap, control, fountain; arrow normalization | `draw`, `equip`, `summon`, `move`, `swap`, `normalize_arrows`, `sync` |
| `rules/targeting.gd` | Turns choice specs into legal commands, validates commands, describes UI steps | `actions(e, p)`, `is_legal(e, p, cmd)`, `steps(e, source)` |
| `rules/natives.gd` | Sanctioned handlers. Empty at launch | `run(e, fn, ctx, args)` |
| `rules/rules_version.gd` | Generated by `tools/rules_hash.py` (`tools/` is committed; `.tools/` is not) | `RULES_VERSION`, `CODE_HASH` |

Transient fields live on the engine instance, never in `state`. They are reset at the start of `start()` and `apply_action()`, and asserted empty or zero when those return:
- `_queue: Array` (trigger instances)
- `_event_index: int`
- `_pulse_depth: int`
- `_ops_left: int` (2048 per command)
- `_lookback: Dictionary` (uid or oid to its snapshot, kept for the current command)
- `_deploying: bool`

### 1.3 One command

```
apply_action(p, cmd)
  canonicalize ints (existing list) → Targeting.is_legal(e, p, cmd) (enumerates only the referenced hand card / source) → journal
  "play":    _play → pay mana → take the card and its hand_state entry out of hand (ctx.played) → event "play"
             creep:        Zones.place_creep (chosen position, arrow roll, emit unit_entered) → VM.run(card.play.ops)   # Play Effect
             equipment:    Zones.equip (replace slot, new item instance, end "until equip" effects) → VM.run(card.enter)
             improvement:  Zones.add_improvement (chosen lane, 16-cap) → emit improvement_entered → VM.run(card.enter)
             deed:         Zones.add_deed
             spell/consumable: VM.run(card.play.ops)
             hacks on the played card: Kernel.pulse → VM.run(hack.ops) with controller p
             Kernel.pulse → Kernel.emit(card_played) → Kernel.pulse
             _check_winner → ctx.end_phase ? _end_action_phase() : _finish_action(p, ctx.keep_initiative)
  "ability": VM.run(ability.ops, ctx{src}) → set cooldown (quicken) → event "ability" → Kernel.pulse → _check_winner → _finish_action(p, false)
  "pass":    unchanged; the second pass runs Combat.resolve → after_combat → next lane's lane_open (before_action)
  shop / deployment commands: unchanged, plus prices from the rules layer and the deployment hooks (§4.6)
  state.revision += 1
```

### 1.4 Determinism and privacy contract

Each rule is enforced by a test (§13):

- **D1. One random stream.** Only `Kernel.rand_index(e, n)` (`e.rng.randi_range(0, n - 1)`) and `Kernel.chance(e, pct)` (`e.rng.randi_range(0, 99) < pct`) touch `e.rng`. Forbidden: `randf`, `randi`, `shuffle()`, `pick_random()`, `Time`, `OS`, `hash()`. A lint test greps the rules scripts.
- **D2. Canonical order.** Candidates are enumerated in one order: player 0 then 1, then lanes ascending, then slot ascending. This is the order `legal_actions` uses today (sides `[0, 1]`, then lanes, then row order), so bot tie-breaks and goldens are unchanged. The tower comes first where it is an option, as `combat_targets` puts it today. Deaths (§4.3) and triggers (§4.2) use their own documented orders.
  - Every sort uses a total key ending in a uid or oid, because `sort_custom` is not stable.
  - Iteration never follows the order of a dictionary keyed by uid.
- **D3. Read-only functions are pure.** `legal_actions`, `combat_preview`, `player_view`, the `*_of` helpers and `choice_steps` never mutate state or touch `rng`. The test compares the digest and `rng.state` before and after each call.
- **D4. Integers only.** `half` rounds down. A chance is an integer percentage.
- **D5. Card JSON is normalized to int at load.** Fractions are a compile error. Commands are canonicalized as today.
- **D6. Ops never error on missing objects.** An op on an object no longer in play fizzles: no event, no randomness. A random pick over an empty set consumes no randomness.
- **D7. Guards.**
  - Limits: 2048 op executions per command, 16 levels of nested Pulses, 64 loop iterations per Pulse.
  - On overflow, the engine stops resolving, clears the queue and emits `{"k":"rules_overflow"}`. This is deterministic on every peer. Fuzz tests assert it never happens.
- **D8. Hidden information stays hidden.** It never reaches public state or public event fields.
  - Private fields go under the event key `_s`, which `player_view` strips per viewer.
  - Opponent `hand_state`, both players' `deck_state`, and the `iid`s of opponent cards are redacted.
- **D9. Bot simulations never see live randomness.** `simulation_from_view` keeps `rng.seed = 1`. Ops over hidden zones in a simulation see empty arrays and do nothing.
- **D10. Every rules change is versioned.** `RULES_VERSION` changes with any rules-code or rules-data change. Replays refuse a different `rules` value (`replay_rules`), and the Steam content hash differs.

---

## 2. State model (all JSON-safe, all in `state_digest`)

### 2.1 Units (`_make_unit`)

| Field | Status | Meaning |
|---|---|---|
| `uid, card, owner, hero, color, lane, ready_round, arrow, combat_target, items` | unchanged | `items` stays `{slot: card_id}` (the UI reads it) |
| `attack, armor, max_health` | **meaning widened** | Printed value plus permanent Modify (written through). Fixtures may still write them |
| `health` | unchanged | Current health |
| `kw` | new, `{}` | Printed keywords plus permanent Modify deltas, e.g. `{"siege": 6}`. Flag keywords use 1. `bounty` is set to 5 for heroes and 1 for creeps |
| `mods` | new, `[]` | Modifier entries (§2.2) in creation order |
| `item_state` | new, `{}` | `slot -> {"oid", "cd": 0, "charges": 0, "mods": []}` |
| `cooldown` | unchanged name | Cooldown of the unit's own active ability (J'Muy tests read `hero.cooldown`) |
| `charges`, `used` | new, `0`, `{}` | Unit counters; once-per marks (`"ability_id:lane" -> round`) |
| `condemned` | new, `false` | Marked for death; resolved at the next Pulse |
| `hp_seen` | new | Last derived max health; settle shifts `health` by the change (§4.4) |
| `roster` | new, `true` | Heroes from the deck. Summoned heroes (Divided We Stand) were `false`; since M4 they join the roster and are `true` (RQ-29, `SUMMONED_HEROES_JOIN_ROSTER`) |
| `silenced, stunned, disarmed` | **mirror** | Written only by `Stats.settle` for the UI and tests. Never read by rules |
| `temp_attack, temp_armor, temp_siege` | **removed** | The M1 shim (read as a round layer, zeroed at round end and in the Fountain) is gone; tests use `give … until round` |

Removed in M1.3, because they become compiled abilities:
- `neighbor_armor`, `neighbor_attack`, `global_attack`, `hero_bonus`, `hero_tower_bonus`, `static_field`, `rapid_deployment`, `combat_growth_attack`, `combat_growth_health`, `ability`, `ability_cooldown`
- `siege` (it moves to `kw.siege`)

### 2.2 Modifier entries (`mods`)

```json
{"id": 1000123, "k": "give", "by": 0, "src": "defensive_stance",
 "st": {"armor": 3}, "kw": {}, "ab": "", "d": "round"}
```
- `k`:
  - `"modify"` is permanent. Its `st` and `kw` deltas were already added to the owner's fields when the entry was created. The entry exists for Purge and the inspect UI.
  - `"give"` is temporary. Its deltas are pulled at read time and it expires according to `d`.
- `by`: the player who created the entry. Purge needs it (RQ-12).
- `src`: the card id of the source, for UI tooltips.
- `ab`: an optional granted ability `"<card_id>#<index into that card's grants>"`. It is live while the entry exists.
- `d`: one of
  - `perm` (modify)
  - `round`
  - `next_combat`
  - `death` (until it dies; also removed in the Fountain)
  - `equip` (until the hero equips an item; also removed in the Fountain)
  - `used` (Death Shield, removed when consumed)
- `modify` entries with the same `by`, `src` and `d` and no `ab` **coalesce** by summing. This bounds the size of state in long games.
- The same entry shape is used on towers (`structures[p].mods`), item instances and improvements.

### 2.3 Towers and mana

- `structures[p]` gains `"armor": 0` (permanent base, written through) and `"mods": []`.
- Mana keeps its fields:
  - `mana[p]`: current mana.
  - `max_mana[p]`: displayed maximum.
  - `mana_bonus[p]`: the total modifier currently applied to `max_mana`. This generalizes what Stars Align does today.
  - `max_mana_base[p]` **[CF-5]**: new. The maximum before temporary and continuous modifiers: 3 at the start, +1 per round, plus permanent `modify` deltas (Arcane Censure). Displayed `max_mana` is always `max(0, max_mana_base + mana_bonus)`.
- Settle (§4.4) recomputes `max_mana` from `max_mana_base` and the current modifier total, and moves `mana` by the change it actually made to `max_mana`, clamped at 0. Because the floor is applied to the derived value and never written into the base, stacking −Mana effects below 0 (The Tyler Estate + Tyler Estate Censor + Mana Drain in round 1) and later losing some of them restores exactly the right maximum. Fixtures without `max_mana_base` get `max_mana − mana_bonus` on their first settle.
- Fixtures that set `mana` and `max_mana` directly keep working. `classic_cards_test.gd:239-241` still sees 12/13, then 11/11.

### 2.4 Improvements, deeds and items as objects

```json
{"lanes[l].improvements": [[{"oid": 1000040, "card": "bitter_enemies", "owner": 0, "lane": 1, "cd": 0, "charges": 3,
                             "mods": [], "condemned": false, "order": 17}], []],
 "players[p].deeds": [{"oid": 1000052, "card": "shop_deed"}],
 "unit.item_state.weapon": {"oid": 1000031, "cd": 0, "charges": 0, "mods": []}}
```
- Each side of each lane holds at most 16 improvements (RQ-34/RQ-47). Playing a 17th condemns one of that side's existing improvements at random (`rand_index`) before the new one enters.

### 2.5 Hidden per-card state

- `players[p].hand_state` runs parallel to `hand`. Each entry is `{"iid": n}` plus optional fields:
  - `"lock": n`
  - `"charges": n`
  - `"hacks": ["self_sabotage#0"]`
  - `"base": true`
- `players[p].deck_state` runs parallel to `deck`. It is sparse: an empty array, or padded with `{}`, until something writes to it (Luna).
- **Default counter value [CF-2].** A card instance whose entry has no `"charges"` key has the card's printed top-level `charges` (0 when the card has none). Eclipse is printed with 1 charge (Valve set 01, `"charges": 1`), so a freshly drawn or base-copied Eclipse repeats once. `card_counter add` first materializes the default, then adds. Drawn cards, `add_card` copies (base or not) and cards in a sparse `deck_state` therefore need no stored value.
- Decks are only shuffled in `start()`, before any state exists, so a parallel shuffle is never needed.
- Rules for these arrays:
  - Every zone change goes through `Zones` helpers.
  - `Zones.sync(e, p)` pads or truncates both arrays at the top of `legal_actions` and `apply_action`. This lets fixtures that assign `hand = ["gust"]` keep working.
  - `iid`s come from `state.next_oid`.

### 2.6 Match-level additions

| Field | Meaning |
|---|---|
| `state.next_oid` | Starts at 1,000,000. Used for items, improvements, deeds, mods and card instances. Unit uids keep `next_id`, so legacy uid sequences, and therefore golden replays, do not change |
| `state.round_log` | `{"tower_hit": [[false,false,false],[false,false,false]], "hits": [[uid, "creep"\|"hero"\|"tower"], ...]}`, cleared at round end. Used by Unearthed Secrets, Rebel Instigator and Red Mist Pillager |
| `state.combat_seq` | Increments on each `Combat.resolve` (diagnostics and `next_combat` bookkeeping) |
| `state.order_seq` | Monotonic counter for the `order` of improvements |

### 2.7 Tolerance for hand-built dictionaries

All `Stats`, `Select` and `Zones` reads use `.get(field, default)`. This covers UI staged models (`board_view.staged_model`, `deployment_overlay.gd:305`) and test fixtures that build units or definitions as partial dicts, such as `_make_unit({"id": "test", "attack": 1, "health": 4}, ...)` in `run_tests.gd:149`.

---

## 3. Card data schema 4 (reference)

`data/classic_cards.json` changes from `schema_version` 3 to 4, and `data/training_cards.json` from 1 to 2.

Rules live inside each card entry. Display text stays in `data/locale/cards.json`.

Integers that are used by the rules, or that fill `{placeholders}` in locale text, stay top-level and are read with `{"param": "name"}`. This keeps `CardLibrary.format_text` working, and the i18n test checks that every placeholder is filled.

### 3.1 Card entry

| Field | Type | Meaning |
|---|---|---|
| `id, source_id, kind, color, cost, price, attack, armor, health, signature, slot, text, image, artist, image_patch, consumable, cross_lane` | existing | Unchanged. `kind` is one of `hero`, `creep`, `spell`, `improvement`, `item`. Equipment has `slot` `weapon`, `armor` or `accessory`; consumables keep `consumable: true`; the new `slot: "deed"` marks a Deed. |
| `status` | `"verified"` \| `"draft"` | `draft` cards compile and can be tested, but `validate_preset` rejects them. |
| `token` | bool | The card is never allowed in a deck: `melee_creep`, `zombie`, `plague_ward`, `loyal_beast`, `hound_of_war`, `roseleaf_wall`. |
| `rq` | `[string]` | Rules questions this entry depends on, listed in `docs/RULES.md`. |
| any other top-level int | int | A parameter, such as `amount`, `chance`, `repeat`, `static_field` or `ability_cooldown`. Rules read it with `{"param": "name"}` and locale placeholders read it too. |
| `keywords` | `{kw: int or {"param": ...}}` | Printed keywords of a unit; a flag keyword uses 1. Copied into `unit.kw` by `_make_unit`. |
| `charges` | int | Starting charges of the object: improvement, item instance or unit. For a spell or other card that counts charges in hand or deck (Eclipse), it is the default counter value of every instance of the card **[CF-2]**. It must equal Valve's `charges` field where Valve has one (Eclipse 1, Bitter Enemies 3, March of the Machines 3; checked by §13.7). |
| `play` | Block | Spells, consumables, and a creep's **Play Effect** (it runs after the creep is placed). |
| `enter` | `[Op]` | Runs when an item or improvement enters play, e.g. an item's **Equip Effect**. |
| `abilities` | `[Ability]` | The card's auras, triggers and active abilities. |
| `grants` | `[Ability or Hack]` | Text this card can grant to other objects through `modify`, `give` or `grant`. |
| `ai` | `{"bias": number}` | Optional hint for the bot. It is never a rule. |

Items keep their legacy meaning for top-level `attack`, `armor` and `health`: the equipped hero gets that much. The compiler turns these fields into an implicit `{"kind":"aura","affects":"$host","grant":{...}}`, mapping top-level `health` to the grant key `max_health`. Every other item bonus is written as an explicit aura. **[CF-11]** A Grant has no `health` key: "has +N Health" is always `max_health` (Stonehall Cloak's granted text is `{"max_health": 2}`), and `health` in a Grant is a compile error whose message suggests `max_health`.

### 3.2 Blocks, choices and abilities

**Block** (the value of `play`):

```json
{"choices": [], "requires": {"all": []}, "ops": [], "initiative": false}
```
- `initiative: true` means "Get initiative".
- `requires` is a pure condition. It is checked in `legal_actions` together with the mana, colour, lock and rules-layer gates.

**Choice.** Three alternative shapes are shown; they are not one choice list:

```json
[{"key": "target", "from": "units"},
 {"key": "destination", "combat_target_of": "$c.target"},
 {"key": "destination", "from": "enemies", "after": "$c.target"}]
```
- `key` must be one of `target`, `destination`, `lane` or `position`. These are the integer command fields the engine already canonicalizes.
- The value kind follows from the selector:

  | Selector `s` | Value |
  |---|---|
  | `units` | uid |
  | `improvements` | oid |
  | `lanes` | lane index |
  | `positions` | position in the `creep_positions` encoding |

- `combat_target_of` lists the legal combat targets of a unit, with 0 meaning the tower (see §7.4).
- `after` keeps only candidates that come after the referenced value in canonical order. Use it for unordered pairs such as Friendly Fire.
- Some choices are implicit and must not be written:

  | Card type | Implicit choice |
  |---|---|
  | creep | `position` |
  | improvement | `lane` (all three lanes) |
  | equipment | `target` (an allied hero in the active lane; allowed while silenced or stunned, [CF-10]) |

**Ability** (an entry of `abilities` or `grants`). Every ability has a `kind`. An entry of `abilities` also has an `id`, unique within the card. Entries of `grants` are referenced by their index and need no `id`. An ability may also have `valve`, the Valve ability card id, used to look up `ability_name` for display.

| `kind` | Fields | Semantics |
|---|---|---|
| `aura` | `affects` Sel, `if` Cond, `grant` Grant | A continuous effect while its source is live (§4.4). `Grant` is `{stat or keyword: Expr, "rules": {...}}`. |
| `trigger` | `on` Event, `filter` {..}, `where` Cond, `lane` `"self"` \| `"any"`, `once_per` `"round"` \| `"lane_round"`, `ops` | A reactive ability (§4.2). |
| `active` | `cooldown` int ≥ 1, `requires` Cond, `choices`, `ops`, `quicken` bool | An activated ability, usable in the action phase from the active lane. After it resolves, `cd = cooldown`. With `quicken`, `cd = max(1, cd - 1)` (RQ-25). |
| `hack` (only in `grants`) | `ops` | Text appended to a card in hand. It runs when that card is played (§3.12). |

A trigger fires at most once per round with `once_per: "round"`, and at most once per lane per round with `"lane_round"`, keyed by `$e.lane`.

### 3.3 Refs and context

Every op runs with a context `ctx = {src, host, controller, lane, card, choices, vars, event, played, keep_initiative, end_phase}`.

| Block | `$self` (`src`) | `$host` | controller | default lane (`ctx.lane`) |
|---|---|---|---|---|
| spell or consumable `play` | — (using it is a lint error) | — | caster | active lane |
| creep `play` (Play Effect) | the new unit | the same unit | caster | active lane |
| item `enter`, trigger or active | the item instance | the equipped hero | the hero's owner | the hero's lane |
| improvement `enter`, trigger, aura or active | the improvement | — | its owner | its lane |
| deed aura | the deed | — | its owner | — |
| unit trigger, aura or active | the unit | the unit | the unit's owner | the unit's lane |
| granted ability (entry in `mods`) | the bearer (unit, item or tower) | the bearer's host | the bearer's controller | the bearer's lane |
| hack | the played card instance | — | the player who plays the card | active lane |

| Ref | Meaning |
|---|---|
| `$self`, `$host` | See the table above. A unit that has left play resolves to its look-back snapshot, which is read-only. |
| `$c.<key>` | A choice. Units resolve to live objects; lane and position are ints. |
| `$e.<field>` | A field of the event payload (§3.8). |
| `$v.<name>` | A variable bound by `let` or `for_each`. Unit lists are stored as uids and resolved when read. |
| `$it` | The candidate inside a selector's `where`. It binds to the innermost `where`; a nested selector's other fields are evaluated in the enclosing scope. |
| `$played` | The played card: `{"card": id, "state": hand_state entry}`. |
| `.lane .owner .card .slot .hero .color .uid` | Read-only fields on unit refs, e.g. `$self.lane`. |
| `"you"`, `"opponent"` | Players relative to the controller. |

**One object from a list [CF-3].** Where a field takes exactly one object (`price`, `stat … of`, `charges`, `card_counter`, `card_of`, `combat_target_of`, `retarget.to`, `swap.a`/`swap.b`, `battle.a`, `move.lane` given as a unit, `.lane` and the other read-only fields), a list-valued ref (a `$v` captured from a selection, or a selector) resolves to its only element:
- an empty list makes an expression 0 and the op fizzle (D6);
- a list with more than one element is a compile error if its size is fixed at more than 1 (`pick: {random: N}` with N > 1); otherwise, at runtime, the op fizzles (no event, no randomness) and the expression is 0, and the validator warns about the ref.

The canonical way to use one random object in several ops is `let` over a `pick: {random: 1}` selection, as Ravenhook does: `let item = pick 1 of the blocker's items` → `condemn $v.item` → `gold add {price: $v.item}`. The item is only marked by `condemn`, so its price is still readable until the Pulse.

### 3.4 Selectors

A selector is a Ref, a shorthand string, a dictionary, or a list. A list is the union of its elements, in canonical order and without duplicates.

| Key | Values | Meaning |
|---|---|---|
| `s` | `units` `towers` `improvements` `items` `cards` `lanes` `positions` `players` | What is selected. |
| `side` | `ally` `enemy` `any` (default) | Relative to the controller. Towers and improvements use the same values. |
| `lane` | `active` `self` `all` `other` `fountain` or a Ref | Default `ctx.lane` (RQ-03, RQ-04). `self` means the source's lane. `other` means lanes other than `ctx.lane`. `fountain` means heroes in the Fountain (Routed). A Ref may be a lane int (`$c.lane`, `$e.lane`, `$it`) or a unit (that unit's lane). |
| `kind` | `hero` `creep` (units), or a card kind (cards) | Filter. |
| `card` | id or `[ids]` | Filter by card id. |
| `color` | `red` `green` `blue` `black` | Filter. |
| `slot` | `weapon` `armor` `accessory` | Filter for items. |
| `rel` | `{relation: Ref or Sel}` | Relation (see the table below). |
| `not` | Ref, list or Sel | Exclusions. |
| `where` | Cond | Evaluated per candidate, with `$it` bound to it. |
| `zone` | `hand` `deck` or `["hand","deck"]` | For `s: cards`. Engine-only: hidden, and empty inside simulations. |
| `player` | `you` `opponent` | For `s: cards` and `s: players`. |
| `pick` | `{"random": Expr}` | A random distinct subset at resolution, fewer if there are not enough candidates. It is never a choice. One `rand_index` call per pick, in candidate order (partial Fisher-Yates). |
| `after` | Ref | Choices only: candidates after the ref in canonical order. |
| `use` | shorthand name | Expands that shorthand, then applies the other keys as overrides, e.g. `{"use": "other_allies", "lane": "all"}`. |

**Relations.** The argument X may be a Ref or a Sel. For a Sel, the results are united in canonical order.

| Relation | Result |
|---|---|
| `allied_neighbors` | Units at X's slot −1 and +1 in X's own row. |
| `enemy_neighbors` | Enemy units at X's slot −1, 0 and +1 in the enemy row (`docs/RULES.md` "Combat positions"). |
| `across` | The enemy unit at X's slot, or nothing. |
| `blocker` | X's combat target, if it is a unit ("the unit blocking X"). |
| `attackers` | Enemy units in X's lane whose current combat target is X and that are not disarmed (RQ-05). |
| `equipped_on` | Item instances on hero X (`s: items`). |

If X is a look-back snapshot (it left play during this command), the relation reads the snapshot's lists and keeps only objects that are still in play (RQ-16).

**Canonical order:**

| Kind | Order |
|---|---|
| units | player 0, then 1 → lane ascending → slot ascending (today's `legal_actions` order) |
| towers | player → lane |
| improvements | player → lane → `order` |
| items | by host in unit order → weapon, armor, accessory |
| cards | hand before deck → index |
| lanes | 0, 1, 2 |
| positions | `creep_positions` order |

**Shorthands** expand at compile time. Relational shorthands are relative to `$host`, so they work unchanged on items and granted text.

| Shorthand | Expansion |
|---|---|
| `units`, `heroes`, `creeps` | `{"s":"units"}` (+ `kind`) |
| `allies`, `enemies` | `{"s":"units","side":"ally"}`, `{"s":"units","side":"enemy"}` |
| `other_allies` | `{"s":"units","side":"ally","not":"$host"}` |
| `allied_heroes`, `enemy_heroes`, `allied_creeps`, `enemy_creeps` | side + kind |
| `allied_neighbors`, `enemy_neighbors`, `blocker`, `attackers` | `{"s":"units","rel":{"<relation>":"$host"}}` |
| `your_tower`, `enemy_tower`, `both_towers` | `{"s":"towers","side":"ally"}`, `...enemy`, `...any` |
| `your_hand`, `opponent_hand` | `{"s":"cards","zone":"hand","player":"you"}`, `...opponent` |
| `you`, `opponent`, `both_players` | players |

### 3.5 Expressions

All expressions are integers.

| Expr | Value |
|---|---|
| `7` | A literal. |
| `{"param": "amount"}` | A top-level int of the card that defines the ability (a compile-time constant). |
| `"$v.spent"` | A variable. |
| `{"count": Sel}` | The number of selected objects. |
| `{"sum": Sel, "stat": S}` | The sum of a derived stat over the selection (Lodestone Demolition: Armor on enemies). |
| `{"stat": S, "of": Ref}` | A derived stat. For units S is one of `attack armor health max_health siege cleave retaliate regeneration bounty`. For towers S is one of `health armor mana max_mana`. |
| `{"charges": Ref}` | Charges of an object (unit, item instance or improvement). |
| `{"card_counter": Ref, "counter": "charges"}` | A counter on a card instance, e.g. `$played`. A missing value reads as the card's printed `charges` **[CF-2]**. |
| `{"gold": "you"}` | A player's gold. |
| `{"price": Ref}` | The base gold cost of an item card or item instance (Ravenhook). |
| `{"half": X}` | `floori(X / 2)` (RQ-28). |
| `{"add": [..]}`, `{"sub": [a, b]}`, `{"mul": [a, b]}`, `{"neg": X}`, `{"min": [..]}`, `{"max": [..]}` | Arithmetic. |

### 3.6 Conditions

| Cond | True when |
|---|---|
| `{"all": [..]}`, `{"any": [..]}`, `{"not": C}` | Logic. |
| `{"cmp": [A, op, B]}` | `op` is one of `== != < <= > >=`. Expressions compare as numbers; refs (players, cards, units, lanes) compare by identity. |
| `{"is": Ref, "in": Sel or list Ref}` | Membership. The list may be a snapshot field such as `$e.attackers`. |
| `{"has": Sel}`, `{"empty": Sel or Ref}` | The selection is non-empty or empty. |
| `{"in_play": Ref}` | The object is live. |
| `{"unblocked": Ref}` | The unit's combat target is the tower. |
| `{"damaged": Ref}` | `health < max_health_of`. |
| `{"flag": [Ref, "stun"]}` | A derived flag or status is on. |
| `{"log": "tower_hit", "tower": Sel}` | One of those towers was dealt damage this round. |
| `{"log": "hit", "by": Ref, "kind": "creep" \| "hero" \| "tower"}` | That unit dealt battle damage of that kind this round. |
| `{"active_lane": "self"}` | The active lane is `ctx.lane`. |

Randomness is never allowed in conditions; use the `chance` op.

### 3.7 Ops

Every op ignores objects that are not in play (D6). "Set" in this table means a Sel, a Ref or a list.

| Op | Fields | Semantics | Emits |
|---|---|---|---|
| `damage` | `to` set, `amount` Expr, `piercing` bool | Each unit takes `amount − armor` (at least 0), or the full amount if piercing. A damage-immune unit takes 0. All amounts are computed first from one derived state, then applied (FX-3; M1 applies them in sequence, as legacy code does). This is not battle damage. | `damage {src, hits:[[uid, n]], pierce}` |
| `damage_split` | `to` set, `total` Expr | Each of the N targets takes `floor(total / N)` as one damage source; the remainder is lost (RQ-28). | `damage` |
| `tower_damage` | `to` towers, `amount`, `piercing` | `max(0, amount − tower armor)` through `_damage_structure`, with no overflow into the ancient. Sets `round_log.tower_hit`. | `tower_damage {hits:[[lane, p, n]]}` |
| `heal` | `to` set, `amount` Expr or `"full"` | `health = min(max_health_of, health + n)`. | `heal {hits}` |
| `tower_heal` | `to` towers, `amount` | Caps at 40 for a tower, 80 for an ancient. | `heal` |
| `modify` | `to` set, `stats` {attack, armor, max_health, mana}, `keywords` {kw: Expr}, `grant` int | **Permanent** (`k:"modify"`, `d:"perm"`). Stat and keyword deltas are written into the target's fields (unit fields and `kw`; for a tower, `structures[p].armor` or `max_mana`/`mana`). A provenance entry is recorded and coalesced. A `grant` is recorded as `ab`. For cards in hand, only a hack `grant` is allowed and it goes to `hand_state.hacks`. On an item instance only a `grant` applies; its entry goes to `item_state[slot].mods`, where the text works like printed item text (M6 as built). Survives the Fountain (RQ-13). | `mod {uid or oid, st, kw, perm:true}` |
| `give` | `to` set, `stats`, `keywords`, `grant`, `until` | Temporary entry (`k:"give"`), pulled at read time, expires by `until` (§3.10). A second Death Shield on a unit that already has one does nothing (RQ-11). | `status {uid, kw, st, until}` |
| `purge` | `to` set, `from` `"opponent"` \| `"all"` | Removes `modify` and `give` entries whose `by` is the controller's opponent (or anyone, for `all`), and reverses the written-through deltas of removed `modify` entries. Base stats, items and auras are untouched (RQ-12). | `purge {uid, n}` |
| `condemn` | `to` units, items or improvements | Marks for death. Units get `condemned = true`; the next Pulse removes them (a Death Shield still saves a unit; Damage Immunity does not). | `condemn {id}` |
| `summon` | `card`, `count` Expr (default 1), `lane` (default `ctx.lane`), `for` `you` \| `opponent`, `as` var | Repeats `count` times: `_make_unit` (`roster:false` for a hero), `_spawn` (a random empty own slot, otherwise a random end), then roll its arrow. During deployment the roll is deferred to `_roll_arrows`. | `summon {uid, card, p, lane, slot}`, `unit_entered{how:"summon"}` |
| `move` | `unit` set, `lane` Ref or `"random_other"` (default: the unit's current lane), `position` Ref | Leaves the current position (attackers released, lane compacted) and enters the target lane at the chosen position, or at a random one through `_spawn` (RQ-17, RQ-42). Then rolls the arrow. **[CF-1]** A set moves one unit at a time in canonical order, captured once; with `"random_other"` each unit gets its own `rand_index` over its own two other lanes, then its own `_spawn` roll (Primal Roar, Nyctasha's Guard). A unit no longer in play when its turn comes fizzles. **Same-lane moves** (Arctic Burn; Ball Lightning into the hero's own lane): `position` values are computed by the `positions` selector *before* the move, with the mover still in its slot (so that slot is never offered). The engine nulls the mover's slot without compacting, calls `_place(unit, lane, position)` (−1 and the row size still add a new end position on both rows), clears forced targets on the mover that are out of range, runs `normalize_arrows` (so a rolled enemy arrow at the old slot resets to forward before that column can compact away and shift its offset onto another unit), then compacts, rolls the mover's arrow and runs `normalize_arrows` again. A same-lane move without `position` does nothing. | `move {uid, from, to, slot}`, `unit_entered{how:"move"}` if the lane changed |
| `swap` | `a`, `b` | Exchanges two units in the same row. Arrows stay with positions (RQ-30), forced combat targets included: the unit now in a position inherits its arrow and forced target, and an enemy whose forced target was one of the two keeps its arrow and now attacks the unit in that position. Then stale targets are cleared and `normalize_arrows` runs. | `swap {a, b}` |
| `retarget` | `unit` set, `to` Ref, `0` or `"across"` | Sets a forced combat target: a uid, `0` for the tower, or `"across"` (arrow 0, `combat_target = -1`, which is legacy Forward Charge). For a unit target the arrow is set to point at it; for `0` the arrow is left unchanged. Both match today's `redirect` branch, so the goldens stay identical. | `retarget` |
| `taunt` | `unit` | Each enemy neighbor of `unit` retargets to it (RQ-18). | `retarget` |
| `battle` | `a` Ref, `b` Ref or set | `a` battles every `b` simultaneously (§4.5). | `battle {a, bs, hits}`, `battle_damage` |
| `to_fountain` | `unit` hero | A voluntary return: no bounty, ready next round (`round + 1`). | `fountain {uid}` |
| `control` | `unit`, `to` `"you"` | Changes the owner. The unit moves to the new owner's row in the same lane (random empty slot) and rolls its arrow; its attackers are released (RQ-17). | `control {uid, from, to}`, `unit_entered{how:"control"}` |
| `draw` | `player` `you` \| `opponent` \| `both`, `n` Expr | Draws from the back of the deck. Gives each card a fresh `iid` and emits an internal `card_drawn` for it. | `draw {p, n}` + `_s{p:{iids}}` |
| `discard` | `cards` cards | Removes those cards and their state from the hand. | `discard {p, n}` + private ids |
| `lock` | `cards` cards, `n` Expr | `hand_state.lock += n` (stacks; RQ-14). | `lock {p, n}` + `_s{p:{idx}}` |
| `add_card` | `player`, `card` id or `"$e.card"` or `{"card_of": Sel}`, `from_pool` `"secret_shop"`, `base` bool | Appends a card to the hand with `{iid, base}`. With `from_pool`, the card is one random entry of `catalog.secret_shop`. The new instance has no stored counters, so it reads its printed `charges` (a base Eclipse has 1) **[CF-2]**. | `gain_card {p}` + `_s{p:{card}}` |
| `card_counter` | `cards` cards (hand and/or deck), `counter`, `add` Expr | Writes `hand_state` or `deck_state`, starting from the printed default when no value is stored **[CF-2]**. Hidden. | `charged {p, n}` |
| `charges` | `on` Ref, `add` or `set` Expr, `min` int | Changes the charges of an object. | `charges {id, n}` |
| `gold` | `player`, `add` Expr or `set` Expr, `as` var | Never below 0. With `set`, `as` receives the amount removed (Spend all your gold). | `gold {p, n}` |
| `mana` | `to` towers, `restore` Expr or `"full"` | Current mana goes up, capped at `max_mana`. Changes to max mana use `give` or `modify` with `stats.mana`. | `mana {lane, p, n}` |
| `initiative` | — | `ctx.keep_initiative = true` (the same as `play.initiative`). | — |
| `end_action_phase` | — | When the command finishes, the lane goes to combat with no passes (RQ-20). | — |
| `let` | `name`, `value` Expr, Sel or Ref | Binds a variable. A selection is captured as a list of ids. | — |
| `if` | `cond`, `then`, `else` | | — |
| `repeat` | `times` Expr (evaluated once), `ops` | | — |
| `for_each` | `in` set (captured once, canonical order), `as`, `ops` | | — |
| `chance` | `pct` Expr, `then`, `else` | One `Kernel.chance` draw. | — |
| `pulse` | — | `Kernel.pulse(e)` immediately. This is Valve's □ marker. | `pulse` |
| `break` | — | Leaves the innermost `repeat` or `for_each`. | — |
| `native` | `fn`, `args` | A registered handler (§3.13). | — |

### 3.8 Events (trigger `on`) and filters

| Event | Payload | Emitted by | Default scope |
|---|---|---|---|
| `before_action` | `lane` | `Kernel.lane_open`: end of `start()` (lane 0), deployment reveal (lane 0), after the previous lane's after-combat (lanes 1 and 2) | Sources in `lane`. |
| `after_combat` | `lane` | `Combat.resolve`, after the combat Pulse | Sources in `lane`. |
| `deployment` | — | Deployment reveal, after all placements and before the arrow roll (RQ-23) | Every source in a lane. |
| `card_played` | `player, card, kind, color, cost, lane, target` | After a played card, including its hacks, has fully resolved and pulsed | Sources in `lane`, which is the active lane (RQ-03). |
| `unit_died` | snapshot (§4.3) | Pulse, after removal | Sources in the snapshot's lane. Units that died in the same Pulse are not live (RQ-43). |
| `death` | snapshot | Pulse, after removal | The dead unit's own abilities only (Death Effect). |
| `unit_entered` | `unit, lane, how` (`deploy`, `play`, `summon`, `move`, `control`) | Placement | Sources in `lane`. |
| `improvement_entered` | `oid, card, owner, lane` | Improvement play | Sources in `lane`. |
| `battle_damage` | `source, target (uid or "t<lane>_<p>"), amount, lane, in_combat, part (attack, cleave, retaliate, siege)` | Combat and `battle`, for each hit with amount > 0 (RQ-32, RQ-45). `source` is a tower string for a tower's Retaliate (Burning Oil) **[CF-6]**: a tower string never matches a unit selector, and a unit-only op given one fizzles | Sources in `lane`. |
| `card_drawn` | `player, card` (the drawn card instance, found by `iid`) | `Zones.draw` | Every live source. |

An ability with `"lane": "any"` triggers wherever its source is: Storm Spirit, Crystal Maiden, Claszureme Hourglass. Events without a `lane` field (`deployment`, `card_drawn`) skip the scope check. In `card_played`, `card` is the played card's id; in `card_drawn`, `card` is the drawn instance.

**Filter keys.** `filter` is shorthand that compiles to a `where`. Sides and players are relative to the controller.

| Event | Keys |
|---|---|
| `card_played` | `player`, `kind`, `not_kind`, `color`, `cost_max` |
| `unit_died`, `death` | `side`, `kind`, `card`, and `was`. `was` is one of `allied_neighbor`, `enemy_neighbor` or `blocker`: `$host` was in the snapshot's `neighbors` or `enemy_neighbors` list, or the dead unit was `$host`'s combat target (`$host.uid ∈ $e.blocking`; `blocking` lists every enemy aimed at the dead unit, stunned or disarmed ones included, while `attackers` leaves those out, RQ-05; M3 as built). |
| `battle_damage` | `role` (`dealer` \| `taker`, relative to `$host`), `target_kind` (`unit` \| `hero` \| `creep` \| `tower`), `source_kind` (`unit` \| `tower`) **[CF-6]**, `in_combat`. Viper ("When a unit deals battle damage to Viper") is `{"role": "taker", "source_kind": "unit"}`; the equivalent `where: {"is": "$e.source", "in": {"s": "units", "lane": "all"}}` stays valid |
| `unit_entered` | `side`, `how` |
| `improvement_entered` | `side` |
| `card_drawn` | `player` |

### 3.9 Keywords, flags and statuses

A keyword's value is the sum of:
- its base value in `kw` (printed value plus permanent Modify),
- active `give` entries,
- auras.

A flag or status is on when its sum is above 0.

| Name | Type | Holders | Where it applies | RQ |
|---|---|---|---|---|
| `siege` | number | units | In the combat plan: if the unit is blocked (its target is a unit, diagonal included) and not disarmed, the enemy tower also takes `siege − tower armor`. | RQ-07 |
| `cleave` | number | units | Same conditions. Each allied neighbor of the target takes `cleave − its armor` (no reduction with `pierce`). It is battle damage. | RQ-08 |
| `retaliate` | number | units, towers | In any battle, each attacker that attacked this unit (or tower) takes `retaliate − attacker armor`. It applies even when stunned or disarmed. Cleave and spells do not cause it. | RQ-06 |
| `regeneration` | number | units, towers | In the combat phase: `health = min(max, health − damage + regeneration)`, before the death check (a tower's before its fall check; max is 40, 80 for an ancient). The unit does not need to be attacked. | RQ-09 |
| `bounty` | number | units | On death, the owner's opponent gains `max(0, bounty)`. The base is 5 for heroes and 1 for creeps. | RQ-02 |
| `bonus_hero`, `bonus_tower` | number | units | Added to battle attack against a hero or tower: Debbi 2/2, Phantom Assassin 4/0, Sorla Khan 0/4, Assault Ladders 0/2. | |
| `pierce` | flag | units | All battle damage this unit deals ignores armor: attack, cleave, retaliate and siege. | |
| `lethal`, `lethal_creeps`, `lethal_heroes` | flag | units | Battle damage above 0 condemns the victim, filtered by kind. | RQ-10 |
| `damage_immunity` | flag | units | All damage becomes 0, and no `battle_damage` event fires. Condemn still kills. | RQ-10 |
| `death_shield` | status, at most 1 | units | In the Pulse: instead of dying, remove the shield, set health to 1 and clear `condemned`. | RQ-11 |
| `stun` | status | units | Counts as both `silence` and `disarm`. | |
| `silence` | status | units | No unit or item actives, and the unit adds no colour for casting. | RQ-31 |
| `disarm` | status | units | Does not attack in combat or battles. It still blocks and retaliates. | |
| `rapid_deployment` | flag | heroes | On death, the hero is ready the next round. | |
| `soulbound` | flag | units | On death, other allied units with the same card in every lane are condemned in the same Pulse. | RQ-39 |
| `armor`, `mana` | stat | towers | Tower armor reduces tower damage that is not piercing, including siege. `mana` changes max mana. | RQ-07 |
| `decay`, `untargetable` | reserved | — | Rejected by the validator. No Classic card uses them; `decay` has 0 hits in sets 00/01 and the glossary. | |

Lock is card state, not a keyword. Taunt is an op.

### 3.10 Durations (`until` on `give`)

| `until` | Removed by |
|---|---|
| (modify) `perm` | Purge from the opposing side only. Survives the Fountain (RQ-13). |
| `round` | `Kernel.end_of_round`. Also removed in the Fountain. |
| `next_combat` | The end of the next combat phase of the lane the unit is in when that combat happens, before after-combat triggers. An entry given during that lane's combat itself (stamped with its `combat_seq`) lasts until the lane's following combat. Also removed in the Fountain. |
| `death` | Death, or entering the Fountain (Viper Strike, Track). |
| `equip` | When that hero equips any item, or enters the Fountain (Caught Unprepared, RQ-35). |
| `used` | Consumption only (Relentless Zombie's Death Shield). A shield given with `round` (Cheating Death) ends when it is consumed or at round end, whichever comes first. |
| (aura) continuous | Never stored. It disappears with its source or when its condition fails. |

### 3.11 Rules-layer grants (`grant.rules` in an aura whose `affects` is a player)

| Key | Value | Effect |
|---|---|---|
| `round_draw` | Expr | The round draw is `2 + Σ` (Troll Soothsayer, Howling Mind). |
| `forbid_play` | `{"kinds": [...], "lane": "self"}` | `legal_actions` drops those card kinds while the active lane is the source's lane (The Oath). |
| `secret_shop_discount` | Expr | Secret Shop price = `base − Σ × base`. A negative price pays gold (Shop Deed, RQ-26). |
| `creep_lane` | `"self"` | The player's lane creeps deploy into the source hero's lane (Kanna, RQ-22). Sources are heroes in a lane **or ready to deploy this round**. |

### 3.12 Granted text and hacks

**Granted text.** A card's `grants` holds text it can give to other objects, e.g. Heartstopper Aura, Viper Strike, Defend the Weak, Routed and the Stonehall items.
- `modify` and `give` attach a grant with `"grant": <index>`, which becomes `ab:"<card>#<index>"` on the entry.
- The granted ability uses the bearer as `$self`.
- It takes params from the **granting** card.
- It is live while the entry exists and the bearer is live.
- It is indexed for its events like a printed ability.
- Purge removes it only if the entry's `by` is the opponent.

**Hacks** (Self Sabotage) go into `hand_state.hacks`.
- When that card is played, the card resolves fully and pulses first.
- Then each hack's `ops` run, with the playing player as controller, followed by a Pulse.
- Only after that is `card_played` emitted.
- A base copy (`add_card` with `base:true`) has no locks, charges or hacks (RQ-36).

### 3.13 Natives (escape hatch)

`{"op":"native","fn":"name","args":{...}}` calls `rules/natives.gd: static func name(e, ctx, args)`.

A native:
- may only call `Kernel`, `Zones`, `Stats`, `Select` and `VM` functions;
- may write no other state;
- may use no randomness except `Kernel.rand_*`;
- must have its own test;
- must appear in the lint report.

The budget is 5 natives and the plan uses **0**: every one of the 303 cards is written with §3.4 to §3.12 (Appendix A, §5).

### 3.14 Compile-time validation (`RulesDB.validate`, run at load and by `tests/rules_schema_test.gd`)

1. Unknown keys are an error: card fields, ability fields, op fields, selector keys, filter keys, rules keys, keywords and durations.
2. Numbers are normalized to int. A fraction is an error.
3. Refs must be bound.
   - `$c.<key>` must be declared earlier in the same `choices`.
   - `$v.<name>` must come from an enclosing `let` or `for_each`.
   - `$e.<field>` must be a field of that event.
   - `$it` is only allowed inside `where`, and `$played` only in a play block.
   - `$self` is not allowed in a spell or consumable play block.
4. Choice keys must be one of the four command fields, with no duplicates, and the value kind must match the selector.
5. Randomness (`pick`, `chance`) is not allowed in choices, `requires`, auras, `filter` or `where`.
6. Aura layering.
   - A grant to attack, armor, max_health or mana may not read derived stats.
   - A keyword grant may read derived attack, armor and max_health, but not keywords (Sven).
   - An aura may not grant `stun`, `silence`, `disarm` or `death_shield`.
   - An aura `if` may not use `damaged`, `stat` or `sum`.
7. Every `param` must be a top-level int on the defining card. Every locale `{placeholder}` must resolve; `tests/i18n_test.gd` checks this.
8. Every `grant` index must exist, and only a `hack` may target cards in hand.
9. Actives need `cooldown ≥ 1`. Holder kinds must match their keywords: towers allow only `armor`, `mana`, `retaliate` and `regeneration`.
10. Natives must exist; each one produces a warning.
11. `status` must be `verified` or `draft`. Tokens and drafts must not appear in presets.
12. **[CF-12]** `enter` is validated like any other op list, as an object block: `$self` is the item instance or improvement, and `$host` is bound for items only. (The prototype `synth_work/check_spec.py` skipped `enter`.)
13. **[CF-3]** A single-object field given a list whose size is fixed above 1 is an error (§3.3).
14. **[CF-11]** A Grant may not use `health`; use `max_health`.

If a card has any error, `playable = false`, and it is listed in `library.errors`. `tests/rules_schema_test.gd` requires zero errors.

---

## 4. Kernel semantics (normative)

### 4.1 The Pulse

Glossary (ZToken): "Continuous effects are updated, reactive abilities are processed, and units that have been condemned or dealt lethal damage are destroyed."

```gdscript
## rules/kernel.gd
const MAX_PULSE_LOOPS = 64
const MAX_PULSE_DEPTH = 16
const BATCH_MODE = "per_batch"   # RQ-37: "per_batch" (glossary: all triggers happen simultaneously) | "per_trigger"

static func pulse(e) -> void:
	e._pulse_depth += 1
	if e._pulse_depth > MAX_PULSE_DEPTH:
		_overflow(e)
		e._pulse_depth -= 1
		return
	for loop in range(MAX_PULSE_LOOPS):
		Stats.settle(e)                                   # max-health / mana deltas, status mirrors (§4.4)
		var dying = _collect_dying(e)                     # units: health <= 0 or condemned; items/improvements: condemned
		dying = _close_soulbound(e, dying)                # allied same-card units in every lane are condemned too (RQ-39)
		dying = _consume_death_shields(e, dying)          # shielded units survive at 1 health; the shield entry is removed (RQ-11)
		if not dying.is_empty():
			var snapshots = _snapshot(e, dying)           # before any removal (§4.3)
			_remove(e, dying, snapshots)                  # bounty, Fountain, release attackers, compact, normalize arrows
			for s in snapshots:
				emit(e, "death", s)
				emit(e, "unit_died", s)
			Stats.settle(e)
		if e._queue.is_empty():
			break
		var batch: Array = e._queue
		e._queue = []
		batch.sort_custom(func(a, b): return Triggers.key_less(a.key, b.key))
		for instance in batch:
			_resolve_trigger(e, instance)                  # VM.run; new emits go to e._queue (next batch)
			if BATCH_MODE == "per_trigger":
				pulse(e)
		if loop == MAX_PULSE_LOOPS - 1:
			_overflow(e)
	e._pulse_depth -= 1
```

- **Who calls `_check_winner`.** The Pulse never does. It is called at the end of each step: after a play or ability, after a lane's combat and after-combat, and after `lane_open`.
  - It becomes idempotent: it returns at once if `state.winner != -1`.
  - This keeps today's event order: `_play` emits `win` after its post-spell triggers.
  - Simultaneous tower falls still produce a draw.
- **Overflow.** `_overflow(e)` clears `e._queue`, sets `e._ops_left = 0` (so the VM stops), and emits `rules_overflow`.

### 4.2 Trigger collection, order and batches

```gdscript
static func emit(e, kind: String, payload: Dictionary) -> void:
	e._event_index += 1
	for listener in Triggers.live_listeners(e, kind, payload):
		e._queue.append({"key": Triggers.key(e, listener, e._event_index), "source": listener.ref,
			"ability": listener.ability, "event": payload, "controller": listener.controller, "lane": listener.lane})
```

**Live listeners are collected when the event is emitted.**
- Candidates: `library.listeners(kind)` (an index built at load), plus granted abilities found in `mods` that listen to `kind`.
- A source counts only if it is in its live zone at that moment:

| Source | Live when |
|---|---|
| Unit ability | The unit is in a lane |
| Granted ability | Its bearer is live |
| Item trigger or active | The host is in a lane (RQ-38) |
| Improvement | It is in its lane |
| Deed | Always |
| `death` event | Only the dead unit's snapshot listens |

- Then the scope is checked: `lane: "self"` must match `payload.lane`.
- Then `filter` and `where` are evaluated on the current state. This is the "intervening if"; it is not checked again at resolution.
- Then `once_per` is checked and marked.
- **A queued trigger still resolves if its source left play in the meantime.** `$self` then resolves to the look-back snapshot, and ops aimed at it fizzle (D6).

**Total order** (`Triggers.key`). This is the only place to change if a reference match disagrees (RQ-37):

```
[event_index,
 side_rank      0 if controller == state.initiative else 1,
 lane           0..2 (lane-less sources such as deeds: -1),
 zone_rank      unit 0 | item 1 | improvement 2 | deed 3,
 position       unit slot | host slot * 3 + {weapon 0, armor 1, accessory 2} | improvement order,
 ability_index  printed abilities first, then granted ones in mods order,
 id             uid or oid]
```

**Batch semantics** (`BATCH_MODE = "per_batch"`). Every trigger instance queued before a batch starts resolves in that batch, in key order, with **no Pulse in between**.
- Damage, Modify and statuses from different triggers therefore combine as if simultaneous.
- A unit dealt lethal damage by an earlier trigger in the batch is still on the board, and is still a legal random target, until the Pulse after the batch.
- Events emitted while the batch resolves are queued for the **next** batch: breadth-first.
- A `pulse` op inside a triggered ability (Valve marks one only on Self Sabotage's hack) runs a nested Pulse at that point.
- `"per_trigger"` is the reference-match switch, pinned by the test `rq_37_batch_mode`.

### 4.3 Deaths and look-back snapshots

`_snapshot(e, dying)` records, for every dying unit, before anything is removed:

```json
{"uid": 57, "card": "pit_fighter_of_quoidge", "owner": 0, "hero": false, "color": "black", "lane": 1, "slot": 2,
 "neighbors": [55, 61], "enemy_neighbors": [12, 14], "target": 12, "attackers": [12], "blocking": [12],
 "items": {}, "attack": 4, "armor": 0, "max_health": 8, "kw": {"bounty": 1},
 "cause": {"src": 1000123, "p": 1}}
```

| Field | Content |
|---|---|
| `neighbors` | Allied left and right uids |
| `enemy_neighbors` | The three uids across |
| `target` | The dead unit's combat target: a uid, or 0 for the tower |
| `attackers` | Uids of units whose combat target was the dead unit and that could attack (not stunned or disarmed, RQ-05) |
| `blocking` | Uids of every unit whose combat target was the dead unit, stunned or disarmed ones included: the units it was blocking, read by `was: blocker` (M3) |
| `cause` | The last damage or condemn source. Best effort; no Classic card reads it |

The snapshot is also stored in `e._lookback[uid]` for the rest of the command. Ops on a snapshot fizzle, with one exception: a `modify` on the snapshot of a roster hero reaches the hero in the Fountain, since heroes keep modifications through death and a Pulse processes reactive abilities before it destroys units (RQ-54, `MODIFY_REACHES_DEAD_HEROES`; M3 as built).

`_remove` processes the dying units by lane, then owner, then slot. This is exactly the order `_clean_dead` uses today; deaths keep this order rather than the selector order of D2. For each unit:
1. Align the lane.
2. Pay the bounty to the opponent: `max(0, bounty)` from the derived bounty.
3. Release its attackers (`_release_attackers`).
4. Send it out of play:
   - A roster hero goes through `_enter_fountain(round + (1 if rapid_deployment else 2))`.
   - A non-roster hero or a creep gets `lane = -1` and is gone. (Since M4 a summoned Meepo is a roster hero, RQ-29.)
5. Emit the existing `death` event `{p, uid, card, gold}`.
6. Null its slot.

After that:
- Condemned items are removed from their host, with event `item_gone`.
- Condemned improvements are removed, with event `improvement_gone`.
- Every affected lane is compacted, then `Zones.normalize_arrows` runs.

**Death Shield** (`_consume_death_shields`):
- A dying unit with `death_shield` loses one shield: from the first `give` entry that carries it (the rest of that entry stays; an entry left empty is dropped), otherwise from its own keywords (a printed shield, or a Modify and its provenance entry).
- It is set to `health = 1` and `condemned = false`, and it stays.
- The shield saves from condemn, Lethal and Soulbound alike (RQ-10, RQ-11, RQ-39).

**Soulbound** (`_close_soulbound`, ordered by `_resolve_dying`):
- Shields are applied first, to the units that are dying. A unit its shield saves did not die.
- Then, if a unit that actually dies has `soulbound`, every other allied unit with the same `card` in any lane gets `condemned = true` and joins this Pulse.
- Shields are applied again to the units the closure added: a partner with an unused shield survives; a partner whose shield already saved it in this Pulse dies with its twin.

### 4.4 Continuous effects

**Derivation.** `Stats.derive(e, u)` is pure. It is computed fresh on every call; there is no cache (K15).

```
attack/armor/max_health/kw  =  u.attack/u.armor/u.max_health/u.kw              # printed + permanent Modify (written through)
                            +  Σ give entries in u.mods                          # temporary
                            +  Σ host auras of u's items (implicit attack/armor/health + explicit "$host" auras + granted)  # apply in the Fountain too
                            +  Σ layer-A board auras whose affects includes u (Select.includes; canonical source order)
                            +  Σ layer-B keyword auras (may read the derived attack/armor/max_health computed above: Sven)
attack = max(0, attack)                                                          # as attack_of today; armor may be negative
```

Aura sources are:
- units in a lane, with their printed and granted auras;
- items on heroes;
- improvements;
- deeds.

Which units count as live aura sources:
- **M1 compatibility:** a unit projects auras only while `health > 0` and it is not condemned. This is today's `neighbor.health > 0` check (`match_engine.gd:875`).
- **FX-3:** a unit projects auras until the Pulse removes it, because the glossary says continuous effects update at Pulses.

`Select.includes` tests membership without enumerating sets, so one stat read costs O(number of aura sources), roughly 10 to 40 checks. `Stats.tower(e, lane, p)` derives `armor`, `max_mana` modifiers, `retaliate` and `regeneration` the same way, from tower base fields, `mods` and auras whose `affects` selects towers. `Stats.rules_of(e, p)` folds the rules grants of §3.11.

**Settle** runs inside every Pulse loop and after deaths:

```gdscript
static func settle(e) -> void:
	for u in Zones.all_units(e):                         # units in lanes + every roster hero (Fountain included)
		var cap = max_health_of(e, u)
		var seen = int(u.get("hp_seen", cap))
		if cap != seen:
			u.health = int(u.health) + cap - seen        # gaining/losing max health moves current health (RQ-40; equip code today)
		u.hp_seen = cap
		u.stunned = flag(e, u, "stun")
		u.silenced = u.stunned or flag(e, u, "silence")  # mirrors for UI/tests
		u.disarmed = u.stunned or flag(e, u, "disarm")
	for lane in 3: for p in 2:                           # [CF-5]
		if not lane.has("max_mana_base"):                # fixture tolerance
			lane.max_mana_base = [lane.max_mana[0] - lane.mana_bonus[0], lane.max_mana[1] - lane.mana_bonus[1]]
		var total = tower_mana_modifier(e, lane, p)      # Σ give + auras on that tower's mana (modify is in the base)
		var new_max = max(0, int(lane.max_mana_base[p]) + total)
		var delta = new_max - int(lane.max_mana[p])      # the change actually made, after the floor
		if delta != 0:
			lane.max_mana[p] = new_max
			lane.mana[p] = max(0, lane.mana[p] + delta)
		lane.mana_bonus[p] = total
```

**[CF-5]** A permanent `modify` of tower `mana` writes `max_mana_base` (not `max_mana`), and the round's +1 growth in `_begin_deployment` becomes `max_mana_base += 1` followed by settle and the refill `mana = max_mana`. Invariant I5 gains `max_mana == max(0, max_mana_base + mana_bonus)`. The numbers in `classic_cards_test.gd:239-241` (12/13, then 11/11) are unchanged. Current mana still moves with the effective maximum, so losing a −Mana aura while the tower has 0 mana gives that mana back; this matches what Stars Align's expiry does today and is noted under RQ-52.

Consequences:
- Equipping, auras, Modify +Health and Purge all move current health by the change in maximum health.
- Losing a +Health aura can kill the unit at the next death check.
- Stars Align becomes `give {to: your_tower, stats: {mana: 3}, until: round}` and produces the numbers it produces today.

### 4.5 Combat and battles

`Combat.plan(e, lane)` is **pure**, computed from one derived state. It returns hits, regeneration entries, condemn entries and `tower_totals`. `combat_preview` and the bot use it.

```
for p in [0, 1]: for slot in row p (ascending):
	a = unit; skip if null or disarmed (stun included)
	t = _combat_target(a, lane, slot)                        # unchanged pathing / forced targets
	atk = attack(a) + (bonus_hero if t is a hero) + (bonus_tower if t is the tower)
	pierce = flag(a, "pierce")
	if t is the tower:                                       # unblocked: no siege, no cleave (RQ-07)
		hit(a → tower[lane][1-p], atk − (0 if pierce else tower armor), "attack")
		if tower retaliate > 0: hit(tower → a, R − armor(a), "retaliate")
	else:
		hit(a → t, immune(t) ? 0 : atk − (0 if pierce else armor(t)), "attack")
		if cleave(a) > 0: for n in allied_neighbors(t): hit(a → n, cleave − (0 if pierce else armor(n)), "cleave")
		if siege(a) > 0: hit(a → tower[lane][1-p], siege − (0 if pierce else tower armor), "siege")
		if retaliate(t) > 0: hit(t → a, R − (0 if flag(t,"pierce") else armor(a)), "retaliate")   # even if t is stunned (RQ-06)
regeneration: every unit and tower in the lane with regeneration > 0 → regen entry
lethal: victims of hits with amount > 0 from a lethal / lethal_creeps / lethal_heroes attacker → condemn entry
every amount = max(0, amount)
```

`Combat.resolve(e, lane)` applies the plan atomically. It replaces `_resolve_combat`; `_pass` calls it.

```
state.combat_seq += 1
event "combat" {lane, damage: [dealt by p0 to tower, dealt by p1 to tower], strikes: [[src, dst, n, part], ...]}   # damage keeps today's meaning
units: health -= Σ hits;  towers: for p in [0, 1]: _damage_structure(lane, 1 - p, Σ hits by p, regeneration of that tower)   # today's order (tower of p1 first); the tower's regeneration heals (cap 40, 80 for an ancient) before its fall check (RQ-09)
regeneration: health = min(max, health + r) for units (towers: inside _damage_structure above; a tower that still falls becomes a fresh 80-health ancient, not healed)
condemn lethal victims; round_log.tower_hit / round_log.hits
emit battle_damage for every hit > 0 (in_combat = true)
Kernel.pulse(e)                          # deaths; death, unit_died and battle_damage triggers
Kernel.expire(e, lane, "next_combat")    # "until end of its next combat phase"
Kernel.emit(e, "after_combat", {"lane": lane}); Kernel.pulse(e)
e._check_winner()
```

`combat_preview(lane)` keeps the keys `unit_damage` (uid string to total damage) and `tower_damage` (`[p0, p1]`), and adds:
- `heal` (uid to regeneration actually applied),
- `dies` (an array of uids that would die: not shielded, and health − damage + heal ≤ 0, or condemned),
- `strikes`.

`Combat.battle(e, a, bs)` handles battles outside the combat phase: Duel, Gank, Friendly Fire, Berserker's Call and Winter's Curse.
- It uses one derived state.
- For each `b`:
  - `a → b` if `a` is not disarmed;
  - `b → a` if `b` is not disarmed;
  - retaliation from the defender back to each actual attacker.
- Bonus vs heroes, Pierce, immunity and Lethal all apply. Siege and cleave do not, because they apply only "during the combat phase".
- All hits are applied simultaneously and emit `battle_damage` with `in_combat = false`. Deaths wait for the caller's Pulse.
- **[CF-4]** Every hit above 0 is also written to `round_log.hits` (`[uid, "creep" | "hero"]`), exactly as `Combat.resolve` does. "Dealt battle damage to a creep this round" (Rebel Instigator) therefore counts Friendly Fire, Gank and Duel battles. `round_log.tower_hit` is written in one place, `_damage_structure`, whenever a tower or ancient loses health, whatever the source (combat, siege, `tower_damage`, a hack).
- With no keywords present, this equals today's `_battle_neighbors` (`match_engine.gd:517`).

### 4.6 Phase hooks

| Where (`match_engine.gd`) | New behaviour |
|---|---|
| `start()`, round-1 placement **[CF-7]** | After `_place_all` and the initiative roll, and before `_roll_arrows`: emit `unit_entered{how:"deploy"}` for each placed unit in placement order, emit `deployment`, then `e._deploying = true`, Pulse, `e._deploying = false`. Venomancer and Prellex among heroes 1 to 3 therefore summon in round 1 (RQ-49, default yes; switch `ROUND1_DEPLOYMENT_HOOKS` in `kernel.gd`). Kanna's `creep_lane` does not apply: round 1 has one fixed Melee Creep per lane, not "the random allied Melee Creeps". The hooks run after the initiative roll because the trigger order key reads `state.initiative`. With no listeners they consume no randomness, so the goldens are unchanged. |
| `start()` end, after `match_start` | `Kernel.lane_open(e, 0, false)`: emit `before_action{lane:0}`, Pulse, `_check_winner`. With no listeners it consumes no randomness, so the goldens are unchanged. |
| `_play` | As described in §1.3. |
| `apply_action` `"ability"` | The source must be live and usable. `VM.run`, then `cd = cooldown` (quicken), event `ability {p, uid: source id, card, ability}` (the existing key and fields), Pulse, `_check_winner`, `_finish_action(p, false)`. |
| `_pass`, second pass | Sets `initiative = first_pass` (unchanged) → `Combat.resolve` → if there is a winner, return → if `lane < 2`: `lane += 1`, `active = initiative`, event `lane_open`, `Kernel.lane_open(e, lane, true)`; otherwise the shop (unchanged). |
| `_end_action_phase` (Enough Magic!) | After `_finish_action(p, false)` (the opponent gets initiative, RQ-20), runs the same path as a second pass. |
| `_begin_deployment` | First `Kernel.end_of_round(e)` (see the list below). Then the existing body. Before `_event("deployment")`, a player whose `rules_of(p).creep_lane` has a live or ready Kanna has every pending creep lane replaced by `-1`, after the random draws, so randomness is unchanged (RQ-22). |
| `_reveal_deployment` | Per player: `Zones.draw(p, 2 + rules_of(p).round_draw)`, then hero plans, then creeps, with `-1` resolved to Kanna's planned or current lane. **[CF-9]** The draw comes before any placement, so its `card_drawn` triggers are collected from items whose host is *already* in a lane (a Claszureme Hourglass on a hero returning from the Fountain does not lock these two cards; RQ-51). They resolve in the deployment Pulse below, after `end_of_round`, so a lock they add lasts the whole new round. Then `_place_all` (same shuffle) → for each placed unit in placement order emit `unit_entered{how:"deploy"}` → emit `deployment` → `e._deploying = true`, Pulse, `e._deploying = false` (summons skip their own arrow roll) → `_roll_arrows()` → the existing phase/active/first_pass assignments → `deployment_placed`, with slots read **after** the Pulse → `deployment_revealed` → `Kernel.lane_open(e, 0, false)`. |
| `_prepare_shop` / buy | Prices come from `Kernel.price_of(e, p, source, card)`: Secret Shop `base − discount × base`; others `base`. `legal_actions` and `apply_action` both use it. |

`Kernel.end_of_round(e)`, in this order:
1. Remove `give` entries with `d:"round"` from units in lanes, roster heroes, towers, item instances and improvements.
2. Zero the legacy temp fields.
3. Lower every lock in both hands by 1.
4. Lower cooldowns by 1, without double counting:
   - roster heroes, in any zone (as today);
   - other units in lanes (creeps and summoned heroes);
   - every item instance;
   - every improvement.
5. Clear `round_log`.
6. Settle.

The existing mana growth and refill run after this, so `max_mana` drops by the expired bonus before the +1, exactly as `_begin_deployment` lines 635-638 do today.

### 4.7 Zone operations

- **Placement and arrows.**
  - `_spawn`, `_place`, `_place_all`, `_roll_arrow`, `_release_attackers` and `_compact` are unchanged.
  - `Zones.normalize_arrows(e, lane)` resets any diagonal arrow that has no forced target when the unit is blocked or the diagonal is empty. This is `_board_invariants`, which `run_tests.gd` checks after every bot action. It runs after every move, swap, control change and death.
- **Equip** (`Zones.equip`):
  - Replacing a slot discards the old instance silently, with no condemn and no event.
  - It then creates `item_state[slot] = {oid, cd: 0, charges: card.charges, mods: []}` and ends the hero's `until:"equip"` entries.
  - It runs `enter` with `$self` = the instance. Settle applies the health change.
  - Equipping is legal while silenced, as today, and also while stunned **[CF-10]**: the equip gate checks only "allied hero in the active lane". Equipping is Caught Unprepared's only exit, so this is pinned by `rq_35_equip_while_stunned`.
- **Fountain** (`_enter_fountain`):
  - Sets `lane = -1`, `ready_round`, `combat_target = -1` and `condemned = false`.
  - Removes **all** `give` entries (round, next_combat, death, equip and used), keeps `modify` entries and items, and zeroes the legacy temp fields.
  - Sets `health = max_health_of` (in Fountain context, so host auras only) and `hp_seen` to the same value.
  - Item and hero cooldowns keep ticking.
- **Improvements** (`Zones.add_improvement`):
  - If the side already holds 16, one random existing improvement on that side is removed first.
  - Then append with the next `order`, emit `improvement_entered`, run `enter`.
- **Hand**:
  - `draw` pops `deck` (and `deck_state`), appends `{iid}`, and emits `card_drawn`.
  - `discard`, `lock`, `card_counter` and `add_card` work as in §3.7.
  - A locked card has no legal plays.
- **Control, move and swap** are as in §3.7. Each one ends with `normalize_arrows` and emits the events listed there.

---

## 5. Worked examples (27 examples, 43 real cards)

Each block below is a valid card entry, or an array of entries, in schema 4. Image and artist fields are omitted. The text quoted with each example is Valve's final English text. The examples run from the migrated legacy cards to the hardest ones in the inventory.

### 5.1 Migrated legacy cards (aura, trigger, write-through Modify, retarget, union target)

```json
[
 {"id": "drow", "source_id": 10032, "kind": "hero", "color": "green", "attack": 4, "armor": 0, "health": 7,
  "signature": "gust", "status": "verified", "global_attack": 1,
  "abilities": [{"id": "precision_aura", "valve": 10504, "kind": "aura",
                 "affects": {"use": "other_allies", "lane": "all"},
                 "grant": {"attack": {"param": "global_attack"}}}]},
 {"id": "zeus", "source_id": 10065, "kind": "hero", "color": "blue", "attack": 3, "armor": 0, "health": 7,
  "signature": "thundergods_wrath", "status": "verified", "static_field": 1,
  "abilities": [{"id": "static_field", "valve": 10519, "kind": "trigger", "on": "card_played",
                 "filter": {"player": "you", "kind": "spell", "color": "blue"},
                 "ops": [{"op": "damage", "to": "enemy_neighbors", "amount": {"param": "static_field"}, "piercing": true}]}]},
 {"id": "savage_wolf", "source_id": 10112, "kind": "creep", "color": "green", "cost": 4, "attack": 3, "armor": 0, "health": 3,
  "status": "verified", "combat_growth_attack": 1, "combat_growth_health": 2,
  "abilities": [{"id": "growth", "kind": "trigger", "on": "after_combat",
                 "ops": [{"op": "modify", "to": "$self", "stats": {"attack": {"param": "combat_growth_attack"},
                                                                    "max_health": {"param": "combat_growth_health"}}}]}]},
 {"id": "forward_charge", "source_id": 10413, "kind": "spell", "color": "black", "cost": 3, "status": "verified", "siege": 2,
  "play": {"ops": [{"op": "give", "to": "allies", "keywords": {"siege": {"param": "siege"}}, "until": "round"},
                   {"op": "retarget", "unit": "allies", "to": "across"}]}},
 {"id": "gust", "source_id": 10339, "kind": "spell", "color": "green", "cost": 4, "status": "verified",
  "play": {"choices": [{"key": "target", "from": "enemy_heroes"}],
           "ops": [{"op": "give", "to": ["$c.target", {"s": "units", "rel": {"allied_neighbors": "$c.target"}}],
                    "keywords": {"silence": 1}, "until": "round"}]}}
]
```
- **Drow.** `global_attack` stays a top-level param because the locale text uses `{global_attack}`. Drow does not buff herself, her aura survives silence, and it disappears when she leaves the board (`expanded_classic_test.gd:92-98`).
- **Zeus.** If Annihilation condemns Zeus, the spell's Pulse removes him before `card_played` is emitted. He is no longer live, so he does not trigger (the comment at `match_engine.gd:412`).
- **Savage Wolf.** The wolf's `attack` field goes from 3 to 4 and `max_health` from 3 to 5. Settle adds 2 to `health`, so `expanded_classic_test.gd:161` passes unchanged.
- **Forward Charge.** `"across"` reproduces today's `arrow = 0, combat_target = -1`. The siege bonus is a `give` entry for the round. The only test edit is `pa.temp_siege` becoming `keyword_of(pa, "siege")` (§11.3).
- **Gust.** The silence is a status entry. The `silenced` mirror keeps `expanded_classic_test.gd:116-125` green.

### 5.2 Book of the Dead: an item with an aura, a trigger, an active ability, charges and tokens

> "Equipped hero has +4 Health. Add a charge to Book of the Dead after an allied Melee Creep dies. | Active 2: Summon a Zombie for each charge and remove all charges."

```json
{"id": "book_of_the_dead", "source_id": 10235, "kind": "item", "color": "item", "slot": "accessory", "price": 10, "health": 4,
 "status": "verified",
 "abilities": [
  {"id": "harvest", "kind": "trigger", "on": "unit_died", "filter": {"side": "ally", "card": "melee_creep"},
   "ops": [{"op": "charges", "on": "$self", "add": 1}]},
  {"id": "raise", "valve": 10480, "kind": "active", "cooldown": 2,
   "ops": [{"op": "summon", "card": "zombie", "count": {"charges": "$self"}},
           {"op": "charges", "on": "$self", "set": 0}]}]}
```
- `health: 4` is the implicit host aura.
- `$self` is the `item_state.accessory` instance and `$host` is the hero. Default lanes resolve to the host's lane.
- The trigger and the active work only while the host is in a lane (RQ-38).
- The command is `{"type":"ability","unit":<item oid>}`. A silenced or stunned host cannot use it.
- Each Zombie takes a random empty position and rolls its own arrow.

### 5.3 Tidehunter: a hero active with a stun and an independent roll per enemy

> "Ravage: Active 4: Stun Tidehunter's enemy neighbors this round and each other enemy has a 50% chance of being stunned this round."

```json
{"id": "tidehunter", "source_id": 10024, "kind": "hero", "color": "red", "attack": 2, "armor": 1, "health": 18,
 "signature": "kraken_shell", "status": "verified", "chance": 50, "ability_cooldown": 4,
 "abilities": [{"id": "ravage", "valve": 10434, "kind": "active", "cooldown": 4,
  "ops": [
   {"op": "let", "name": "near", "value": "enemy_neighbors"},
   {"op": "give", "to": "$v.near", "keywords": {"stun": 1}, "until": "round"},
   {"op": "for_each", "in": {"use": "enemies", "not": "$v.near"}, "as": "u", "ops": [
     {"op": "chance", "pct": {"param": "chance"},
      "then": [{"op": "give", "to": "$v.u", "keywords": {"stun": 1}, "until": "round"}]}]}]}]}
```
- There is exactly one roll per non-neighbor enemy, in slot order, so replays reproduce.
- The spec checks the distribution over 200 seeds (§13.1).

### 5.4 Sven and Timbersaw: layering and relation-based auras

> Sven: "Great Cleave: Sven has +X Cleave where X is equal to half its Attack."
> Timbersaw: "Reactive Armor: Timbersaw has +1 Armor for each of its attackers. Timbersaw's attackers have -1 Armor."

```json
[
 {"id": "sven", "source_id": 10054, "kind": "hero", "color": "red", "attack": 5, "armor": 0, "health": 11,
  "signature": "gods_strength", "status": "verified",
  "abilities": [{"id": "great_cleave", "valve": 10513, "kind": "aura", "affects": "$self",
                 "grant": {"cleave": {"half": {"stat": "attack", "of": "$self"}}}}]},
 {"id": "timbersaw", "source_id": 10022, "kind": "hero", "color": "red", "attack": 4, "armor": 0, "health": 11,
  "signature": "whirling_death", "status": "verified",
  "abilities": [{"id": "reactive_armor", "valve": 10498, "kind": "aura", "affects": "$self",
                 "grant": {"armor": {"count": "attackers"}}},
                {"id": "reactive_armor_debuff", "kind": "aura", "affects": "attackers", "grant": {"armor": -1}}]}
]
```
- Sven is a layer-B keyword grant: it reads the derived attack, including items and Drow. Two Svens cannot loop, because keyword grants may not read keywords (§3.14 rule 6).
- `attackers` depends only on positions, arrows and forced targets, plus the disarm status. Auras cannot grant disarm, so there is no cycle (RQ-05).

### 5.5 Bloodseeker and Vhoul Martyr: death snapshots and a Death Effect

> Bloodseeker: "Blood Bath: Fully heal Bloodseeker after a unit blocking it dies."
> Vhoul Martyr: "Death Effect: Modify allies with +1 Attack and +1 Health."

```json
[
 {"id": "bloodseeker", "source_id": 10018, "kind": "hero", "color": "black", "attack": 7, "armor": 0, "health": 7,
  "signature": "blood_rage", "status": "verified",
  "abilities": [{"id": "blood_bath", "valve": 10496, "kind": "trigger", "on": "unit_died", "filter": {"was": "blocker"},
                 "ops": [{"op": "heal", "to": "$self", "amount": "full"}]}]},
 {"id": "vhoul_martyr", "source_id": 10107, "kind": "creep", "color": "green", "cost": 2, "attack": 2, "armor": 0, "health": 2,
  "status": "verified",
  "abilities": [{"id": "martyrdom", "kind": "trigger", "on": "death",
                 "ops": [{"op": "modify", "to": "allies", "stats": {"attack": 1, "max_health": 1}}]}]}
]
```
- `was: blocker` means `$host.uid` is in `$e.attackers`: the dead unit was Bloodseeker's combat target when it died.
  - If Bloodseeker dies in the same Pulse, he is in the Fountain and not live, so nothing happens (RQ-43).
  - Pit Fighter of Quoidge (`was: allied_neighbor`) and Necrophos (`was: enemy_neighbor`) use the same mechanism.
- For Vhoul Martyr, `$self` is the snapshot. `allies` resolves in the snapshot's lane for its controller, and the Martyr itself is gone.

### 5.6 Venomancer and Plague Ward: a deployment summon and a random before-action ping

> Venomancer: "Venomous Nature: Summon a Plague Ward into Venomancer's lane each deployment phase."
> Plague Ward: "Before the action phase, deal 2 piercing damage to a random enemy neighbor of Plague Ward."

```json
[
 {"id": "venomancer", "source_id": 10001, "kind": "hero", "color": "blue", "attack": 2, "armor": 0, "health": 6,
  "signature": "sow_venom", "status": "verified", "rq": ["RQ-23"],
  "abilities": [{"id": "venomous_nature", "valve": 10491, "kind": "trigger", "on": "deployment",
                 "ops": [{"op": "summon", "card": "plague_ward"}]}]},
 {"id": "plague_ward", "source_id": 10003, "kind": "creep", "token": true, "color": "blue", "cost": 3,
  "attack": 1, "armor": 0, "health": 3, "status": "verified", "amount": 2,
  "abilities": [{"id": "ward", "kind": "trigger", "on": "before_action",
                 "ops": [{"op": "damage", "to": {"use": "enemy_neighbors", "pick": {"random": 1}},
                          "amount": {"param": "amount"}, "piercing": true}]}]}
]
```
- The summon happens after heroes are placed, so a Venomancer deployed this round summons into its new lane (RQ-23).
- It happens before `_roll_arrows`, so the ward rolls its arrow with everyone else and no extra randomness is consumed.
- Several wards fire in one batch (§4.2). A random pick from an empty set consumes no randomness.

### 5.7 Bitter Enemies and March of the Machines: improvements with charges

> Bitter Enemies: "After the combat phase, remove a charge from Bitter Enemies. Before the action phase, if there are zero charges on Bitter Enemies, deal 6 damage to both towers."
> March of the Machines: "Before the action phase, if there are charges on March of the Machines, remove one and deal 2 damage to the enemy tower and 2 damage to each enemy."

```json
[
 {"id": "bitter_enemies", "source_id": 10156, "kind": "improvement", "color": "black", "cost": 2, "amount": 6, "charges": 3,
  "status": "verified", "rq": ["RQ-27"],
  "abilities": [
   {"id": "countdown", "kind": "trigger", "on": "after_combat", "ops": [{"op": "charges", "on": "$self", "add": -1, "min": 0}]},
   {"id": "feud", "kind": "trigger", "on": "before_action", "where": {"cmp": [{"charges": "$self"}, "==", 0]},
    "ops": [{"op": "tower_damage", "to": "both_towers", "amount": {"param": "amount"}}]}]},
 {"id": "march_of_the_machines", "source_id": 10291, "kind": "improvement", "color": "black", "cost": 5, "amount": 2,
  "charges": 3, "status": "verified", "rq": ["RQ-01", "RQ-27"],
  "abilities": [{"id": "march", "kind": "trigger", "on": "before_action", "where": {"cmp": [{"charges": "$self"}, ">", 0]},
                 "ops": [{"op": "charges", "on": "$self", "add": -1},
                         {"op": "tower_damage", "to": "enemy_tower", "amount": {"param": "amount"}},
                         {"op": "damage", "to": "enemies", "amount": {"param": "amount"}}]}]}
]
```
- The play command is `{"type":"play","hand":i,"lane":L}`. Every improvement is cross-lane: it pays mana and needs a black hero in the active lane.
- Bitter Enemies can fell both towers at once, which `_check_winner` turns into a draw.
- **[CF-8]** Valve's set 01 data gives Bitter Enemies `"charges": 3`, the same field March of the Machines uses, so RQ-27 is closed for both and Bitter Enemies is `verified`. `rq_27_starting_charges` pins both values against the Valve data.

### 5.8 The Oath: a rules-layer restriction and a conditional aura

> "You can not play spells or creeps while this is the active lane. If there is an allied black hero in this lane, allies have +4 Attack."

```json
{"id": "the_oath", "source_id": 10182, "kind": "improvement", "color": "black", "cost": 3, "amount": 4, "status": "verified",
 "abilities": [
  {"id": "oath", "kind": "aura", "affects": "you",
   "grant": {"rules": {"forbid_play": {"kinds": ["spell", "creep"], "lane": "self"}}}},
  {"id": "sworn", "kind": "aura", "affects": "allies",
   "if": {"has": {"s": "units", "side": "ally", "kind": "hero", "color": "black"}},
   "grant": {"attack": {"param": "amount"}}}]}
```
- In The Oath's lane, `legal_actions` drops the owner's spell and creep plays. Items and improvements are still allowed, and `_reason` reports `REASON_FORBIDDEN`.

### 5.9 Gank and Friendly Fire: two choices and battles

> Gank: "Choose an allied black hero. Choose another unit in any lane. They battle each other."
> Friendly Fire: "Choose two enemies. They battle each other."

```json
[
 {"id": "gank", "source_id": 10328, "kind": "spell", "color": "black", "cost": 4, "cross_lane": true, "status": "verified",
  "play": {"choices": [{"key": "target", "from": {"s": "units", "side": "ally", "kind": "hero", "color": "black"}},
                       {"key": "destination", "from": {"s": "units", "lane": "all", "not": "$c.target"}}],
           "ops": [{"op": "battle", "a": "$c.target", "b": "$c.destination"}]}},
 {"id": "friendly_fire", "source_id": 10360, "kind": "spell", "color": "blue", "cost": 6, "status": "verified",
  "play": {"choices": [{"key": "target", "from": "enemies"},
                       {"key": "destination", "from": "enemies", "after": "$c.target"}],
           "ops": [{"op": "battle", "a": "$c.target", "b": "$c.destination"}]}}
]
```
- Commands look like `{"type":"play","hand":i,"target":<uid>,"destination":<uid>}`.
- `after` stops Friendly Fire from offering both (A, B) and (B, A).
- A battle applies armor, Pierce, hero bonuses, immunity, Retaliate in both directions and Lethal. It never applies siege or cleave.

### 5.10 Mystic Flare: an evenly divided damage split

> "Deal 12 damage evenly divided among a unit and its allied neighbors."

```json
{"id": "mystic_flare", "source_id": 10063, "kind": "spell", "color": "blue", "cost": 6, "amount": 12, "status": "verified",
 "rq": ["RQ-28"],
 "play": {"choices": [{"key": "target", "from": "units"}],
          "ops": [{"op": "damage_split", "to": ["$c.target", {"s": "units", "rel": {"allied_neighbors": "$c.target"}}],
                   "total": {"param": "amount"}}]}}
```

### 5.11 Winter's Curse: disarm, then a Pulse, then a battle

> "Disarm a unit until end of round. □ That unit's allied neighbors battle it."

```json
{"id": "winters_curse", "source_id": 10011, "kind": "spell", "color": "black", "cost": 6, "status": "verified",
 "play": {"choices": [{"key": "target", "from": "units"}],
          "ops": [{"op": "give", "to": "$c.target", "keywords": {"disarm": 1}, "until": "round"},
                  {"op": "pulse"},
                  {"op": "battle", "a": "$c.target", "b": {"s": "units", "rel": {"allied_neighbors": "$c.target"}}}]}}
```
- The target is disarmed, so it deals no battle damage. Its Retaliate still hits each neighbor that attacks it (RQ-06).

### 5.12 Chain Frost: repeat, Pulses, a random bounce and look-back (hardest)

> "Deal 3 damage to a unit. Repeat 7 times: □ Deal 3 damage to a random unit to its left or right. Get initiative."

```json
{"id": "chain_frost", "source_id": 10318, "kind": "spell", "color": "black", "cost": 7, "amount": 3, "repeat": 7,
 "status": "draft", "rq": ["RQ-15", "RQ-16"],
 "play": {"initiative": true,
  "choices": [{"key": "target", "from": "units"}],
  "ops": [
   {"op": "damage", "to": "$c.target", "amount": {"param": "amount"}},
   {"op": "let", "name": "prev", "value": "$c.target"},
   {"op": "repeat", "times": {"param": "repeat"}, "ops": [
     {"op": "pulse"},
     {"op": "let", "name": "next", "value": {"s": "units", "rel": {"allied_neighbors": "$v.prev"}, "pick": {"random": 1}}},
     {"op": "if", "cond": {"empty": "$v.next"}, "then": [{"op": "break"}]},
     {"op": "damage", "to": "$v.next", "amount": {"param": "amount"}},
     {"op": "let", "name": "prev", "value": "$v.next"}]}]}}
```
- The Pulse at the start of each repetition removes the dead and resolves triggers.
- If `$v.prev` died, `allied_neighbors` reads its snapshot's neighbor uids that are still in play.
- When there are none, the remaining bounces fizzle (RQ-16, low confidence). The card stays `draft` until a reference match confirms this; the pinned test is `rq_16_chain_frost_fizzles`.

### 5.13 Relentless Pursuit: a cross-lane choice, a random move and a Pulse

> "Choose a unit in another lane. Move a random allied black hero from this lane to that lane. □ Deal 2 damage to the chosen unit."

```json
{"id": "relentless_pursuit", "source_id": 10399, "kind": "spell", "color": "black", "cost": 1, "amount": 2, "cross_lane": true,
 "status": "verified",
 "play": {"choices": [{"key": "target", "from": {"s": "units", "lane": "other"}}],
          "ops": [{"op": "move", "unit": {"s": "units", "side": "ally", "kind": "hero", "color": "black", "lane": "active",
                                          "pick": {"random": 1}}, "lane": "$c.target.lane"},
                  {"op": "pulse"},
                  {"op": "damage", "to": "$c.target", "amount": {"param": "amount"}}]}}
```

### 5.14 Luna and Eclipse: hidden per-card state

> Luna: "Lucent Beam: Before the action phase, deal 1 piercing damage to a random enemy and add a charge to three random Eclipse cards in your hand or deck."
> Eclipse: "Repeat one time for each charge: □ Deal 3 piercing damage to a random enemy."

```json
[
 {"id": "luna", "source_id": 10006, "kind": "hero", "color": "blue", "attack": 3, "armor": 0, "health": 8,
  "signature": "eclipse", "status": "verified",
  "abilities": [{"id": "lucent_beam", "valve": 10489, "kind": "trigger", "on": "before_action",
   "ops": [{"op": "damage", "to": {"use": "enemies", "pick": {"random": 1}}, "amount": 1, "piercing": true},
           {"op": "card_counter", "counter": "charges", "add": 1,
            "cards": {"s": "cards", "zone": ["hand", "deck"], "player": "you", "card": "eclipse", "pick": {"random": 3}}}]}]},
 {"id": "eclipse", "source_id": 10007, "kind": "spell", "color": "blue", "cost": 6, "amount": 3, "charges": 1, "status": "verified",
  "play": {"ops": [{"op": "repeat", "times": {"card_counter": "$played", "counter": "charges"}, "ops": [
     {"op": "pulse"},
     {"op": "damage", "to": {"use": "enemies", "pick": {"random": 1}}, "amount": {"param": "amount"}, "piercing": true}]}]}}
]
```
- **[CF-2]** Eclipse is printed with 1 charge (Valve `"charges": 1`). An instance with no stored value reads 1, so an Eclipse that Luna never touched, or a Multicast base copy, still deals 3 once. Each Lucent Beam charge adds to that.
- Charges are written to `hand_state` (the owner can see them on their own cards) or to `deck_state` (nobody can see them). The public log gets `charged {p, n}`.
- `$played.state` is the `hand_state` entry removed from the hand.
- In a bot simulation the deck is empty, so fewer cards get charged. That is acceptable for a heuristic and harmless.

### 5.15 Meepo and Divided We Stand: Soulbound, a cross-lane move with a Pulse, and a summoned hero

> Meepo: "Poof: Active 2: Move Meepo to an allied Meepo's lane. □ Deal 2 damage to the new enemy neighbors. | United We Fall: Meepo has Soulbound."
> Divided We Stand: "Summon a Meepo."

```json
[
 {"id": "meepo", "source_id": 10004, "kind": "hero", "color": "blue", "attack": 4, "armor": 0, "health": 5,
  "signature": "divided_we_stand", "status": "draft", "rq": ["RQ-29", "RQ-39"], "amount": 2,
  "keywords": {"soulbound": 1},
  "abilities": [{"id": "poof", "valve": 10429, "kind": "active", "cooldown": 2,
   "choices": [{"key": "lane", "from": {"s": "lanes", "not": "$self.lane",
                "where": {"has": {"s": "units", "side": "ally", "card": "meepo", "lane": "$it", "not": "$self"}}}}],
   "ops": [{"op": "move", "unit": "$self", "lane": "$c.lane"},
           {"op": "pulse"},
           {"op": "damage", "to": "enemy_neighbors", "amount": {"param": "amount"}}]}]},
 {"id": "divided_we_stand", "source_id": 10005, "kind": "spell", "color": "blue", "cost": 4, "status": "draft", "rq": ["RQ-29"],
  "play": {"ops": [{"op": "summon", "card": "meepo"}]}}
]
```
- A summoned Meepo is a hero unit with `roster: true`: it joins its owner's roster (RQ-29, `SUMMONED_HEROES_JOIN_ROSTER`).
  - It has hero bounty, its colour counts for casting, and it can equip items.
  - When it dies it returns to the Fountain and is redeployed like any hero, keeping its items and Modify effects (RQ-29).
  - **M4 as built:** the pre-M4 default (`roster: false`, removed from the game when it dies) had no source. RQ-29 was decided from the glossary ("When [a hero] is killed, it ... returns to the Fountain to be redeployed later"), and both cards are `verified`. Setting the switch to false restores the old behaviour.
- Soulbound condemns every other allied Meepo in the same Pulse, the roster Meepo included. A Death Shield saves a partner (RQ-39).
- `"lane": "$it"` inside the nested selector refers to the outer lane candidate (§3.3, `$it` scoping).

### 5.16 Ravenous Mass and Lich: values read before condemn

> Ravenous Mass: "Active 1: Condemn Ravenous Mass's allied neighbors. Modify Ravenous Mass with their Attack and Health."
> Lich: "Sacrifice: Condemn another ally and draw a card. If that ally has 6 or more Attack, draw an extra card."

```json
[
 {"id": "ravenous_mass", "source_id": 10116, "kind": "creep", "color": "black", "cost": 4, "attack": 1, "armor": 0, "health": 1,
  "status": "verified",
  "abilities": [{"id": "devour", "valve": 10459, "kind": "active", "cooldown": 1,
   "ops": [{"op": "let", "name": "eaten", "value": "allied_neighbors"},
           {"op": "let", "name": "atk", "value": {"sum": "$v.eaten", "stat": "attack"}},
           {"op": "let", "name": "hp", "value": {"sum": "$v.eaten", "stat": "health"}},
           {"op": "condemn", "to": "$v.eaten"},
           {"op": "modify", "to": "$self", "stats": {"attack": "$v.atk", "max_health": "$v.hp"}}]}]},
 {"id": "lich", "source_id": 10038, "kind": "hero", "color": "black", "attack": 5, "armor": 0, "health": 9,
  "signature": "chain_frost", "status": "verified", "threshold": 6,
  "abilities": [{"id": "sacrifice", "valve": 10440, "kind": "active", "cooldown": 2,
   "choices": [{"key": "target", "from": "other_allies"}],
   "ops": [{"op": "let", "name": "atk", "value": {"stat": "attack", "of": "$c.target"}},
           {"op": "condemn", "to": "$c.target"},
           {"op": "draw", "player": "you", "n": 1},
           {"op": "if", "cond": {"cmp": ["$v.atk", ">=", {"param": "threshold"}]},
            "then": [{"op": "draw", "player": "you", "n": 1}]}]}]}
]
```
- The condemned units die at the next Pulse, and their bounty goes to the opponent (RQ-02).

### 5.17 Self Sabotage: a hack on cards in the opponent's hand

> "Modify two random cards in opponent's hand with "□ Deal 6 damage to a random allied tower in any lane.""

```json
{"id": "self_sabotage", "source_id": 10302, "kind": "spell", "color": "blue", "cost": 4, "amount": 6, "status": "verified",
 "rq": ["RQ-36", "RQ-46"],
 "grants": [{"kind": "hack", "ops": [
   {"op": "pulse"},
   {"op": "tower_damage", "to": {"s": "towers", "side": "ally", "lane": "all", "pick": {"random": 1}}, "amount": {"param": "amount"}}]}],
 "play": {"ops": [{"op": "modify", "to": {"use": "opponent_hand", "pick": {"random": 2}}, "grant": 0}]}}
```
- The hack is stored in the victim's `hand_state[i].hacks`. The holder sees it; the caster's view only gets `hack {p, n:2}`.
- When the victim plays a hacked card, the card resolves and pulses. Then the hack runs with the victim as controller, so "allied" means the victim's towers. Only after that is `card_played` emitted.
- RQ-46: "towers" includes a lane's standing ancient.

### 5.18 Kanna: deployment redirect without a privacy leak

> "Bringer of Conquest: The random allied Melee Creeps are deployed into Kanna's lane."

```json
{"id": "kanna", "source_id": 10031, "kind": "hero", "color": "blue", "attack": 2, "armor": 0, "health": 12,
 "signature": "prey_on_the_weak", "status": "draft", "rq": ["RQ-22"],
 "abilities": [{"id": "bringer_of_conquest", "valve": 10503, "kind": "aura", "affects": "you",
                "grant": {"rules": {"creep_lane": "self"}}}]}
```
- At `_begin_deployment`, the player's pending creep lanes are still drawn, so randomness is unchanged. They are then published as `-1` ("Kanna's lane") if Kanna is in a lane or ready to deploy.
- At reveal, `-1` resolves to her planned or current lane. Her private plan never appears in any event before the reveal.

### 5.19 Ogre Magi: a 25% base copy of the played card

> "Multicast: After you play a blue spell, there is a 25% chance to put a base copy of that card into your hand."

```json
{"id": "ogre_magi", "source_id": 10043, "kind": "hero", "color": "blue", "attack": 3, "armor": 0, "health": 7,
 "signature": "ignite", "status": "verified", "chance": 25,
 "abilities": [{"id": "multicast", "valve": 10509, "kind": "trigger", "on": "card_played",
                "filter": {"player": "you", "kind": "spell", "color": "blue"},
                "ops": [{"op": "chance", "pct": {"param": "chance"},
                         "then": [{"op": "add_card", "player": "you", "card": "$e.card", "base": true}]}]}]}
```

### 5.20 Crystal Maiden and Storm Spirit: any-lane triggers, once-per, and "until its next combat"

> Crystal Maiden: "Arcane Aura: After the first time an allied spell is played in each lane, restore 2 Mana to the tower in that lane."
> Storm Spirit: "Overload: Give Storm Spirit +2 Attack until end of its next combat phase after you play a black card in any lane."

```json
[
 {"id": "crystal_maiden", "source_id": 10064, "kind": "hero", "color": "blue", "attack": 2, "armor": 0, "health": 5,
  "signature": "frostbite", "status": "verified", "amount": 2,
  "abilities": [{"id": "arcane_aura", "valve": 10518, "kind": "trigger", "on": "card_played", "lane": "any", "once_per": "lane_round",
                 "filter": {"player": "you", "kind": "spell"},
                 "ops": [{"op": "mana", "to": {"s": "towers", "side": "ally", "lane": "$e.lane"}, "restore": {"param": "amount"}}]}]},
 {"id": "storm_spirit", "source_id": 10536, "kind": "hero", "color": "black", "attack": 4, "armor": 0, "health": 6,
  "signature": "ball_lightning", "status": "verified", "amount": 2,
  "abilities": [{"id": "overload", "valve": 10537, "kind": "trigger", "on": "card_played", "lane": "any",
                 "filter": {"player": "you", "color": "black"},
                 "ops": [{"op": "give", "to": "$self", "stats": {"attack": {"param": "amount"}}, "until": "next_combat"}]}]}
]
```

### 5.21 Wrath of Gold: spend all gold, then repeat with Pulses

> "Spend all your gold. Repeat one time for each gold spent: □ Deal 4 damage to a random ally or enemy."

```json
{"id": "wrath_of_gold", "source_id": 10331, "kind": "spell", "color": "blue", "cost": 3, "amount": 4, "status": "verified",
 "play": {"ops": [{"op": "gold", "player": "you", "set": 0, "as": "spent"},
                  {"op": "repeat", "times": "$v.spent", "ops": [
                    {"op": "pulse"},
                    {"op": "damage", "to": {"use": "units", "pick": {"random": 1}}, "amount": {"param": "amount"}}]}]}}
```
- This can produce dozens of Pulses. The 2048-op budget per command allows about 600 repetitions. The UI fast-forwards long event bursts (§8.7).

### 5.22 Caught Unprepared and Heroic Resolve: durations and granted triggers

> Caught Unprepared: "Stun a hero until they equip an item."
> Heroic Resolve: "Modify a red hero with "After you play a non-item card costing 2 or less, modify this hero with +2 Health.""

```json
[
 {"id": "caught_unprepared", "source_id": 10396, "kind": "spell", "color": "green", "cost": 4, "status": "verified",
  "rq": ["RQ-35"],
  "play": {"choices": [{"key": "target", "from": "heroes"}],
           "ops": [{"op": "give", "to": "$c.target", "keywords": {"stun": 1}, "until": "equip"}]}},
 {"id": "heroic_resolve", "source_id": 10327, "kind": "spell", "color": "red", "cost": 2, "amount": 2, "status": "verified",
  "rq": ["RQ-44"],
  "grants": [{"kind": "trigger", "on": "card_played", "filter": {"player": "you", "not_kind": "item", "cost_max": 2},
              "ops": [{"op": "modify", "to": "$self", "stats": {"max_health": {"param": "amount"}}}]}],
  "play": {"choices": [{"key": "target", "from": {"s": "units", "kind": "hero", "color": "red"}}],
           "ops": [{"op": "modify", "to": "$c.target", "grant": 0}]}}
]
```
- **Caught Unprepared.** The stun lasts across rounds. It ends when that hero equips any item, or when it enters the Fountain.
- **Heroic Resolve.** The granted trigger is permanent.
  - Its "you" is the bearer's controller, so an enemy red hero would benefit its own owner.
  - It sees the `card_played` event of Heroic Resolve itself, because the event is emitted after resolution (RQ-44).

### 5.23 Claszureme Hourglass: the opponent's draw locks that card

> "Equipped hero has +4 Health. Whenever opponent draws a card, give that card +1 Lock if equipped hero is in any lane."

```json
{"id": "claszureme_hourglass", "source_id": 10241, "kind": "item", "color": "item", "slot": "accessory", "price": 10,
 "health": 4, "status": "verified",
 "abilities": [{"id": "hourglass", "kind": "trigger", "on": "card_drawn", "lane": "any", "filter": {"player": "opponent"},
                "ops": [{"op": "lock", "cards": "$e.card", "n": 1}]}]}
```
- The trigger is live only while the host is in a lane, which is exactly the card's condition.
- `$e.card` is the drawn instance, found by its `iid`. Each of the two round-draw cards locks separately.
- The holder's view shows which card is locked; the Hourglass owner's view gets `lock {p, n:1}`.

### 5.24 Apotheosis Blade: Lethal, then condemning improvements and the blocker's items

> "Equipped hero has +8 Attack and +4 Siege. Condemn each unit equipped hero deals battle damage to. | Active 1: Condemn enemy improvements. Condemn each item equipped by the unit blocking equipped hero."

```json
{"id": "apotheosis_blade", "source_id": 10263, "kind": "item", "color": "item", "slot": "weapon", "price": 25, "attack": 8,
 "status": "verified",
 "abilities": [
  {"id": "godlike", "kind": "aura", "affects": "$host", "grant": {"siege": 4, "lethal": 1}},
  {"id": "ascension", "valve": 10541, "kind": "active", "cooldown": 1,
   "ops": [{"op": "condemn", "to": {"s": "improvements", "side": "enemy"}},
           {"op": "condemn", "to": {"s": "items", "rel": {"equipped_on": "blocker"}}}]}]}
```
- Lethal works in combat and in battles. It needs more than 0 damage actually dealt, so an immune unit is not condemned (RQ-10). A Death Shield saves the victim once.

### 5.25 Routed: Fountain targets, half attack, and a granted tower aura that follows the hero

> "Modify enemy heroes at the Fountain with -X Attack where X is half their Attack. Modify them with "Your tower has -1 Mana.""

```json
{"id": "routed", "source_id": 10191, "kind": "spell", "color": "red", "cost": 6, "status": "verified", "rq": ["RQ-28"],
 "grants": [{"kind": "aura", "affects": "your_tower", "grant": {"mana": -1}}],
 "play": {"ops": [{"op": "for_each", "in": {"s": "units", "side": "enemy", "kind": "hero", "lane": "fountain"}, "as": "h",
   "ops": [{"op": "modify", "to": "$v.h", "stats": {"attack": {"neg": {"half": {"stat": "attack", "of": "$v.h"}}}}, "grant": 0}]}]}}
```
- The granted aura is relative to the bearer. It gives −1 Mana to the tower of whatever lane the hero deploys into, and nothing while the hero is in the Fountain.
- Both modifications survive death. Purge removes them only if they came from the purger's opponent.

### 5.26 Chen and Shop Deed: control change, and the rules layer on the shop

> Chen: "Holy Persuasion: Active 4: Get control of an enemy creep."
> Shop Deed: "Each item in your Secret Shop costs X less gold, where X is equal to its base cost."

```json
[
 {"id": "chen", "source_id": 10017, "kind": "hero", "color": "green", "attack": 4, "armor": 0, "health": 9,
  "signature": "hand_of_god", "status": "verified", "rq": ["RQ-17"],
  "abilities": [{"id": "holy_persuasion", "valve": 10432, "kind": "active", "cooldown": 4,
                 "choices": [{"key": "target", "from": "enemy_creeps"}],
                 "ops": [{"op": "control", "unit": "$c.target", "to": "you"}]}]},
 {"id": "shop_deed", "source_id": 10255, "kind": "item", "color": "item", "slot": "deed", "price": 22, "status": "draft",
  "rq": ["RQ-26", "RQ-41"],
  "abilities": [{"id": "deed", "kind": "aura", "affects": "you", "grant": {"rules": {"secret_shop_discount": 1}}}]}
]
```
- **Chen.** The stolen creep keeps its permanent modifications, together with their original `by`. Its bounty now goes to Chen's opponent.
- **Shop Deed.** It is played for free and with no hero needed, like a consumable, into the public `deeds` zone (RQ-41).
  - The Secret Shop price is `base − n × base`.
  - A second deed makes the price negative, and buying then pays gold (RQ-26).

### 5.27 Glyph of Confusion and Enough Magic!: entering a lane, and ending the action phase

> Glyph of Confusion: "Whenever any unit enters this lane, stun it this round."
> Enough Magic!: "Proceed to the combat phase."

```json
[
 {"id": "glyph_of_confusion", "source_id": 10187, "kind": "improvement", "color": "blue", "cost": 6, "status": "verified",
  "rq": ["RQ-21"],
  "abilities": [{"id": "confusion", "kind": "trigger", "on": "unit_entered",
                 "ops": [{"op": "give", "to": "$e.unit", "keywords": {"stun": 1}, "until": "round"}]}]},
 {"id": "enough_magic", "source_id": 10326, "kind": "spell", "color": "red", "cost": 5, "status": "draft", "rq": ["RQ-20"],
  "play": {"ops": [{"op": "end_action_phase"}]}}
]
```
- **Glyph of Confusion.** `unit_entered` fires for every placement into the Glyph's lane: deployment (the entrants stay stunned for the whole new round), creep plays, summons, moves in, and control changes. Swaps inside the lane do not fire it (RQ-21).
- **Enough Magic!** After the card resolves, `_finish_action(p, false)` hands initiative to the opponent, and the lane goes straight to combat as if both players had passed. The card stays `draft` until a reference match confirms RQ-20.

---

## 6. Engine API changes

### 6.1 Public functions (signatures unchanged)

| Function | Change |
|---|---|
| `start(seed, decks)` | Initializes the new fields. Ends with `Kernel.lane_open(e, 0, false)`. |
| `legal_actions(player)` | Same shapes and the same leading order (§7.1). Adds improvement `lane` plays, item and improvement abilities, lock and rules-layer gates, and rules-layer prices. |
| `apply_action(player, cmd)` | Same canonicalization. Validation uses `Targeting.is_legal`, which accepts exactly the commands in `legal_actions` (tested). |
| `player_view(player)` | Adds the redactions in §10.4 and per-viewer merging of `_s` event fields. |
| `simulation_from_view(player)` | Unchanged. |
| `combat_preview(lane)` | Same keys, plus `heal`, `dies` and `strikes` (§4.5). |
| `attack_of`, `armor_of`, `max_health_of` | Derived through `Stats.derive`. Same meaning, now including every keyword source. |
| `battle_attack(a, t)` | `attack_of(a) + bonus_hero` (if `t` is a hero) `+ bonus_tower` (if `t` is the tower). |
| `combat_targets(unit)` | After FX-2 (RQ-19), the tower is legal only when the position directly across is empty. |
| `slot_of`, `combat_target_of`, `find_unit`, `creep_positions`, `can_concede`, `state_digest` | Unchanged. |
| `replay_data()` / `load_replay(data)` | Adds `"rules": RULES_VERSION`. A mismatch fails with code `replay_rules` (ERR_REPLAY_RULES in `i18n/ui.csv`). |

### 6.2 New read-only helpers

All are pure. They work on the live engine and on `board_view.display_engine` over a view.

| Helper | Returns |
|---|---|
| `keyword_of(unit, k) -> int` | Derived keyword value (siege, cleave, retaliate, regeneration, bounty, bonus_hero, bonus_tower). |
| `has_flag(unit, f) -> bool` | pierce, lethal, damage_immunity, death_shield, stun, silence, disarm, rapid_deployment, soulbound. |
| `badges(unit) -> Array` | `[{"k": "stun", "v": 1, "until": "round", "src": "astral_imprisonment"}]`, for unit_card and inspect. |
| `tower_stats(lane, p) -> Dictionary` | `{armor, retaliate, regeneration, mana_mod}`. |
| `find_object(id) -> Dictionary` | Unit, item instance (with `host` and `slot`), improvement or deed. |
| `improvements(lane, p) -> Array` | Improvement objects in `order`. |
| `abilities_of(id) -> Array` | `[{"source": id, "ability": "raise", "card": "book_of_the_dead", "cooldown": 2, "cd": 0, "ready": true, "steps": [...]}]`. |
| `choice_steps(source) -> Array` | `source` is `{"hand": i}` or `{"unit": id}`. Returns `[{"key": "target", "type": "unit"}, {"key": "destination", "type": "combat_target"}]`. Types: `unit`, `improvement`, `combat_target`, `lane`, `position` (with `lane_key` or `lane`). |
| `can_cast_colour(unit) -> bool` | Hero, not silenced, not stunned. Used by `_reason`. |
| `rules_of(p) -> Dictionary` | Folded rules layer (§3.11). |
| `price_of(p, source, card) -> int` | Shop price after rules. |
| `hand_public(p) -> Array` | `[{"lock": n}]` per hand slot. Lock counts are visible on card backs. |

### 6.3 Commands

| Command | Shape |
|---|---|
| Play a creep, spell or item | Unchanged: `{"type":"play","hand":i[,"target":uid][,"destination":uid\|0][,"position":p]}` |
| Play an improvement | `{"type":"play","hand":i,"lane":L}` (the existing integer field `lane`) |
| Play with lane or position choices | e.g. Ball Lightning: `{"type":"play","hand":i,"target":uid,"lane":L,"position":p}` |
| Activate an ability | `{"type":"ability","unit":id[,choice keys]}`. `id` is a unit uid (as for J'Muy today), an item oid, or an improvement oid. Oids start at 1,000,000 and never collide with uids. |
| Shop and deployment commands | Unchanged. |

### 6.4 Versions

| Constant | Old → new | When |
|---|---|---|
| `MatchEngine.PROTOCOL_VERSION` | 6 → 7 | M1.2 (state shape). The comment block at `match_engine.gd:11-19` gains a "7:" line. |
| `SteamBridge.PROTOCOL` | 7 → 8 | M1.2 |
| `RULES_VERSION` (`rules/rules_version.gd`, generated) | new | Every rules-code change. Hashed into `compute_content_hash` and written into replays. |

### 6.5 Events

Every new key gets a formatter in `event_text.gd`, an `EV_*` template in `i18n/ui.csv` (en and zh_CN), a sample in `run_tests._test_event_formatter_keys`, and a row in `KEYS`. The event window grows from 100 to 400 (`_event`, `match_engine.gd:920`).

| Key | Public fields | Private (`_s`) |
|---|---|---|
| `damage` | `src, hits:[[uid, n]], pierce` | — |
| `tower_damage` | `src, hits:[[lane, p, n]]` | — |
| `heal` | `src, hits` | — |
| `mod` | `id, st, kw, perm, src` | — |
| `status` | `id, kw, until, src` | — |
| `purge` | `id, n` | — |
| `condemn` | `id` | — |
| `summon` | `uid, card, p, lane, slot` | — |
| `move` | `uid, from, to, slot` | — |
| `swap` | `a, b` | — |
| `retarget` | `uid, target` | — |
| `control` | `uid, from, to` | — |
| `fountain` | `uid` | — |
| `battle` | `a, bs, hits` | — |
| `trigger` | `src, card, ability, p` (animation beat when a reactive ability fires) | — |
| `charges` | `id, n` | — |
| `gold` | `p, n` | — |
| `mana` | `lane, p, n` | — |
| `draw` | `p, n` | the drawer: `iids` |
| `discard` | `p, n` | the owner: `cards` |
| `lock` | `p, n` | the holder: `idx` |
| `gain_card` | `p` | the receiver: `card` |
| `charged` | `p, n` | — |
| `hack` | `p, n` | the holder: `idx` |
| `improvement` | `oid, card, p, lane` | — |
| `improvement_gone` | `oid` | — |
| `item_gone` | `uid, slot, card` | — |
| `pulse` | — | — |
| `rules_overflow` | — | — |

Existing keys keep their fields. `combat` gains `strikes`, and `ability` gains `ability` (the ability id).

### 6.6 Internals

| Status | Items |
|---|---|
| Removed | the `match card.effect` switch, `_static_field`, `_battle_neighbors`, the wolf growth loop, the legacy ad-hoc unit fields |
| Kept as thin wrappers, because tests call them | `_clean_dead(lane)` (an aligned Pulse), `_begin_deployment`, `_reveal_deployment`, `_make_unit`, `_place`, `_spawn`, `_remove_from_lane`, `_damage_structure` (now takes `piercing` and subtracts tower armor), `_check_winner` (idempotent), `_max_health`, `_event` (gains an optional `private` parameter) |

---

## 7. `legal_actions` and targeting

### 7.1 Order

The order is deterministic and keeps today's prefix, so callers that take `legal_actions(p)[0]` still get `pass`. Within the action phase:
1. `{"type":"pass"}`.
2. Unit abilities: active-lane units of the player, by row slot. This puts J'Muy exactly where it is today.
3. Item abilities: by host row slot, then weapon, armor, accessory.
4. Improvement abilities: the player's improvements in the active lane, by `order`.
5. Hand cards by index. Within a card, choice combinations come out depth-first in the order of the choice spec. Candidates follow the canonical order (§3.4), which matches today's `[0, 1]` sides, then lanes, then row order.

Shop and deployment actions are unchanged, apart from prices.

### 7.2 Gates

**Gates for a hand card at index `i`:**
1. `hand_state[i].lock` is 0.
2. `cost ≤ lanes[active].mana[p]` for non-item cards. Items (equipment, consumables, deeds) cost 0.
3. The colour check, for non-item cards (improvements included): some allied hero in the active lane of that colour where `can_cast_colour` is true (silence and stun both block it).
4. No `forbid_play` in `rules_of(p)` covers the card.
5. `play.requires` holds.
6. At least one complete choice combination exists.

**Gates for an ability:**
1. The source is live and in the active lane (a unit in it; an item whose host is in it; an improvement in it).
2. A unit, or an item's host, is not silenced or stunned. Improvements cannot be silenced.
3. `cd == 0`.
4. `requires` holds.
5. At least one combination exists.

### 7.3 Choice combinations

```gdscript
## rules/targeting.gd
static func combos(e, spec: Array, ctx: Dictionary, i: int = 0, acc: Dictionary = {}) -> Array:
	if i == spec.size():
		return [acc.duplicate()]
	var out: Array = []
	for value in Select.choice_values(e, spec[i], ctx, acc):   # canonical order; earlier picks bound as $c.<key>
		acc[spec[i].key] = value
		out.append_array(combos(e, spec, ctx, i + 1, acc))
	acc.erase(spec[i].key)
	return out
```

Implicit choices are prepended by the compiler:

| Card type | Implicit choice |
|---|---|
| creep | `{"key":"position","from":{"s":"positions","side":"ally","lane":"active"}}` (today's `creep_positions`) |
| improvement | `{"key":"lane","from":{"s":"lanes","lane":"all"}}` |
| equipment | `{"key":"target","from":{"s":"units","side":"ally","kind":"hero","lane":"active"}}` |

### 7.4 Combat targets

A `combat_target_of` choice lists `combat_targets(unit)`: `0` for the tower first, when it is legal, then the enemy uids across.

Today's rule (M1): the tower is legal when any of the three positions across is empty. FX-2 (RQ-19) changes this: the tower is legal only when the position directly across is empty. That one commit also changes `classic_cards_test.gd:171-176`.

The UI draws `0` as the target tower (`_redirect_tower`).

### 7.5 Validation

`Targeting.is_legal(e, p, cmd)` builds the actions for one source only:
- For `play`: the actions of hand index `cmd.hand`.
- For `ability`: the actions of `cmd.unit`.
- For every other type: today's list.

It then checks membership. The extra keys a command may carry are exactly the keys in that source's choice spec, so unknown or forged fields are rejected, as they are today.

The test `targeting_equivalence` fuzzes 10,000 commands, both mutated and legal, and asserts `is_legal == (cmd in legal_actions)`.

### 7.6 Size

The worst realistic cases:

| Card | Actions |
|---|---|
| Steal Strength | unit × other unit ≈ 20 × 19 |
| Gank | ≤ 5 heroes × ≤ 60 units |
| Ball Lightning | heroes × 3 lanes × positions |
| Friendly Fire | an unordered pair, thanks to `after` |

Limits:
- **Fuzz invariant:** `legal_actions(p).size() ≤ 2000`, and the guest packet stays under 200 KB.
- **If fuzzing exceeds either,** Steam protocol 9 sends path-encoded choices instead. That is the hybrid design's format, kept in reserve.
- **The bot prefilters** large action sets (§9.4).

---

## 8. UI integration

### 8.1 Display models (`board_view.build_models`)

Each unit model gains:
- `keywords`: non-zero derived keywords;
- `badges`: `engine.badges(unit)`;
- `abilities`: from `abilities_of` for the unit and its items, each with `ready` set when its ability action is in `actions`;
- `heal` and `dies`, from the preview;
- `mods`, a summary for inspect.

Two other changes in `board_view`:
- `"dies"` uses the preview's `dies` set instead of `damage >= health`.
- `PASSIVE_FIELDS` (`board_view.gd:18`) is replaced by `Library.has_passive(card)`. In `card_view.gd:15`, `ABILITY_FIELDS` is replaced by `Library.has_active(card) or Library.has_passive(card)`.

Staged models (`staged_model`, `deployment_overlay.gd:305`) need no new fields (§2.7). `deployment_overlay.gd:238` switches from `hero.max_health` to `max_health_of(hero)`.

### 8.2 Target prompts (generic stepper)

`match_screen._begin_hold` (`match_screen.gd:1288-1312`) stops guessing the hold kind from `plays[0]` keys and asks for `engine.choice_steps({"hand": index})`. Abilities ask for `engine.choice_steps({"unit": id})`.

The hold becomes:

```
{source, steps, step, picked, plays, card, mode, press, cross_lane}
```

At step `k`, the candidates are the distinct values of `plays[*][steps[k].key]` among plays whose earlier keys equal `picked`. Each step type has a renderer:

| Step type | Rendering | Commit |
|---|---|---|
| `unit` | `target_state = 1` on the candidate cards (existing). Cross-lane candidates use overview mode or edge panning (`hold.cross_lane`). | click or drop on a card |
| `combat_target` | Source card gets `target_state = 3`; candidates are highlighted; `0` is `_redirect_tower()` (existing redirect stage) | card or tower |
| `lane` | Board lanes highlighted (`lane_view.drop_state`, as in deployment); overview mode | click a lane (`board.lane_at`) |
| `position` | `lane.set_ghost_slots(positions)` in the lane from `lane_key` or `lane` | ghost slot |
| `improvement` | `improvement_chip.target_state = 1` (§8.4) | chip |

- A play with no steps keeps today's "drop on the board" behaviour.
- `HINT_*` keys are chosen per step type. New: `HINT_SELECT_LANE`, `HINT_SELECT_IMPROVEMENT`.
- The test hooks are kept: `select_card`, `target_unit`, `choose_position` and `choose_destination` now advance the current step if its type matches.
- New test hooks: `choose_lane(i)`, `choose_improvement(oid)`, `use_ability(id)` (generalized to item and improvement ids), `item_ability_point(uid, slot)`, `improvement_point(oid)`.

### 8.3 Ability buttons

- **Units:** the existing badge. It is drawn when `Library.has_active(card)`, and its cooldown comes from the model.
- **Items:** the slot icons in `unit_card._draw_slots` (`unit_card.gd:199`) become buttons when the item has an active. They show a ready glow, or a cooldown number, and `unit_card.item_rect(slot)` gives the hit area. A press on an own item icon calls `use_ability(item_oid)`; right-click inspects the item.
- **Improvements:** chips (§8.4) glow when ready.
- `use_ability(id)` acts immediately if the ability has no steps. Otherwise it starts a hold with `source = {"unit": id}`.

### 8.4 Improvement row by the towers

There is a new control, `scripts/ui/improvement_chip.gd`: a 44×44 medallion showing:
- the card art crop (`CardArt`), with a colour rim;
- a charges badge in the bottom-right corner;
- a cooldown overlay;
- `target_state` (0 none, 1 candidate, 2 hovered);
- a ready glow.

`lane_view.gd` gains `improvement_rows = [enemy_chips, own_chips]` and fills them in `sync()` from `lane.improvements`.
- In lane view, chips sit on each wall to the right of the tower, starting at `tower_center(own).x + TowerView.SIZE.x * 0.5 + 18`, 50 px apart. Up to 6 are shown, then a `+n` chip.
- In overview mode, the row collapses to a single count chip.
- Hover shows the card text, right-click inspects, and left-click on an own ready chip calls `use_ability(oid)`.
- Entering chips scale in. Removed chips fade out with a burst (`improvement_gone`).

`tower_view.gd` shows tower badges for derived `armor`, `retaliate` and `regeneration` next to its health plate.

### 8.5 Status and keyword icons

`unit_card._draw_badges` (`unit_card.gd:243`) draws from `model.badges` instead of `unit.silenced`, `unit.siege` and `temp_siege`.
- Up to 4 discs on the right edge, then `+n`.
- Order: statuses, then flags, then numeric keywords.

| Badge | Icon (existing `UiKit` icon or a glyph fallback) | Shown when |
|---|---|---|
| stun | dizzy stars / "暈" | `stun` |
| silence | `lock_closed` (existing) | `silence` |
| disarm | broken sword | `disarm` |
| damage_immunity | shield with star | `damage_immunity` |
| death_shield | ankh / "护" | `death_shield` |
| pierce | arrow | `pierce` |
| lethal | skull | `lethal*` |
| siege n | existing siege disc | `siege > 0` |
| cleave n | double axe | `cleave > 0` |
| retaliate n | spiked shield | `retaliate > 0` |
| regeneration n | green cross | `regeneration > 0` |
| bounty ±n | coin | `bounty` differs from its base |
| rapid / soulbound | glyph | flag |

Valve's own status set (`valve_card_effects.txt`: stunned, silenced, disarmed, invulnerability, deathshield, locked, numHacks) confirms this list.

### 8.6 Hand badges

`card_view.gd` gains a `badges` property. `hand_view.sync(hand, states, ...)` passes, per card, `states[i].badges` built from `view.players[viewer].hand_state[i]`:
- lock n
- charges n
- hacked (a "changed text" glyph)

`match_screen._card_states` adds a `reason` of `REASON_LOCKED` or `REASON_FORBIDDEN` (both new) when one of those gates fails. The enemy hand fan (`card_pile` / `enemy_hand`) draws lock numbers from `view.players[enemy].hand_public`.

### 8.7 Animations from events

`_apply_state` (`match_screen.gd:292`) keeps its structure (animations before the sync, the sync, then animations after it) with two changes:
1. The event list is split at each `lane_open`. Events after the last `lane_open` (the before-action triggers of the new lane) play after the camera has moved.
2. Events are dispatched to these handlers:

| Event | Animation |
|---|---|
| `trigger`, `ability` | Flash the source (unit card, item slot icon or improvement chip, found by uid or oid) and float the ability name (`Library.loc(card, "ability_name")` or the card name). `_anim_ability` stops assuming the source is a unit |
| `damage`, `tower_damage` | Red numbers per hit plus a `hit` burst (combat-style), or `tower` for towers |
| `heal` | Green numbers plus a `heal` burst |
| `status`, `mod` | Badge pop on the unit; green or red stat flash |
| `summon` | Card enters from the lane edge (the sync marks it as added; it uses `_animate_enter`) |
| `move`, `swap`, `control` | The sync's `moved` entries animate with `_animate_move`; for a cross-lane move, the camera follows |
| `condemn` | Purple mark, then the death animation at the sync |
| `improvement`, `improvement_gone` | Chip scales in, or fades out |
| `lock`, `hack`, `charged` | Hand card shake plus a badge pop (own hand) |
| `gold`, `mana` | `gold` burst near the player panel; mana number pulse on the tower |
| `pulse` | A 0.12 s beat that separates steps of one spell |
| `combat` | Uses `strikes` for lunges and numbers instead of the stale preview model. Cleave hits fan out; retaliation returns |

The hard-sync rule (`events.size() > 40`) now counts only animated keys and allows up to 60. Beyond that, the rest of the burst is applied instantly, so a large Wrath of Gold fast-forwards instead of snapping. `log_panel.set_events` formats every key.

### 8.8 Inspect, log and i18n

- **`inspect_overlay.refresh_text`** (`inspect_overlay.gd:81`) lists:
  - derived keywords and statuses, with their durations;
  - modifications with source names (`Library.loc(mod.src)`) and a "permanent" or "this round" tag;
  - granted text (`Library.loc(card, "grant_0")`);
  - item and improvement ability names and cooldowns.
- **Locale entries** in `data/locale/cards.json` gain `grants: [{en, zh_CN}]` for cards whose granted text must be displayed. The i18n test checks that placeholders match.
- **New `i18n/ui.csv` rows** (en and zh_CN): `EV_*` for the §6.5 keys, `REASON_LOCKED`, `REASON_FORBIDDEN`, `HINT_SELECT_LANE`, `HINT_SELECT_IMPROVEMENT`, `ERR_REPLAY_RULES`, and `BADGE_*` tooltips. The existing `i18n_test` checks that every key has both locales.

### 8.9 UI files touched

`match_screen.gd`, `board_view.gd`, `lane_view.gd`, `unit_card.gd`, `tower_view.gd`, `hand_view.gd`, `card_view.gd`, `card_pile.gd`, `inspect_overlay.gd`, `deployment_overlay.gd`, `log_panel.gd`, plus the new `improvement_chip.gd`, plus `event_text.gd` and `i18n/ui.csv`.

The deployment staging, reveal, shop and coin code is unchanged.

---

## 9. Bot integration (`scripts/ai/heuristic_bot.gd`)

1. **Kept unchanged:**
   - One-ply simulation on `simulation_from_view(player)`.
   - Synthetic randomness (`rng.seed = 1`).
   - No hidden information. The test "changing hidden opponent cards cannot influence bot choice" must also hold with `hand_state` and `deck_state`.
2. **Static values from compiled rules replace the special cases.** `Library.static_value(card_id)` returns:
   - `draw`: the sum of constant top-level `draw` ops for "you";
   - `initiative`: `play.initiative`;
   - `random`: whether any `pick` or `chance` is present;
   - `bias`: from `ai.bias`;
   - `gold` (M7): whether a `gold` op adds gold for "you" (Revtel Investments, Ravenhook, Payday); the bot adds `0.25` per gold the simulation gains, since the evaluation has no gold term. Spending gold (`set`) is not a gain.

   The bot uses `0.9 × min(draw, deck_count)` and `+0.35` for initiative, which are today's numbers (lines 50-59). In M1 these must equal today's values for every legacy card, so the goldens stay identical. For abilities, `abilities_of` plus the same static value replace `ability == draw`.
3. **Evaluation terms** are added in M2 and tuned with the bot-vs-bot matrix:
   - Per unit: `+0.3 × (cleave + retaliate + regeneration + siege)` and `+1.0 × damage_immunity`.
   - A stunned or disarmed unit contributes only 25% of its attack term.
   - Each improvement is worth `±2.0`, plus `0.5 × charges`. M7 tuned it to `±(2.0 + 0.25 × cost)`, plus `0.5 × charges`: with a flat 2.0 an improvement on the board was worth less than the card in hand plus the play penalty from cost 3 up, so the bot never played the dearer Classic improvements whose effect a one-ply simulation cannot see.
   - Each opponent card with a lock is worth `+0.3` (from `hand_public`).
   - `combat_preview.dies` and `heal` replace `damage >= health`.
4. **Prefilter.** With more than 60 candidates, the bot keeps `pass` and every ability, and up to 3 combinations per hand card. Combinations are ranked by a compile-time *polarity* score:
   - damage, condemn, stun, disarm and negative modifications on enemies are good;
   - heal, give and positive modifications on allies are good;
   - each is weighted by `attack_of + health` of the target.

   The bot simulates the best 40.
5. **Random cards** (`static_value.random`) are simulated with seeds 1, 2 and 3 and averaged, from M4.
6. **Deployment.** `_deployment_lane` treats a pending creep lane of `-1` as the lane where its Kanna is planned. Otherwise it is unchanged.
7. **Shop.** It reads `price_of` (Deed prices can be negative). `_should_hold` is unchanged.
8. **Tests:**
   - Existing bot matches.
   - `bot_purity`: the bot never mutates the live engine.
   - `bot_hidden_swap`.
   - `bot_budget`: a decision takes under 250 ms on the dense fixture.

---

## 10. Network, replays and privacy

### 10.1 Host authority (unchanged)

- The host runs the engine. The guest receives `player_view(1)` and `legal_actions(1)` in their current flat shape.
- `match_controller._online_command` keeps checking `command in engine.legal_actions(1)` for planning phases, and can switch to `Targeting.is_legal` for speed.
- The guest's `board_view.display_engine` derives stats from the view. Every input to stats is public: units, mods, items, improvements and deeds.

### 10.2 Content hash and versions

- `SteamBridge.compute_content_hash` hashes `CONTENT_FILES` plus `"protocol:%d"` (both unchanged), plus `"rules:%s" % RULES_VERSION` (new).
- Rules data is inside `data/classic_cards.json`, so `CONTENT_FILES` and the export `include_filter` (`data/*.json`) need no change.
- `RULES_VERSION` is the first 12 hex characters of a SHA-256 over every file in `scripts/core/rules/`, plus `match_engine.gd` and `card_library.gd`, with line endings normalized to LF.
  - `tools/rules_hash.py` writes it into `rules/rules_version.gd`.
  - `tests/rules_schema_test.gd` recomputes the hash from the source files (they are text in the editor and in headless test runs) and fails if the constant is stale.
  - Exported builds use `script_export_mode=2` (binary tokens), so the constant is the only reliable source at runtime.

### 10.3 Replays

- `replay_data()` is `{protocol: 7, rules: RULES_VERSION, content_pack, seed, decks, actions}`.
- `load_replay` rejects:
  - a different protocol (`replay_version`, as today);
  - a different `rules` value (`replay_rules`, new). This is deliberate: a rules change would otherwise make a replay diverge silently.
- The journal still holds commands only.

### 10.4 Privacy (`player_view(viewer)`)

| Data | Viewer's own | Opponent's |
|---|---|---|
| `hand` | visible | `[]` (existing) |
| `hand_state` | visible (`iid`, lock, charges, hacks, base) | `[]` |
| `hand_public` | `[{lock}]` | `[{lock}]` (locks show on card backs) |
| `deck`, `deck_state` | `[]` (counts only) | `[]` |
| `plans`, `shop`, `held_secret`, `bought` | visible | redacted (existing) |
| `deeds`, improvements, items, `mods` | visible | visible (public board) |
| event `_s` | merged for the viewer | stripped |
| `pending_creeps` | `-1` for Kanna's player, until the reveal | same |

Tests (§13.3):
- **Taint fuzz.** Each player's hidden card ids and `iid`s never appear in `JSON.stringify(player_view(other))`.
- **Hidden swap.** Replace the opponent's hidden hand and deck with other cards of equal count. `player_view(p)`, `legal_actions(p)` and the bot's choice stay identical.

### 10.5 Packet size

The largest `player_view` plus `legal_actions` packet measured in fuzzing must stay under 200 KB, against the 262,144-byte `MAX_PACKET_BYTES`. Modifier coalescing (§2.2) and the 400-event window keep views bounded.

### 10.6 Determinism checklist for contributors (lint plus tests)

1. Randomness only through `rand_index` and `chance`. No `randf`, `randi`, `shuffle`, `pick_random`, `Time` or `hash`.
2. No `for k in dict` where the iteration order would affect state. Iterate arrays in canonical order instead.
3. Every sort uses a total key.
4. No float arithmetic in the rules.
5. No instance members in the rules scripts.
6. No hidden ids in public event fields.

---

## 11. Migration of the 49 Classic cards and the 17 training cards

### 11.1 Field mapping

`tools/migrate_rules.py` performs this mapping and adds `"status": "verified"`. Numeric fields stay top-level as params, so locale `{placeholders}` keep filling.

**Targets** (the legacy `target` field becomes a choice's `from`):

| Legacy `target` | `from` |
|---|---|
| `unit` | `"units"`, or `{"s":"units","lane":"all"}` if `cross_lane` |
| `hero` | `"heroes"` |
| `creep` | `"creeps"` |
| `red_hero` | `{"s":"units","kind":"hero","color":"red"}` |
| `ally_hero` | `"allied_heroes"` |
| `ally_red_hero` | `{"s":"units","side":"ally","kind":"hero","color":"red"}` |
| `enemy_hero` | `"enemy_heroes"` |
| `ally` (training) | `"allies"` |
| `enemy` (training) | `"enemies"` |
| `none` | no choice; creeps get the implicit `position` |

**Effects:**

| Legacy `effect` (cards) | Schema 4 `play` |
|---|---|
| `damage` (+`piercing`) | `damage {to: $c.target, amount: {param: amount}, piercing}` |
| `area_damage` | `damage {to: enemies}`; with `include_tower`, also `tower_damage {to: enemy_tower}`, until FX-1 |
| `heal` | `heal {to: $c.target}` |
| `buff` | `give {to: $c.target, stats: {attack, armor}, until: round}` |
| `modify` | `modify {to: $c.target, stats}` (written through, as today) |
| `modify_creeps` | `modify {to: allied_creeps, stats}` |
| `silence` (+`neighbors`) | `give {to: [$c.target, allied_neighbors of target], keywords: {silence: 1}, until: round}` |
| `condemn` (+`discard_random`) | `discard {cards: {use: your_hand, pick: {random: 1}}}` then `condemn {to: $c.target}`. The random draw happens in the same place as today. |
| `condemn_lane` | `condemn {to: units}` (active lane, RQ-04) |
| `global_hero_damage` | `damage {to: {s: units, side: enemy, kind: hero, lane: all}, piercing}` |
| `siege_buff` | §5.1 Forward Charge |
| `return_hero` | `to_fountain {unit: $c.target}` |
| `battle_neighbors` | `battle {a: $c.target, b: {s: units, rel: {enemy_neighbors: $c.target}}}` |
| `redirect` | choices `target` + `destination` (`combat_target_of`); `retarget {unit: $c.target, to: $c.destination}` |
| `summon` | `summon {card: melee_creep, count: {param: amount}}`. Each copy calls `_make_creep`, `_spawn` and `_roll_arrow` in the same order as today. |
| `mana` | `give {to: your_tower, stats: {mana: {param: amount}}, until: round}` |
| `draw` | `draw {player: you, n: {param: amount}}` |
| `tower_damage` | `tower_damage {to: enemy_tower}` |
| `equip` | Item card: drop `effect` and `target`. The implicit equipment choice and the host aura from `attack`/`armor`/`health` replace them. |
| `initiative` (training) | `play: {initiative: true, ops: []}` |
| `initiative: true` (any card) | `play.initiative: true` |

**Hero and creep fields:**

| Legacy field | Schema 4 ability |
|---|---|
| `neighbor_armor`, `neighbor_attack` | `aura {affects: allied_neighbors, grant: {armor or attack: {param}}}` |
| `global_attack` | §5.1 Drow |
| `hero_bonus`, `hero_tower_bonus` | `keywords {bonus_hero: {param}}`; Debbi gets `bonus_hero` and `bonus_tower` from `hero_tower_bonus` |
| `static_field` | §5.1 Zeus |
| `combat_growth_*` | §5.1 Savage Wolf |
| `rapid_deployment` | `keywords {rapid_deployment: 1}` |
| `siege` (units) | `keywords {siege: {param: siege}}`; the top-level `siege` stays for the `{siege}` placeholder |
| `ability: draw`, `ability_cooldown` | `active {id: wisdom_of_the_elders, valve: 4009, cooldown: 4, ops: [draw you 1]}`; the top-level `ability_cooldown` stays for its placeholder |

Other changes:
- `melee_creep` gets `token: true`.
- `centaur_hunter` stays a deck creep (RQ-48).
- Each entry gains `valve_text` (Valve's English text, used only by the review and text-drift tests).

### 11.2 Behaviour-preserving order (details in §12, M1)

1. **Record the goldens** (M1.0).
2. **Refactor into static modules with byte-identical digests** (M1.1).
3. **Rules kernel and state v7 with dual data.**
   - The converted rules sit next to the legacy fields.
   - A debug flag `e.legacy_effects` runs the old switch for the differential test.
   - The projection goldens must stay identical.
   - Done in M1.2.
4. **Data cutover:** legacy fields and the switch are deleted (M1.3).
5. **UI adaptation** (M1.4).
6. **Deliberate fidelity fixes, one commit each** (M1.5):

| Fix | Change | Expected test change |
|---|---|---|
| **FX-1 (RQ-01)** | Tower Barrage and Thunderstorm lose their tower damage, and their locale text changes | `classic_cards_test.gd:210` expects the tower at 40 |
| **FX-2 (RQ-19)** | The tower is a legal combat target only when the position directly across is empty | `classic_cards_test.gd:171-176` opens the position directly across instead |
| **FX-3 (RQ-15)** | Group damage is computed simultaneously, and the auras of lethally damaged units last until the Pulse | — |

Every FX commit re-baselines the goldens, updates `docs/RULES.md`, and adds its named RQ test.

### 11.3 Every expected edit to existing tests

| Test | Edit | When |
|---|---|---|
| `expanded_classic_test.gd:172` | `pa.temp_siege == 2` becomes `engine.keyword_of(pa, "siege") == 2`. A legacy `keyword_of` returning `siege + temp_siege` is added first, so the edit is checked against today's engine. | M1.0 |
| `run_tests.gd` (around line 297) | `int(replay.protocol) == 6` becomes `7` | M1.2 |
| `run_tests.gd` (around line 663) | `PROTOCOL_VERSION == 6 and BridgeClass.PROTOCOL == 7` becomes `7 and 8` | M1.2 |
| `run_tests._test_event_formatter_keys` | Samples for each new event key | M1.4 |
| `classic_cards_test.gd:210` | Tower Barrage leaves the tower at 40 | FX-1 |
| `classic_cards_test.gd:171-176` | The fixture opens the position directly across | FX-2 |

Everything else stays green unchanged:
- `wolf.attack` and `wolf.max_health`, through write-through.
- `hero.temp_attack` and `hero.silenced`, through the shim and the mirrors.
- `max_mana` for Stars Align, through write-through mana.
- `hero.cooldown`, the same field.
- Every `attack_of` / `armor_of` assertion.

---

## 12. Implementation plan

Each milestone ends with every suite green: `run_tests`, `classic_cards_test`, `expanded_classic_test`, `i18n_test`, `steam_test`, `ui_smoke`, plus the new suites. Each milestone also checks:
- the determinism and privacy invariants after every fuzz step;
- the performance budgets (§13.6);
- a view-plus-actions packet under 200 KB.

### M1. Kernel and migration (49 Classic + 17 training cards; no new content)

| Step | Work | Acceptance |
|---|---|---|
| **M1.0 Baseline** | Write the golden recorder `tools/record_goldens.gd` (game definitions in `tests/golden/golden_games.gd`, checker `tests/golden_test.gd`). It plays 54 games: the 24 training seeds of `run_tests`, the 12 Classic seeds of `classic_cards_test`, and the 18 `_matchup_matrix` games. After every action it stores (a) `state_digest()` and (b) a model-independent projection, in `tests/data/goldens/{training,classic,matchups}.json`. Add `tests/invariants.gd` (moved from `_board_invariants` and `_aligned`) and the legacy `keyword_of`. Make the `expanded_classic_test.gd:172` edit. | All suites green. Recording twice gives identical files. |
| **M1.1 Static modules (pure refactor)** | Move `_damage_unit`, `_damage_structure`, `_clean_dead`, `_place`, `_spawn`, `_compact`, `_release_attackers`, `_roll_arrow(s)`, `_draw`, `_shuffle`, `combat_preview`, `_battle_neighbors` and `attack_of`/`armor_of` into `rules/kernel.gd`, `zones.gd`, `combat.gd` and `stats.gd`. Each is a static function taking `e`, and the engine keeps same-name wrappers. No new state. | **Byte-identical `state_digest` after every action of all 54 goldens.** Lint: no instance members in `rules/*.gd`. |
| **M1.2 Rules kernel and state v7** | Add `vocab`, `rules_db` (compile and validate), `vm`, `select`, `stats` (derive, settle), `kernel` (emit, Pulse, batches, deaths, snapshots, `lane_open`, `end_of_round`, `rand_*`), `combat` (strikes), `zones` (hand and deck state, iids, item instances, improvements, deeds) and `targeting` (combos, `is_legal`, steps). Add the new state fields (§2). Bump `PROTOCOL_VERSION` to 7 and Steam to 8, and add `RULES_VERSION` to the hash and replays. `tools/migrate_rules.py` writes schema-4 rules **next to** the legacy fields. The VM runs the rules; `e.legacy_effects = true` runs the old switch. | Projection goldens identical for all 54 games: same bot choices, same randomness, same legacy event-key subsequence. `tests/differential_test.gd`: for each of the 66 definitions, 200 seeded fixtures give equal projections under the legacy switch and the VM. `rules_schema_test`: 0 errors and a current `RULES_VERSION`. `targeting_equivalence` over 10,000 commands. Purity of `legal_actions`, `combat_preview`, `player_view`, `choice_steps` and the `*_of` helpers (digest and `rng.state` unchanged). Privacy taint and hidden swap. Replay round trips. Perf budgets recorded. |
| **M1.3 Data cutover** | Remove the legacy fields from both packs and from `_make_unit`. Delete the effect switch, `_static_field`, the wolf loop and `e.legacy_effects`. `classic_cards.json` moves to schema 4 and `training_cards.json` to schema 2. Add `valve_text`. | Projection goldens identical. `i18n_test` green: every placeholder fills from params. |
| **M1.4 UI adaptation** | Board models (§8.1); unit_card badges from models; `Library.has_active` / `has_passive`; inspect lines; `deployment_overlay` `max_health_of`; `_reason` through `can_cast_colour` plus `REASON_LOCKED` / `REASON_FORBIDDEN`; formatters, `i18n/ui.csv` rows and formatter samples for the §6.5 keys; animated-event threshold. | `ui_smoke` green, including the ability badge click at `ui_smoke.gd:347-356`. `capture_preview` screenshots reviewed (only the badge layout changes). `i18n_test` green. |
| **M1.5 Fidelity fixes** | FX-1, FX-2 and FX-3 as separate commits (§11.2). Rewrite `docs/RULES.md` rows (Triggers, Combat, Extra effects) and add `docs/EFFECTS.md` (the contributor guide: §3 in brief, the §5 patterns, Appendix B). Commit `tools/mechanics.py` (the inventory generator, now in the scratchpad), its trimmed output `tests/data/mechanics_tags.json` (per card: Valve text, clauses, trigger/verb/target/duration tags), and `tools/new_card.py`. | Only the listed assertions change. New tests `rq_01_each_enemy_excludes_tower`, `rq_19_tower_needs_empty_across` and `fx3_aura_persists_until_pulse` pass. Goldens re-recorded in each commit. |

#### M1 as built: deviations from this plan

- The goldens live where §13.5 says (not `tests/golden/record.gd` and `legacy.json`).
- The differential test runs against a frozen copy of the pre-migration engine and data in `tests/legacy/` instead of an `e.legacy_effects` switch. The copy receives FX-1 to FX-3 too, so it stays a valid reference.
- `RULES_VERSION` also hashes both data packs, because the rules live in the card entries.
- The event for drawn cards is `draw_cards` (`draw` already names the match-draw result). The `ability` event comes before the ability's ops, so the log reads "X uses Y" before the effects. Death Shield consumption logs a `shield` event, and several events carry the card id as `card`.
- Read frames (`Stats.frame_begin`/`frame_end`) cache derived stats during pure reads (`combat_preview`, the bot evaluation, board models), so every per-call budget of §13.6 is met (K15). The full bot match is not under the original 3 s: it takes about 3.1 to 3.4 s, 1.2 to 1.3× the pre-M1 engine (which alone needs 2.6 to 2.8 s), so §13.6 now states that budget as ≤ 1.5× the legacy engine, a failing check in `tests/perf_test.gd`.
- Invariants: `tests/invariants.gd` splits §13.3 into `violations` (I1 to I10, every step), `write_through` (I11) and `deep_violations` (I12 privacy, I13 purity, I14 action and packet bounds). The golden gate runs the first two after every command and the third after every tenth; `rules_kernel_test` runs all of them in its bot games and in a random-agent fuzz (6 seeds on both packs, forged commands, the hidden swap for both viewers in every phase, replay round trips). The 50/2,000-seed `tests/fuzz_test.gd` of §13.4 is M2.
- A forced tower target (Battlefield Control) ends when a unit enters the position directly across, which then blocks the unit (RQ-19, `Zones.place`); before, the unit stayed unblocked with a blocker across. It changed one golden game (starter_vs_blue_black_control_73 from step 232; same length and winner).
- The validator also requires the op fields the VM reads (`Vocab.OP_REQUIRED`), unit `attack`/`health`, and pack links (summoned units, signatures; `CardLibrary._check_links`), and warns on parameters nothing reads. A shipped card is `verified` or a `draft` with an RQ.
- Deferred to M2 with the per-card spec runner: §13.7 meta tests 5 to 7 (every verified card has a spec, spec `text` = `valve_text`, `covers` ⊇ tags) and `tools/coverage.py`. Item 10's Valve parity runs in `rules_schema_test` (`_valve_parity`: cooldowns, charges, Pulse markers, Get initiative, randomness) except its last bullet (verb and trigger tags mapped to ops), which needs the coverage table.
- The `temp_attack`/`temp_armor`/`temp_siege` shim and the legacy-schema warning path (`legacy_ok`) are removed.
- `Kernel.lane_open(e, lane)` has no flag; filters are evaluated directly instead of being compiled into `where`; `CardLibrary.with_cards(pack, entries)` builds test libraries with fixture cards.
- `player_view(player, with_events = true)`: simulations are built without the event history, and the bot evaluates the simulation's own state (already the player's view) instead of copying it again.
- The Pulse loops again after a removal even when nothing is queued, so a unit killed by losing an aura at that removal dies in the same Pulse (needed by FX-3, RQ-40). It changes no golden.
- `tools/mechanics.py` reads Valve's final set files (`.tools/valve_set0X_final.json`) and ranks ties deterministically, so `MECHANICS.md` changed only in the order of tied counts.

### M2. Keywords, statuses, durations, zones and UI infrastructure

This milestone builds and tests every generic mechanic before any new card ships. It uses a test-only pack, `tests/fixtures/rules_fixtures.json`, loaded with `CardLibrary.from_file(path, "rules_fixtures")`. That pack is never in presets or `PACKS` and is excluded from exports. It holds synthetic cards such as `fx_cleave_3`, `fx_retaliate_2`, `fx_regen_2`, `fx_lethal_item`, `fx_shield_spell`, `fx_soulbound_creep`, `fx_lock_spell`, `fx_hack_spell`, `fx_move_any`, `fx_swap`, `fx_control`, `fx_improvement_ping` and `fx_deed`.

**Engine work:**
- **Combat strikes:** siege with tower armor; cleave; retaliate (units and towers); regeneration (units and towers); pierce; lethal.
- **Statuses and keywords:** damage immunity, death shield, stun/silence/disarm, soulbound closure, bounty, generic rapid deployment, tower armor/mana/retaliate/regeneration.
- **Durations:** `next_combat`, `death`, `equip`, `used`.
- **Effect ops:** Purge with provenance; Fountain rules.
- **Hand state:** lock with round decay, discard, `add_card`, `card_counter`, hacks.
- **Zone ops:** summon (a summoned hero joins its owner's roster, `roster: true`, RQ-29), move, swap, control, `to_fountain`.
- **Objects:** the improvements zone and its cap; item instances with triggers, actives and charges; deeds.
- **Rules layer:** `round_draw`, `forbid_play`, `secret_shop_discount`, `creep_lane`.
- **Preview:** `combat_preview` with `heal`, `dies` and `strikes`.

**UI work:** status and keyword icons (§8.5); the generic target stepper (§8.2); item and improvement ability buttons (§8.3); the improvement row (§8.4); hand badges (§8.6); event animations (§8.7); inspect lines (§8.8).

**Bot work:** the evaluation terms, the prefilter and static values (§9).

**Acceptance:**
- **Keyword matrix.** At least 3 cases per keyword, including these interactions:
  - Retaliate against a stunned defender, and against a disarmed attacker that does not attack.
  - Regeneration saving a unit at 0 health.
  - Cleave with Pierce.
  - Siege against tower armor.
  - Lethal against immunity and against a shield.
  - A shield against condemn.
  - Soulbound with a shield (RQ-39).
  - Purge provenance: a modification by the caster stays.
  - The Fountain keeping `modify` and clearing `give`.
  - Lock decay.
  - `next_combat` expiring in the unit's own lane only, and following a move to another lane.
  - `until equip`.
- **`preview_equals_combat`.** On 2,000 random fixture boards, `combat_preview` (damage, heal, dies, tower damage) equals what `Combat.resolve` then does.
- **Zone invariants after summon, move, swap and control:** rows aligned, arrows consistent, no stale forced target, each roster hero in exactly one place.
- **Privacy:** hacks, card counters, locks and deck charges stay hidden in fuzzing; hidden swap holds.
- **UI** (`ui_smoke` additions):
  - a lane-then-position stepper (`fx_move_any`);
  - an improvement choice;
  - an item ability click;
  - an improvement chip click;
  - status icons present;
  - a lock badge on an own card and on an enemy card back.
- **Fuzz:** 50 seeds over the fixture pack, with no `rules_overflow`.
- **Perf budgets met.**

#### M2 as built: deviations from this plan

Where the acceptance lives: the keyword matrix, durations, Purge, the Fountain, hand state, hacks, zones, objects, the rules layer, the RQ cases and `preview_equals_combat` (2,000 boards) are in `tests/mechanics_test.gd`; zone invariants after summon, move, swap and control are also fuzzed there; privacy (hacks, counters, locks, deck charges, the hidden swap) is in `tests/fuzz_test.gd` (50 seeds by default, `--nightly` for 2,000); the bot in `tests/bot_test.gd`; the per-card runner in `tests/card_specs_test.gd` with the 49 specs in `tests/cards/`; meta tests 5 to 7 and the coverage gate in `tests/rules_schema_test.gd`; the UI additions in `tests/ui_smoke.gd`. Deviations:

- **Bot.** The prefilter starts above 100 candidates, not 60, and keeps `pass`, every ability and the best 3 combinations per hand card up to 40: at 60 it changed the bot's choices in three golden games (the most legal actions in any golden step is 81). Siege is left out of the `0.3 ×` keyword term: siege already counts through the preview's tower damage, and the term changed two golden games. `bot_budget` runs on the M2 fixture dense board (3 lanes × 8 positions, 6 items, 16 improvements per side, a 10-card hand) and is normalized by the machine's speed (the legacy full match divided by `perf_baseline.json`'s).
- **Preview.** `heal` is what regeneration actually restores after the combat's damage (up to the maximum), and `dies` includes the lane-local Soulbound closure (shields still save), so it equals what `Combat.resolve` does.
- **Hacks** run after the played card's ops and their Pulse, each as a `trigger` event with ability `hack` (empty `src`), with `$self` the played card (`{card, state}`), then a Pulse, before `card_played`.
- **Zones.** A move to a position taken in the meantime fizzles; control of a roster hero fizzles; locks apply only to cards in hand; `add_card` with an unknown id fizzles; lane creeps that follow a hero go to lane 0 when no such hero is found at the reveal. The `swap` event also carries `card`, `other`, `p` and `lane`.
- **Packs.** `CardLibrary.from_file` registers a test pack by id (`known_pack`, `open`); `load_replay` keeps the current library when the replay's pack matches it. Fixture cards are `verified`, so random fuzz decks validate. Test packs carry granted text inline in a `grant_text` card field (the Classic pack uses locale `grants`).
- **Tests.** Fuzz failures are saved under `res://.tools/fuzz_failures/`, not `user://`. Meta tests 5 to 7 cover the Classic pack (training cards have no `valve_text`) and live in `rules_schema_test`; `tests/data/coverage.json` records the SHA-256 of `tools/coverage.py`, and the schema test fails when the table is stale.
- **Speed.** Listener contexts are built only for units that listen or carry granted abilities, aura scans skip zones that cannot hold a wanted aura (`CardLibrary.aura_holders`), settle derives only tower mana, and the combat plan maps victims by uid.
- **Review fixes (after the M2 review).** `next_combat` entries given while their own lane's combat resolves (a death or battle-damage trigger in its Pulse) carry that combat's `combat_seq` and outlast it, ending with the lane's next combat. The `attackers` relation and death snapshots skip stunned and disarmed attackers (`Stats.flag`). Soulbound closes only from units that actually die (the order above; `Combat.plan` matches). Discard and card counters find hand handles by `iid`. The bot scores the locks its own plays add from a compiled static value (`static.lock`: random opponent hand cards a play locks), up to the opponent's unlocked cards (public), because its simulation has no opponent hand.
- **UI.** Improvement chips start 26 px right of the tower (not 18) to clear the pending-damage tag; while the stepper asks for an improvement, every chip shows, compressed into the usual six-chip span so the row stays clear of the coin. Book marks and charges badges are drawn in a pass above every chip, and the hovered chip is drawn in front, so an overlapping row never hides them. Hovering or clicking a "+n" chip opens its lane's rows the same way (they close when the pointer leaves them or a press lands elsewhere; a press on the "+n" spot right after a hover opened the rows only opens them), and "+n" glows while an own chip it hides can be used. A cooling chip without art darkens its letter almost fully under the number. In a lane step the hint sits in the band below the lane panels. A hand card's note (reason and marks; a lock mark replaces the "Locked" reason) shows in a panel beside the lifted card, level with its art, instead of a cursor tooltip; lock, charges and cooldown strings have singular forms (`*_ONE`). A lane step opens the overview and closes it again. Ability holds start in click mode. Tower badges sit under the health plate; hand badges run down the card's left edge (the visible spine of the fan). Inspect adds a statuses line and one line per badge explaining it (`BADGE_*`), and hand tooltips explain their marks. The hard sync now happens only when events rolled out of the window; a longer burst animates its first 60 animated events and applies the rest at once. Your own hero-following lane creeps are staged in that hero's lane during deployment; the opponent's stay hidden until the reveal.

### M3 to M7. Card batches

Each card lands in the milestone where all its mechanics exist. The lists are in Appendix A. Within a milestone, cards land in sub-batches by complexity: data-only cards first, then complexity 2, then 3, then 4 and 5.

**What each card needs:**
- the schema-4 entry with `status: "verified"` (or `draft` with a named RQ);
- locale entries for both skins in en and zh_CN, generated from `catalog_mapping.json` by `tools/new_card.py` and reviewed;
- a spec (§13.1) that passes the coverage gate.

**Acceptance for every content milestone:**
1. Every card in the batch is `verified`, or `draft` with an RQ.
2. Each spec has at least one positive and one negative or edge case per Valve clause. RQ cases are named `rq_XX_*`. Random effects have an `expect_rate` over 200 or more seeds. Hidden effects have `expect_private`.
3. Meta tests pass:
   - spec `text` equals `valve_text`;
   - spec `covers` includes every trigger, verb, target and duration tag from `tests/data/mechanics_tags.json`;
   - locale placeholders fill;
   - a listener exists for every trigger the card uses.
4. Fuzz: 50 CI seeds and 2,000 nightly seeds with random legal decks from all verified cards, bot against a random agent. Invariants hold every step. Every match ends with a replay round trip and equal digests. No `rules_overflow`.
5. At least one new preset per milestone (5 heroes, 40 cards, 9 items) passes `validate_preset`, and bot-vs-bot matches with it terminate within 1,500 steps for 6 seeds. The bot-vs-bot matrix is extended.
6. Perf budgets hold with the batch in decks, and the network packet stays under 200 KB.

**Specific acceptance tests per milestone:**

| Milestone | Cards | Specific acceptance tests |
|---|---|---|
| **M3 Red and Green** | 92 | Retaliate in Duel and Berserker's Call; Routed in the Fountain (RQ-28); Enough Magic! (RQ-20); Caught Unprepared across rounds and in the Fountain (RQ-35); Chen's control and bounty; Tidehunter's distribution; Heroic Resolve and Rising Anger seeing their own play (RQ-44); Primal Roar's random-lane moves, one independent lane roll per neighbor (CF-1; randomness reproduced in replay); Aphotic Shield and Cleansing Rite provenance; Viper Strike until death; Dark Seer's two-step lane choice in the UI; the Spring the Trap token (RQ-48 decision recorded) |
| **M4 Blue** | 44 | Luna/Eclipse: hidden charges in hand and deck, the hidden swap, an untouched and a base-copied Eclipse each repeating exactly once (CF-2); Lost in Time and Buying Time distinct picks (RQ-14); Self Sabotage hack privacy and resolution order; Kanna `-1` lanes, then her lane at reveal (RQ-22); Meepo Soulbound and Divided We Stand `roster: true`, the summoned Meepo returning to the Fountain (RQ-29); Ogre Magi base copies (RQ-36); Wrath of Gold op budget; Mystic Flare rounding (RQ-28); Venomancer summoning at deployment (RQ-23) and in round 1 (RQ-49, CF-7); Prellex likewise |
| **M5 Black** | 39 | Chain Frost (RQ-16 pinned, stays `draft` until a reference match); Gank across lanes; Relentless Pursuit; Storm Spirit any-lane and `next_combat`; Lich and Ravenous Mass reading values before condemn; Assassin's Shadow scope (RQ-04) and self-count (RQ-50); Payday and Lodestone Demolition arithmetic; Winter Wyvern and Ball Lightning positions (RQ-42), including a same-lane move to each end and to an inner empty slot whose old slot compacts away (CF-1); Rebel Instigator copying after a Friendly Fire battle (CF-4); Bounty Hunter's chance |
| **M6 Items** | 40 | Ability buttons on item icons; Book of the Dead; Golden Ticket privacy; Shop Deed with negative prices (RQ-26, RQ-41); Claszureme Hourglass timing and privacy (round draw before placement, RQ-51); Apotheosis Blade Lethal against immunity and shield; Phase Boots arrows (RQ-30); Blink Dagger and Nyctasha's Guard moves (one roll per enemy neighbor, CF-1); Ravenhook's gold equal to the condemned item's price (CF-3); Jasper Daggers Equip Effect purge; Stonehall granted stacking; Secret Shop and consumable pools updated in `classic_cards.json` |
| **M7 Improvements** | 39 | The 16 cap (RQ-47); The Tyler Estate with Tyler Estate Censor and Mana Drain below 0 maximum mana, then each removed in turn (CF-5); The Oath's forbid with `REASON_FORBIDDEN`; Howling Mind's symmetric draw; Glyph of Confusion stunning deployment entrants (RQ-21); Watchtower on enemy improvements; Bitter Enemies (RQ-27 closed by Valve data, CF-8); Trebuchets' piercing damage against Steel Reinforcement's armor; Path of the X lane scope (RQ-03); Unearthed Secrets' round log; Revtel Investments condemning itself; Unsupervised Artillery and Cheating Death `requires` |

#### M3 as built: deviations from this plan

- **Cards.** All 92 M3 cards ship, each with its spec in `tests/cards/`; all are `verified` except Enough Magic! (`draft`, RQ-20, §5.27). Three M7 improvements ship early as heroes' signatures: Steel Reinforcement (Mazzie), Nether Ward (Pugna) and Verdant Refuge (Enchantress). Without them those heroes could never fill a deck (`validate_preset` needs three copies of a pack card as each hero's signature). All improvements are Cross Lane (glossary), so the implicit any-lane choice of §3.2 is right for them. Card `text` fields of the new cards are Valve's text with `{placeholders}` (as `tools/new_card.py` writes it), not the paraphrases of the 49 migrated cards.
- **RQ-48 decided.** Centaur Hunter is a token (Valve's data). Green Assault plays three Satyr Duelists instead, so the 10 matchup goldens that use it were re-recorded (`starter_vs_green_assault_*`, `green_assault_vs_*`, `blue_black_control_vs_green_assault_*`); the other 44 golden games are byte-identical.
- **Engine.**
  - Death snapshots record `blocking`, every enemy aimed at the dead unit, stunned or disarmed ones included; `was: blocker` reads it (§3.8, §4.3). It read `attackers`, which leaves those out since the M2 review (RQ-05), so a stunned or disarmed Bristleback or Stonehall Elite missed its trigger.
  - RQ-54: a `modify` on the look-back snapshot of a roster hero reaches the hero in the Fountain (`MODIFY_REACHES_DEAD_HEROES`), as heroes keep modifications through death (Viper, Ursa, Hellbear Crippler, Loyal Beast).
  - `mod` and `status` events of a grant carry `ab` (`"<card>#<index>"`), and `EventText` quotes the granted text (`EV_CHANGE_GRANT`); the log read "gives X none".
  - `validate_preset` rejects a hero without a signature card in the pack instead of crashing; the fuzz deck builder skips such heroes.
  - No golden changed with these, and none changed with the new cards themselves.
- **Bot.** The compile-time polarity (§9.4) estimates expressions (`neg`, `half`, `add`, `sub`, `mul`, `min`, `max`; a board read counts as positive), so Rend Armor, Routed and Steal Strength read as harmful whatever their encoding, and judges granted text by what it does for its bearer (Viper Strike harms; Soul of Spring, Defend the Weak, Heroic Resolve and Allseeing One's Favor help).
- **Spec runner (§13.1).** `as` on a play step, `deploy` on `end_round`, the `units.<lane>.<p>[.<card>]` count, and the `gd` escape (`check(engine, labels)` returns failure messages).
- **Presets (acceptance 5).** Five presets, one per colour pair with red or green: Sun–Liu Alliance (red/green), Northern Expedition (red/blue), A Gathering of Champions (red/black), Standoff at Ruxu (green/blue) and The Little Conqueror (green/black). Each has 5 heroes, 40 main cards and 9 items, and holds signature cards only with their heroes. `expanded_classic_test` plays each for 6 seeds against every preset in turn (each ends within 1,500 steps and round-trips through a replay); the golden matrix stays the original three presets.
- **Tests.** `expanded_classic_test` counts 28 heroes, 116 cards and 8 presets; `differential_test` compares only the migrated definitions, with board creeps, equipment and hands from the frozen legacy pack and decks from presets both packs define identically; `mechanics_test` adds two fixtures (`fx_grudge_creep`, `fx_corrode_creep`) for the engine changes; `ui_smoke` checks Dark Seer's unit-then-lane ability and the catalog (every definition, colour filters).
- **UI.** The catalog lists heroes first, then cards by colour, kind and cost, with colour (faction) filters. New cards without Three Kingdoms art show the generated placeholder.
- **Fonts.** The subsets were rebuilt (`tools/build_fonts.py`) for the characters the new names use.

#### M4 as built: deviations from this plan

- **Cards.** All 44 M4 cards ship, each with its spec in `tests/cards/` (spec helpers for deployment summons, round-1 summons, summon permanence, Kanna's lanes and privacy, and Self Sabotage's order and privacy in `tests/cards/extra/`). Two M7 improvements ship early as heroes' signatures, as in M3: Barracks (Prellex) and Ignite (Ogre Magi). The pack has 38 heroes and 152 other definitions. All are `verified` except Kanna (`draft`, RQ-22, §5.18) and, from M3, Enough Magic! (RQ-20).
- **RQ-29 decided the other way (medium confidence).** §5.15's default removed a dead summoned Meepo from the game. The Valve glossary says of every hero that "when it is killed, it ... returns to the Fountain to be redeployed later", and nothing exempts summoned ones, so `Zones.summon` now adds a summoned hero to its owner's roster (`SUMMONED_HEROES_JOIN_ROSTER` in `kernel.gd`; false restores the old default). It then pays hero bounty, goes to the Fountain, keeps its items and Modify effects, is offered for deployment when ready and cannot change sides. Meepo and Divided We Stand are `verified`. Tests: `rq_29_summoned_hero` and `rq_29_returns_1` to `_4` (mechanics test) and the two `rq_29_*` cases of the Divided We Stand spec.
- **RQ-44 widened.** Incarnation of Selemene's "after you play any card" sees its own play (it is in its lane when `card_played` is emitted), so playing her refills the mana she cost; no Valve source either way (medium-low confidence). Flipping it would need a `card_played` filter that excludes the source itself.
- **Other rulings pinned by the specs.** RQ-14 random lock picks are distinct cards (`rq_14_distinct_picks`); Mystic Flare's 12 always divides evenly among its one to three targets, so RQ-28 rounding never applies to the printed card; Bolt of Damocles and Arcane Assault do not overflow into an ancient; Rolling Storm can fell both players' second towers at once (a draw); Meepo's Poof never offers his own lane; a creep's active (Satyr Magician) can be used the round it is played. Wrath of Gold stops after about 1,000 repetitions at the 2,048-op command budget with `rules_overflow` (Valve has no cap; a 600-gold case resolves fully).
- **Bot (§9).** §9.5 is implemented: a play of a random card (`static.random`) or an ability with random ops (`ability_static.random`) is simulated with seeds 1, 2 and 3 and its scores averaged; equal scores keep the seed-1 value exactly, so the deterministic outcome of Coup de Grace's random discard keeps every golden choice. Averaging every random combination took the dense fixture from about 195 to over 300 ms normalized, past the §13.6 budget, so `choose_action` averages only the random candidates among the three best by seed-1 score (`RANDOM_REFINE`, the contenders); the others keep their seed-1 score. Two exact savings keep it near 205 ms: a pass is no longer simulated (its score never read the simulation), and a candidate whose seed-1 simulation drew no randomness (a pick from the hidden, empty opponent hand) is not re-simulated. Static values gain `hack` and `hack_damage` (Self Sabotage: each hacked opponent card is worth its tower damage at the structure-health weight, up to the opponent's public hand size) and `mana` (a restore of the caster's tower, worth 0.12 per point the dearest unlocked card in hand still needs; Satyr Magician's active).
- **Compiler.** A selector's `card` must be an id or a list of ids, so `Select`'s membership test can never become a substring test.
- **UI.** `Targeting.steps` marks the second choice of an `after` pair with `pair`, and the target stepper takes the two units of such an unordered pair in either order (Friendly Fire: the rightmost enemy can be clicked first; the command sent is the canonical legal one). A hacked card's hand note quotes the text the hack added (`EV_CHANGE_GRANT`); only the holder sees hacks. A card's note no longer reaches under the initiative coin (`hand_view.note_right`): beside a card at the right of the fan it goes left, as a longer note already did.
- **Spec runner (§13.1).** `as` names the first unit a play summons when it puts no creep of its own into a lane; `fountain.<p>[.<card>]` counts roster heroes out of the lanes; `p<i>.hand.<i>` reads a card id and `p<i>.hand.<card>` counts its copies (...And One For Me's spec adds a per-item rate over 300 seeds to its two fixed-seed cases); a `hand_state` read past the end is `null` instead of a script error; `begin_deployment`, `plan` (real deploy commands) and `reveal` run a deployment phase step by step; `expect_rate` counts an empty list or string as false.
- **Tools.** `tools/new_card.py` writes an active's literal cooldown as the `ability_cooldown` parameter (M3's convention), gives a hero every Valve ability in its text (Meepo's Poof and United We Fall), keeps only the first ability name of a mapping entry ("Lightning March (active 2); One Root (passive)"), and never turns a per-charge rate ("每有1能量") into a placeholder.
- **Presets (acceptance 5).** Three presets on the blue cards: Bronze Sparrow Terrace (blue: Luna, Crystal Maiden, Ogre Magi, J'Muy, Zeus), Siege of Xiapi (blue/black: Phantom Assassin, Outworld Devourer, Earthshaker, Debbi, Prellex) and Struggle for Longxi (blue/red: Venomancer, Centaur Warrunner, Meepo, Skywrath Mage, Ursa); between them they play every deckable M4 card except Kanna's signature. In 132 bot games against every preset (2 seeds, both seats), Siege of Xiapi won 23 of 44, Struggle for Longxi 20 and Bronze Sparrow Terrace 13 (its first, spell-heavy list won 7, so it gained Relentless Zombies, Tower Barrage and Thunderstorm; the one-ply bot plays control poorly); no game took more than 364 steps. `expanded_classic_test` counts 38 heroes, 152 cards and 11 presets and plays each new preset for 6 seeds against every preset in turn (the M3 presets keep their 8-preset opponent pool). The golden matrix stays the original three presets, and no golden changed.
- **Fonts.** The subsets were rebuilt for the new names (壑, 殁, 锢 among them).
- **Review fixes: chosen combat targets are arrows like any other.** The M4 review found two places where a chosen target (Battlefield Control, New Orders, Pick a Fight, Compel, a taunt from Ventriloquy) did not follow the wiki Pathing rules that rolled arrows follow. (1) `Zones.swap` (Cunning Plan, Juke, Rebel Decoy, later Phase Boots) swapped the arrows but left the chosen target on the unit, so the arrow followed the unit. Now the forced target swaps with the arrow (RQ-30: "the arrows for the current position will remain"), and an enemy whose forced target was one of the two keeps its arrow and now attacks the unit in that position. (2) `Zones.place` reset only a rolled diagonal arrow and a forced tower target when a unit entered the position directly across. It now resets a chosen diagonal unit target too ("placing an allied unit in front of an enemy unit that is currently attacking a target to its left or right will reset the target"), which extends the FX-2 placement rule to forced unit targets and replaces the earlier "keeps that target" note in `docs/RULES.md`. Tests: `rq_30_swap_forced` and `rq_30_swap_forced_enemy` (mechanics test), four `rq_30_*` cases in the Cunning Plan spec, and a "pathing reset" case in the Compel (two) and Ventriloquy specs; each fails without its fix. As with FX-2, the placement fix is applied to the frozen legacy reference (`tests/legacy/legacy_engine.gd`) too, so `differential_test` keeps comparing only the migration (two of its fixtures, a Battlefield Control target then a creep across, changed). No golden game changed.

#### M5 as built: deviations from this plan

- **Cards.** All 39 M5 cards ship, each with its spec in `tests/cards/` (391 cases for the 41 new entries; checks for Chain Frost's collapsing bounce and shared look-back, and for Heartstopper Aura's granted text in the Fountain, in `tests/cards/extra/`). Two M7 improvements ship early as heroes' signatures, as in M3 and M4: Assault Ladders (Sorla Khan) and March of the Machines (Tinker). The pack has 48 heroes and 183 other definitions. All are `verified` except Chain Frost (`draft`, RQ-15 and RQ-16, §5.12, as planned) and, from M3 and M4, Enough Magic! (RQ-20) and Kanna (RQ-22). A preset needs three deckable copies of each hero's signature, so Lich cannot fill a deck while Chain Frost is a draft; the fuzz deck builder now skips a hero whose signature is not deckable (it picked Lich and built an illegal deck).
- **Engine: battles across lanes.** `Combat.battle` labelled every battle-damage event with the attacker's lane, and a lane-scoped listener only hears its own lane, so when Gank made a hero battle a unit in another lane, the other unit's own reactions (Viper's Corrosive Skin, Ursa's Fury Swipes, Hellbear Crippler, Loyal Beast) never fired, although Valve's texts have no lane condition. A strike between units of two lanes now also carries `lanes` (both, ascending) and `Kernel._consider` lets a lane-scoped listener in either lane hear it (RQ-45). Combat and same-lane battles carry no `lanes`, so nothing else changes and no golden changed. Tests: `m5_cross_lane_battle_1` to `_3` (mechanics test; the taker side with `fx_corrode_creep`, the dealer side with a new fixture creep, `fx_maul_creep`) and Gank's spec cases 10 and 11 (Viper and Ursa in another lane) fail without the fix; `_4` to `_6` pin same-lane battles and combat as unchanged. `round_log.hits` (CF-4) and death snapshots needed no change.
- **Engine: same-lane moves and rolled arrows (review fix).** `Zones.move` inside a lane (Arctic Burn, Ball Lightning into the hero's own lane) compacted before it reset enemy arrows, so an enemy attacking the mover diagonally whose target column compacted away kept its offset and now pointed at the unit two positions over (it killed that unit instead of hitting the tower). The same move without compaction, or into another lane, already reset it to forward (wiki Pathing; `docs/RULES.md`, "an attacker and its diagonal target stay adjacent"). The same-lane branch now runs `normalize_arrows` before `compact` as well (§3.7 `move`); forced targets keep their CF-1 handling. Tests: Winter Wyvern's spec cases 11 to 14 and Ball Lightning's 12 to 14 (to the left end and the right end, in combat, and the no-compaction and other-lane controls); Winter Wyvern's 11 to 13 and Ball Lightning's 12 and 13 fail without the fix. No golden changed. March of the Machines' spec also gained the `rq_27_starting_charges` case CF-8 names (a played March enters with Valve's 3 charges, `tests/cards/extra/march_starting_charges.gd`).
- **RQ-55 decided: a Cross Lane card's unqualified hero is in the active lane (medium confidence).** Gank, Ball Lightning and The Cover of Night name "an allied black hero" without a lane and put only their second part elsewhere ("another unit in any lane", "an empty combat position in any lane", "to another lane"). The glossary says Cross Lane cards "use mana and heroes from the active lane", RQ-04 reads an unqualified reference as the active lane, every other shipped Cross Lane card writes its any-lane part out, and Dark Seer's lane-bound Surge words the same move the same way ("Move another ally to another lane"), so the hero comes from the active lane, as the drafts had it. One staging of Ball Lightning and The Cover of Night had widened the hero choice to every lane (RQ-33's "target in any lane"); the integrated entries keep the drafts' reading for all three cards, and `rq_55_active_lane_hero` in their specs pins it. Flipping it is one `"lane": "all"` per card.
- **Other new rules questions.** RQ-56: Dirty Deeds is one hit of 2 × N, reduced once by tower armor. RQ-57: Lodestone Demolition sums the enemies' derived Armor, negative values included; a total of 0 or less deals nothing. RQ-58: Ravenous Mass gains the Attack and current Health of every neighbor it condemns, read before the condemn, even from one its Death Shield then saves. Each is one data entry and has a named spec case.
- **Other rulings pinned by the specs.** Quicken (RQ-25) sets Finger of Death's cooldown to 3 after every use (the 2018-12-20 patch notes: "reduce cooldown by 1, but not below 1"). Sorla Khan's and Assault Ladders' bonus is the `bonus_tower` keyword: only while attacking a tower or ancient, never to Siege, a unit or a disarmed attacker; two Ladders stack. March of the Machines stays in play at 0 charges and does nothing; its `where` is checked when `before_action` fires. Tyler Estate Censor's lost Mana comes back even from 0 (RQ-52), and Arcane Censure keeps its -1 in the exact base below 0 (CF-5). Track's bounty is read before the Fountain clears it (a tracked hero pays 15), Town Portal Scroll ends it with no payout, two Tracks stack, and tracking your own hero pays the opponent (RQ-02). Payday doubles 0 to 0. Ravenhook's active can be used with nothing to take (it does nothing and goes on cooldown), and losing a condemned Traveler's Cloak's +4 Health can kill (RQ-40). Bloodseeker heals when stunned (still blocked, RQ-05) but not when he dies with his blocker (RQ-43). Murder Plot, Heartstopper Aura, Coordinated Assault and Collateral Damage may target an enemy black hero. Winter's Curse disarms, pulses (Valve's □), then the target's allied neighbors battle it, and its Retaliate answers each neighbor that attacks. Storm Spirit's `next_combat` bonus follows a move, outlasts another lane's combat and lasts into the next round when given after its lane's combat. Coordinated Assault sees its own play (RQ-44). Assassin's Shadow counts itself (RQ-50); Disciple of Nevermore's and Assassin's Shadow's allies are lane-local (RQ-04).
- **Spec runner (§13.1).** A `give` step gives statuses this round mid-case, as the board's `give` does at setup, so Heartstopper Aura's spec now shows a stunned and a silenced bearer still dealing its damage (`rq_31`, in the next lane to open).
- **Text.** The Three Kingdoms text of Track says 赏金, the bounty keyword's term on the badge, instead of the mapping's 悬赏 (mapping and `docs/CATALOG_MAPPING.md` glossary updated, Revtel Signet Ring's future text too). No `i18n/ui.csv` row was needed: every event the new cards emit already had text. No font rebuild either: every character of the new names and texts (佗, 岘, 诏 and 貂 among them) was already in the subsets.
- **Presets (acceptance 5).** Three presets on the black cards: Fengyi Pavilion (black: Bloodseeker, Phantom Assassin, Winter Wyvern, Storm Spirit, Debbi), Battle of Hulao Pass (black/red: Sorla Khan, Axe, Bounty Hunter, Sven, Keefe) and Yellow Turban Rebellion (black/blue: Tinker, Sniper, Zeus, Lion, Necrophos); between them they play every deckable M5 card (all but Lich and his Chain Frost). In 168 bot games against every preset (2 seeds, both seats), Yellow Turban Rebellion won 37 of 56, Fengyi Pavilion 25 and Battle of Hulao Pass 18, with 4 draws; no game took more than 362 steps. `expanded_classic_test` counts 48 heroes, 183 cards and 14 presets and plays each new preset for 6 seeds against every preset in turn (the M3 and M4 presets keep the opponent pools they had when they landed, 8 and 11 presets). The golden matrix stays the original three presets, and no golden changed.
- **Fuzz (acceptance 4).** The 50 CI seeds and the 2,000 nightly seeds (run as eight slices of 250) pass with the M5 cards in the random decks: no invariant failed and no journal was saved.
- **UI.** `ui_smoke` checks Winter Wyvern's Arctic Burn, the first unit active whose only choice is a position (the generic stepper shows ghost positions in her lane; a click moves her and starts the cooldown), and the black (Qun) catalog filter, Chain Frost included. `tests/capture_preview.gd` has M5 shots (`m5_*`) and an `--out=` option.
- **Tools.** `tools/mechanics.py` records the RQ-55 decision under RQ-33; `docs/design/MECHANICS.md` was regenerated (231 implemented cards).


#### M6 as built: deviations from this plan

- **Cards.** All 40 M6 items ship `verified`, each with its spec in `tests/cards/` (389 cases; Shop Deed's purchases and prices, Golden Ticket's privacy and pool and Demagicking Maul's single pick checked by scripts in `tests/cards/extra/`). The pack has 48 heroes and 223 other definitions, among them all 48 Classic items. Item stats in card text are `{attack}`/`{armor}`/`{health}` placeholders, as the M1 items' locale had them; every other number is a parameter. Golden Ticket, Keenfolk Musket and Shiva's Guard name RQ-59, RQ-24 and RQ-12 in `rq`, after their named spec cases. Ravenhook's spec gained the CF-3 case with an M6 item: an Apotheosis Blade gives its base cost, 25 gold, whatever a Shop Deed does to Secret Shop prices.
- **Engine: granted text on an item instance.** "Modify Stonehall Pike with ..." aims a `modify` at `$self`, the item instance; `Kernel.modify` had no `item` branch, so the Stonehall growth silently did nothing. Now the grant is recorded on `item_state[slot].mods` (a `mod` event names the item and quotes the text), and that text works like the item's printed text: `Stats._derive` adds its `$host` auras wherever the hero is, `Stats._aura_sources` projects its other auras and `Kernel._live_listeners` collects its triggers while the hero is in a lane (RQ-38). The entries stack, leave with the instance (a replaced or condemned item, a fresh copy starting over), and the opponent's Purge never reaches them (RQ-12); stats or keywords aimed at an item change nothing. Tests: `m6_item_modify_1` to `_7` and `m6_item_grant_1` to `_5` (mechanics test, with the fixtures `fx_growth_item` and `fx_rune_item`; each fails without the change), and the Stonehall specs. No golden game changed with it. Budget: Stonehall Cloak's grant was the first granted aura on `max_health`, so every settle scanned the whole board for granted auras and the dense bot fixture took 545 ms normalized (§13.6 budget 250). A granted `$host` aura only ever changes its bearer, so `Stats._derive` now reads it from the bearer's own entries (a unit's while it is in a lane, as the board scan applied it; an item instance's wherever the hero is) and `CardLibrary` keeps such grants out of `granted_aura_fields`: 214 ms again, with no change in behaviour.
- **Shop pools (FX-4, RQ-59).** The wiki Item Shop page: the Secret Shop sells "one random item ... any item that is not a basic consumable", the Consumables Shop one of Healing Salve, Fountain Flask, Town Portal Scroll and Potion of Knowledge, and the item deck "can only contain Weapon, Armor and Accessory cards". So `secret_shop` holds the 44 items that are not basic consumables (Golden Ticket, Obliterating Orb and Shop Deed included), `consumables` the four basic ones, and `validate_preset` now rejects consumables (as before) and Deeds in an item deck (`deck_item_card`); the fuzz deck builder draws equipment only. The pick stays uniform (the page names no tiers). Every Classic golden game sees other shop offers from its first shopping phase, so the `classic` and `matchups` suites (30 games) were re-recorded; the 24 training games are byte-identical, and with the M1 pools restored the M6 engine, cards, presets and bot replay all 54 golden games byte-identically. `differential_test` gives the modern engine the frozen pack's pools, so it keeps comparing only the migration, and so does `perf_test`'s full-match ratio (it must time the legacy engine's own game: with the M1 pools the seed-3 match is the same 218 commands, 1.28x the legacy engine as before M6; with the M6 pools it is another, longer game of 238 commands and 11 rounds). The rules fixture pack's pools gained the M6 items too, so the fuzz meets the Secret Shop-only cards.
- **Rulings.** RQ-03 widened to death triggers (Poaching Knife counts deaths in the equipped hero's lane, medium confidence); Book of the Dead counts allied Melee Creeps dying in its hero's lane (RQ-04) and keeps its charges in the Fountain (medium confidence); a Stonehall hero that dies in combat does not grow that round (RQ-38, low-medium confidence); "the unit blocking equipped hero" (Ristul Emblem, Apotheosis Blade) is the hero's combat target, a diagonal or chosen one included (RQ-05); Seraphim Shield's "all units" are both sides of the hero's lane, the hero included (RQ-04); Wingfall Hammer reads half the hero's Attack once (RQ-28); an item equipped this round can use its active at once (RQ-24); actives with nothing to act on can still be used and go on cooldown (Nyctasha's Guard, Demagicking Maul, Book of the Dead at 0 charges). Each is one data entry and has a named spec case.
- **UI.** Item actives were already buttons on the item slots (M2); `ui_smoke` now clicks Keenfolk Musket's slot and aims it at a unit. The shop shows each offer's price after the rules layer (`price_of`): under a Shop Deed the Secret Shop card's coin turns green with its price (`+14` when it pays) and its label says "Free" or "Pays 14 gold"; a paid purchase logs `EV_BUY_PAID` and the opponent's spending summary `SHOP_OPPONENT_PAID`. Each player's plate shows their Deeds (a count, the names in its tooltip), the inspector names the Deed slot (`SLOT_DEED`) and lists repeated granted text once with its count (a Stonehall item's growths), and the catalog sorts items by slot, then price. A card text that does not fit at the usual minimum size shrinks further instead of overflowing its box (Apotheosis Blade's passive and active), and a three-digit discounted price uses a smaller figure.
- **Bot.** The evaluation has no economy term, so a bought Shop Deed would never be played: it gets `"ai": {"bias": 2.0}` (spec §9.2), and in the 144 preset games above every deed it bought was played. Nothing else changed; the shop phase still buys the first affordable offer, so the bot buys every M6 item from the Secret Shop and equips most of them. Like Potion of Knowledge and Town Portal Scroll before it, Golden Ticket is bought but never played: a card for a card scores below a pass in the one-ply evaluation.
- **Spec runner (§13.1).** `<label>.<slot>.<field>` reads an item instance (`cooldown`, `charges`, `card`, `mods`), `p<i>.deeds` the deeds zone and `p<i>.price.<source>.<card>` a shop price; the board's `charges` and `cooldowns` take `"<label>.<slot>"`; an ability step maps `"tower"` to 0 explicitly (it worked only because `int("tower")` is 0); an unknown card or a `+item` that is not equipment fails the board instead of equipping nothing (`"card#x+item:arrow=-1"` put the modifier inside the item id).
- **Presets (acceptance 5).** Four presets, one per colour: Five Tiger Generals (red: Keefe, Axe, Timbersaw, Legion Commander, Bristleback), The Emperor of Wu (green: Farvhan, Drow Ranger, Treant Protector, Lycan, Abaddon), Battle of Guandu (blue: J'Muy, Earthshaker, Prellex, Ogre Magi, Crystal Maiden) and Rise of the Warlords (black: Debbi, Phantom Assassin, Bounty Hunter, Necrophos, Lion). Their item decks hold nine different M6 equipment cards each, and between them all 36 M6 equipment cards once. In 144 bot games against every preset (one seed, both seats), The Emperor of Wu won 26 of 36, Five Tiger Generals 24, Battle of Guandu 21 and Rise of the Warlords 12 (its first list, with Payday, Murder Plot, The Cover of Night and Gank, won 8, so it plays Oglodi Vandals, Disciples of Nevermore and a Ravenous Mass instead; fragile black heroes keep it the weakest); no game took more than 428 steps. `expanded_classic_test` counts 48 heroes, 223 cards and 18 presets, checks the pools and the item-deck rule, and plays each new preset for 6 seeds against every preset in turn (the M5 presets keep their 14-preset opponent pool). The golden matrix stays the original three presets.
- **Fonts.** The subsets were rebuilt for the new names and UI strings (鳌, 匕, 铠, 橹, 祛 and 槌 among them).
- **Docs and data.** Nyctasha's Guard's ability name (Lock the Gates, 锁阵) joined `catalog_mapping.json`; `docs/design/MECHANICS.md` was regenerated.
- **Review fixes (no rules change).** The adversarial review found no rules defect in the 40 cards; it found four presentation and tooling defects. (1) A play aimed at an improvement (Obliterating Orb) logged no target, because `_play` looked the target up among units only: the `play` event now carries the improvement's oid as `target` and its card as `target_card`, so the log names it like a unit-targeted play, and the board flashes its chip (spec case with `tests/cards/extra/obliterating_orb_log.gd`; no golden game changed). (2) Counted log lines read "1 effects ... are purged", "1 cards ... are locked", "now has 1 charges": `EventText.counted` picks an `_ONE` template at 1 for purge, lock, charges, battle, charged and hack, as draw and discard already did (`i18n_test`). (3) The spec runner read `"a.armor.cooldown"` as the hero's Armor stat, so an armor-slot item's cooldown, charges, card and mods could not be checked and a wrong expectation could pass; `<label>.<slot>.<field>` is now resolved before the stat names (two Bracers of Sacrifice cases, which fail without it). (4) `MECHANICS.md`'s `blocker` row said "its combat target across"; it now says a diagonal or chosen combat target counts too (RQ-05), as the engine and this spec rule.

#### M7 as built: deviations from this plan

- **Cards.** All 32 remaining improvements ship `verified`, each with its spec in `tests/cards/` (326 cases; checks in `tests/cards/extra/` for The Oath's rules-layer entry, an improvement's active the round it is played, Bitter Enemies' starting charges and the 16 cap). With the seven heroes' signatures pulled forward in M3 to M5, all 39 Classic improvements ship, and the pack holds every one of the 303 counted Classic cards: 48 heroes and 255 other definitions. `tools/coverage.py` reports all 303 shipped (Valve parity 303/303); Chain Frost (RQ-16), Enough Magic! (RQ-20) and Kanna (RQ-22) stay drafts. Three authors staged the cards in three chunks (static auras, tower stats and lane rules; triggered effects; actives, charges, gold and the round log), each verified on a full copy of the project with single-rule mutations; the integration appended them in Appendix A order. No card needed an engine change.
- **Rulings.** RQ-24 widened to improvements: `Zones.add_improvement` creates an improvement at cooldown 0, so one played this round can use its active at once (medium confidence; an `rq_24` case in each of the eight active improvements' specs, and `m7_improvement_*` in the mechanics test). RQ-60 (new, medium-high confidence): "if there is an allied red/black/green hero in this lane" is a presence test, so a stunned or silenced hero of the colour still enables Grand Melee's Cleave, The Oath's +4 Attack and Cheating Death (`rq_60_*` cases). RQ-03: a Path hears only cards played while its lane is active, and The Omexe Arena draws only for heroes of either side dying in its lane (medium-low confidence; Valve's text names no lane, and `"lane": "any"` on its trigger flips it). RQ-44: a Path played into the active lane reacts to its own play, as Incarnation of Selemene does (medium-low). RQ-06: a tower's Retaliate (Burning Oil) answers each unit whose combat target is the tower, not Siege. RQ-52 and CF-5: Selemene's Favor and The Tyler Estate move current mana with the maximum, and The Tyler Estate's spec runs the CF-5 sequence (the Estate, a Tyler Estate Censor and Mana Drain below 0, each removed in turn in both orders, then the round end). RQ-27: Bitter Enemies starts with Valve's 3 charges (CF-8); Revtel Investments has no charges field, so it starts at 0. Glyph of Confusion stuns every entrant of its lane (creep plays of either player, summons, deployment, Blink Dagger, Chen; not swaps), and its stun is its owner's effect, so the other player's Purge removes it from their units (RQ-12). Each ruling is one data entry or constant, listed in `docs/RULES.md`.
- **Acceptance tests.** The 16 cap (RQ-47) with real cards: a 17th Trebuchets beside 16 replaces a random one (`tests/cards/extra/improvement_cap.gd`). The Tyler Estate's CF-5 cases. The Oath's forbid in the rules layer (`the_oath_forbid.gd`) and in the UI: `ui_smoke` checks that its owner's spells and creeps in its lane are dimmed with a `REASON_FORBIDDEN` note while an improvement and an item stay playable. Howling Mind's symmetric draw; Glyph of Confusion's deployment entrants (RQ-21); Watchtower on enemy improvements only; Bitter Enemies' countdown; Trebuchets' piercing damage through Steel Reinforcement; the Paths' lane scope; Unearthed Secrets' round log (its lane's tower or ancient, any source); Revtel Investments condemning itself; the `requires` of Unsupervised Artillery (no unblocked enemy, RQ-05) and Cheating Death.
- **Bot (§9.2, §9.3).** With a flat 2.0, an improvement on the board was worth less than the card in hand (0.9) plus the play penalty (0.7 plus 0.12 per mana) from cost 3 up, so the one-ply bot never played the dearer improvements whose effect it cannot simulate (a first probe of the M7 presets never played Keenfolk Turret, Steam Cannon, Aghanim's Sanctum, Barracks, Conflagration, Glyph of Confusion, Cheating Death, Selemene's Favor or Homefield Advantage). The improvement term is now `2.0 + 0.25 x cost`, plus `0.5 x charges`, so every Classic improvement beats a first pass when affordable, and destroying a dear improvement is worth more. A new static value, `gold`, flags a `gold` op that adds gold for "you"; the bot adds `GOLD_WEIGHT` (0.25) per gold the simulation gains (spending all gold with `set` is not a gain), so Revtel Investments cashes in from 6 charges and Ravenhook and Payday count their gold. Tests: `bot_test` (the cost term, every improvement played rather than passing, the gold value of an active and of Revtel at 2, 5, 6 and 8 charges). No golden game has an improvement or a gold gain, so all 54 golden games stay byte-identical, and the dense-board decision budget holds.
- **Engine: `legal_actions` in a read frame.** The Oath and Howling Mind are the first improvements with rules-layer auras, so the scan behind `Stats.rules_of` now reaches every improvement on the board, and `Targeting.forbidden` ran it once per hand card: on the dense perf fixture (16 improvements per side in every lane) `legal_actions` went from 0.150 to 0.505 ms normalized, past three times its baseline. `Targeting.actions` now runs in a read frame (§13.6, like the bot's evaluation and the combat plan), so one listing derives each unit once and scans the rules-layer auras once (0.27 ms). The listed actions are unchanged: the golden games, the rules kernel test's targeting equivalence and the specs' rejected-command checks pass.
- **Presets (acceptance 5).** Four presets on the improvements, each with 5 heroes, 40 main cards and 9 items, signature cards only with their heroes, and between them every M7 improvement: Siege of Ye (blue/black: Ogre Magi, Debbi, Bounty Hunter, Luna, Prellex; Trebuchets, Unsupervised Artillery, Steam Cannon, Keenfolk Turret, Bitter Enemies, Aghanim's Sanctum, Messenger Rookery, Watchtower, Fractured Timeline, Path of the Wise), Struggle for Jing Province (red/green: Keefe, Rix, Mazzie, Treant Protector, Chen; Burning Oil, Grand Melee, Path of the Bold, The Omexe Arena, Temple of War, Unearthed Secrets, Path of the Dreamer, Homefield Advantage, Altar of the Mad Moon), Dong Zhuo's Tyranny (black/blue: Bloodseeker, J'Muy, Phantom Assassin, Debbi, Winter Wyvern; The Tyler Estate, Iron Fog Goldmine, Revtel Investments, The Oath, Escape Route, Path of the Cunning, Assured Destruction, Howling Mind) and Battle of Xiaoyao Ford (blue/green: Earthshaker, Farvhan, Crystal Maiden, Lycan, Abaddon; Glyph of Confusion, Conflagration, Mist of Avernus, Cheating Death, Selemene's Favor). In 352 bot games against every preset (2 seeds, both seats), the Struggle for Jing Province won 47 of 88, the Siege of Ye 39, the Battle of Xiaoyao Ford 38 and Dong Zhuo's Tyranny 31 (black's fragile heroes again, and The Oath and The Tyler Estate restrict their own player too, which the one-ply bot cannot weigh); no game took more than 402 steps. The first lists held 15 to 20 improvements each and won 31 to 33 of 88; with 8 to 11 and more creeps they do better. `expanded_classic_test` counts 48 heroes, 255 cards and 22 presets, plays each M7 preset for 6 seeds against every preset in turn and checks that they play every M7 improvement; the M6 presets keep their 18-preset opponent pool, and the M5 check that its presets play every new black card leaves M7's black improvements to the M7 presets. The golden matrix stays the original three presets.
- **UI.** Nothing per card: improvement actives were chip buttons since M2. `ui_smoke` uses Keenfolk Turret, played this round, from its chip: the click asks for a unit, which takes 2 piercing damage, and the chip goes on cooldown; the catalog holds all 303 cards, each colour filter its improvements. `tests/capture_preview.gd` has M7 shots (`m7_*`), The Oath's forbidden note and an improvement inspected among them.
- **Fonts.** The subsets were rebuilt for 夙, 瞭, 癫 and 霭 (Valve's Chinese names of Bitter Enemies, Watchtower, Altar of the Mad Moon and Mist of Avernus).
- **Docs and data.** `docs/design/MECHANICS.md` was regenerated (303 implemented, none mapped but unimplemented), `tests/data/coverage.json` regenerated (all 303 shipped), and `docs/RULES.md` lists the M7 cards under their rules questions. The Three Kingdoms name of Aghanim's Sanctum, Bronze Sparrow Terrace (铜雀台, from `catalog_mapping.json`), is also the name of the M4 preset `bronze_sparrow_terrace`; neither was renamed.
- **Review fixes.** The adversarial review of the 32 improvements found one rules defect and one stale note. (1) Tower Regeneration ran only after `Kernel.damage_structure` had already turned a tower at 0 into an ancient, so Path of the Dreamer's +3 could not keep a tower at 2 standing against 2 damage, against RQ-09 and the glossary ("Regeneration is applied before checking for death"); §4.5 also said "unless the tower fell". `damage_structure` now takes the combat's tower Regeneration and heals (cap 40, 80 for an ancient) before the fall check; a tower that still reaches 0 falls into a fresh, unhealed 80-health ancient, and damage the Regeneration outheals still counts as dealt (round log). Regression: five `rq_09_*` cases in `path_of_the_dreamer.json`; `kw_regeneration_5`, which pinned the old order, now expects the tower to stand, with `_6` (falls) and `_7` (an ancient stands) beside it. No golden game changed. (2) `tools/mechanics.py` still said Bitter Enemies' starting charges were "not in data"; Valve's set 01 gives 3 (RQ-27/CF-8), and `MECHANICS.md` was regenerated.
---

## 13. Testing

### 13.1 Per-card test template (`tests/cards/<id>.json`, run by `tests/card_specs_test.gd`)

```json
{
 "card": "tidehunter",
 "source_id": 10024,
 "text": "Ravage: Stun Tidehunter's enemy neighbors this round and each other enemy has a 50% chance of being stunned this round.",
 "covers": ["active", "stun", "enemy_neighbors", "random_chance", "this_round"],
 "cases": [
  {"name": "Ravage stuns every enemy neighbor", "clause": 0, "tags": ["active", "stun", "enemy_neighbors"], "seed": 1,
   "board": {"active_lane": 0,
             "lanes": {"0": {"p0": [null, "tidehunter#t", null, null],
                             "p1": ["melee_creep#a", "melee_creep#b", "melee_creep#c", "melee_creep#d"]}}},
   "do": [{"ability": "t"}],
   "expect": {"a.stunned": true, "b.stunned": true, "c.stunned": true, "t.cooldown": 4}},
  {"name": "each other enemy is stunned half of the time", "clause": 0, "tags": ["random_chance"],
   "seeds": {"from": 1, "count": 200}, "board": "@0",
   "do": [{"ability": "t"}],
   "expect_rate": {"d.stunned": [0.4, 0.6]}},
  {"name": "the stun ends with the round", "clause": 0, "tags": ["this_round"], "board": "@0",
   "do": [{"ability": "t"}, {"end_round": true}],
   "expect": {"a.stunned": false, "t.cooldown": 3}},
  {"name": "a silenced Tidehunter cannot Ravage", "clause": 0, "tags": ["negative"],
   "board": {"base": "@0", "give": {"t": ["silence"]}},
   "expect_illegal": [{"ability": "t"}]},
  {"name": "stunned enemy neighbors deal no combat damage", "clause": 0, "tags": ["interaction"], "board": "@0",
   "do": [{"ability": "t"}, {"combat": true}],
   "expect": {"t.health": 18}}
 ]
}
```

**Board DSL:**

| Key | Meaning | Default |
|---|---|---|
| `lanes` | Lane index → `{p0, p1}` rows. An entry is `"card#label[:hp=N][:atk=N][:arm=N][+item_id...]"`, or `null` for an empty slot | — |
| `active_lane` | Active lane | 0 |
| `active_player` | Active player | 0 |
| `initiative` | Initiative holder | 0 |
| `round` | Round number | 2 |
| `mana` | Mana per lane and player | 10 |
| `gold`, `hand`, `deck`, `towers` | Players and towers | — |
| `improvements` | `{"0": {"p0": ["card#label"]}}` | — |
| `fountain` | Heroes in the Fountain | — |
| `give` | Labels to statuses for this round | — |
| `charges`, `cooldowns`, `hand_state` | Object counters and hand state | — |
| `"@n"` | Reuse case n's board; `{"base": "@n", ...}` merges into it | — |

**Steps** go through `apply_action`, so they are validated:

| Step | Meaning |
|---|---|
| `{"play": "card", "target": "label", "destination": "label" \| "tower", "lane": n, "position": n, "as": "label"}` | The runner puts the card in hand if needed; `as` names the creep the play puts into the lane (M3) |
| `{"ability": "label"}`, `{"ability": "label.weapon"}`, `{"ability": "improvement_label"}` | Activate an ability, plus choice keys |
| `{"pass": p}` | One pass |
| `{"combat": true}` | Both players pass |
| `{"end_round": true, "deploy": {"label": lane}}` | `_begin_deployment`, then the reveal; `deploy` plans heroes from the Fountain into lanes (M3) |
| `{"kill": [labels]}` | Health 0, then a Pulse; a test-only helper |
| `{"draw": {"p1": 1}}` | Draw |

**Expectations:**
- `"label.field"`, where the field is one of `attack`, `armor`, `health`, `max_health` (derived), `kw.<k>`, `stunned`, `silenced`, `disarmed`, `in_play`, `lane`, `slot`, `owner`, `cooldown`, `charges`.
- `"tower.<lane>.<p>.health"`, `"mana.<lane>.<p>"`, `"p<i>.gold"`, `"p<i>.hand"`, `"p<i>.hand_state.<i>.lock"`, `"initiative"`, `"winner"`, `"units.<lane>.<p>[.<card>]"` (a count of units, M3).
- `"events": {"has": [...], "not": [...]}`.
- `expect_legal` / `expect_illegal`: lists of commands.
- `expect_rate`: probability bounds over `seeds`.
- `expect_private`: `{"viewer": 1, "absent": ["eclipse"]}`.
- `"gd": "res://tests/cards/extra/<id>.gd"`: an optional escape for assertions the DSL cannot express: a RefCounted script whose `check(engine, labels)` returns failure messages (implemented in M3; `soul_of_spring.gd`).

**The runner also, automatically:**
- checks every global invariant (§13.3) after every step;
- runs each case twice and compares digests;
- checks that every emitted event formats with the classic and three_kingdoms skins in en and zh_CN;
- checks that a rejected command leaves the digest and `rng.state` unchanged.

**Per-card checklist:**
1. One positive case per Valve clause (`clause` is the index into `mechanics_tags.json`).
2. One negative or edge case per clause, picking whichever apply:
   - no legal target;
   - a fizzle (the target died or moved);
   - a silenced or stunned source or colour hero;
   - immunity or a shield against damage or condemn;
   - Purge by the opponent;
   - Fountain survival.
3. For durations: cases before and after `end_round`. `next_combat` is checked in its own lane and after a move.
4. For random effects: `expect_rate` over 200 or more seeds, plus a fixed-seed case.
5. For hidden information: `expect_private` from the opponent's view.
6. Lane scope: an identical board in another lane is not affected (RQ-03, RQ-04).
7. RQ decisions: cases named `rq_XX_*` and tagged with the RQ.

### 13.2 Generated per-card checks (`tests/card_invariants_test.gd`; no per-card code)

For every compiled card, on a canonical fixture with a hero of its colour, an ally and enemies in all lanes, 3 items, 2 improvements per side, and its owner holding it:
1. **Playability.** The card is playable exactly when its choices are satisfiable, and every legal action applies successfully.
2. **Determinism.** The same snapshot and command give the same digest.
3. **Inertness.** A forged or illegal variant leaves the digest unchanged.
4. **No overflow.** No `rules_overflow`.
5. **Simulation safety.** The play also runs inside `simulation_from_view` for both players without errors.

### 13.3 Global invariants (`tests/invariants.gd`; asserted after every fuzz or golden step)

| # | Invariant |
|---|---|
| I1 | Rows are aligned, and no position is empty on both sides. |
| I2 | Arrows are consistent (`_board_invariants`). |
| I3 | Every unit in a lane has `owner == side`, `lane == index`, `health > 0` and `condemned == false`. |
| I4 | `health ≤ max_health_of` and `hp_seen == max_health_of`. |
| I5 | `mana ≥ 0`, `max_mana ≥ 0`, and `mana_bonus` equals the derived tower mana modifier. |
| I6 | uids and oids are unique. Every `mods` entry has a known `k`, `d` and `by`, and every `ab` resolves. |
| I7 | `hand_state.size() == hand.size()`, `deck_state` is either empty or as long as `deck`, and locks are ≥ 0. |
| I8 | No side of a lane has more than 16 improvements. |
| I9 | Transient queues are empty, the op budget was not exceeded, and there was no `rules_overflow`. |
| I10 | Every roster hero is in exactly one place: a lane or the Fountain. |
| I11 | Write-through consistency. For units created by the engine: own fields = printed value + Σ the `st` deltas of `modify` entries, unless a test wrote them directly. Checked only in fuzzing. |
| I12 | Privacy: no hidden id of the other player and no `_s` appear in `player_view`. |
| I13 | Purity of the read-only API (D3). |
| I14 | `legal_actions(p).size() ≤ 2000`, and the guest packet is under 200 KB. |

### 13.4 Fuzz (`tests/fuzz_test.gd`)

- **Decks.** Random legal decks drawn from the verified cards, plus the existing presets.
- **Agents.** The bot plays against a seeded random-legal agent, and the bot plays against itself.
- **Volume.** 50 matches in CI and 2,000 nightly.
- **Each match:**
  - the invariants after every step;
  - a replay round trip with an equal `state_digest`;
  - a second run with the same seed giving the same digests;
  - mutated illegal commands rejected with no change (as `run_tests.gd:88-94` does today).
- **Torture mode.** Random boards with statuses, items and improvements, where every legal action of every card is applied to a copy.
- **Failing journals** are saved under `user://fuzz_failures/` so they can be reproduced.

### 13.5 Goldens (`tests/golden/`)

- **Files.** `tests/golden/golden_games.gd` defines the 54 games and the projection; `tools/record_goldens.gd` records them; `tests/golden_test.gd` checks them (`--projection-only`, `--journal-only`, `--suite <name>`, `--game <id>`).
- **Format.** `tests/data/goldens/<suite>.json` holds, per game (id, pack, seed, decks), one step per command: `{r: revision, p: player, c: command, d: state_digest, h: projection hash, e: event keys}`, plus the final projection.
- **Checks.** The journal replay applies the recorded commands and compares every step (strict: digests; `--projection-only`: projection hashes and the event-key subsequence) and the invariants (§13.3). The bot replay lets the bot play again and requires the recorded choice at every step.
- **Projection** (stays valid while the state shape changes):
  - per unit: `uid, card, owner, lane, slot, attack_of, armor_of, max_health_of, health, arrow, combat_target, cooldown, ready_round`;
  - structures and mana;
  - gold, hand ids, deck size;
  - `rng.state`, `next_id`;
  - `round, lane, phase, active_player, initiative, winner`.
- **Re-recording** is done with `tools/record_goldens.gd`. It happens only in a commit that intends a rules change (FX or RQ), and the commit message says why.

### 13.6 Performance (`tests/perf_test.gd`; dense fixture: 3 lanes × 8 positions, 16 improvements per side, 6 items, 10-card hands)

| Measure | Budget (CI desktop) |
|---|---|
| `legal_actions` | < 5 ms |
| `apply_action` (median) | < 5 ms |
| `Kernel.pulse` with no deaths | < 1 ms |
| `combat_preview` | < 2 ms |
| Bot decision | < 250 ms |
| Full headless bot match | ≤ 1.5× the pre-M1 engine (`tests/legacy/`) on the same machine |

- The match budget was < 3 s. The pre-M1 engine alone needs 2.6 to 2.8 s for the same match on the reference desktop, so that figure could not be met by any engine that adds work; the M1 engine measures 1.2 to 1.3× it (about 3.1 to 3.4 s). The ratio is machine-independent and is a failing check.
- The other budgets are failing checks too, on times normalized by the machine factor (the legacy match time against the stored baseline).
- If a budget fails, the first remedy is a per-frame derived-stats cache: `Stats.frame_begin`/`frame_end` around bot evaluation and `board_view.build_models`, invalidated by every kernel mutation. Nothing is cached before a budget fails (K15).
- CI warns at 2× the stored baseline and fails at 3×.

### 13.7 Meta tests (`tests/rules_schema_test.gd`)

1. Zero compile errors across all packs.
2. The vocabulary is closed (§3.14).
3. `RULES_VERSION` matches the source hash.
4. Rules scripts have no instance members and no forbidden calls (D1).
5. Every `verified` card has a spec.
6. Every spec's `text` equals `valve_text`.
7. Every spec's `covers` contains the card's tags.
8. Every RQ tag used by a card appears in `docs/RULES.md`.
9. No token and no draft card appears in a preset.
10. **[CF-12] Valve parity** (generalizes the review script `effects/coverage.py`, committed as `tools/coverage.py` with its output in `tests/data/`), for every card:
    - every counted card in `mechanics_tags.json` has an entry, and every Valve ability (75) maps to an ability of its parent card;
    - the sorted `cooldown`s of its actives equal Valve's `Active N` values;
    - its top-level `charges` equals Valve's `charges` field when Valve has one;
    - the number of `pulse` ops equals the number of Valve □ markers;
    - `play.initiative` is set exactly when the text says "Get initiative";
    - text tagged random contains a `pick`, `chance`, `from_pool` or `random_other`;
    - each verb and trigger tag maps to an op, keyword, rules key or listener (the table in `coverage.py`).

---

## 14. Rules questions added by this design

These add to RQ-01..36 in MECHANICS.md. Each decision lives in one place and has one named test.

| RQ | Question | Default | Where | Test |
|---|---|---|---|---|
| RQ-37 | Order and resolution of "simultaneous" triggers | Batch without Pulses between triggers; key: event → initiative side → lane → zone → position → ability → id | `Triggers.key`, `BATCH_MODE` | `rq_37_order`, `rq_37_batch_mode` |
| RQ-38 | Do item triggers and actives work while the host is in the Fountain? | No. Host stat auras still apply (Fountain healing includes them) | live-zone table §4.2 | `rq_38_item_in_fountain` |
| RQ-39 | Does a Death Shield save a Soulbound partner? | Yes; shields apply after the Soulbound closure | `_consume_death_shields` | `rq_39_soulbound_shield` |
| RQ-40 | Can losing a +Health aura kill? | Yes, through the settle delta | `Stats.settle` | `rq_40_aura_loss_kills` |
| RQ-41 | Where does a Deed go? | It is played free (no mana, no hero) into a public `deeds` zone; permanent | `Zones.add_deed` | `rq_41_deed_zone` |
| RQ-42 | What is an "empty combat position" for moves? | The `creep_positions` set: an empty own slot, or a new position at either end | `positions` selector | `rq_42_empty_position` |
| RQ-43 | Do units dying in the same Pulse trigger on each other's deaths? | No, except their own Death Effect | `Triggers.live_listeners` | `rq_43_simultaneous_death` |
| RQ-44 | Does a granted "after you play" trigger see the card that granted it? | Yes, because `card_played` is emitted after resolution | `_play` order | `rq_44_heroic_resolve_self` |
| RQ-45 | What is battle damage? | Attack, cleave, retaliate and siege hits; siege counts as tower battle damage | `Combat.plan` parts | `rq_45_battle_damage_parts` |
| RQ-46 | Does "a random allied tower in any lane" include a lane's ancient? | Yes: the standing structure of each lane | `towers` selector | `rq_46_ancient_is_tower` |
| RQ-47 | Is the improvement cap per side or per lane? | 16 per side of a lane (refines RQ-34) | `Zones.add_improvement` | `rq_47_improvement_cap` |
| RQ-48 | Centaur Hunter is a Valve token, but the green_assault preset uses it as a 5-mana creep | Decided in M3: a token, as in Valve's data; Green Assault plays Satyr Duelist instead (golden matchups of that preset re-recorded); Spring the Trap summons the token | `classic_cards.json` | `rq_48_summons` (Spring the Trap spec) |
| RQ-49 | Is round 1's initial placement a "deployment phase" for Venomancer, Prellex (and, if ever in play, Barracks)? The glossary puts deployment "in between rounds"; Valve's texts say "each deployment phase" | Yes, low confidence: `start()` runs the deployment hooks after placement (CF-7). One constant flips it | `ROUND1_DEPLOYMENT_HOOKS` in `kernel.gd` | `rq_49_round1_deployment` |
| RQ-50 | Does "for each ally" (Assassin's Shadow) count the unit itself? | Yes: `allies` includes the source, unlike "other allies" (Drow, Disciple of Nevermore) | Assassin's Shadow entry (`allies` vs `other_allies`) | `rq_50_shadow_counts_itself` |
| RQ-51 | Does Claszureme Hourglass lock the round-draw cards when its host is redeployed in the same deployment? | No: the round draw happens before placement (CF-9); a host already in a lane locks both cards | `_reveal_deployment` order | `rq_51_hourglass_round_draw` |
| RQ-52 | Losing a −Mana effect while the tower has 0 current mana: does current mana rise? | Yes: current mana follows the effective change in maximum (as Stars Align's expiry does); the maximum itself is exact (CF-5) | `Stats.settle` | `rq_52_mana_floor` |
| RQ-53 | Is a hero not yet deployed (heroes 4 and 5 before rounds 2 and 3) "at the Fountain" (Routed)? | Yes, low confidence: `lane: "fountain"` selects every roster hero out of the lanes | `Select` | `rq_53_undeployed_heroes_are_at_the_fountain` |
| RQ-54 | Does a Modify reach a hero that died earlier in the same command (Viper, Ursa, Hellbear Crippler, Loyal Beast hitting a hero that dies)? | Yes: heroes keep modifications through death and a Pulse processes reactive abilities before it destroys units (glossary); other ops on a unit that left play fizzle | `MODIFY_REACHES_DEAD_HEROES` in `kernel.gd` | `rq_54_*` |
| RQ-55 | Which hero does a Cross Lane card that names "an allied black hero" without a lane use (Gank, Ball Lightning, The Cover of Night)? | Decided in M5, medium confidence: one in the active lane (glossary: Cross Lane cards "use mana and heroes from the active lane"); only the part the text places in any lane or another lane reaches other lanes | card data (the hero choice has no `lane`) | `rq_55_active_lane_hero` (Gank, Ball Lightning and The Cover of Night specs) |
| RQ-56 | Dirty Deeds: one hit of 2 × N, or N hits of 2? | One hit of `amount × N`, reduced once by tower armor (medium confidence) | Dirty Deeds entry (`mul`) | `rq_56_one_hit` |
| RQ-57 | Lodestone Demolition with negative Armor | The plain sum of the enemies' derived Armor, so negative Armor lowers it; a total of 0 or less deals nothing (medium-low confidence) | Lodestone Demolition entry (`sum`) | `rq_57_negative_armor` |
| RQ-58 | What does Ravenous Mass gain? | The derived Attack and current Health of every neighbor it condemns, read before the condemn, even from one its Death Shield saves (medium-low confidence) | Ravenous Mass entry (`let` before `condemn`) | `rq_58_current_health`, `rq_58_death_shield` |

Existing RQs that this design pins explicitly:

| RQ | Where it is pinned |
|---|---|
| RQ-01 | FX-1 |
| RQ-15 | FX-3 |
| RQ-16 | Chain Frost spec |
| RQ-19 | FX-2 |
| RQ-20 | `_end_action_phase` |
| RQ-22 | Kanna `-1` |
| RQ-24 | `const HERO_ACTIVE_START_COOLDOWN = 0` in `kernel.gd` |
| RQ-27 | The `charges` param, equal to Valve's `charges` field (closed, CF-8) |
| RQ-28 | The `half` expression and `damage_split` |
| RQ-34 / RQ-47 | The improvement cap |
| RQ-35 | The `equip` duration |

---

## 15. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Bugs in the VM's semantics spread to many cards | Op-level unit tests in M2 against the fixture pack; the differential test in M1.2; generated per-card checks; fuzz with invariants. |
| GDScript interpretation is too slow for bot simulation | Budgets measured from M1.2. Membership tests instead of set enumeration. Optional per-frame cache. A bot prefilter for more than 60 candidates. |
| Trigger order and batching are unverified Classic behaviour | One function and one switch (RQ-37), named tests, and goldens re-recorded only on purpose. |
| Action counts explode, or packets get too large | `after` deduplication; fuzz caps at 2,000 actions and 200 KB; path-encoded choices kept as a reserve protocol 9. |
| The UI target stepper regresses | Old hooks kept; one `ui_smoke` case per step type; the UI adaptation lands in M1.4, before any new content. |
| Hidden state leaks | All redaction is in `player_view` (one function), plus `_s` handling, the taint fuzz and the hidden-swap test. |
| Contributors write invalid or unfaithful JSON | Validator errors with JSON paths; Appendix B and `docs/EFFECTS.md` patterns; `tools/new_card.py` scaffolds; the spec and coverage gate before `verified`. |
| Every rules change invalidates saved replays | It is deliberate (`replay_rules`); the error names both versions. Replays are debugging records, not an archive. |
| Write-through Modify and Purge drift apart | Invariant I11 in fuzzing; Purge reverses only its own entries' deltas. |
| M1 bot choices change from floating-point drift | Static values are computed exactly as today's constants. Goldens compare the chosen actions step by step. |
| Kanna or other hidden plans leak | `-1` publication, a reveal-time resolution test, and the privacy fuzz with deployment phases. |

---

## Appendix A. Card → milestone (303 cards)

The complexity score from MECHANICS.md is in parentheses. Tokens ship with the cards that summon them. Cards that refer to improvements or items that are not yet playable are tested with fixture improvements and items from M2 on.

**M1 (already implemented; migrated): 49.**
- Black: Debbi the Cunning, Phantom Assassin, Untested Grunt, Hip Fire, No Accident, Pick Off, Slay, Coup de Grace, Forward Charge.
- Blue: J'Muy the Wise, Zeus, Annihilation, Battlefield Control, Dimensional Portal, Foresight, Lightning Strike, Thundergod's Wrath, Thunderstorm, Tower Barrage.
- Green: Drow Ranger, Farvhan the Dreamer, Lycan, Rix, Thunderhide Pack, Prowler Vanguard, Savage Wolf, Act of Defiance, Arm the Rebellion, Avernus' Blessing, Gust, Stars Align.
- Red: Axe, Keefe the Bold, Bronze Legionnaire, Ogre Conscript, Centaur Hunter (token), Combat Training, Defensive Stance, Fighting Instinct, Berserker's Call.
- Neutral: Melee Creep (token), Broadsword, Claymore, Leather Armor, Short Sword, Traveler's Cloak, Healing Salve, Potion of Knowledge, Town Portal Scroll.

**M3 Red and Green: 92.**
- Green heroes: Magnus (1), Treant Protector (2), Abaddon (3), Enchantress (3), Omniknight (3), Viper (3), Dark Seer (4), Chen (5).
- Green creeps: Thunderhide Alpha (1), Emissary of the Quorum (3), Rampaging Hellbear (3), Roseleaf Druid (3), Roseleaf Rejuvenator (3), Satyr Duelist (3), Selfish Cleric (3), Vhoul Martyr (3), Champion of the Ancient (4), Rebel Decoy (4), Revtel Convoy (4), Smeevil Blacksmith (4).
- Tokens: Roseleaf Wall (1), Zombie (1, also used by Book of the Dead), Loyal Beast (3).
- Green spells: Corrosive Mist, Curse of Atrophy, Defensive Bloom, Divine Intervention, Divine Purpose, Empower, Hand of God, Ion Shell, Iron Branch Protection, Restoration Effort, Rumusque Blessing, Steal Strength (2 each), Aphotic Shield (3), Cleansing Rite (3), Juke (3), Allseeing One's Favor (4), Bellow (4), Defend the Weak (4), Intimidation (4), Soul of Spring (4), Viper Strike (4), Caught Unprepared (5).
- Red heroes: Mazzie (1), Centaur Warrunner (2), Legion Commander (2), Beastmaster (3), Bristleback (3), Sven (3), Ursa (3), Pugna (4), Tidehunter (4), Timbersaw (4).
- Red creeps: Marrowfell Brawler (1), Legion Standard Bearer (2), Hellbear Crippler (3), Ogre Corpse Tosser (3), Stonehall Elite (3), Cursed Satyr (4), Keenfolk Golem (4), Mercenary Exiles (4), Rebel Instigator (4), Red Mist Pillager (4), Smeevil Armsmaster (4).
- Red spells: Clear the Deck, Crippling Blow, Double Edge, Enrage, Fight Through the Pain, God's Strength, Kraken Shell, New Orders, Poised to Strike, Raze, Spot Weakness, Spring the Trap, Sucker Punch, Time of Triumph, Viscous Nasal Goo, Whirling Death (2 each), Duel (3), Rend Armor (3), Smash Their Defenses! (3), Heroic Resolve (4), Pick a Fight (4), Primal Roar (4), Rising Anger (4), Tresdin's Standards (4), Enough Magic! (5), Routed (5).

**M4 Blue: 44.**
- Heroes: Earthshaker (3), Prellex (3), Skywrath Mage (3), Venomancer (3), Crystal Maiden (4), Outworld Devourer (4), Kanna (5), Luna (5), Meepo (5), Ogre Magi (5).
- Creeps: Relentless Zombie (3), Satyr Magician (3), Incarnation of Selemene (4), Troll Soothsayer (4).
- Tokens: Plague Ward (4), Hound of War (1).
- Spells: Arcane Assault, Astral Imprisonment, At Any Cost, Better Late Than Never, Bolt of Damocles, Call the Reserves, Compel, Diabolic Revelation, Frostbite, Rolling Storm, Sow Venom, Strafing Run (2 each), Cunning Plan (3), Prey on the Weak (3), Ventriloquy (3), ...And One For Me (4), Buying Time (4), Echo Slam (4), Fog of War (4), Friendly Fire (4), Lost in Time (4), Mystic Flare (4), Remote Detonation (4), Whispers of Madness (4), Divided We Stand (5), Eclipse (5), Self Sabotage (5), Wrath of Gold (5).

**M5 Black: 39.**
- Heroes: Bloodseeker (3), Lion (3), Necrophos (3), Sniper (3), Sorla Khan (3), Tinker (3), Bounty Hunter (4), Lich (4), Storm Spirit (4), Winter Wyvern (4).
- Creeps: Disciple of Nevermore (2), Assassin's Apprentice (3), Oglodi Catapult (3), Oglodi Vandal (3), Pit Fighter of Quoidge (3), Sister of the Veil (3), Tyler Estate Censor (3), Assassin's Shadow (4), Ravenhook (4), Ravenous Mass (4).
- Spells: Arcane Censure, Assassinate, Blood Rage, Collateral Damage, Grazing Shot, Mana Drain, Murder Plot, Payday, Track (2 each), Dirty Deeds (3), Lodestone Demolition (3), Ball Lightning (4), Coordinated Assault (4), Gank (4), Heartstopper Aura (4), Relentless Pursuit (4), The Cover of Night (4), Winter's Curse (4), Chain Frost (5).

**M6 Items: 40.**
- Chainmail, Fur-lined Mantle, Hero's Cape, Platemail, Red Mist Maul (1 each).
- Barbed Mail, Blade of the Vigil, Fountain Flask, Obliterating Orb, Revtel Signet Ring, Ring of Tarrasque, Ristul Emblem, Shield of Aquila, Shield of Basilius (2 each).
- Assassin's Veil, Bracers of Sacrifice, Cloak of Endless Carnage, Horn of the Alpha, Keenfolk Musket, Poaching Knife, Rumusque Vestments, Shiva's Guard (3 each).
- Blink Dagger, Book of the Dead, Demagicking Maul, Golden Ticket, Jasper Daggers, Keenfolk Plate, Nyctasha's Guard, Phase Boots, Seraphim Shield, Stonehall Cloak, Stonehall Pike, Stonehall Plate, Vesture of the Tyrant, Wingfall Hammer (4 each).
- Apotheosis Blade, Claszureme Hourglass, Helm of the Dominator, Shop Deed (5 each).

**M7 Improvements: 39.**
- Black: Assured Destruction (2), Escape Route, Iron Fog Goldmine, Keenfolk Turret, Steam Cannon, The Tyler Estate, Trebuchets (3 each), Assault Ladders, Bitter Enemies, March of the Machines, Path of the Cunning, Revtel Investments, Unsupervised Artillery (4 each), The Oath (5).
- Blue: Aghanim's Sanctum, Barracks, Conflagration, Ignite, Messenger Rookery (3 each), Fractured Timeline, Howling Mind, Path of the Wise, Watchtower (4 each), Glyph of Confusion (5).
- Green: Verdant Refuge (2), Altar of the Mad Moon, Mist of Avernus, Path of the Dreamer, Selemene's Favor (3 each), Cheating Death, Homefield Advantage, Unearthed Secrets (4 each).
- Red: Steel Reinforcement (2), Temple of War (2), Burning Oil, Nether Ward, The Omexe Arena (3 each), Grand Melee (4), Path of the Bold (4).
- Shipped early with M3 as heroes' signatures: Steel Reinforcement, Nether Ward and Verdant Refuge.
- Shipped early with M4 as heroes' signatures: Barracks and Ignite; with M5: Assault Ladders and March of the Machines.

---

## Appendix B. Contributor quick reference: adding a card

1. Run `python tools/new_card.py "<Valve name or id>"`. It writes:
   - a `draft` entry in `data/classic_cards.json`, with metadata, `valve_text` and numbers taken from `data/catalog/catalog_mapping.json`;
   - locale entries for both skins in en and zh_CN;
   - `tests/cards/<id>.json`, with one empty case per Valve clause and `covers` taken from `tests/data/mechanics_tags.json`.
2. Write the rules. Copy the closest pattern from `docs/EFFECTS.md` (§5 of this spec), and prefer shorthands and `filter` over raw selectors and `where`.
3. Validate with `python tools/rules_hash.py`, then `godot --headless --path . -s tests/rules_schema_test.gd`. Errors name the card, the JSON path and the problem.
4. Fill in the spec cases using the checklist in §13.1, then run `godot --headless --path . -s tests/card_specs_test.gd -- --card <id>`.
5. Set `"status": "verified"` (or keep a `draft` that names its RQ), run `python tools/rules_hash.py` (it hashes the data too, so any edit changes `RULES_VERSION`), then run `test.ps1`.
6. Optionally add the card to a preset; `validate_preset` enforces the deck rules.

Rules of thumb:
- Numbers that appear in the card text belong at the top level and are read with `{"param": ...}`.
- Every random choice goes through `pick` or `chance`.
- Put a `pulse` op wherever Valve's text has □.
- When the glossary is silent, write an RQ entry instead of guessing silently.

---

## Coverage fixes (completeness review)

### C.1 Method

Every one of the 303 counted cards in `mechanics.json` (and, through its parent card, every one of the 75 Valve ability cards) was written out as a schema-4 entry, then checked mechanically. The two files are in the scratchpad next to this spec:

- `effects/coverage_cards.py`: the rules of all 303 cards, keyed by Valve id. They can seed `tools/new_card.py`.
- `effects/coverage.py`: builds each full entry (metadata from `mechanics.json` and Valve's set files), then
  1. validates it with this spec's vocabulary, using the validator in `synth_work/check_spec.py` extended to `enter` blocks, once with the vocabulary as originally written ("before") and once with the additions below ("after");
  2. cross-checks it against Valve data: `Active N` cooldowns, `charges`, the number of □ Pulse markers, "Get initiative", randomness, and each trigger and verb tag;
  3. applies a registry of semantic issues: cards whose entry validates but which the written semantics would get wrong, or leave undefined, in a reachable game state.

Run it with `python -I -X utf8 effects/coverage.py [--json out.json]`.

Classes used below:
- **A**: cannot be expressed with the schema.
- **B**: expressible, but wrong or undefined in a reachable state under the semantics as written.
- **C**: correct, but only by an unstated assumption; now made explicit.

### C.2 Results

| | Before the fixes | After the fixes |
|---|---|---|
| Cards whose entry validates (class A gaps) | 303 / 303 (no class A gap; natives still 0) | 303 / 303 |
| Cards that validate, pass every Valve cross-check and have no class B issue | **287 / 303** | **303 / 303** |
| Valve ability cards whose parent card is correct | 68 / 75 | 75 / 75 |

The vocabulary itself was complete: every verb, target, trigger, duration and condition tag maps to an op, selector, event, keyword or rules key. The gaps were in semantics and state. The only vocabulary addition is the `source_kind` filter key, which is sugar.

Three findings came only from comparing against Valve's raw data rather than the card text:
- **Eclipse** is printed with `"charges": 1`.
- **Bitter Enemies** is printed with `"charges": 3`.
- **Smash Their Defenses!** has a □ marker ("Condemn an improvement. □ Draw a card."); its entry is `condemn → pulse → draw`.

### C.3 Class B issues (16 cards) and their fixes

| Fix | Problem in the spec as written | Cards | Change | Where |
|---|---|---|---|---|
| **CF-1** | `move` did not define (a) whether a set moved to `"random_other"` gets one roll or one per unit, or (b) what a `position` index means for a move inside the same lane, where leaving the old slot compacts the lane and shifts indexes. `lane` had no default | Primal Roar, Nyctasha's Guard (a); Winter Wyvern, Ball Lightning into its own lane (b) | One unit at a time in canonical order, with an independent lane roll and `_spawn` roll per unit. Same-lane moves: positions come from the board with the mover in place; vacate without compacting, `_place`, then compact. `lane` defaults to the current lane | §3.7 `move` |
| **CF-2** | Card-instance counters started at 0. Valve prints Eclipse with 1 charge, so an Eclipse never touched by Luna, or a Multicast base copy, did nothing | Eclipse, Luna, Ogre Magi | A missing counter reads the card's printed `charges`; `card_counter` starts from it; Eclipse gets `"charges": 1` | §2.5, §3.1, §3.5, §3.7, §5.14 |
| **CF-3** | Single-object fields (`price`, `stat … of`, and others) given a `$v` captured from a selection were undefined. Ravenhook must use the same random item for `condemn` and for its gold | Ravenhook | A singleton list resolves to its element; an empty one gives 0 or a fizzle; a list of fixed size above 1 is a compile error | §3.3, §3.14 |
| **CF-4** | `round_log.hits` was written only by `Combat.resolve`, so battle damage dealt in Friendly Fire, Gank or Duel was missed by "this round" checks | Rebel Instigator | `Combat.battle` writes `round_log.hits`; `_damage_structure` is the single writer of `tower_hit` | §4.5 |
| **CF-5** | Settle clamped `max_mana` at 0 in place, which lost information. Example: round 1 (max 3) with The Tyler Estate (−2), Tyler Estate Censor (−1) and Mana Drain (−2) drops to 0; when Mana Drain expires the maximum came back as 2 instead of 0 | The Tyler Estate, Tyler Estate Censor, Arcane Censure, Mana Drain, Routed | New `max_mana_base`. The floor is applied only to the derived `max_mana`, and current mana moves by the actual change | §2.3, §4.4, I5 |
| **CF-7** | `start()` never emitted `deployment`, so a Venomancer or Prellex among heroes 1 to 3 summoned nothing in round 1. The spec did not say whether that was intended | Venomancer, Prellex | Round-1 deployment hooks after the initiative roll, with a switch (RQ-49) | §4.6 |

### C.4 Class C clarifications

| Fix | Clarification | Cards | Where |
|---|---|---|---|
| **CF-6** | `$e.source` can be a tower string (Burning Oil's Retaliate). "When a unit deals battle damage to Viper" must exclude it; this was possible with a `where`, and is now also the filter key `source_kind` | Viper | §3.8 |
| **CF-8** | RQ-27 is closed by Valve data: Bitter Enemies starts with 3 charges, the same field as March of the Machines | Bitter Enemies, March of the Machines | §5.7, §14 |
| **CF-9** | The round draw happens before placement, so Hourglass sees it only from a host already in a lane, and the lock lasts the new round (RQ-51) | Claszureme Hourglass | §4.6 |
| **CF-10** | Equipping is legal while stunned. It is Caught Unprepared's only exit | Caught Unprepared | §3.2, §4.7 |
| **CF-11** | A Grant has no `health` key. Item `health` compiles to `max_health`; the first encoding of Stonehall Cloak used `health` and was rejected | Stonehall Cloak (and any granted "+N Health") | §3.1, §3.14 |
| **CF-12** | `enter` blocks are validated, and a Valve-parity meta test (cooldowns, charges, □ count, initiative, randomness, tags) runs over every card | Jasper Daggers (the only `enter`), all cards | §3.14, §13.7 |

### C.5 Rules-timing review (no change needed)

These were checked against the glossary and are consistent with the spec as written:
- Triggers are collected at emit time from live sources and resolve in batches; `filter` and `where` act as an intervening "if" (March of the Machines, Bitter Enemies).
- `battle_damage` triggers fire before the combat Pulse, so Ursa and Viper effects on units that die in that combat fizzle.
- `next_combat` expires before after-combat triggers.
- A hero's bounty is read before its `until death` entries are purged in the Fountain (Track, Revtel Signet Ring).
- Hacks resolve after the card and its Pulse, but before `card_played`.
- Glyph of Confusion stuns deployment entrants after `end_of_round`, so the stun covers the new round.
- Deaths in the same Pulse do not see each other (Pit Fighter, Cloak of Endless Carnage, Poaching Knife on a host that dies in the same Pulse).

### C.6 Questions that remain open

Each has a default and a single switch or entry, and is pinned by a named test:
- **RQ-16**: Chain Frost when the previous unit has no neighbor. The card stays `draft`.
- **RQ-20**: initiative after Enough Magic!. The card stays `draft`.
- **RQ-22**: Kanna's lane resolution. Draft.
- **RQ-24**: whether hero actives start ready.
- **RQ-28**: rounding of "half" and of evenly divided damage.
- **RQ-29**: summoned Meepo.
- **RQ-37**: per-batch versus per-trigger resolution.
- **RQ-49** (new): round-1 deployment hooks. Default yes, low confidence.
- **RQ-50** (new): Assassin's Shadow counts itself. Default yes.
- **RQ-51** (new): Hourglass and the round draw. Default: no lock from a host redeployed that phase.
- **RQ-52** (new): current mana regained when a −Mana effect ends at 0 mana. Default: yes.

None of these needs a native or a schema change to flip.
