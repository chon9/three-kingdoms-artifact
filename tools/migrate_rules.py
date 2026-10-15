#!/usr/bin/env python3
"""Migrates the card packs to rules schema 4 (docs/design/EFFECT_SYSTEM_SPEC.md §11.1).

    python tools/migrate_rules.py --dual      # step M1.2: rules next to the legacy fields
    python tools/migrate_rules.py             # step M1.3: cut over (drop legacy fields, schema 4 / 2)
    python tools/migrate_rules.py --check     # report only

The legacy effect fields (`effect`, `target`, `include_tower`, ...) become a
`play` block, unit fields become abilities or keywords, and every entry gets
`"status": "verified"`. Numbers stay top-level as params, so locale
{placeholders} keep filling. `valve_text` comes from tests/data/mechanics_tags.json
(Valve's English text; Classic cards only).

Deterministic and idempotent: running it twice gives the same files.
"""
import argparse
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLASSIC = os.path.join(ROOT, "data", "classic_cards.json")
TRAINING = os.path.join(ROOT, "data", "training_cards.json")
TAGS = os.path.join(ROOT, "tests", "data", "mechanics_tags.json")
LEGACY_FIELDS = ["effect", "target", "include_tower", "piercing", "neighbors", "discard_random", "initiative",
                 "ability", "rapid_deployment"]
# Ability ids and Valve ability card ids of the migrated passives and actives.
ABILITY_IDS = {
    "jmuy": ("wisdom_of_the_elders", 4009), "farvhan": ("pack_leadership", 4001),
    "lycan": ("feral_impulse", 10494), "drow": ("precision_aura", 10504),
    "zeus": ("static_field", 10519), "prowler_vanguard": ("vanguard", None),
    "savage_wolf": ("growth", None),
}
TOKENS = {"melee_creep"}
TARGETS = {
    "unit": "units", "hero": "heroes", "creep": "creeps",
    "red_hero": {"s": "units", "kind": "hero", "color": "red"},
    "ally_hero": "allied_heroes",
    "ally_red_hero": {"s": "units", "side": "ally", "kind": "hero", "color": "red"},
    "enemy_hero": "enemy_heroes", "ally": "allies", "enemy": "enemies",
}


def param(name):
    return {"param": name}


def target_from(card):
    selector = TARGETS[card["target"]]
    if card.get("cross_lane"):
        if isinstance(selector, str):
            return {"use": selector, "lane": "all"} if selector != "units" else {"s": "units", "lane": "all"}
        return dict(selector, lane="all")
    return selector


def stats_of(card, keys=("attack", "armor")):
    return {key: param(key) for key in keys if card.get(key)}


