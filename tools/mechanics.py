#!/usr/bin/env python3
"""Mechanics taxonomy for every Artifact Classic card (Valve final data).

Reads (read-only):
  * Valve card-set JSON (set 00 + set 01, final Classic text): --set00, --set01
  * Valve localization files (glossary keyword tags [g:NNN[...]], Pulse markers
    and "Active (cooldown)" markup): --loc00, --loc01
  * Valve glossary: --glossary
  * Project data: data/classic_cards.json (implemented), data/catalog/
    catalog_mapping.json (remaining cards), data/locale/cards.json (skin names)

Writes:
  * docs/design/MECHANICS.md        frequency tables, hard cards, rules questions, engine map (--md)
  * tests/data/mechanics_tags.json  per card: Valve text, clauses and the trigger, verb, target and
                                    duration tags, Pulse markers, cooldowns and charges (--tags); read
                                    by tools/migrate_rules.py (valve_text), tools/new_card.py and
                                    tests/rules_schema_test.gd (Valve parity)
  * the full inventory, when --json PATH is given (about 760 KB; not committed)

The Valve files are not in the repository (docs/design/EFFECT_SYSTEM_SPEC.md, Sources). The set
files must be Valve's final card-set API files (set0_C0748A17E2C08252A9CCE75BB593E62D71DCDA77.json and
set1_29AA36A590C46C60AF09F5E97D6D5C168FCE7AB1.json from the card-set CDN), saved by default as
.tools/valve_set00_final.json and .tools/valve_set01_final.json. The older .tools/valve_api_set0X.json
snapshots predate the final balance patch (other names and texts) and give a different inventory.

Usage:  python -I tools/mechanics.py [--set00 F] [--set01 F] [--loc00 F] [--loc01 F] [--glossary F]
Deterministic: no randomness, sorted output.
"""
import argparse
import html
import json
import os
import re
import sys
from collections import Counter, defaultdict, OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = ROOT
VALVE_FILES = [
    os.path.join(ROOT, ".tools", "valve_set00_final.json"),
    os.path.join(ROOT, ".tools", "valve_set01_final.json"),
]
LOC_FILES = [
    os.path.join(ROOT, ".tools", "valve_card_set_00_english.txt"),
    os.path.join(ROOT, ".tools", "valve_card_set_01_english.txt"),
]
GLOSSARY_FILE = os.path.join(ROOT, ".tools", "valve_glossary.txt")
CLASSIC_FILE = os.path.join(ROOT, "data", "classic_cards.json")
MAPPING_FILE = os.path.join(ROOT, "data", "catalog", "catalog_mapping.json")
LOCALE_FILE = os.path.join(ROOT, "data", "locale", "cards.json")
OUT_JSON = None
OUT_MD = os.path.join(ROOT, "docs", "design", "MECHANICS.md")
OUT_TAGS = os.path.join(ROOT, "tests", "data", "mechanics_tags.json")
TAG_FIELDS = ("triggers", "verbs", "targets", "durations")

# --------------------------------------------------------------------------
# Glossary tag ids used by Valve's localization markup ([g:ID[text]]).
GLOSSARY_TAGS = {
    0: "Hero", 1: "Creep", 2: "Tower", 3: "Improvement", 4: "Spell", 5: "Item",
    200: "Before the action phase", 202: "After the combat phase", 203: "Combat phase",
    204: "Deployment phase", 205: "Shopping phase", 300: "Fountain",
    400: "Battle", 401: "Modify", 402: "Purge", 403: "Taunt", 404: "Disarm", 405: "Stun",
    406: "Silence", 407: "Lock", 408: "Condemn", 409: "Summon",
    500: "Bounty", 501: "Siege", 502: "Cleave", 503: "Retaliate", 504: "Armor",
    505: "Regeneration", 506: "Death Shield", 507: "Damage Immunity", 508: "Piercing",
    509: "Attack", 510: "Health", 511: "Mana", 512: "Soulbound",
    600: "Enemy Neighbors", 601: "Allied Neighbors", 602: "Play Effect", 603: "Death Effect",
    604: "Get Initiative", 606: "Unblocked", 607: "Unit", 608: "Pulse", 609: "Battle Damage",
    610: "Rapid Deployment", 611: "Pierce",
}
# Keywords that carry rules (the stat/type words above are kept but marked basic).
BASIC_TAGS = {"Hero", "Creep", "Tower", "Improvement", "Spell", "Item", "Attack", "Health",
              "Armor", "Mana", "Unit"}

# --------------------------------------------------------------------------
# Taxonomy definitions (id -> description). Frequency tables use these ids.
TRIGGERS = OrderedDict([
    ("play", "Spell / consumable resolves when cast (action phase)"),
    ("play_effect", "Creep 'Play Effect': when the creep card is played from hand"),
    ("equip_effect", "Item 'Equip Effect': when the item is equipped"),
    ("equip", "Equipment: continuous effect while equipped ('Equipped hero has ...')"),
    ("continuous", "Continuous effect / aura ('has', 'have'), recomputed on every pulse"),
    ("active", "Active ability with cooldown (hero, creep, item or improvement)"),
    ("before_action", "Before the action phase of the lane (simultaneous)"),
    ("after_combat", "After the combat phase of the lane (simultaneous)"),
    ("deployment_phase", "Each deployment phase (summons, deployment redirection)"),
    ("round_draw", "Round draw (extra card each round)"),
    ("self_death", "'Death Effect': after this unit dies"),
    ("ally_death", "After an allied unit dies (neighbor / Melee Creep filter)"),
    ("enemy_death", "After an enemy unit dies (neighbor / hero / creep filter)"),
    ("hero_death", "After any hero dies"),
    ("blocker_death", "After the unit blocking this one dies"),
    ("after_you_play", "After you play a card (colour / type / cost filter)"),
    ("after_opponent_plays", "After the opponent plays a card (spell filter)"),
    ("battle_damage_dealt", "When this deals battle damage to a unit"),
    ("battle_damage_taken", "When a unit deals battle damage to this"),
    ("unit_enters_lane", "Whenever any unit enters this lane"),
    ("improvement_enters_lane", "Whenever an enemy improvement enters this lane"),
    ("opponent_draws", "Whenever the opponent draws a card"),
    ("shop_phase", "Shopping phase price modifier"),
    ("hacked_card_played", "Text granted to a card in hand fires when that card is played"),
])

TARGETS = OrderedDict([
    ("self", "This card / unit / improvement / item"),
    ("equipped_hero", "The hero this item is equipped to"),
    ("unit", "A chosen unit (hero or creep, either side)"),
    ("hero", "A chosen hero (either side)"),
    ("creep", "A chosen creep (either side)"),
    ("colour_hero", "A chosen hero of a colour (red / black / green)"),
    ("allied_unit", "A chosen ally"),
    ("allied_hero", "A chosen allied hero (optionally coloured)"),
    ("enemy_unit", "A chosen enemy unit"),
    ("enemy_hero", "A chosen enemy hero"),
    ("enemy_creep", "A chosen enemy creep"),
    ("all_units", "Every unit (both sides)"),
    ("all_heroes", "Every hero (both sides)"),
    ("all_allies", "Every ally"),
    ("all_allied_heroes", "Every allied hero"),
    ("all_allied_creeps", "Every allied creep"),
    ("allied_melee_creeps", "Allied Melee Creeps"),
    ("all_enemies", "Every enemy unit"),
    ("all_enemy_heroes", "Every enemy hero"),
    ("all_enemy_creeps", "Every enemy creep"),
    ("enemies_across_empty", "Every enemy across from an empty combat position"),
    ("fountain_heroes", "Heroes in the Fountain"),
    ("allied_neighbors", "Allied neighbors (left/right in own row)"),
    ("enemy_neighbors", "Enemy neighbors (three enemy positions across)"),
    ("blocker", "The unit blocking X (its combat target across)"),
    ("attackers", "Units whose combat target is X"),
    ("battle_victims", "Each unit X deals battle damage to"),
    ("random_unit", "Random unit (ally or enemy)"),
    ("random_enemy", "Random enemy unit"),
    ("random_ally", "Random ally"),
    ("random_allied_hero", "Random allied hero"),
    ("random_enemy_neighbor", "Random enemy neighbor"),
    ("enemy_tower", "The enemy tower (this lane)"),
    ("allied_tower", "Your tower (this lane)"),
    ("both_towers", "Both towers of this lane"),
    ("all_towers", "Every tower (all lanes)"),
    ("random_allied_tower", "Random allied tower in any lane"),
    ("improvement", "A chosen improvement"),
    ("random_enemy_improvement", "Random enemy improvement"),
    ("all_enemy_improvements", "All enemy improvements (this lane)"),
    ("all_equipped_items", "All equipped items"),
    ("random_equipped_item", "Random item equipped by a unit"),
    ("equipped_items_of", "Each item equipped by a unit"),
    ("secret_shop", "Secret Shop offer"),
    ("own_hand", "Your hand"),
    ("own_hand_random", "Random card in your hand"),
    ("own_hand_and_deck", "Cards in your hand or deck"),
    ("opponent_hand_random", "Random card(s) in the opponent's hand"),
    ("drawn_card", "The card just drawn"),
    ("played_card", "The card just played"),
    ("lane_choice", "A chosen lane"),
    ("other_lane", "Another lane (chosen)"),
    ("random_other_lane", "Random other lane"),
    ("empty_position", "Empty combat position"),
    ("combat_target", "Combat target choice"),
    ("fountain", "The Fountain (destination)"),
    ("player_gold", "Gold"),
    ("tower_mana", "Tower mana"),
    ("count_enemies", "Count of enemies (scaling)"),
    ("count_damaged_units", "Count of damaged units (scaling)"),
    ("random_adjacent_unit", "Random unit left/right of the previous target (bounce)"),
    ("trigger_subject", "The unit that caused the trigger (entered / dealt damage)"),
    ("opponent", "The opponent (receives the created unit / is affected)"),
])

VERBS = OrderedDict([
    ("damage", "Deal damage (reduced by armor)"),
    ("piercing_damage", "Deal piercing damage (ignores armor)"),
    ("damage_split", "Damage evenly divided among targets"),
    ("tower_damage", "Damage to a tower"),
    ("damage_bonus", "Bonus battle damage vs heroes / towers"),
    ("heal", "Heal N"),
    ("full_heal", "Fully heal"),
    ("tower_heal", "Heal a tower"),
    ("modify", "Modify: permanent buff/debuff (kept through death)"),
    ("temp_buff", "Give ... this round / until X (temporary)"),
    ("stat_attack", "Attack change"),
    ("stat_armor", "Armor change"),
    ("stat_health", "Health change"),
    ("siege", "Siege"),
    ("cleave", "Cleave"),
    ("retaliate", "Retaliate"),
    ("regeneration", "Regeneration"),
    ("pierce", "Pierce (battle damage is piercing)"),
    ("bounty", "Bounty change"),
    ("rapid_deployment", "Rapid Deployment"),
    ("mana_change", "Tower mana +/- (temporary or modified)"),
    ("mana_restore", "Restore mana"),
    ("gold_gain", "Get gold"),
    ("gold_spend", "Spend all gold"),
    ("gold_double", "Double gold"),
    ("cost_reduction", "Gold cost reduction (Shop Deed)"),
    ("draw", "Draw cards"),
    ("discard", "Discard"),
    ("add_card_to_hand", "Put a card into hand"),
    ("copy_card", "Base copy of a card"),
    ("summon", "Summon unit(s) into random empty combat position"),
    ("condemn", "Condemn (destroy; unit, improvement or item)"),
    ("stun", "Stun (silence + disarm)"),
    ("silence", "Silence"),
    ("disarm", "Disarm"),
    ("taunt", "Taunt"),
    ("lock", "Lock cards in hand"),
    ("purge", "Purge (opponent's) effects"),
    ("swap", "Swap positions"),
    ("move", "Move / relocate a unit (lane or position)"),
    ("change_combat_target", "Choose / change combat target"),
    ("battle", "Units battle outside combat"),
    ("return_to_fountain", "Return a hero to the Fountain"),
    ("steal_control", "Get control of an enemy unit"),
    ("death_shield", "Death Shield"),
    ("damage_immunity", "Damage Immunity"),
    ("get_initiative", "Get initiative"),
    ("quicken", "Quicken (cooldown -1, min 1)"),
    ("charges", "Counters / charges"),
    ("repeat", "Repeat N times / once per charge"),
    ("random_chance", "Percentage chance"),
    ("scaling_x", "X equal to / for each (dynamic amount)"),
    ("grant_text", "Grant a quoted ability (modify with \"...\")"),
    ("hack_hand_card", "Modify a card in hand with quoted text"),
    ("play_restriction", "Restrict what can be played"),
    ("activation_condition", "Ability 'May only be used if ...'"),
    ("end_action_phase", "Proceed to the combat phase"),
    ("deploy_redirect", "Redirect deployment (Kanna)"),
    ("soulbound", "Soulbound"),
    ("lethal", "Condemn each unit dealt battle damage"),
    ("discard_hand", "Discard your hand"),
])

DURATIONS = OrderedDict([
    ("permanent", "Modify / summon / damage: lasts"),
    ("this_round", "Until end of round"),
    ("until_next_combat", "Until end of its next combat phase"),
    ("until_death", "Until it dies (removed in the Fountain)"),
    ("until_equip", "Until the hero equips an item"),
    ("continuous", "While the source is in play"),
])

