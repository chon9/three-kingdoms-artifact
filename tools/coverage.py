#!/usr/bin/env python3
"""Valve parity of every Classic card's rules (docs/design/EFFECT_SYSTEM_SPEC.md §13.7 item 10, CF-12).

    python tools/coverage.py            # check, print a report, write tests/data/coverage.json
    python tools/coverage.py --check    # exit 1 when tests/data/coverage.json is stale or a card fails

For every counted Classic card (the shipped entry in data/classic_cards.json, otherwise its
schema-4 draft in tests/data/classic_rules_drafts.json) it compares the rules with Valve's data
in tests/data/mechanics_tags.json:
  * the sorted cooldowns of its actives equal Valve's "Active N" values (one per ability card);
  * its top-level charges equal Valve's charges field where Valve has one;
  * the number of pulse ops equals the number of Valve's Pulse markers;
  * play.initiative is set exactly when the text says "Get initiative";
  * text tagged random contains a pick, chance, from_pool or random_other;
  * each verb and trigger tag maps to an op, keyword, rules key, listener or block (VERBS and
    TRIGGERS below).
The tables are written to tests/data/coverage.json; tests/rules_schema_test.gd applies them in
GDScript to every card (the GDScript validator stays the only authority; this script reports)
and fails when the file is stale.

Generalizes the review script of the effect-system design (effects/coverage.py), which built
entries from Valve's set files; this one reads only committed data.
"""
import hashlib
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK = "data/classic_cards.json"
DRAFTS = "tests/data/classic_rules_drafts.json"
TAGS = "tests/data/mechanics_tags.json"
OUTPUT = "tests/data/coverage.json"

# A tag holds when the card uses one of the listed ops, keywords (printed, granted or given),
# rules keys, ability kinds, trigger events, blocks or top-level fields, or when its JSON
# contains one of the listed text fragments. An empty rule always holds.
VERBS = {
    "damage": {"ops": ["damage", "damage_split", "tower_damage"]},
    "piercing_damage": {"ops": ["damage", "tower_damage"]},
    "damage_split": {"ops": ["damage_split"]},
    "tower_damage": {"ops": ["tower_damage"]},
    "damage_bonus": {"keywords": ["bonus_hero", "bonus_tower"]},
    "heal": {"ops": ["heal", "tower_heal"]},
    "full_heal": {"ops": ["heal"]},
    "tower_heal": {"ops": ["tower_heal"]},
    "modify": {"ops": ["modify"]},
    "temp_buff": {"ops": ["give"]},
    "stat_attack": {},
    "stat_armor": {},
    "stat_health": {},
    "siege": {"keywords": ["siege"]},
    "cleave": {"keywords": ["cleave"]},
    "retaliate": {"keywords": ["retaliate"]},
    "regeneration": {"keywords": ["regeneration"]},
    "pierce": {"keywords": ["pierce"]},
    "bounty": {"keywords": ["bounty"]},
    "rapid_deployment": {"keywords": ["rapid_deployment"]},
    "mana_change": {"keywords": ["mana"], "text": ['"mana"']},
    "mana_restore": {"ops": ["mana"]},
    "gold_gain": {"ops": ["gold"]},
    "gold_spend": {"ops": ["gold"]},
    "gold_double": {"ops": ["gold"]},
    "cost_reduction": {"rules": ["secret_shop_discount"]},
    "draw": {"ops": ["draw"], "rules": ["round_draw"]},
    "discard": {"ops": ["discard"]},
    "discard_hand": {"ops": ["discard"]},
    "add_card_to_hand": {"ops": ["add_card"]},
    "copy_card": {"ops": ["add_card"]},
    "summon": {"ops": ["summon"]},
    "condemn": {"ops": ["condemn"], "keywords": ["lethal", "lethal_creeps", "lethal_heroes"]},
    "stun": {"keywords": ["stun"]},
    "silence": {"keywords": ["silence"]},
    "disarm": {"keywords": ["disarm"]},
    "taunt": {"ops": ["taunt"]},
    "lock": {"ops": ["lock"]},
    "purge": {"ops": ["purge"]},
    "swap": {"ops": ["swap"]},
    "move": {"ops": ["move"]},
    "change_combat_target": {"ops": ["retarget", "taunt"]},
    "battle": {"ops": ["battle"]},
    "return_to_fountain": {"ops": ["to_fountain"]},
    "steal_control": {"ops": ["control"]},
    "death_shield": {"keywords": ["death_shield"]},
    "damage_immunity": {"keywords": ["damage_immunity"]},
    "get_initiative": {"initiative": True},
    "quicken": {"text": ['"quicken": true']},
    "charges": {"ops": ["charges", "card_counter"], "text": ['"charges"']},
    "repeat": {"ops": ["repeat"], "text": ['"count": {']},
    "random_chance": {"ops": ["chance"]},
    "scaling_x": {},
    "grant_text": {"fields": ["grants"]},
    "hack_hand_card": {"text": ['"kind": "hack"']},
    "play_restriction": {"rules": ["forbid_play"]},
    "activation_condition": {"text": ['"requires"']},
    "end_action_phase": {"ops": ["end_action_phase"]},
    "deploy_redirect": {"rules": ["creep_lane"]},
    "soulbound": {"keywords": ["soulbound"]},
    "lethal": {"keywords": ["lethal", "lethal_creeps", "lethal_heroes"]},
}
TRIGGERS = {
    "play": {"blocks": ["play"]},
    "play_effect": {"blocks": ["play"]},
    "equip_effect": {"blocks": ["enter"]},
    "equip": {},
    "continuous": {"kinds": ["aura"], "fields": ["keywords"]},
    "active": {"kinds": ["active"]},
    "before_action": {"events": ["before_action"]},
    "after_combat": {"events": ["after_combat"]},
    "deployment_phase": {"events": ["deployment"], "rules": ["creep_lane"]},
    "round_draw": {"rules": ["round_draw"], "events": ["card_drawn"]},
    "self_death": {"events": ["death"]},
    "ally_death": {"events": ["unit_died"]},
    "enemy_death": {"events": ["unit_died"]},
    "hero_death": {"events": ["unit_died"]},
    "blocker_death": {"events": ["unit_died"]},
    "after_you_play": {"events": ["card_played"]},
    "after_opponent_plays": {"events": ["card_played"]},
    "battle_damage_dealt": {"events": ["battle_damage"], "keywords": ["lethal", "lethal_creeps", "lethal_heroes"]},
    "battle_damage_taken": {"events": ["battle_damage"]},
    "unit_enters_lane": {"events": ["unit_entered"]},
    "improvement_enters_lane": {"events": ["improvement_entered"]},
    "opponent_draws": {"events": ["card_drawn"]},
    "shop_phase": {"rules": ["secret_shop_discount"], "ops": ["add_card"]},
    "hacked_card_played": {"text": ['"kind": "hack"']},
}


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as handle:
        return json.load(handle)