def play_block(card):
    """The schema-4 play block of a legacy spell, consumable or initiative card."""
    effect = card.get("effect")
    choices = []
    if card.get("target", "none") != "none" and effect != "equip":
        choices.append({"key": "target", "from": target_from(card)})
    ops = []
    if effect == "damage":
        op = {"op": "damage", "to": "$c.target", "amount": param("amount")}
        if card.get("piercing"):
            op["piercing"] = True
        ops.append(op)
    elif effect == "area_damage":
        ops.append({"op": "damage", "to": "enemies", "amount": param("amount")})
        if card.get("include_tower"):
            ops.append({"op": "tower_damage", "to": "enemy_tower", "amount": param("amount")})
    elif effect == "heal":
        ops.append({"op": "heal", "to": "$c.target", "amount": param("amount")})
    elif effect == "buff":
        ops.append({"op": "give", "to": "$c.target", "stats": stats_of(card), "until": "round"})
    elif effect == "modify":
        ops.append({"op": "modify", "to": "$c.target", "stats": stats_of(card)})
    elif effect == "modify_creeps":
        ops.append({"op": "modify", "to": "allied_creeps", "stats": stats_of(card)})
    elif effect == "silence":
        to = "$c.target"
        if card.get("neighbors"):
            to = ["$c.target", {"s": "units", "rel": {"allied_neighbors": "$c.target"}}]
        ops.append({"op": "give", "to": to, "keywords": {"silence": 1}, "until": "round"})
    elif effect == "condemn":
        if card.get("discard_random"):
            ops.append({"op": "discard", "cards": {"use": "your_hand", "pick": {"random": 1}}})
        ops.append({"op": "condemn", "to": "$c.target"})
    elif effect == "condemn_lane":
        ops.append({"op": "condemn", "to": "units"})
    elif effect == "global_hero_damage":
        op = {"op": "damage", "to": {"s": "units", "side": "enemy", "kind": "hero", "lane": "all"}, "amount": param("amount")}
        if card.get("piercing"):
            op["piercing"] = True
        ops.append(op)
    elif effect == "siege_buff":
        ops.append({"op": "give", "to": "allies", "keywords": {"siege": param("siege")}, "until": "round"})
        ops.append({"op": "retarget", "unit": "allies", "to": "across"})
    elif effect == "return_hero":
        ops.append({"op": "to_fountain", "unit": "$c.target"})
    elif effect == "battle_neighbors":
        ops.append({"op": "battle", "a": "$c.target", "b": {"s": "units", "rel": {"enemy_neighbors": "$c.target"}}})
    elif effect == "redirect":
        choices.append({"key": "destination", "combat_target_of": "$c.target"})
        ops.append({"op": "retarget", "unit": "$c.target", "to": "$c.destination"})
    elif effect == "summon":
        ops.append({"op": "summon", "card": "melee_creep", "count": param("amount")})
    elif effect == "mana":
        ops.append({"op": "give", "to": "your_tower", "stats": {"mana": param("amount")}, "until": "round"})
    elif effect == "draw":
        ops.append({"op": "draw", "player": "you", "n": param("amount")})
    elif effect == "tower_damage":
        ops.append({"op": "tower_damage", "to": "enemy_tower", "amount": param("amount")})
    elif effect in (None, "equip", "initiative"):
        pass
    else:
        raise SystemExit("%s: unknown legacy effect %s" % (card["id"], effect))
    if effect == "equip" or (card.get("kind") == "creep" and not ops):
        return None
    block = {}
    if choices:
        block["choices"] = choices
    block["ops"] = ops
    if card.get("initiative"):
        block["initiative"] = True
    return block


def unit_rules(card):
    """Abilities and keywords of a legacy hero or creep."""
    abilities = []
    keywords = {}
    ids = ABILITY_IDS.get(card["id"], ("ability", None))

    def ability(entry):
        entry = dict({"id": ids[0]}, **entry)
        if ids[1]:
            entry["valve"] = ids[1]
        abilities.append(entry)

    if card.get("neighbor_armor"):
        ability({"kind": "aura", "affects": "allied_neighbors", "grant": {"armor": param("neighbor_armor")}})
    if card.get("neighbor_attack"):
        ability({"kind": "aura", "affects": "allied_neighbors", "grant": {"attack": param("neighbor_attack")}})
    if card.get("global_attack"):
        ability({"kind": "aura", "affects": {"use": "other_allies", "lane": "all"}, "grant": {"attack": param("global_attack")}})
    if card.get("static_field"):
        ability({"kind": "trigger", "on": "card_played", "filter": {"player": "you", "kind": "spell", "color": "blue"},
                 "ops": [{"op": "damage", "to": "enemy_neighbors", "amount": param("static_field"), "piercing": True}]})
    if card.get("combat_growth_attack") or card.get("combat_growth_health"):
        stats = {}
        if card.get("combat_growth_attack"):
            stats["attack"] = param("combat_growth_attack")
        if card.get("combat_growth_health"):
            stats["max_health"] = param("combat_growth_health")
        ability({"kind": "trigger", "on": "after_combat", "ops": [{"op": "modify", "to": "$self", "stats": stats}]})
    if card.get("ability") == "draw":
        ability({"kind": "active", "cooldown": param("ability_cooldown"), "ops": [{"op": "draw", "player": "you", "n": 1}]})
    if card.get("hero_bonus"):
        keywords["bonus_hero"] = param("hero_bonus")
    if card.get("hero_tower_bonus"):
        keywords["bonus_hero"] = param("hero_tower_bonus")
        keywords["bonus_tower"] = param("hero_tower_bonus")
    if card.get("rapid_deployment"):
        keywords["rapid_deployment"] = 1
    if card.get("siege") and card.get("kind") in ("creep", "hero"):
        keywords["siege"] = param("siege")
    return abilities, keywords