# --------------------------------------------------------------------------
# Current engine support (scripts/core/match_engine.gd unless noted).
# status: full | partial | none
E = "scripts/core/match_engine.gd"
ENGINE_SUPPORT = {
    # triggers
    "trigger:play": ("full", f"{E}:_play", "spell / consumable effect switch on card.effect"),
    "trigger:play_effect": ("none", f"{E}:_play", "creep cards only place a unit (_place + _roll_arrow)"),
    "trigger:equip_effect": ("none", f"{E}:_play 'equip'", "equip only stores the slot and adjusts health"),
    "trigger:equip": ("partial", f"{E}:_item_stat, _play 'equip'", "attack/armor/health only; slot replacement"),
    "trigger:continuous": ("partial", f"{E}:attack_of/armor_of/_item_stat", "neighbor_attack, neighbor_armor, global_attack, item stats; no general aura layer"),
    "trigger:active": ("partial", f"{E}:legal_actions/apply_action 'ability'", "only hero ability 'draw' (J'Muy); cooldown tick in _begin_deployment"),
    "trigger:before_action": ("none", "-", "no lane-start hook; lane opens in _pass"),
    "trigger:after_combat": ("partial", f"{E}:_resolve_combat", "only combat_growth_attack/health (Savage Wolf)"),
    "trigger:deployment_phase": ("none", f"{E}:_reveal_deployment", "no per-card deployment hook"),
    "trigger:round_draw": ("none", f"{E}:_reveal_deployment", "fixed _draw(player, 2)"),
    "trigger:self_death": ("none", f"{E}:_clean_dead", "no death events beyond bounty/fountain"),
    "trigger:ally_death": ("none", f"{E}:_clean_dead", ""),
    "trigger:enemy_death": ("none", f"{E}:_clean_dead", ""),
    "trigger:hero_death": ("none", f"{E}:_clean_dead", ""),
    "trigger:blocker_death": ("none", f"{E}:_clean_dead", ""),
    "trigger:after_you_play": ("partial", f"{E}:_static_field", "hard-coded Zeus Static Field after a blue spell"),
    "trigger:after_opponent_plays": ("none", "-", ""),
    "trigger:battle_damage_dealt": ("none", f"{E}:combat_preview", "damage is aggregated per target; no per-hit events"),
    "trigger:battle_damage_taken": ("none", f"{E}:combat_preview", ""),
    "trigger:unit_enters_lane": ("none", f"{E}:_place", ""),
    "trigger:improvement_enters_lane": ("none", "-", "no improvements"),
    "trigger:opponent_draws": ("none", f"{E}:_draw", ""),
    "trigger:shop_phase": ("none", f"{E}:_prepare_shop", "fixed prices"),
    "trigger:hacked_card_played": ("none", "-", "hand holds card ids only (strings)"),
    # targets
    "target:self": ("partial", f"{E}:_make_unit", "only via ad-hoc unit fields"),
    "target:equipped_hero": ("partial", f"{E}:_item_stat", "stat items only"),
    "target:unit": ("full", f"{E}:_add_target_actions", "target 'unit'"),
    "target:hero": ("full", f"{E}:_add_target_actions", "target 'hero'"),
    "target:creep": ("full", f"{E}:_add_target_actions", "target 'creep'"),
    "target:colour_hero": ("partial", f"{E}:_add_target_actions", "red only (red_hero, ally_red_hero)"),
    "target:allied_unit": ("none", f"{E}:legal_actions", "no 'ally' target kind"),
    "target:allied_hero": ("partial", f"{E}:_add_target_actions", "ally_hero / ally_red_hero"),
    "target:enemy_unit": ("partial", f"{E}:legal_actions", "'enemy' side selection exists, no card uses it"),
    "target:enemy_hero": ("full", f"{E}:_add_target_actions", "enemy_hero"),
    "target:enemy_creep": ("none", "-", ""),
    "target:all_units": ("partial", f"{E}:_play 'condemn_lane'", "condemn only"),
    "target:all_heroes": ("none", "-", ""),
    "target:all_allies": ("none", "-", ""),
    "target:all_allied_heroes": ("none", "-", ""),
    "target:all_allied_creeps": ("full", f"{E}:_play 'modify_creeps'", ""),
    "target:allied_melee_creeps": ("none", "-", ""),
    "target:all_enemies": ("full", f"{E}:_play 'area_damage'", "damage only"),
    "target:all_enemy_heroes": ("partial", f"{E}:_play 'global_hero_damage'", "all lanes, damage only"),
    "target:all_enemy_creeps": ("none", "-", ""),
    "target:enemies_across_empty": ("none", "-", "positional filter"),
    "target:fountain_heroes": ("none", "-", ""),
    "target:allied_neighbors": ("partial", f"{E}:_play 'silence' neighbors, attack_of/armor_of", "silence + auras"),
    "target:enemy_neighbors": ("partial", f"{E}:_battle_neighbors/_static_field", "battle + Static Field"),
    "target:blocker": ("partial", f"{E}:combat_target_of", "query exists, no effect uses it"),
    "target:attackers": ("none", "-", "no reverse lookup of attackers"),
    "target:battle_victims": ("none", "-", ""),
    "target:random_unit": ("none", "-", ""),
    "target:random_enemy": ("none", "-", ""),
    "target:random_ally": ("none", "-", ""),
    "target:random_allied_hero": ("none", "-", ""),
    "target:random_enemy_neighbor": ("none", "-", ""),
    "target:enemy_tower": ("full", f"{E}:_damage_structure", ""),
    "target:allied_tower": ("partial", f"{E}:_play 'mana'", "mana only; no tower heal/armor/retaliate"),
    "target:both_towers": ("none", "-", ""),
    "target:all_towers": ("none", "-", ""),
    "target:random_allied_tower": ("none", "-", ""),
    "target:improvement": ("none", "-", "no improvements in state"),
    "target:random_enemy_improvement": ("none", "-", ""),
    "target:all_enemy_improvements": ("none", "-", ""),
    "target:all_equipped_items": ("none", "-", ""),
    "target:random_equipped_item": ("none", "-", ""),
    "target:equipped_items_of": ("none", "-", ""),
    "target:secret_shop": ("partial", f"{E}:_prepare_shop", "offer exists; no price modifiers"),
    "target:own_hand": ("partial", f"{E}:_play 'condemn' discard_random", ""),
    "target:own_hand_random": ("full", f"{E}:_play 'condemn' discard_random", ""),
    "target:own_hand_and_deck": ("none", "-", "cards are plain ids; no per-card state"),
    "target:opponent_hand_random": ("none", "-", "cards are plain ids; no per-card state"),
    "target:drawn_card": ("none", f"{E}:_draw", ""),
    "target:played_card": ("none", f"{E}:_play", "card id known at play time; no copy-to-hand"),
    "target:lane_choice": ("partial", f"{E}:legal_actions cross_lane", "only unit targets in any lane"),
    "target:other_lane": ("none", "-", ""),
    "target:random_other_lane": ("none", "-", ""),
    "target:empty_position": ("partial", f"{E}:creep_positions/_spawn", "placement helpers exist"),
    "target:combat_target": ("full", f"{E}:combat_targets", "Battlefield Control destinations"),
    "target:fountain": ("full", f"{E}:_enter_fountain", ""),
    "target:player_gold": ("partial", f"{E}:_clean_dead", "bounty only"),
    "target:tower_mana": ("partial", f"{E}:_play 'mana'", "temporary bonus only"),
    "target:count_enemies": ("none", "-", ""),
    "target:count_damaged_units": ("none", "-", ""),
    "target:random_adjacent_unit": ("none", "-", ""),
    "target:trigger_subject": ("none", "-", "needs trigger context (event payload)"),
    "target:opponent": ("partial", f"{E}:_clean_dead", "opponent receives bounty; no opponent-side summons"),
    # verbs
    "verb:damage": ("full", f"{E}:_damage_unit", ""),
    "verb:piercing_damage": ("full", f"{E}:_damage_unit(piercing)", ""),
    "verb:damage_split": ("none", "-", ""),
    "verb:tower_damage": ("full", f"{E}:_damage_structure", "no tower armor"),
    "verb:damage_bonus": ("full", f"{E}:battle_attack", "hero_bonus, hero_tower_bonus; tower-only bonus missing"),
    "verb:heal": ("full", f"{E}:_play 'heal'", ""),
    "verb:full_heal": ("none", "-", "(Fountain heals; no effect verb)"),
    "verb:tower_heal": ("none", "-", ""),
    "verb:modify": ("partial", f"{E}:_play 'modify'/'modify_creeps'", "attack/armor only, no modifier provenance (purge impossible)"),
    "verb:temp_buff": ("partial", f"{E}:_play 'buff'", "temp_attack / temp_armor / temp_siege"),
    "verb:stat_attack": ("full", f"{E}:attack_of", ""),
    "verb:stat_armor": ("full", f"{E}:armor_of", ""),
    "verb:stat_health": ("partial", f"{E}:_max_health", "items + wolf growth; no health modify verb"),
    "verb:siege": ("full", f"{E}:combat_preview", "siege, temp_siege"),
    "verb:cleave": ("none", f"{E}:combat_preview", ""),
    "verb:retaliate": ("none", f"{E}:combat_preview", ""),
    "verb:regeneration": ("none", f"{E}:_resolve_combat", ""),
    "verb:pierce": ("none", f"{E}:combat_preview", "spell piercing exists; unit Pierce does not"),
    "verb:bounty": ("partial", f"{E}:_clean_dead", "fixed 5 / 1, no modifiers"),
    "verb:rapid_deployment": ("full", f"{E}:_clean_dead", "rapid_deployment flag"),
    "verb:mana_change": ("partial", f"{E}:_play 'mana', _begin_deployment", "temporary + only own tower"),
    "verb:mana_restore": ("none", "-", ""),
    "verb:gold_gain": ("partial", f"{E}:_clean_dead", "bounty only"),
    "verb:gold_spend": ("none", "-", ""),
    "verb:gold_double": ("none", "-", ""),
    "verb:cost_reduction": ("none", "-", ""),
    "verb:draw": ("full", f"{E}:_draw", ""),
    "verb:discard": ("full", f"{E}:_play 'condemn' discard_random", "random discard only"),
    "verb:add_card_to_hand": ("partial", f"{E}:apply_action 'buy'", "buying only"),
    "verb:copy_card": ("none", "-", ""),
    "verb:summon": ("partial", f"{E}:_spawn/_make_creep", "Melee Creep only (_make_creep)"),
    "verb:condemn": ("partial", f"{E}:_play 'condemn'/'condemn_lane'", "units only, health = 0"),
    "verb:stun": ("none", "-", "RULES.md: stun absent"),
    "verb:silence": ("full", f"{E}:_play 'silence', legal_actions", "round-long flag"),
    "verb:disarm": ("none", "-", ""),
    "verb:taunt": ("none", "-", ""),
    "verb:lock": ("none", "-", ""),
    "verb:purge": ("none", "-", ""),
    "verb:swap": ("none", "-", ""),
    "verb:move": ("partial", f"{E}:_remove_from_lane/_place", "helpers exist; no move effect"),
    "verb:change_combat_target": ("full", f"{E}:_play 'redirect'/'siege_buff'", "combat_target / arrow"),
    "verb:battle": ("partial", f"{E}:_battle_neighbors", "hero vs its enemy neighbors only"),
    "verb:return_to_fountain": ("full", f"{E}:_play 'return_hero'", ""),
    "verb:steal_control": ("none", "-", ""),
    "verb:death_shield": ("none", "-", ""),
    "verb:damage_immunity": ("none", "-", ""),
    "verb:get_initiative": ("full", f"{E}:_finish_action(keep_initiative)", ""),
    "verb:quicken": ("none", "-", ""),
    "verb:charges": ("none", "-", ""),
    "verb:repeat": ("partial", f"{E}:_play 'summon' amount", "fixed repeat for summons only"),
    "verb:random_chance": ("none", "-", "engine rng exists (rng.randi_range)"),
    "verb:scaling_x": ("none", "-", ""),
    "verb:grant_text": ("none", "-", ""),
    "verb:hack_hand_card": ("none", "-", ""),
    "verb:play_restriction": ("none", "-", ""),
    "verb:activation_condition": ("none", "-", ""),
    "verb:end_action_phase": ("none", "-", ""),
    "verb:deploy_redirect": ("none", "-", ""),
    "verb:soulbound": ("none", "-", ""),
    "verb:lethal": ("none", "-", ""),
    "verb:discard_hand": ("none", "-", ""),
    # durations
    "duration:permanent": ("full", "-", ""),
    "duration:this_round": ("partial", f"{E}:_begin_deployment", "temp_attack/armor/siege + silenced reset"),
    "duration:until_next_combat": ("none", "-", ""),
    "duration:until_death": ("none", "-", ""),
    "duration:until_equip": ("none", "-", ""),
    "duration:continuous": ("partial", f"{E}:attack_of/armor_of", "fixed aura fields"),
}