def walk(value, visit):
    visit(value)
    if isinstance(value, dict):
        for item in value.values():
            walk(item, visit)
    elif isinstance(value, list):
        for item in value:
            walk(item, visit)


def facts(entry):
    """What a card entry uses: ops, keywords, rules keys, ability kinds, events, blocks, fields."""
    out = {"ops": set(), "keywords": set(), "rules": set(), "kinds": set(), "events": set(), "blocks": set(),
           "fields": set(), "pulses": 0, "random": False}

    def visit(value):
        if not isinstance(value, dict):
            return
        if "op" in value:
            out["ops"].add(value["op"])
            if value["op"] == "pulse":
                out["pulses"] += 1
            if value["op"] == "chance" or value.get("from_pool") or value.get("lane") == "random_other":
                out["random"] = True
        if "pick" in value:
            out["random"] = True
        for key in ("keywords",):
            if isinstance(value.get(key), dict):
                out["keywords"].update(value[key])
        if isinstance(value.get("grant"), dict):
            out["keywords"].update(k for k in value["grant"] if k != "rules")
            if isinstance(value["grant"].get("rules"), dict):
                out["rules"].update(value["grant"]["rules"])
        if value.get("kind") in ("aura", "trigger", "active", "hack") and ("ops" in value or "grant" in value):
            out["kinds"].add(value["kind"])
        if value.get("kind") == "trigger" and "on" in value:
            out["events"].add(value["on"])
    walk(entry, visit)
    for block in ("play", "enter"):
        if block in entry:
            out["blocks"].add(block)
    for field in ("grants", "keywords"):
        if entry.get(field):
            out["fields"].add(field)
    if entry.get("keywords"):
        out["keywords"].update(entry["keywords"])
    return out


def holds(rule, entry, known, text):
    if not rule:
        return True
    if rule.get("initiative") and entry.get("play", {}).get("initiative"):
        return True
    for key in ("ops", "keywords", "rules", "kinds", "events", "blocks", "fields"):
        if known[key] & set(rule.get(key, [])):
            return True
    return any(fragment in text for fragment in rule.get("text", []))