def migrate_entry(card, is_hero, valve_texts, cutover):
    out = dict(card)
    if is_hero and "kind" not in out:
        out["kind"] = "hero"
    out.setdefault("status", "verified")
    if card["id"] in TOKENS:
        out["token"] = True
    if out.get("kind") in ("hero", "creep"):
        abilities, keywords = unit_rules(card)
        if keywords and "keywords" not in out:
            out["keywords"] = keywords
        if abilities and "abilities" not in out:
            out["abilities"] = abilities
    if out.get("kind") != "hero" and "play" not in out:
        block = play_block(card) if ("effect" in card or card.get("initiative")) else None
        if block is not None:
            out["play"] = block
    if card["id"] == "centaur_hunter":
        out.setdefault("rq", ["RQ-48"])
    if card["id"] in ("tower_barrage", "thunderstorm"):
        out.setdefault("rq", ["RQ-01"])
    if card["id"] == "annihilation":
        out.setdefault("rq", ["RQ-02", "RQ-04"])
    if card["id"] == "battlefield_control":
        out.setdefault("rq", ["RQ-19"])
    text = valve_texts.get(str(card.get("source_id", "")))
    if text is not None and "valve_text" not in out:
        out["valve_text"] = text
    if cutover:
        for field in LEGACY_FIELDS:
            out.pop(field, None)
    return out


def load_valve_texts(path):
    if not os.path.exists(path):
        return {}
    data = json.load(open(path, encoding="utf-8"))
    return {str(card["source_id"]): card["text"] for card in data.get("cards", []) if card.get("text") is not None}


def training_dump(data):
    """The training pack keeps one compact JSON object per hero or card."""
    lines = ["{"]
    keys = [key for key in data if key not in ("heroes", "cards")]
    for key in keys:
        lines.append("  %s: %s," % (json.dumps(key), json.dumps(data[key], ensure_ascii=False)))
    for section in ("heroes", "cards"):
        lines.append("  %s: [" % json.dumps(section))
        entries = data[section]
        for index, entry in enumerate(entries):
            text = json.dumps(entry, ensure_ascii=False, separators=(",", ":"))
            lines.append("    " + text + ("," if index < len(entries) - 1 else ""))
        lines.append("  ]" + ("," if section == "heroes" else ""))
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dual", action="store_true", help="keep the legacy fields next to the rules (step M1.2)")
    parser.add_argument("--check", action="store_true", help="report what would change without writing")
    parser.add_argument("--tags", default=TAGS, help="mechanics tags with Valve texts (tests/data/mechanics_tags.json)")
    args = parser.parse_args()
    valve_texts = load_valve_texts(args.tags)
    cutover = not args.dual
    changed = []
    for path, schema in ((CLASSIC, 4), (TRAINING, 2)):
        raw = open(path, encoding="utf-8").read()
        data = json.loads(raw)
        data["heroes"] = [migrate_entry(card, True, valve_texts, cutover) for card in data["heroes"]]
        data["cards"] = [migrate_entry(card, False, valve_texts, cutover) for card in data["cards"]]
        if cutover:
            data["schema_version"] = schema
        text = json.dumps(data, indent=2, ensure_ascii=False) + "\n" if path == CLASSIC else training_dump(data)
        if text != raw:
            changed.append(os.path.relpath(path, ROOT))
            if not args.check:
                with open(path, "w", encoding="utf-8", newline="\n") as handle:
                    handle.write(text)
    print(("would change: " if args.check else "changed: ") + (", ".join(changed) if changed else "nothing"))
    return 1 if (args.check and changed) else 0


if __name__ == "__main__":
    sys.exit(main())