# --------------------------------------------------------------------------
# Curated knowledge (hard cards, divergences, rules questions).
HARD_REASONS = {
    10004: "Meepo: Poof moves between lanes to an allied Meepo, then a Pulse deals 2 to NEW enemy neighbors; Soulbound kills every allied Meepo in all lanes; summoned Meepos (Divided We Stand) are heroes that are not in the roster.",
    10005: "Divided We Stand summons a hero (Meepo) mid-game: needs a non-roster hero unit with bounty/fountain/colour rules and Soulbound linkage.",
    10006: "Luna: before-action random piercing ping plus charges written onto Eclipse cards in hand AND deck (per-card state on hidden cards).",
    10007: "Eclipse: repeat once per charge stored on this card instance; Pulse between hits; random enemy re-chosen each time (dead units excluded).",
    10010: "Winter Wyvern: move self to an empty combat position (same lane) and temporary attack; pathing/blocking recalculated.",
    10011: "Winter's Curse: disarm, then the target's allied neighbors battle it (battles initiated by the target's own allies, retaliate applies).",
    10017: "Chen: get control of an enemy creep (owner change, position on your side, bounty owner flips).",
    10224: "Helm of the Dominator: item active that steals an enemy creep (owner change).",
    10022: "Timbersaw: armor depends on number of current attackers and debuffs each attacker; recomputed whenever combat targets change.",
    10259: "Keenfolk Plate: Timbersaw-style attacker-count armor on an item.",
    10031: "Kanna: overrides where this round's random lane creeps deploy; interacts with the public pending-creep reveal (privacy) and with her own deployment choice.",
    10043: "Ogre Magi: 25% copy of the played blue spell's BASE card into hand (hidden RNG, card provenance).",
    10046: "Outworld Devourer: 50% chance restore 2 mana after any blue card (random on every play).",
    10064: "Crystal Maiden: once-per-lane-per-round tracking of the first allied spell, refunds mana in that lane.",
    10091: "Revtel Convoy: attack derived from your gold (half, rounding) - continuously recomputed.",
    10094: "Mercenary Exiles: spend all gold, X = half the gold spent (rounding).",
    10106: "Incarnation of Selemene: after any card you play, fully restore mana (infinite-mana loops need guards).",
    10115: "Ravenhook: condemn a random item of the blocker and gain its base gold cost.",
    10116: "Ravenous Mass: condemn allied neighbors, then absorb their attack and health (values read before condemn).",
    10133: "Champion of the Ancient: play-effect scaling by enemy count, including Cleave.",
    10148: "Fractured Timeline: random lock on a hidden opponent card each round (privacy + redacted views).",
    10156: "Bitter Enemies: counter decremented after combat, symmetric 6 tower damage when zero; initial charge count not in data.",
    10164: "Revtel Investments: charges each round, active converts to gold and condemns itself.",
    10178: "Grand Melee: conditional continuous aura (allied red hero in lane) granting Cleave to ALL heroes (both sides).",
    10182: "The Oath: play restriction on the active lane for its owner plus conditional +4 attack aura.",
    10187: "Glyph of Confusion: any unit entering the lane (deploy, summon, move, control change) is stunned this round.",
    10191: "Routed: targets enemy heroes in the Fountain; halves attack (rounding) and grants a hero a tower-mana debuff that follows the hero to whatever lane it deploys into.",
    10194: "Watchtower: reacts to the opponent playing an improvement into this lane.",
    10196: "...And One For Me: copies a random item equipped by a chosen hero into your hand as a base card.",
    10216: "Golden Ticket: get a random Secret Shop item (shop pool RNG, hidden card into hand).",
    10225: "Vesture of the Tyrant: grants Rapid Deployment and +3 Armor to the tower in the hero's lane (moves with the hero).",
    10232: "Seraphim Shield: -2 Attack to ALL units (both sides) in the lane from an item.",
    10235: "Book of the Dead: item with charges fed by allied Melee Creep deaths; active summons one Zombie per charge.",
    10241: "Claszureme Hourglass: whenever the opponent draws, lock that card (hidden information, simultaneous draws).",
    10255: "Shop Deed: Secret Shop prices reduced by base cost; stacks into negative prices (gold gain on purchase).",
    10256: "Jasper Daggers: Pierce on a hero plus equip-time Purge of opponent's effects (needs modifier provenance).",
    10262: "Nyctasha's Guard: move each enemy neighbor to a random other lane (multiple placements, re-pathing).",
    10263: "Apotheosis Blade: lethal-to-anything on battle damage, plus active condemning all enemy improvements and the blocker's items.",
    10293: "Primal Roar: stun the blocker of an allied red hero, then move that unit's allied neighbors to random other lanes.",
    10294: "Viper Strike: grants a before-action piercing damage trigger until the unit dies (not a modify; removed in Fountain/purge).",
    10302: "Self Sabotage: hacks two random cards in the opponent's hand with an on-play 6 damage to a random allied tower in any lane.",
    10318: "Chain Frost: 7 bounces to a random left/right neighbor of the previous unit with Pulses; get initiative.",
    10323: "Echo Slam: damage X = number of enemies, counted once at resolution.",
    10326: "Enough Magic!: ends the action phase immediately; initiative for the next lane is not specified.",
    10327: "Heroic Resolve: grants a cost-filtered after-you-play trigger (non-item card costing 2 or less) permanently (modify).",
    10349: "Rising Anger: same cost-filtered granted trigger as Heroic Resolve.",
    10331: "Wrath of Gold: spend all gold, repeat 4 damage to random ally OR enemy per gold spent (can be dozens of Pulses).",
    10359: "Buying Time: lock random hidden opponent cards.",
    10298: "Lost in Time: lock three random hidden opponent cards.",
    10360: "Friendly Fire: two enemies battle each other (retaliate, armor, pierce both ways).",
    10328: "Gank: allied black hero battles a unit in ANY lane (cross-lane battle).",
    10376: "Remote Detonation: positional filter 'across from an empty combat position'.",
    10396: "Caught Unprepared: stun that lasts until the hero equips an item (crosses rounds and the Fountain? see rules).",
    10399: "Relentless Pursuit: choose a unit in another lane, move a random allied black hero there, then damage.",
    10404: "The Cover of Night: move an allied black hero to another lane with a buff lasting until its next combat.",
    10413: "Forward Charge: all allies re-target straight ahead (unit or tower across) plus temporary Siege.",
    10422: "Whispers of Madness: stun an enemy and ALL allied heroes in all lanes (self-harm, colour availability).",
    10536: "Storm Spirit: cross-lane trigger on black cards played in any lane; buff lasts until end of its next combat phase.",
    10538: "Ball Lightning: move an allied black hero to an empty combat position in any lane (choose lane and slot).",
    10085: "Assassin's Shadow: attack scales down per ally (scope question: lane vs all lanes, self excluded).",
    10171: "Howling Mind: both players draw an extra card each round (symmetric draw count change).",
    10138: "Troll Soothsayer: extra card each round while alive (round draw hook).",
    10114: "Cursed Satyr: summons a Zombie for the opponent (owner != controller of the source).",
    10084: "Rebel Instigator: conditional self-copy after combat if it dealt battle damage to a creep this round (per-round battle log).",
    10132: "Red Mist Pillager: conditional self-copy after combat if it dealt battle damage to a tower this round.",
    10149: "Unearthed Secrets: conditional draw if your tower was dealt damage this round (per-round tower damage log).",
    10024: "Tidehunter: stun enemy neighbors and 50% independent stun roll for each other enemy.",
    10377: "Fog of War: independent 50% disarm roll per enemy.",
    10023: "Bounty Hunter: 50% before-action self buff.",
    10303: "Bellow: move a creep to a random other lane.",
    10379: "Intimidation: move a unit (hero or creep) to a random other lane.",
    10068: "Dark Seer: Surge moves another ally to another (chosen) lane.",
    10206: "Blink Dagger: item active moves equipped hero to another lane.",
    10203: "Phase Boots: item active swaps equipped hero with any ally (pathing keeps positions).",
    10063: "Mystic Flare: 12 damage evenly divided among a unit and its allied neighbors (rounding, armor per hit).",
    10342: "Pick a Fight: taunt plus choose a combat target for the taunting hero.",
}

# Divergences between implemented engine data (classic_cards.json) and Valve final text.
# Score 5 regardless of heuristics: each needs a subsystem of its own.
HARD_FIVE = {10004, 10005, 10006, 10007, 10017, 10031, 10043, 10182, 10187, 10191, 10224, 10241,
             10255, 10263, 10302, 10318, 10326, 10331, 10396}

# Glossary keywords implied by classified verbs / targets / triggers (Valve tags are sparse).
VERB_KEYWORDS = {
    "stun": "Stun", "silence": "Silence", "disarm": "Disarm", "taunt": "Taunt", "lock": "Lock",
    "purge": "Purge", "condemn": "Condemn", "summon": "Summon", "modify": "Modify", "battle": "Battle",
    "siege": "Siege", "cleave": "Cleave", "retaliate": "Retaliate", "regeneration": "Regeneration",
    "death_shield": "Death Shield", "damage_immunity": "Damage Immunity", "piercing_damage": "Piercing",
    "pierce": "Pierce", "bounty": "Bounty", "soulbound": "Soulbound", "rapid_deployment": "Rapid Deployment",
    "get_initiative": "Get Initiative", "return_to_fountain": "Fountain", "lethal": "Lethal",
}
TARGET_KEYWORDS = {"enemy_neighbors": "Enemy Neighbors", "allied_neighbors": "Allied Neighbors",
                   "random_enemy_neighbor": "Enemy Neighbors", "fountain_heroes": "Fountain"}
TRIGGER_KEYWORDS = {"before_action": "Before the action phase", "after_combat": "After the combat phase",
                    "deployment_phase": "Deployment phase", "play_effect": "Play Effect",
                    "self_death": "Death Effect", "battle_damage_dealt": "Battle Damage",
                    "battle_damage_taken": "Battle Damage"}

DIVERGENCES = {
    10402: "Tower Barrage: Valve final text is 'Deal 2 damage to each enemy.'; classic_cards.json sets include_tower=true (also damages the enemy tower). See rules question RQ-01.",
    10412: "Thunderstorm: Valve final text is 'Deal 4 damage to each enemy.'; classic_cards.json sets include_tower=true. See RQ-01.",
    10315: "Annihilation: Valve 'Condemn all units.'; engine condemns the active lane only (consistent with lane scope RQ-04), and pays bounty for every unit (RQ-02).",
    10308: "Coup de Grace: matches (discard random, then condemn a hero); no death-shield interaction yet.",
    10413: "Forward Charge: engine sets arrow 0 and combat_target -1 for every ally (straight ahead); Valve says 'change their combat target to the unit or tower across'. Equivalent unless a Taunt/forced target is later applied.",
    4010: "Battlefield Control: engine offers the tower when ANY of the three positions across is empty; see RQ-19 (tower should need the position directly across to be empty).",
    10288: "Berserker's Call: matches; retaliate/cleave/pierce are not applied in _battle_neighbors yet.",
}