def check(entry, tag):
    problems = []
    known = facts(entry)
    text = json.dumps(entry, sort_keys=True)
    cooldowns = sorted(int(a["cooldown"]) if isinstance(a.get("cooldown"), int) else int(entry.get(a["cooldown"]["param"], 0))
                       for a in entry.get("abilities", []) if a.get("kind") == "active")
    if cooldowns != sorted(tag.get("valve_cooldowns", [])):
        problems.append("active cooldowns %s, Valve %s" % (cooldowns, sorted(tag.get("valve_cooldowns", []))))
    if "charges" in tag and entry.get("charges") != tag["charges"]:
        problems.append("charges %s, Valve %s" % (entry.get("charges"), tag["charges"]))
    if known["pulses"] != tag.get("pulses", 0):
        problems.append("%d pulse ops, Valve %d markers" % (known["pulses"], tag.get("pulses", 0)))
    if bool(entry.get("play", {}).get("initiative")) != bool(tag.get("get_initiative")):
        problems.append("Get initiative differs from Valve")
    if tag.get("random") and not known["random"] and "creep_lane" not in text:
        problems.append("the Valve text is random but the rules draw no randomness")
    for verb in tag.get("verbs", []):
        if verb not in VERBS:
            problems.append("verb tag %s has no rule in tools/coverage.py" % verb)
        elif not holds(VERBS[verb], entry, known, text):
            problems.append("verb tag %s maps to nothing in the rules" % verb)
    for trigger in tag.get("triggers", []):
        if trigger not in TRIGGERS:
            problems.append("trigger tag %s has no rule in tools/coverage.py" % trigger)
        elif not holds(TRIGGERS[trigger], entry, known, text):
            problems.append("trigger tag %s maps to nothing in the rules" % trigger)
    return problems


def source_hash():
    with open(os.path.abspath(__file__), "rb") as handle:
        return hashlib.sha256(handle.read().decode("utf-8").replace("\r", "").encode("utf-8")).hexdigest()


def build():
    pack = read(PACK)
    shipped = {entry["source_id"]: entry for entry in pack["heroes"] + pack["cards"]}
    drafts = {entry["source_id"]: entry for entry in read(DRAFTS)["cards"]}
    tags = read(TAGS)["cards"]
    children = {}
    for tag in tags:
        if "parent" in tag:
            children.setdefault(tag["parent"], []).append(tag)
    results = {}
    for tag in tags:
        if not tag.get("counted"):
            continue
        entry = shipped.get(tag["source_id"]) or drafts.get(tag["source_id"])
        if entry is None:
            results[tag["id"] or str(tag["source_id"])] = {"source": "missing", "problems": ["no entry"]}
            continue
        wanted = [child["cooldowns"][0] for child in children.get(tag["source_id"], [])
                  if child.get("type") == "Ability" and child.get("cooldowns")]
        if not wanted:
            import re
            wanted = [int(found) for found in re.findall(r"Active (\d+)", tag.get("text", ""))]
        enriched = dict(tag)
        enriched["valve_cooldowns"] = wanted
        results[entry["id"]] = {"source": "shipped" if tag["source_id"] in shipped else "draft",
                                "problems": check(entry, enriched)}
    abilities = [tag for tag in tags if not tag.get("counted")]
    parents = {tag["source_id"]: tag for tag in tags if tag.get("counted")}
    orphans = [tag["name"] for tag in abilities if tag.get("parent") not in parents]
    return {"generated_by": "tools/coverage.py", "source_sha256": source_hash(),
            "description": "Valve parity tables (verb and trigger tags to rules) and per-card results. Regenerate with python tools/coverage.py.",
            "verbs": VERBS, "triggers": TRIGGERS,
            "summary": {"cards": len(results), "passing": sum(1 for r in results.values() if not r["problems"]),
                        "abilities": len(abilities), "abilities_with_parent": len(abilities) - len(orphans)},
            "cards": dict(sorted(results.items()))}


def render(report):
    lines = ["{"]
    for key in ("generated_by", "source_sha256", "description", "verbs", "triggers", "summary"):
        lines.append("%s: %s," % (json.dumps(key), json.dumps(report[key], sort_keys=True)))
    lines.append('"cards": {')
    items = list(report["cards"].items())
    for index, (card_id, result) in enumerate(items):
        lines.append("%s: %s%s" % (json.dumps(card_id), json.dumps(result, sort_keys=True), "," if index < len(items) - 1 else ""))
    lines.append("}}")
    return "\n".join(lines) + "\n"


def main():
    report = build()
    text = render(report)
    path = os.path.join(ROOT, OUTPUT)
    current = open(path, encoding="utf-8").read().replace("\r", "") if os.path.exists(path) else ""
    failing = {card_id: result["problems"] for card_id, result in report["cards"].items() if result["problems"]}
    summary = report["summary"]
    print("Valve parity: %d / %d counted cards pass; %d / %d ability cards map to a parent." % (
        summary["passing"], summary["cards"], summary["abilities_with_parent"], summary["abilities"]))
    for card_id, problems in failing.items():
        print("  %-28s %s" % (card_id, "; ".join(problems)))
    if "--check" in sys.argv:
        stale = current != text
        if stale:
            print("tests/data/coverage.json is STALE: run python tools/coverage.py")
        return 1 if stale or failing else 0
    if current != text:
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
        print("wrote " + OUTPUT)
    return 1 if failing else 0


if __name__ == "__main__":
    sys.exit(main())