RULES_QUESTIONS = [
    ("RQ-01", "Does 'each enemy' (Tower Barrage, Thunderstorm, Conflagration, Ignite, Echo Slam) include the enemy tower?",
     "No: 'enemy' means enemy units. March of the Machines says 'deal 2 damage to the enemy tower and 2 damage to each enemy', which would be redundant if towers were enemies; Echo Slam would count the tower. Engine currently adds the tower for Tower Barrage/Thunderstorm (include_tower) - recommend removing unless a reference match shows otherwise.",
     "Valve loc CardText_10291 (March of the Machines), CardText_10323 (Echo Slam); glossary DCG_Glossary_Unit ('Towers are not units'). Confidence: medium-high."),
    ("RQ-02", "Who gets bounty when a unit dies to its owner's own effect (Annihilation, Lich Sacrifice, Bracers of Sacrifice, At Any Cost)?",
     "The opponent of the dying unit's owner, always. The glossary defines Bounty as gold 'awarded to the opponent when this unit dies' with no exception. (A community glossary claims no gold for condemning your own cards; it is unsourced.)",
     "valve_glossary.txt DCG_Glossary_Bounty, DCG_Glossary_Creep; docs/RULES.md (engine already does this); counter-claim: .tools/artifact_compiled.json 'Condemn'. Confidence: medium."),
    ("RQ-03", "Lane scope of 'after you play ...' triggers (Zeus, Ogre Magi, Outworld Devourer, Path of the X, Tresdin's Standards, Coordinated Assault, Heroic Resolve...).",
     "Only cards played while the trigger source is in the active lane (an improvement: its own lane). Storm Spirit explicitly says 'in any lane' and Crystal Maiden 'in each lane', implying the default is the source's lane. Engine Static Field already scans the active lane only.",
     "Wiki Phases ('cards and abilities generally only affect the active lane, unless otherwise noted'); Valve text 10537, 10518. Confidence: medium."),
    ("RQ-04", "Default scope of 'allies', 'enemies', 'all units', 'all heroes', 'enemy heroes', 'allied heroes' without a lane qualifier.",
     "The active lane (for spells) or the source's lane (continuous / triggered). Only texts that say 'in all lanes', 'in any lane', 'every lane' or name the Fountain reach elsewhere (Drow, Thundergod's Wrath, Diabolic Revelation, Whispers of Madness, Rolling Storm, Routed).",
     "Wiki Phases; contrast Drow 'Other allies in all lanes' vs Disciple of Nevermore 'Other allies'. Confidence: medium-high."),
    ("RQ-05", "Who are a unit's 'attackers' (Timbersaw, Keenfolk Plate)?",
     "Enemy units in the lane whose current combat target is that unit (not cleave sources, not spell battles). Recomputed whenever combat targets change (taunt, redirect, death, placement).",
     "Glossary DCG_Glossary_Battle / Unblocked (combat target); patch 2018-12-20 Reactive Armor text. Confidence: medium."),
    ("RQ-06", "When does Retaliate apply?",
     "Whenever the unit is attacked during ANY battle (combat phase, Duel, Gank, Friendly Fire, Berserker's Call, Winter's Curse), once per attacker, even if the retaliator is stunned or disarmed. It is reduced by the attacker's armor (armor reduces each damage source). Cleave and spell damage do not trigger it.",
     "Glossary DCG_Glossary_Retaliate ('even outside of the combat phase'), DCG_Glossary_Stunned, DCG_Glossary_Disarmed, DCG_Glossary_Armor. Confidence: high (armor reduction: medium)."),
    ("RQ-07", "Do Siege / Cleave apply when the unit is disarmed, stunned, or attacking the tower?",
     "No. Both are 'when blocked during the combat phase, in addition to battle damage'; a disarmed unit does not attack; an unblocked unit (combat target = tower) deals normal damage to the tower and nothing extra. Siege counts for diagonal targets (combat target is a unit, so it is blocked). Tower armor (Steel Reinforcement) reduces siege.",
     "Glossary DCG_Glossary_Siege, _Cleave, _Unblocked, _Disarm. Confidence: high (tower armor: medium)."),
    ("RQ-08", "Cleave: which units, and is it armor-reduced / piercing?",
     "The blocking unit's (target's) allied neighbors (left/right in the target's row). Each cleave hit is reduced by that unit's armor; a unit with Pierce makes it piercing because cleave is battle damage.",
     "Glossary DCG_Glossary_Cleave, _BattleDamage, _BattleDamageIsPiercing. Confidence: medium."),
    ("RQ-09", "Regeneration timing and cap.",
     "Heals during the combat phase simultaneously with combat damage and is applied before the death check (can save a unit), capped at max health; applies even if the unit is not attacked. Tower regeneration (Path of the Dreamer) heals the tower in combat.",
     "Glossary DCG_Glossary_Regeneration; wiki Phases ('Health Regeneration resolves at the same time as combat damage'). Confidence: high (cap: medium)."),
    ("RQ-10", "Damage Immunity vs condemn / lethal / Death Shield.",
     "Immune units take no damage from any source but still die to condemn (Lethal, Annihilation, Slay). A Death Shield saves from condemn as well as damage. Lethal effects ('condemn each unit it deals battle damage to') need damage actually dealt, so an immune unit is not condemned by them.",
     "Glossary DCG_Glossary_DamageImmunity, _Condemn, _DeathShield, _LethalToCreeps. Confidence: high (lethal vs immunity: medium)."),
    ("RQ-11", "Death Shield stacking and duration.",
     "A unit holds at most one; giving another is wasted. When it would die it removes the shield and survives at 1 health. 'this round' shields (Cheating Death) expire at end of round; play-effect shields (Relentless Zombie) last until used.",
     "Glossary DCG_Glossary_DeathShield; patch 2018-12-20 Cheating Death text. Confidence: high."),
    ("RQ-12", "What does 'Purge your opponent's effects' remove?",
     "Modifications and temporary effects whose source is the opponent (stun/silence/disarm, -armor modifies, Viper Strike, Track, Caught Unprepared), not damage, not base abilities, not equipped items, not continuous auras from neighbors/improvements. Requires modifier provenance (source player) on every effect.",
     "Glossary DCG_Glossary_Purge; patch 2018-12-20 Jasper Daggers. Confidence: high."),
    ("RQ-13", "What survives the Fountain?",
     "Equipped items and Modify effects survive; temporary effects and 'until it dies' effects (Viper Strike, Track, Caught Unprepared) are removed; the hero is fully healed. Charges/hacks on hand cards are unaffected.",
     "Glossary DCG_Glossary_Fountain, _Modify; wiki Fountains. Confidence: high."),
    ("RQ-14", "Lock details.",
     "A locked card cannot be played; at end of round every locked card loses 1 Lock; Lock stacks additively. Lost in Time / Buying Time pick distinct random cards in hand (fewer if the hand is smaller). Hourglass locks the drawn card itself.",
     "Glossary DCG_Glossary_Lock, _Locked. Confidence: high (distinct picks: medium)."),
    ("RQ-15", "Pulse semantics inside multi-step effects.",
     "At each Pulse continuous effects update, reactive abilities process, and condemned / lethally damaged units are destroyed (deaths, bounty, pathing reset). Random choices after a Pulse exclude units that just died. Valve marks Pulses in the localization (g:608) for Poof, Chain Frost, Eclipse, Wrath of Gold, etc.",
     "Glossary DCG_Glossary_ZToken; Valve loc [g:608] markers (pulse counts in mechanics.json). Confidence: high."),
    ("RQ-16", "Chain Frost bounce target.",
     "'its' is the unit damaged by the previous hit; candidates are that unit's existing allied neighbors (same row). Best guess: if it has no neighbor (or both died), the remaining bounces fizzle. Needs a reference match.",
     "Valve text 10318; glossary Allied Neighbors. Confidence: low."),
    ("RQ-17", "Where do summoned / moved / stolen units go?",
     "Summon: a random empty combat position on the owner's side of the named lane (glossary). Moves to another lane and stolen creeps: treat like a summon (random empty position, then roll its arrow). Cursed Satyr's Zombie goes to the opponent's side of Satyr's lane.",
     "Glossary DCG_Glossary_Summon; wiki Pathing ('Any new unblocked unit ... will have a Pathing Card placed'). Confidence: high for summon, low for moves/control."),
    ("RQ-18", "Taunt scope and duration.",
     "All of the taunting unit's enemy neighbors (three positions across) set their combat target to it; units elsewhere are unaffected. It is a combat-target change, so it lasts until the next re-target or the end of the round like Battlefield Control.",
     "Glossary DCG_Glossary_Taunt; artifact_compiled 'Taunt' (does not affect cards that cannot normally attack the unit). Confidence: medium (duration)."),
    ("RQ-19", "Legal choices for 'Choose a combat target' (Battlefield Control, New Orders, Compel, Murder Plot, Assassin's Veil...).",
     "Any enemy unit in the three positions across; the tower only if the position directly across is empty (Forward Charge: 'the unit or tower across from them'; pathing: an empty diagonal means forward). Engine currently allows the tower when either diagonal is empty.",
     "Valve text 10413; wiki Pathing; engine combat_targets(). Confidence: medium."),
    ("RQ-20", "Initiative after Enough Magic! (proceed to combat without passes).",
     "Not specified. Best guess: the caster's opponent gets initiative for the next lane (same as any action without Get Initiative: engine _finish_action(player, false)). Needs a reference match.",
     "Valve text 10326; glossary Get Initiative. Confidence: low."),
    ("RQ-21", "Glyph of Confusion: what counts as 'enters this lane'?",
     "Every placement into the lane: deployment of heroes and lane creeps, creep cards, summons, moves from other lanes, units whose control changes. Not swaps within the lane. 'this round' means the round in which it entered (deployment entrants are stunned for the whole new round).",
     "Valve text 10187; glossary Stun. Confidence: medium."),
    ("RQ-22", "Kanna: when and where do the random allied Melee Creeps go?",
     "If Kanna is in play (already in a lane or being deployed this phase), both of her player's lane creeps enter her lane after deployment is revealed. The public pending-creep reveal must therefore show them as 'to Kanna's lane' (her destination stays private until reveal). If Kanna is in the Fountain, creeps use their random lanes.",
     "Valve text 10503; wiki Phases (creeps randomly assigned before hero choice). Confidence: medium."),
    ("RQ-23", "Order of deployment-phase summons (Venomancer, Prellex, Barracks).",
     "They resolve at deployment reveal together with lane creeps, into the source's lane after heroes are placed (a hero deployed this round summons into its new lane). A hero in the Fountain summons nothing.",
     "Valve text 10491, 10523, 10147. Confidence: medium."),
    ("RQ-24", "Do active abilities start ready? (heroes / items / improvements)",
     "Improvements: ready as soon as played (wiki Improvements). Heroes: wiki says the ability 'starts on a cooldown that begins to count down from the start of the game' and ticks down at end of every round even in the Fountain; engine starts at 0 (ready). Items: assume ready when equipped. Keep as a configurable rule until a reference match settles it.",
     "Wiki Heroes/Improvements; docs/RULES.md (J'Muy cooldown open). Confidence: low for heroes."),
    ("RQ-25", "Quicken.",
     "After using Finger of Death its cooldown is set to 4, then reduced by 1 (not below 1) - effectively 3.",
     "Valve text 10449; patch notes 2018-12-20 ('reduce cooldown by 1, but not below 1'). Confidence: high."),
    ("RQ-26", "Shop Deed with several deeds / negative prices.",
     "Each deed reduces Secret Shop prices by the item's base cost; a second deed makes prices negative and buying pays you gold.",
     "Richard Garfield Goes Shopping (Steam news 2018-11-15). Confidence: high."),
    ("RQ-27", "Starting charges of March of the Machines / Bitter Enemies.",
     "March of the Machines starts with 3 charges. Bitter Enemies' starting count is not in Valve's data; best guess 3 (same design pattern). Must be a data field (charges_initial).",
     "Richard Garfield on Upkeep Kills (Steam news 2018-11-08) for March; none for Bitter Enemies. Confidence: high / low."),
    ("RQ-28", "Rounding of 'half' (Sven, Revtel Convoy, Mercenary Exiles, Routed, Wingfall Hammer) and of 'evenly divided' (Mystic Flare).",
     "Round down. For Mystic Flare 12 split among N targets: floor(12/N) each, remainder lost (best guess). Needs reference.",
     "Valve texts; no source. Confidence: low."),
    ("RQ-29", "Summoned Meepo (Divided We Stand): hero or creep? What happens when it dies?",
     "It is a hero unit (hero colour, 5 bounty, can equip items, Soulbound links it to other Meepos). Best guess: a summoned copy is not part of the roster and does not return from the Fountain. Needs reference.",
     "Valve text 10004, 10005; glossary Hero, Soulbound. Confidence: low."),
    ("RQ-30", "Swaps and pathing.",
     "Arrows stay with the combat positions when units swap (Cunning Plan, Juke, Rebel Decoy, Phase Boots); the unit now in a position inherits that position's arrow.",
     "Wiki Pathing 'Resetting Pathing'. Confidence: high."),
    ("RQ-31", "Silence vs passive abilities and colour.",
     "Silence stops active abilities (unit and item) and colour contribution, not passives/continuous effects. Stun = silence + disarm. Stunned/disarmed units still retaliate.",
     "Glossary DCG_Glossary_Silence, _Stun, _Stunned. Confidence: high."),
    ("RQ-32", "'When X deals battle damage to a unit' (Ursa, Viper, Hellbear Crippler, Loyal Beast) with 0 damage after armor.",
     "Does not trigger: damage must actually be dealt (> 0 after armor, not prevented by immunity).",
     "Glossary DCG_Glossary_BattleDamage. Confidence: medium."),
    ("RQ-33", "Cross Lane cards.",
     "Use mana and a hero of the card's colour from the active lane, but the target / destination may be any lane. All improvements are cross lane. 'in all lanes' effects are global but NOT cross lane (still need the coloured hero in the active lane).",
     "Glossary DCG_Glossary_Inspect_Crosslane, DCG_Glossary_Improvement. Confidence: high."),
    ("RQ-34", "Improvements per lane.",
     "Each lane holds at most 16 improvements; a 17th destroys a random existing one. Improvements are not units and occupy no combat position.",
     "Wiki Improvements. Confidence: medium."),
    ("RQ-35", "Caught Unprepared duration.",
     "The stun stays until that hero equips an item, including across rounds; best guess: it is a temporary (non-modify) effect, so the Fountain removes it.",
     "Valve text 10396; wiki Fountains (lists Caught Unprepared as removed). Confidence: medium."),
    ("RQ-36", "Hacked cards (Self Sabotage) and Multicast/...And One For Me copies.",
     "A 'base copy' is the unmodified card (no locks, charges, hacks). A hacked card keeps its hack until played; the extra text resolves when it is played by its owner (damaging the owner's random tower).",
     "Valve texts 10302, 10509, 10196; glossary DCG_Glossary_NumHacks ('The text of this card has been changed'). Confidence: medium."),
]

# Generalised notes for designing the effect system (rendered in MECHANICS.md).
DESIGN_NOTES = [
    "Every reactive trigger in Valve's glossary is 'simultaneous' (before action / after combat): collect all triggered effects, order them deterministically (e.g. initiative player first, then lane position left to right, then uid), and resolve with Pulses between.",
    "Card instances need state in hand and deck (Lock, Eclipse charges, Self Sabotage hacks): hands must hold instance dictionaries {cid, card, lock, charges, hacks} instead of bare ids. player_view must redact the opponent's instances except public counters (lock is visible on the card back: DCG 'enemyCardLocked' effect).",
    "Modifiers need provenance {source_uid, source_player, kind: modify|temp|until_death|until_next_combat|continuous} so Purge, Fountain and end-of-round cleanup are exact.",
    "Combat must become per-attacker events (battle record: attacker, target, damage after armor, piercing) so retaliate, cleave, lethal, 'when X deals battle damage', Rebel Instigator/Red Mist Pillager conditions and Unearthed Secrets can be evaluated deterministically.",
    "Improvements and towers need their own state per lane (improvements list, tower armor/retaliate/regeneration/mana modifiers).",
    "Random choices must all go through the seeded engine rng in a fixed order (iterate lanes 0..2, positions left to right, player 0 then 1) to keep replays and Steam host authority stable; hidden-information randomness (opponent hand picks) must never be resolved on the guest.",
]


# --------------------------------------------------------------------------
# Loading

def load_valve():
    cards = {}
    for path in VALVE_FILES:
        with open(path, encoding="utf-8") as handle:
            for card in json.load(handle)["card_set"]["card_list"]:
                cards[card["card_id"]] = card
    return cards


def load_loc():
    loc = {}
    pattern = re.compile(r'"(Card(?:Name|Text|Effect)_\d+(?:_\d+)?)"\s+"((?:[^"\\]|\\.)*)"')
    for path in LOC_FILES:
        with open(path, encoding="utf-8", errors="replace") as handle:
            text = handle.read()
        for match in pattern.finditer(text):
            loc[match.group(1)] = match.group(2).replace('\\"', '"')
    return loc


def load_glossary_keys():
    keys = {}
    with open(GLOSSARY_FILE, encoding="utf-8-sig", errors="replace") as handle:
        for match in re.finditer(r'"DCG_Glossary_(\w+?)_Title"\s+"([^"]*)"', handle.read()):
            keys[match.group(1)] = html.unescape(match.group(2))
    return keys


def load_project():
    with open(CLASSIC_FILE, encoding="utf-8") as handle:
        classic = json.load(handle)
    with open(MAPPING_FILE, encoding="utf-8") as handle:
        mapping = json.load(handle)
    with open(LOCALE_FILE, encoding="utf-8") as handle:
        locale = json.load(handle)
    return classic, mapping, locale


# --------------------------------------------------------------------------
# Text helpers

def strip_html(text):
    text = re.sub(r"<br\s*/?>", "\n", text or "", flags=re.I)
    text = re.sub(r"<[^>]+>", "", text)
    text = html.unescape(text)
    text = re.sub(r"[ \t]+", " ", text)
    return text.strip()


def colour_of(card):
    for key in ("is_red", "is_blue", "is_green", "is_black"):
        if card.get(key):
            return key[3:]
    return "none"


def loc_tags(loc_text):
    tags = []
    for match in re.finditer(r"\[g:(\d+)\[", loc_text or ""):
        name = GLOSSARY_TAGS.get(int(match.group(1)))
        if name:
            tags.append(name)
    return tags


def pulse_count(loc_text):
    return len(re.findall(r"\[g:608\[", loc_text or ""))


# --------------------------------------------------------------------------
# Clause classification

STATS = ["attack", "armor", "health", "siege", "cleave", "retaliate", "regeneration", "bounty", "mana"]

TRIGGER_RULES = [
    ("before_action", r"before the action phase"),
    ("after_combat", r"after the combat phase"),
    ("deployment_phase", r"each deployment phase|are deployed into"),
    ("round_draw", r"extra card each round"),
    ("ally_death", r"after an allied (?:neighbor|melee creep)(?: of equipped hero)? dies"),
    ("blocker_death", r"after a (?:unit|hero) blocking it dies"),
    ("enemy_death", r"after an enemy (?:neighbor|hero|creep) dies"),
    ("hero_death", r"after a hero dies"),
    ("after_you_play", r"after you play|after the first time an allied spell is played"),
    ("after_opponent_plays", r"after opponent plays"),
    ("battle_damage_dealt", r"when this deals battle damage to a unit|each unit equipped hero deals battle damage to"),
    ("battle_damage_taken", r"when a unit deals battle damage to this"),
    ("unit_enters_lane", r"whenever any unit enters this lane"),
    ("improvement_enters_lane", r"whenever an enemy improvement enters this lane"),
    ("opponent_draws", r"whenever opponent draws a card"),
    ("shop_phase", r"secret shop costs"),
]

# (regex, target, scope override) applied in order; matches are consumed.
TARGET_RULES = [
    (r"enemy heroes at the fountain", "fountain_heroes", "fountain"),
    (r"each enemy hero in all lanes", "all_enemy_heroes", "all_lanes"),
    (r"other allies in all lanes", "all_allies", "all_lanes"),
    (r"allies in all lanes", "all_allies", "all_lanes"),
    (r"allied heroes in all lanes", "all_allied_heroes", "all_lanes"),
    (r"all towers in all lanes", "all_towers", "all_lanes"),
    (r"each enemy across from an empty combat position", "enemies_across_empty", None),
    (r"each other enemy", "all_enemies", None),
    (r"all equipped heroes", "all_heroes", None),
    (r"(?:each|every) enemy creep", "all_enemy_creeps", None),
    (r"(?:each|every) enemy hero|enemy heroes", "all_enemy_heroes", None),
    (r"for each enemy|the number of enemies|on enemies", "count_enemies", None),
    (r"every damaged unit", "count_damaged_units", None),
    (r"(?:each|every) enemy|all enemies", "all_enemies", None),
    (r"a random unit to its left or right", "random_adjacent_unit", None),
    (r"for your opponent|you and your opponent", "opponent", None),
    (r"the trigger subject", "trigger_subject", None),
    (r"(?:to )?a random enemy neighbor", "random_enemy_neighbor", None),
    (r"(?:a )?random enemy improvement", "random_enemy_improvement", None),
    (r"(?:all )?enemy improvements|for each of its improvements", "all_enemy_improvements", None),
    (r"an improvement", "improvement", None),
    (r"a random ally or enemy", "random_unit", None),
    (r"(?:a )?random enemy", "random_enemy", None),
    (r"(?:a )?random allied(?: red| black| green| blue)? hero", "random_allied_hero", None),
    (r"(?:a )?random ally", "random_ally", None),
    (r"(?:the random )?allied melee creeps?|an allied melee creep", "allied_melee_creeps", None),
    (r"(?:two |three )?random cards? in opponent's hand", "opponent_hand_random", None),
    (r"three random eclipse cards in your hand or deck", "own_hand_and_deck", None),
    (r"discard a random card", "own_hand_random", None),
    (r"the played card", "played_card", None),
    (r"the drawn card", "drawn_card", None),
    (r"your hand", "own_hand", None),
    (r"(?:a )?random item equipped by", "random_equipped_item", None),
    (r"each item equipped by", "equipped_items_of", None),
    (r"all equipped items", "all_equipped_items", None),
    (r"(?:a )?random item from the secret shop|each item in your secret shop", "secret_shop", None),
    (r"(?:the |a )?units? blocking (?:it|this|equipped hero|an allied red hero)", "blocker", None),
    (r"(?:its|this's|equipped hero's) attackers|each of its attackers", "attackers", None),
    (r"each unit equipped hero deals battle damage to", "battle_victims", None),
    (r"(?:new )?enemy neighbors?", "enemy_neighbors", None),
    (r"(?:one of )?(?:its |their |this's |this unit's |this hero's |that unit's |equipped hero's )?allied neighbors?", "allied_neighbors", None),
    (r"(?:an )?allied (?:red|black|green|blue) hero", "allied_hero", None),
    (r"an allied hero", "allied_hero", None),
    (r"(?:a|an) (?:red|black|green|blue) hero", "colour_hero", None),
    (r"an enemy hero", "enemy_hero", None),
    (r"(?:a|another) hero", "hero", None),
    (r"an enemy creep", "enemy_creep", None),
    (r"(?:a|another) creep", "creep", None),
    (r"two enemies|an enemy", "enemy_unit", None),
    (r"another unit in any lane", "unit", "any_lane"),
    (r"a unit in another lane", "unit", "other_lane"),
    (r"a unit in any lane", "unit", "any_lane"),
    (r"(?:another|an|the chosen) ally", "allied_unit", None),
    (r"(?:modify |give )?allied heroes", "all_allied_heroes", None),
    (r"allied creeps", "all_allied_creeps", None),
    (r"(?:other )?allies|each ally", "all_allies", None),
    (r"(?:every|each|all) units?(?! equipped)", "all_units", None),
    (r"all heroes", "all_heroes", None),
    (r"(?:a|another|that|each) unit|every damaged unit", "unit", None),
    (r"the enemy tower", "enemy_tower", None),
    (r"a random allied tower in any lane", "random_allied_tower", "any_lane"),
    (r"both towers", "both_towers", None),
    (r"all towers", "all_towers", None),
    (r"your tower|the tower in that lane", "allied_tower", None),
    (r"(?:an )?empty combat position", "empty_position", None),
    (r"random other lanes?", "random_other_lane", None),
    (r"another lane|an allied this's lane", "other_lane", None),
    (r"choose a lane", "lane_choice", "any_lane"),
    (r"into any lane", "lane_choice", "any_lane"),
    (r"the fountain", "fountain", None),
    (r"combat target", "combat_target", None),
    (r"equipped hero", "equipped_hero", None),
    (r"\bthis(?:'s)?(?: hero| unit)?\b(?! round| lane| is the active lane)", "self", None),
    (r"\bgold\b", "player_gold", None),
    (r"\bmana\b", "tower_mana", None),
]

VERB_RULES = [
    ("piercing_damage", r"piercing damage"),
    ("damage", r"\bdeals? (?:\d+ |x )?damage|\bdeal damage"),
    ("damage_bonus", r"deals? \+\d+ damage when attacking"),
    ("damage_split", r"evenly divided"),
    ("full_heal", r"fully heal"),
    ("heal", r"\bheal\b"),
    ("modify", r"\bmodify\b|\bmodified\b"),
    ("pierce", r"\bpierce\b"),
    ("rapid_deployment", r"rapid deployment"),
    ("mana_restore", r"restore (?:\d+ )?mana|restore your tower's mana|fully restore"),
    ("gold_gain", r"\bget (?:\d+ |x )?gold|get gold|get \d+ gold"),
    ("gold_spend", r"spend all your gold"),
    ("gold_double", r"double your gold"),
    ("cost_reduction", r"costs? x less"),
    ("draw", r"\bdraw (?:a |an |\d+ |two |three )"),
    ("discard_hand", r"discard your hand"),
    ("discard", r"\bdiscard\b"),
    ("add_card_to_hand", r"into your hand|get a random item"),
    ("copy_card", r"base copy"),
    ("summon", r"\bsummons?\b"),
    ("condemn", r"\bcondemn\b"),
    ("stun", r"\bstun(?:ned)?\b"),
    ("silence", r"\bsilence\b"),
    ("disarm", r"\bdisarm(?:ed)?\b"),
    ("taunt", r"\btaunts?\b"),
    ("lock", r"\block\b"),
    ("purge", r"\bpurge\b"),
    ("swap", r"\bswap\b"),
    ("move", r"\bmove\b"),
    ("change_combat_target", r"combat target"),
    ("battle", r"\bbattles?\b(?! damage)"),
    ("return_to_fountain", r"return [^.]* to the fountain"),
    ("steal_control", r"get control of"),
    ("death_shield", r"death shield"),
    ("damage_immunity", r"damage immunity"),
    ("get_initiative", r"get initiative"),
    ("quicken", r"\bquicken\b"),
    ("charges", r"\bcharges?\b"),
    ("repeat", r"\brepeat\b|summon [^.]* for (?:each|every)"),
    ("random_chance", r"\d+% chance"),
    ("scaling_x", r"where x is|equal to|for each|for every|[+-]x\b|with their attack"),
    ("play_restriction", r"can not play|cannot play"),
    ("activation_condition", r"may only be used if"),
    ("end_action_phase", r"proceed to the combat phase"),
    ("deploy_redirect", r"are deployed into"),
    ("soulbound", r"soulbound"),
    ("lethal", r"condemn each unit [^.]*deals battle damage"),
]


def find_stats(text):
    """Stat tokens with sign: [('attack', '+2'), ...]."""
    found = []
    for match in re.finditer(r"([+-])\s?(\d+|x) (attack|armor|health|siege|cleave|retaliate|regeneration|bounty|mana)", text):
        found.append((match.group(3), match.group(1) + match.group(2)))
    # 'with their Attack and Health' (Ravenous Mass), 'Siege 5.' keyword form
    for match in re.finditer(r"\b(siege|cleave|retaliate|regeneration) (\d+)\b", text):
        found.append((match.group(1), "+" + match.group(2)))
    if re.search(r"with their attack and health", text):
        found += [("attack", "+x"), ("health", "+x")]
    return found


def split_quotes(text):
    quotes = []

    def keep(match):
        quotes.append(match.group(1).strip())
        return "\u27e6Q%d\u27e7" % (len(quotes) - 1)

    return re.sub(r'"([^"]*)"', keep, text), quotes


def sentences(text):
    text, quotes = split_quotes(text)
    parts = []
    for paragraph in re.split(r"\n+", text):
        paragraph = paragraph.strip()
        if not paragraph:
            continue
        for sentence in re.split(r"(?<=[.!])\s+(?=[A-Z\u27e6])", paragraph):
            if sentence.strip():
                parts.append(sentence.strip())
    restored = []
    for part in parts:
        inner = [quotes[int(i)] for i in re.findall(r"\u27e6Q(\d+)\u27e7", part)]
        restored.append((part, inner))
    return restored, quotes


def restore_quotes(text, quotes):
    return re.sub(r"\u27e6Q(\d+)\u27e7", lambda m: '"%s"' % quotes[int(m.group(1))], text)


def normalise(text, names):
    lowered = " " + text + " "
    for name in sorted({n for n in names if n}, key=len, reverse=True):
        lowered = re.sub(re.escape(name) + r"(?:'s|s)?", lambda m: "this's" if m.group(0).endswith("'s") else "this", lowered, flags=re.I)
    lowered = lowered.lower()
    lowered = re.sub(r"\([^)]*\)", " ", lowered)  # reminder text
    return re.sub(r"\s+", " ", lowered).strip()


def classify_clause(raw, names, ctx):
    """ctx: {'kind': card type, 'default_trigger': str, 'granted_on': None|'unit'|'hand_card'}"""
    text = normalise(raw, names)
    clause = OrderedDict()
    clause["text"] = raw
    trigger = None
    prefix = re.match(r"(play effect|death effect|equip effect|active (\d+))\s*:\s*", text)
    cooldown = None
    if prefix:
        label = prefix.group(1)
        trigger = {"play effect": "play_effect", "death effect": "self_death",
                   "equip effect": "equip_effect"}.get(label, "active")
        if prefix.group(2):
            cooldown = int(prefix.group(2))
        text = text[prefix.end():]
    if ctx.get("cooldown") is not None:
        trigger = "active"
        cooldown = ctx["cooldown"]
    body = re.sub(r"\u27e6q\d+\u27e7", " ", text)
    if trigger is None:
        for name, pattern in TRIGGER_RULES:
            if re.search(pattern, body):
                trigger = name
                break
    if trigger is None:
        trigger = ctx["default_trigger"]
    clause["trigger"] = trigger
    if cooldown is not None:
        clause["cooldown"] = cooldown
    # trigger filter
    trigger_filter = None
    match = re.search(r"after you play (?:a|an|any) ([a-z0-9\- ]+?)(?: card| spell)?(?: in any lane)?(?:,|$| costing| \u27e6)", body)
    if trigger == "after_you_play":
        if "first time an allied spell" in body:
            trigger_filter = "first allied spell in each lane (per round)"
        else:
            m2 = re.search(r"after you play (?:a |an )?(.+?)(?:,|$)", body)
            trigger_filter = m2.group(1).strip().rstrip(".") if m2 else None
    elif trigger == "after_opponent_plays":
        trigger_filter = "spell"
    elif trigger in ("ally_death", "enemy_death", "blocker_death"):
        m2 = re.search(r"after an? ((?:allied |enemy )?(?:neighbor|melee creep|hero|creep|unit)(?: blocking it)?(?: of equipped hero)?) dies", body)
        trigger_filter = m2.group(1) if m2 else None
    if trigger_filter:
        clause["trigger_filter"] = trigger_filter
    # targets
    targets, scopes = [], []
    work = body
    if trigger == "unit_enters_lane":
        work = re.sub(r"\bstun it\b", "stun the trigger subject", work)
    if trigger in ("battle_damage_dealt", "battle_damage_taken"):
        work = work.replace("that unit", "the trigger subject")
    if trigger in ("after_you_play", "after_opponent_plays", "ally_death", "enemy_death", "blocker_death", "hero_death", "opponent_draws", "unit_enters_lane", "improvement_enters_lane", "battle_damage_dealt", "battle_damage_taken"):
        # Do not read the trigger condition as a target.
        work = re.sub(r"after (?:you|opponent) play[^,]*,?|after the first time[^,]*,|after an? [a-z ]+ dies|whenever opponent draws a card,?|whenever (?:any unit|an enemy improvement) enters this lane,?|when (?:a unit|this) deals battle damage to (?:a unit|this),?", " ", work)
        work = re.sub(r"after a (?:unit|hero) blocking it dies", " ", work)
    # Conditions are not targets ("if there is an allied red hero in this lane, ...").
    work = re.sub(r"may only be used if [^.]+|\bif [^,.]+", " ", work)
    if "damage_bonus" in [n for n, p in VERB_RULES if re.search(p, body)]:
        work = re.sub(r"when attacking an? (?:hero|tower)(?: or tower)?", " ", work)
    if trigger in ("opponent_draws",):
        work = work.replace("that card", "the drawn card")
    work = work.replace("that card", "the played card")
    for pattern, target, scope in TARGET_RULES:
        if re.search(pattern, work):
            if target not in targets:
                targets.append(target)
            if scope and scope not in scopes:
                scopes.append(scope)
            work = re.sub(pattern, " \u2022 ", work)
    cbody = re.sub(r"may only be used if [^.]+|\bif [^,.]+", " ", body)
    if re.search(r"in all lanes|in every lane|in any lane", cbody) and not scopes:
        scopes.append("all_lanes" if "all lanes" in cbody or "every lane" in cbody else "any_lane")
    clause["targets"] = targets
    clause["scope"] = scopes[0] if scopes else ("fountain" if "fountain" in targets and "fountain_heroes" in targets else "lane")
    # verbs
    verbs = []
    for name, pattern in VERB_RULES:
        if re.search(pattern, body) and name not in verbs:
            verbs.append(name)
    stats = find_stats(body)
    for stat, sign in stats:
        token = {"attack": "stat_attack", "armor": "stat_armor", "health": "stat_health",
                 "mana": "mana_change"}.get(stat, stat)
        if token not in verbs:
            verbs.append(token)
    if "pierce" in body and "pierce" not in verbs:
        verbs.append("pierce")
    if (stats or "pierce" in verbs) and "modify" not in verbs and re.search(r"\bgive\b|\bgain\b", body):
        verbs.append("temp_buff")
    if ("damage" in verbs or "piercing_damage" in verbs) and any(t in targets for t in ("enemy_tower", "both_towers", "all_towers", "random_allied_tower")):
        verbs.append("tower_damage")
    if "heal" in verbs and "allied_tower" in targets:
        verbs.append("tower_heal")
    if "discard_hand" in verbs:
        verbs = [v for v in verbs if v != "discard"]
    if "full_heal" in verbs:
        verbs = [v for v in verbs if v != "heal"]
    if "lethal" in verbs:
        verbs = [v for v in verbs if v != "condemn"] + ["condemn"]
    # quoted grant
    inner = re.findall(r"\u27e6q(\d+)\u27e7", text)
    if inner:
        if "opponent_hand_random" in targets:
            verbs.append("hack_hand_card")
        else:
            verbs.append("grant_text")
    clause["verbs"] = verbs
    clause["stats"] = ["%s%s" % (sign, stat) for stat, sign in stats]
    # durations
    durations = []
    dbody = re.sub(r"may only be used if [^.]+|\bif [^,.]+", " ", body)
    if re.search(r"this round|until end of round", dbody):
        durations.append("this_round")
    if re.search(r"until end of (?:its|their) next combat phase", body):
        durations.append("until_next_combat")
    if re.search(r"until it dies", body):
        durations.append("until_death")
    if re.search(r"until they equip", body):
        durations.append("until_equip")
    if "modify" in verbs or "summon" in verbs:
        durations.append("permanent")
    if trigger in ("continuous", "equip") and not durations:
        durations.append("continuous")
    clause["durations"] = durations
    # conditions
    conditions = []
    for match in re.finditer(r"(?<!used )\bif ([^,.]+)", body):
        conditions.append("if " + match.group(1).strip())
    for match in re.finditer(r"when attacking an? (hero|tower)(?: or tower)?", body):
        conditions.append(match.group(0))
    for match in re.finditer(r"may only be used if ([^.]+)", body):
        conditions.append("only if " + match.group(1).strip())
    for match in re.finditer(r"(\d+)% chance", body):
        conditions.append("%s%% chance" % match.group(1))
    for match in re.finditer(r"(where x is [^.]+|equal to [^.,]+|for each [^.,]+|for every [^.,]+)", body):
        conditions.append(match.group(1).strip())
    for match in re.finditer(r"until they equip [^.]+", body):
        conditions.append(match.group(0))
    clause["conditions"] = list(OrderedDict.fromkeys(conditions))
    clause["random"] = bool(re.search(r"\brandom\b|% chance", body))
    clause["granted"] = bool(ctx.get("granted"))
    clause["_inner"] = [int(i) for i in inner]
    return clause


# --------------------------------------------------------------------------
# Card assembly

def card_names(card, cards):
    names = [card["card_name"]["english"]]
    for ref in card.get("references", []):
        if ref["ref_type"] in ("active_ability", "passive_ability"):
            pass
    return names


def parent_map(cards):
    parents = {}
    for cid, card in cards.items():
        for ref in card.get("references", []):
            if ref["ref_type"] in ("active_ability", "passive_ability"):
                parents[ref["card_id"]] = (cid, ref["ref_type"])
    return parents


def hero_cooldowns(card):
    text = strip_html(card["card_text"].get("english", ""))
    found = {}
    for match in re.finditer(r"([A-Z][^\n|]*?)\n\s*Active (\d+):", text):
        found[match.group(1).strip()] = int(match.group(2))
    return found


def segment_card_text(card, cards, parents):
    """Returns list of (segment_text, source, ctx overrides)."""
    ctype = card["card_type"]
    text = strip_html(card["card_text"].get("english", ""))
    refs = card.get("references", [])
    ability_refs = [r for r in refs if r["ref_type"] in ("active_ability", "passive_ability")]
    segments = []
    if ctype == "Hero":
        cooldowns = hero_cooldowns(card)
        for ref in ability_refs:
            ability = cards.get(ref["card_id"])
            if not ability:
                continue
            name = ability["card_name"]["english"]
            atext = strip_html(ability["card_text"].get("english", ""))
            cooldown = cooldowns.get(name) if ref["ref_type"] == "active_ability" else None
            if ref["ref_type"] == "active_ability" and cooldown is None:
                m = re.search(re.escape(name) + r"\s*\n?\s*Active (\d+):", text)
                cooldown = int(m.group(1)) if m else None
            segments.append((atext, "ability:%d" % ref["card_id"], {"cooldown": cooldown} if ref["ref_type"] == "active_ability" else {"passive": True}))
        return segments
    # Non-hero: split at "Active N:"
    match = re.search(r"Active (\d+):", text)
    if match:
        before = text[:match.start()].strip()
        after = text[match.end():].strip()
        active_ref = next((r for r in ability_refs if r["ref_type"] == "active_ability"), None)
        if before:
            segments.append((before, "card", {}))
        segments.append((after, "ability:%d" % active_ref["card_id"] if active_ref else "card", {"cooldown": int(match.group(1))}))
    elif text:
        segments.append((text, "card", {}))
    return segments


def default_trigger(card, kind, sub_type):
    if kind == "Spell":
        return "play"
    if kind == "Item" and sub_type == "Consumable":
        return "play"
    if kind == "Item" and sub_type == "Deed":
        return "continuous"
    if kind == "Item":
        return "equip"
    if kind == "Ability":
        return "active"
    return "continuous"


def classify_segment(text, names, ctx, quotes_out):
    clauses = []
    parts, quotes = sentences(text)
    for part, inner in parts:
        clause = classify_clause(part, names, ctx)
        clause["text"] = restore_quotes(part, quotes)
        clauses.append(clause)
        for index in clause.pop("_inner"):
            granted_text = quotes[index]
            on_hand = "hack_hand_card" in clause["verbs"]
            gctx = {"default_trigger": "hacked_card_played" if on_hand else "continuous", "granted": True}
            for sub, _ in sentences(granted_text)[0]:
                gclause = classify_clause(sub, names, gctx)
                gclause.pop("_inner")
                clauses.append(gclause)
    return clauses


def complexity(entry):
    score = 1
    reasons = []
    verbs = set(entry["verbs"])
    triggers = set(entry["triggers"])
    simple_verbs = {"stat_attack", "stat_armor", "stat_health", "modify", "temp_buff", "siege", "damage",
                    "piercing_damage", "draw", "heal", "tower_damage", "summon", "condemn", "mana_change",
                    "get_initiative"}
    if not entry["clauses"]:
        return 1, ["vanilla (no text)"]
    nontrivial = verbs - {"stat_attack", "stat_armor", "stat_health", "siege"}
    if nontrivial:
        score += 1
        reasons.append("effect verbs: " + ", ".join(sorted(nontrivial)))
    reactive = triggers - {"play", "continuous", "equip_effect", "equip"}
    if reactive:
        score += 1
        reasons.append("triggers: " + ", ".join(sorted(reactive)))
    elif triggers & {"continuous", "equip"} and (set(entry["targets"]) - {"self", "equipped_hero"}):
        score += 1
        reasons.append("aura affecting other units/towers")
    tricky = verbs & {"move", "swap", "battle", "steal_control", "lock", "purge", "copy_card", "charges",
                      "repeat", "scaling_x", "random_chance", "grant_text", "hack_hand_card",
                      "play_restriction", "end_action_phase", "deploy_redirect", "soulbound", "lethal",
                      "cost_reduction", "gold_spend", "damage_split", "taunt", "activation_condition",
                      "add_card_to_hand", "discard_hand"}
    if tricky or entry["conditions"] or entry["random"] or entry["pulses"]:
        score += 1
        bits = sorted(tricky)
        if entry["conditions"]:
            bits.append("conditions")
        if entry["random"]:
            bits.append("randomness")
        if entry["pulses"]:
            bits.append("%d pulse(s)" % entry["pulses"])
        reasons.append("complex: " + ", ".join(bits))
    unique = verbs & {"steal_control", "hack_hand_card", "play_restriction", "end_action_phase",
                      "deploy_redirect", "soulbound", "cost_reduction", "copy_card", "lethal"}
    if unique or entry["cross_lane"] and verbs & {"move", "battle"}:
        score += 1
        reasons.append("rule-bending: " + ", ".join(sorted(unique or {"cross-lane move/battle"})))
    if entry["id"] in HARD_REASONS and score < 4:
        score = 4
        reasons.append("curated hard card")
    if entry["id"] in HARD_FIVE or entry.get("parent") in HARD_FIVE:
        score = 5
        reasons.append("curated: unique system")
    return min(score, 5), reasons


def engine_status(entry, implemented):
    tokens = ["trigger:" + t for t in entry["triggers"]]
    tokens += ["target:" + t for t in entry["targets"]]
    tokens += ["verb:" + v for v in entry["verbs"]]
    tokens += ["duration:" + d for d in entry["durations"]]
    supported, partial, missing = [], [], []
    for token in OrderedDict.fromkeys(tokens):
        status = ENGINE_SUPPORT.get(token, ("none", "-", "unmapped"))[0]
        (supported if status == "full" else partial if status == "partial" else missing).append(token)
    total = len(supported) + len(partial) + len(missing)
    coverage = 1.0 if total == 0 else round((len(supported) + 0.5 * len(partial)) / total, 2)
    return OrderedDict([
        ("implemented", implemented),
        ("full", supported), ("partial", partial), ("missing", missing),
        ("coverage", coverage),
    ])


def build():
    cards = load_valve()
    loc = load_loc()
    classic, mapping, locale = load_project()
    parents = parent_map(cards)
    implemented = {c["source_id"]: c for c in classic["heroes"] + classic["cards"]}
    mapped = {m["card_id"]: m for m in mapping}
    skin = locale["skins"]["three_kingdoms"]["cards"]
    union = set(implemented) | set(mapped)
    includes = {}
    for cid, card in cards.items():
        for ref in card.get("references", []):
            if ref["ref_type"] == "includes":
                includes[ref["card_id"]] = cid

    entries = []
    ids = sorted(union) + sorted(parents)
    for cid in ids:
        card = cards[cid]
        kind = card["card_type"]
        sub_type = card.get("sub_type")
        is_ability = kind in ("Ability", "Passive Ability")
        parent_id = parents.get(cid, (None, None))[0]
        names = [card["card_name"]["english"]]
        if parent_id:
            names.append(cards[parent_id]["card_name"]["english"])
        token = kind == "Creep" and (cid in (1006, 1009) or (mapped.get(cid, {}).get("type", "").startswith("Token"))
                                     or (cid in implemented and cid == 10082))
        entry = OrderedDict()
        entry["id"] = cid
        entry["name"] = card["card_name"]["english"]
        entry["type"] = "Token" if token else kind
        entry["card_type"] = kind
        if sub_type:
            entry["sub_type"] = sub_type
        entry["colour"] = colour_of(card) if not parent_id else colour_of(cards[parent_id])
        if card.get("mana_cost") is not None:
            entry["mana_cost"] = card["mana_cost"]
        if card.get("gold_cost") is not None:
            entry["gold_cost"] = card["gold_cost"]
        if kind in ("Hero", "Creep"):
            entry["stats"] = [card.get("attack", 0), card.get("armor", 0), card.get("hit_points", 0)]
        entry["rarity"] = card.get("rarity", "Basic" if cid < 10000 else ("Signature" if cid in includes else "Token/none"))
        if cid in includes:
            entry["signature_of"] = includes[cid]
        if parent_id:
            entry["parent"] = parent_id
            entry["ability_kind"] = "active" if parents[cid][1] == "active_ability" else "passive"
        signature = [r["card_id"] for r in card.get("references", []) if r["ref_type"] == "includes"]
        if signature:
            entry["signature"] = signature[0]
        abilities = [r["card_id"] for r in card.get("references", []) if r["ref_type"] in ("active_ability", "passive_ability")]
        if abilities:
            entry["abilities"] = abilities
        summons = [r["card_id"] for r in card.get("references", []) if r["ref_type"] == "references"]
        if summons:
            entry["references"] = summons
        project_id = implemented[cid]["id"] if cid in implemented else (mapped[cid]["id"] if cid in mapped else None)
        entry["project_id"] = project_id
        entry["status"] = "implemented" if cid in implemented else ("mapped" if cid in mapped else "ability")
        if cid in mapped:
            entry["skin"] = {"en": mapped[cid].get("en_name"), "zh": mapped[cid].get("zh_name")}
        elif project_id in skin:
            entry["skin"] = {"en": skin[project_id]["name"].get("en"), "zh": skin[project_id]["name"].get("zh_CN")}
        entry["counted"] = not is_ability
        full_text = strip_html(card["card_text"].get("english", ""))
        if kind == "Hero":
            parts = []
            for ref in card.get("references", []):
                if ref["ref_type"] in ("active_ability", "passive_ability") and ref["card_id"] in cards:
                    ab = cards[ref["card_id"]]
                    parts.append("%s: %s" % (ab["card_name"]["english"], strip_html(ab["card_text"].get("english", ""))))
            full_text = " | ".join(parts) if parts else full_text
        entry["text"] = re.sub(r"\s*\n\s*", " | ", full_text)
        # clauses
        if is_ability:
            ctx = {"default_trigger": "active" if entry["ability_kind"] == "active" else "continuous"}
            if entry["ability_kind"] == "active":
                parent_text = strip_html(cards[parent_id]["card_text"].get("english", ""))
                m = re.search(r"Active (\d+):", parent_text) if cards[parent_id]["card_type"] != "Hero" else None
                cooldowns = hero_cooldowns(cards[parent_id]) if cards[parent_id]["card_type"] == "Hero" else {}
                ctx["cooldown"] = cooldowns.get(entry["name"], int(m.group(1)) if m else None)
                if ctx["cooldown"] is None:
                    m = re.search(re.escape(entry["name"]) + r"\s*\n?\s*Active (\d+):", parent_text)
                    ctx["cooldown"] = int(m.group(1)) if m else None
            segments = [(strip_html(card["card_text"].get("english", "")), "card", ctx)]
        else:
            segments = []
            for text, source, extra in segment_card_text(card, cards, parents):
                ctx = {"default_trigger": default_trigger(card, kind, sub_type)}
                if extra.get("cooldown") is not None:
                    ctx["cooldown"] = extra["cooldown"]
                    ctx["default_trigger"] = "active"
                segments.append((text, source, ctx))
        clauses = []
        for text, source, ctx in segments:
            for clause in classify_segment(text, names, ctx, None):
                clause["source"] = source
                clauses.append(clause)
        # Equipment stat line: continuous on equipped hero
        entry["clauses"] = clauses
        # aggregate
        def collect(key):
            values = []
            for clause in clauses:
                v = clause[key]
                for item in (v if isinstance(v, list) else [v]):
                    if item and item not in values:
                        values.append(item)
            return values
        entry["triggers"] = collect("trigger")
        entry["targets"] = collect("targets")
        entry["verbs"] = collect("verbs")
        entry["durations"] = collect("durations")
        entry["conditions"] = collect("conditions")
        entry["random"] = any(c["random"] for c in clauses)
        cooldowns = [c["cooldown"] for c in clauses if c.get("cooldown") is not None]
        if cooldowns:
            entry["cooldown"] = cooldowns[0]
        # keywords from Valve localization glossary tags (card + its abilities)
        loc_text = loc.get("CardText_%d" % cid, "")
        if kind == "Hero" and "abilityname" not in loc_text:
            for ab in abilities:
                loc_text += loc.get("CardText_%d" % ab, "")
        tags = loc_tags(loc_text)
        keywords = []
        for tag in tags:
            if tag not in keywords:
                keywords.append(tag)
        derived = []
        if "active" in entry["triggers"]:
            derived.append("Active")
        unquoted = re.sub(r'"[^"]*"', " ", entry["text"])
        cross = kind == "Improvement" or (kind == "Spell" and bool(re.search(
            r"into any lane|in any lane|choose a lane|in another lane|to another lane", unquoted, re.I)))
        entry["cross_lane"] = bool(cross)
        if cross:
            derived.append("Cross Lane")
        if "quicken" in entry["verbs"]:
            derived.append("Quicken")
        if "charges" in entry["verbs"]:
            derived.append("Charges")
        if "equip_effect" in entry["triggers"]:
            derived.append("Equip Effect")
        if entry["random"]:
            derived.append("Random")
        if any(c["granted"] for c in clauses):
            derived.append("Granted text")
        entry["keywords_valve"] = [k for k in keywords if k not in BASIC_TAGS]
        implied = []
        for verb in entry["verbs"]:
            if verb in VERB_KEYWORDS and VERB_KEYWORDS[verb] not in implied:
                implied.append(VERB_KEYWORDS[verb])
        for target in entry["targets"]:
            if target in TARGET_KEYWORDS and TARGET_KEYWORDS[target] not in implied:
                implied.append(TARGET_KEYWORDS[target])
        for trig in entry["triggers"]:
            if trig in TRIGGER_KEYWORDS and TRIGGER_KEYWORDS[trig] not in implied:
                implied.append(TRIGGER_KEYWORDS[trig])
        entry["keywords"] = list(OrderedDict.fromkeys(entry["keywords_valve"] + implied + derived))
        entry["keywords_basic"] = [k for k in keywords if k in BASIC_TAGS]
        entry["pulses"] = pulse_count(loc_text)
        if entry["pulses"]:
            entry["keywords"].append("Pulse") if "Pulse" not in entry["keywords"] else None
        entry["get_initiative"] = "get_initiative" in entry["verbs"]
        entry["valve_effect_count"] = len([k for k in loc if k.startswith("CardEffect_%d_" % cid)])
        if cid in mapped:
            mflag = bool(mapped[cid].get("crosslane"))
            if mflag != entry["cross_lane"]:
                entry["note_crosslane_mismatch"] = "catalog_mapping crosslane=%s, derived=%s" % (mflag, entry["cross_lane"])
        score, reasons = complexity(entry)
        entry["complexity"] = score
        entry["complexity_reasons"] = reasons
        entry["hard_reason"] = HARD_REASONS.get(cid)
        entry["engine"] = engine_status(entry, cid in implemented)
        if cid in implemented:
            fields = sorted(k for k in implemented[cid] if k not in ("id", "source_id", "name", "color", "kind", "cost",
                                                                      "image", "artist", "text", "image_patch", "attack",
                                                                      "armor", "health", "price", "signature"))
            entry["engine"]["data_fields"] = fields
        if cid in DIVERGENCES:
            entry["divergence"] = DIVERGENCES[cid]
        entries.append(entry)
    return entries, cards, loc


# --------------------------------------------------------------------------
# Report

def md_escape(text):
    return str(text).replace("|", "\\|")


def examples(entries, predicate, limit=4):
    names = [e["name"] for e in entries if predicate(e)]
    return ", ".join(names[:limit]) + (" ..." if len(names) > limit else "")


def ranked(counter):
    """Counter items by count, ties by name: stable across Python hash seeds."""
    return sorted(counter.items(), key=lambda item: (-item[1], str(item[0])))


def frequency_table(counted, key, vocab, title):
    counts = Counter()
    for entry in counted:
        for value in set(entry[key]):
            counts[value] += 1
    lines = ["### %s" % title, "", "| %s | Cards | Engine | Examples | Meaning |" % key[:-1].title(), "|---|---:|---|---|---|"]
    prefix = {"triggers": "trigger:", "targets": "target:", "verbs": "verb:", "durations": "duration:"}.get(key)
    keys = list(vocab.keys()) + sorted(k for k in counts if k not in vocab)
    for value in keys:
        n = counts.get(value, 0)
        status = ENGINE_SUPPORT.get(prefix + value, ("none", "", ""))[0] if prefix else ""
        lines.append("| `%s` | %d | %s | %s | %s |" % (value, n, status,
                                                         md_escape(examples(counted, lambda e, v=value: v in e[key])),
                                                         md_escape(vocab.get(value, ""))))
    lines.append("")
    return lines


def report(entries):
    counted = [e for e in entries if e["counted"]]
    abilities = [e for e in entries if not e["counted"]]
    out = []
    out.append("# Artifact Classic mechanics taxonomy")
    out.append("")
    out.append("Generated by `mechanics.py` from Valve's final card data (set 00 + set 01), Valve localization "
               "glossary tags, the Valve glossary and the project's catalog. Do not edit by hand; edit the script.")
    out.append("")
    types = Counter(e["type"] for e in counted)
    out.append("**Scope:** %d cards (%s) plus %d hero/creep/item/improvement abilities listed separately "
               "(ability mechanics are folded into their parent card for the frequency tables). "
               "Implemented in the engine today: %d; mapped but unimplemented: %d." % (
                   len(counted), ", ".join("%s %d" % kv for kv in sorted(types.items())), len(abilities),
                   sum(1 for e in counted if e["status"] == "implemented"),
                   sum(1 for e in counted if e["status"] == "mapped")))
    out.append("")
    out.append("Per-card fields in `mechanics.json`: id, name, type, colour, costs, stats, text, clauses[] (each with "
               "trigger, trigger_filter, targets, scope, verbs, stats, durations, conditions, random, granted, source), "
               "aggregated triggers/targets/verbs/durations/keywords/conditions, cross_lane, pulses, complexity (1-5) "
               "with reasons, hard_reason, and engine {implemented, full, partial, missing, coverage}.")
    out.append("")
    # complexity distribution
    dist = Counter(e["complexity"] for e in counted)
    out.append("## Complexity distribution")
    out.append("")
    out.append("| Score | Cards | Meaning | Examples |")
    out.append("|---:|---:|---|---|")
    meaning = {1: "vanilla / pure stats", 2: "one standard effect", 3: "reactive trigger, aura or status",
               4: "conditions, randomness, movement, counters, hand state", 5: "rule-bending / unique system"}
    for score in range(1, 6):
        out.append("| %d | %d | %s | %s |" % (score, dist.get(score, 0), meaning[score],
                                               md_escape(examples(counted, lambda e, s=score: e["complexity"] == s, 6))))
    out.append("")
    # engine coverage summary
    out.append("## Engine readiness summary")
    out.append("")
    ready = [e for e in counted if e["status"] != "implemented" and not e["engine"]["missing"] and not e["engine"]["partial"]]
    almost = [e for e in counted if e["status"] != "implemented" and not e["engine"]["missing"] and e["engine"]["partial"]]
    out.append("Coverage = (full + 0.5 x partial) / required mechanics, measured against the generic engine facilities "
               "below. The 49 implemented cards work through ad-hoc fields, so their coverage can be < 1.")
    out.append("")
    out.append("- Unimplemented cards whose every mechanic is already fully supported (data only): %d - %s" % (
        len(ready), md_escape(", ".join(e["name"] for e in ready))))
    out.append("- Unimplemented cards needing only partially supported mechanics: %d - %s" % (
        len(almost), md_escape(", ".join(e["name"] for e in almost))))
    missing = Counter()
    for e in counted:
        if e["status"] != "implemented":
            for token in e["engine"]["missing"]:
                missing[token] += 1
    out.append("- Missing mechanics ranked by number of unimplemented cards blocked:")
    out.append("")
    out.append("| Missing mechanic | Cards blocked |")
    out.append("|---|---:|")
    for token, n in ranked(missing):
        out.append("| `%s` | %d |" % (token, n))
    out.append("")
    out.append("## Frequency tables")
    out.append("")
    out.append("Counts are cards (not clauses) among the %d counted cards. 'Engine' is the current engine status "
               "(full / partial / none, see the engine map below)." % len(counted))
    out.append("")
    out += frequency_table(counted, "triggers", TRIGGERS, "Triggers")
    out += frequency_table(counted, "targets", TARGETS, "Target specs")
    out += frequency_table(counted, "verbs", VERBS, "Effect verbs")
    out += frequency_table(counted, "durations", DURATIONS, "Durations")
    # keywords
    kw = Counter()
    for e in counted:
        for k in set(e["keywords"]):
            kw[k] += 1
    out.append("### Keywords (Valve glossary tags + derived)")
    out.append("")
    out.append("| Keyword | Cards | Examples |")
    out.append("|---|---:|---|")
    for k, n in ranked(kw):
        out.append("| %s | %d | %s |" % (k, n, md_escape(examples(counted, lambda e, k=k: k in e["keywords"]))))
    out.append("")
    # trigger filters
    filters = Counter()
    for e in counted:
        for c in e["clauses"]:
            if c.get("trigger_filter"):
                filters[(c["trigger"], c["trigger_filter"])] += 1
    out.append("### Trigger filters")
    out.append("")
    out.append("| Trigger | Filter | Clauses |")
    out.append("|---|---|---:|")
    for (t, f), n in sorted(filters.items()):
        out.append("| `%s` | %s | %d |" % (t, md_escape(f), n))
    out.append("")
    # scopes
    scopes = Counter()
    for e in counted:
        for c in e["clauses"]:
            scopes[c["scope"]] += 1
    out.append("### Lane scope of clauses")
    out.append("")
    out.append("| Scope | Clauses |")
    out.append("|---|---:|")
    for s, n in ranked(scopes):
        out.append("| %s | %d |" % (s, n))
    out.append("")
    # hard cards
    out.append("## Hard cards")
    out.append("")
    out.append("Cards with complexity 5 or a curated reason. Sorted by complexity, then id.")
    out.append("")
    out.append("| Card | Type | Score | Why |")
    out.append("|---|---|---:|---|")
    hard = [e for e in counted if e["complexity"] >= 5 or e["hard_reason"]]
    hard.sort(key=lambda e: (-e["complexity"], e["id"]))
    for e in hard:
        why = e["hard_reason"] or "; ".join(e["complexity_reasons"])
        out.append("| %s (%d) | %s | %d | %s |" % (md_escape(e["name"]), e["id"], e["type"], e["complexity"], md_escape(why)))
    out.append("")
    # rules questions
    out.append("## Rules questions (ambiguous in glossary / wiki)")
    out.append("")
    for rq, question, answer, source in RULES_QUESTIONS:
        out.append("**%s. %s**" % (rq, question))
        out.append("")
        out.append("- Best answer: %s" % answer)
        out.append("- Source: %s" % source)
        out.append("")
    # engine map
    out.append("## Current engine support map")
    out.append("")
    out.append("`full` = a data field drives it generically; `partial` = exists for specific cards or a subset; "
               "`none` = absent. Locations are file:function.")
    out.append("")
    out.append("| Mechanic | Status | Where | Notes |")
    out.append("|---|---|---|---|")
    for token, (status, where, note) in ENGINE_SUPPORT.items():
        out.append("| `%s` | %s | %s | %s |" % (token, status, md_escape(where), md_escape(note)))
    out.append("")
    out.append("Other existing engine facilities relevant to an effect system:")
    out.append("")
    for line in [
        "Seeded RNG and journal: `%s:start`, `_shuffle`, `rng.randi_range`, `replay_data`/`load_replay`, `state_digest`." % E,
        "Lane geometry: `%s:_slot_of`, `_place`, `_spawn`, `_compact`, `_align`, `creep_positions`, `combat_targets`, `_combat_target`, `_roll_arrow(s)`, `_release_attackers`." % E,
        "Death processing: `%s:_clean_dead` (bounty, fountain, rapid deployment, event), `_enter_fountain`, `_remove_from_lane`." % E,
        "Stat queries: `%s:attack_of`, `armor_of`, `_max_health`, `_item_stat`, `battle_attack`, `combat_preview`." % E,
        "Privacy: `%s:player_view` (hides opponent hand/plans/shop/held_secret, deck order) and `simulation_from_view` (bot)." % E,
        "Events: `%s:_event` structured events, displayed by `scripts/core/event_text.gd`." % E,
        "Card data: `scripts/core/card_library.gd:get_card/definition` (ad-hoc numeric fields read by the engine).",
        "Bot: `scripts/ai/heuristic_bot.gd` only understands effect == 'draw' for abilities and simulates via `simulation_from_view`.",
    ]:
        out.append("- " + line)
    out.append("")
    out.append("## Implemented cards: divergences from Valve final text")
    out.append("")
    for e in entries:
        if e.get("divergence"):
            out.append("- **%s (%d)**: %s" % (e["name"], e["id"], e["divergence"]))
    out.append("")
    mism = [e for e in counted if e.get("note_crosslane_mismatch")]
    if mism:
        out.append("## Cross-lane flag mismatches (catalog_mapping vs derived)")
        out.append("")
        for e in mism:
            out.append("- %s (%d): %s" % (e["name"], e["id"], e["note_crosslane_mismatch"]))
        out.append("")
    out.append("## Design notes for the effect system")
    out.append("")
    for note in DESIGN_NOTES:
        out.append("- " + note)
    out.append("")
    # appendix: per-card one-liners
    out.append("## Appendix: per-card classification")
    out.append("")
    out.append("| Id | Card | Type | Col | Cx | Triggers | Targets | Verbs | Engine cov. |")
    out.append("|---:|---|---|---|---:|---|---|---|---:|")
    for e in sorted(counted, key=lambda e: e["id"]):
        out.append("| %d | %s | %s | %s | %d | %s | %s | %s | %s%s |" % (
            e["id"], md_escape(e["name"]), e["type"] + ("/" + e["sub_type"] if e.get("sub_type") else ""),
            e["colour"], e["complexity"], ", ".join(e["triggers"]), ", ".join(e["targets"]),
            ", ".join(e["verbs"]), e["engine"]["coverage"], " (impl)" if e["status"] == "implemented" else ""))
    out.append("")
    return "\n".join(out)


def tags_payload(entries, cards):
    """The trimmed per-card tags committed as tests/data/mechanics_tags.json."""
    out = []
    for e in sorted(entries, key=lambda e: e["id"]):
        valve = cards.get(e["id"], {})
        card = OrderedDict()
        card["source_id"] = e["id"]
        card["id"] = e.get("project_id")
        card["name"] = e["name"]
        card["type"] = e["type"]
        card["counted"] = e["counted"]
        if e.get("parent"):
            card["parent"] = e["parent"]
        if e.get("abilities"):
            card["abilities"] = e["abilities"]
        card["text"] = e["text"]
        for key in TAG_FIELDS:
            card[key] = sorted(set(e[key]))
        card["random"] = e["random"]
        card["get_initiative"] = e["get_initiative"]
        card["pulses"] = e["pulses"]
        cooldowns = sorted(c["cooldown"] for c in e["clauses"] if c.get("cooldown") is not None)
        if cooldowns:
            card["cooldowns"] = cooldowns
        if valve.get("charges"):
            card["charges"] = valve["charges"]
        card["clauses"] = [OrderedDict([("text", c["text"]), ("trigger", c["trigger"]), ("targets", c["targets"]),
                                        ("verbs", c["verbs"]), ("durations", c["durations"]), ("random", c["random"])])
                           for c in e["clauses"]]
        out.append(card)
    return OrderedDict([
        ("generated_by", "tools/mechanics.py"),
        ("description", "Valve's final English text and the mechanics tags of every Classic card and ability, "
                        "trimmed from the full inventory. Regenerate with tools/mechanics.py."),
        ("vocab", OrderedDict([("triggers", list(TRIGGERS)), ("targets", list(TARGETS)), ("verbs", list(VERBS)),
                               ("durations", list(DURATIONS))])),
        ("cards", out),
    ])


def write_tags(path, tags):
    """One card per line, so diffs point at the changed card."""
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("{\n")
        for key in tags:
            if key != "cards":
                handle.write("%s: %s,\n" % (json.dumps(key), json.dumps(tags[key], ensure_ascii=False)))
        handle.write('"cards": [\n')
        for index, card in enumerate(tags["cards"]):
            handle.write(json.dumps(card, ensure_ascii=False) + ("," if index < len(tags["cards"]) - 1 else "") + "\n")
        handle.write("]}\n")


def main():
    global VALVE_FILES, LOC_FILES, GLOSSARY_FILE, OUT_JSON, OUT_MD, OUT_TAGS
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--set00", default=VALVE_FILES[0])
    parser.add_argument("--set01", default=VALVE_FILES[1])
    parser.add_argument("--loc00", default=LOC_FILES[0])
    parser.add_argument("--loc01", default=LOC_FILES[1])
    parser.add_argument("--glossary", default=GLOSSARY_FILE)
    parser.add_argument("--md", default=OUT_MD)
    parser.add_argument("--tags", default=OUT_TAGS)
    parser.add_argument("--json", default=None, help="also write the full inventory here")
    args = parser.parse_args()
    VALVE_FILES = [args.set00, args.set01]
    LOC_FILES = [args.loc00, args.loc01]
    GLOSSARY_FILE = args.glossary
    OUT_JSON, OUT_MD, OUT_TAGS = args.json, args.md, args.tags
    entries, cards, loc = build()
    if OUT_JSON:
        payload = OrderedDict([
            ("generated_by", "tools/mechanics.py"),
            ("sources", {"valve": [os.path.basename(p) for p in VALVE_FILES],
                         "localization": [os.path.basename(p) for p in LOC_FILES],
                         "glossary": os.path.basename(GLOSSARY_FILE),
                         "project": ["data/classic_cards.json", "data/catalog/catalog_mapping.json"]}),
            ("vocab", OrderedDict([("triggers", TRIGGERS), ("targets", TARGETS), ("verbs", VERBS), ("durations", DURATIONS)])),
            ("engine_support", OrderedDict((k, {"status": v[0], "where": v[1], "note": v[2]}) for k, v in ENGINE_SUPPORT.items())),
            ("rules_questions", [OrderedDict([("id", q[0]), ("question", q[1]), ("answer", q[2]), ("source", q[3])]) for q in RULES_QUESTIONS]),
            ("frequencies", OrderedDict(
                (key, OrderedDict(ranked(Counter(v for e in entries if e["counted"] for v in set(e[key])))))
                for key in ("triggers", "targets", "verbs", "durations", "keywords"))),
            ("complexity", OrderedDict(sorted(Counter(e["complexity"] for e in entries if e["counted"]).items()))),
            ("cards", entries),
        ])
        with open(OUT_JSON, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=1)
    with open(OUT_MD, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(report(entries))
    write_tags(OUT_TAGS, tags_payload(entries, cards))
    counted = [e for e in entries if e["counted"]]
    print("cards counted: %d, abilities: %d" % (len(counted), len(entries) - len(counted)))


if __name__ == "__main__":
    main()
