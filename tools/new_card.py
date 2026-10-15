#!/usr/bin/env python3
"""Scaffolds a new Classic card (docs/EFFECTS.md, EFFECT_SYSTEM_SPEC.md Appendix B).

    python tools/new_card.py "Chain Frost"          # a Valve name, a Valve id (10318) or an id (chain_frost)
    python tools/new_card.py 10318 --dry-run        # print everything it would write; change nothing

It writes four things:
  * a "draft" entry in data/classic_cards.json (heroes go to "heroes", every
    other card to "cards"). Rules and numbers come from the schema-4 draft in
    tests/data/classic_rules_drafts.json, the name and artist from Valve's set
    files, and "valve_text" from tests/data/mechanics_tags.json;
  * the card's Valve art in assets/classic_cards/manifest.json (download it
    with tools/fetch_classic_art.ps1; the images are not committed);
  * locale entries in data/locale/cards.json for both skins, in en and zh_CN:
    three_kingdoms from data/catalog/catalog_mapping.json, classic from Valve's
    English and Simplified Chinese localization. A number in the text that
    equals exactly one card parameter becomes that {placeholder};
  * tests/cards/<id>.json: one empty case per Valve clause, with "covers" taken
    from the clause tags in tests/data/mechanics_tags.json (spec §13.1).

The card stays a draft: validate_preset rejects it until its rules are
reviewed, its spec cases pass and its status is "verified". Afterwards run
tests/rules_schema_test.gd and python tools/rules_hash.py (the data packs are
part of RULES_VERSION). Valve's set files (.tools/valve_set0X_final.json) are
optional: without them the names come from mechanics_tags.json and the classic
skin gets English text only.
"""
import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLASSIC = "data/classic_cards.json"
LOCALE = "data/locale/cards.json"
MAPPING = "data/catalog/catalog_mapping.json"
DRAFTS = "tests/data/classic_rules_drafts.json"
TAGS = "tests/data/mechanics_tags.json"
VALVE_SETS = [".tools/valve_set00_final.json", ".tools/valve_set01_final.json"]
CARD_TESTS = "tests/cards"
ART_MANIFEST = "assets/classic_cards/manifest.json"
FONT_TEXT = ["i18n/ui.csv", "data/locale/cards.json", "data/locale/glossary.json"]

## Fields that are not rule parameters (scripts/core/rules/vocab.gd CARD_FIELDS).
CARD_FIELDS = {"id", "source_id", "kind", "color", "cost", "price", "attack", "armor", "health",
               "signature", "slot", "text", "image", "artist", "image_patch", "consumable", "cross_lane",
               "status", "token", "rq", "keywords", "charges", "play", "enter", "abilities", "grants", "ai",
               "valve_text", "name", "ability_name"}
RULE_BLOCKS = ["keywords", "play", "enter", "abilities", "grants"]
FACTIONS = {"Shu": "shu", "Wei": "wei", "Wu": "wu", "Qun": "qun"}


def read_json(root, path, required=True):
    full = os.path.join(root, path)
    if not os.path.exists(full):
        if required:
            sys.exit("new_card: missing %s" % path)
        return None
    with open(full, encoding="utf-8", newline="") as handle:
        return handle.read()


def dump_like(original, data):
    """Serializes `data` the way `original` is formatted (tab or two-space indent,
    trailing newline or not), so an unchanged part of the file stays byte-identical."""
    indent = "\t" if re.search(r'^\{\n\t"', original) else 2
    text = json.dumps(data, indent=indent, ensure_ascii=False)
    return text + "\n" if original.endswith("\n") else text


def strip_html(text, chinese=False):
    """Valve card text without markup; Chinese text needs no spaces between sentences."""
    text = re.sub(r"<br\s*/?>", "" if chinese else " ", text or "")
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    if chinese:
        text = re.sub(r"\s*([\u3000-\u303f\uff00-\uffef])\s*", r"\1", text)
    return text


def ordered(block):
    """A play block or ability with its keys in the order docs/EFFECTS.md uses."""
    order = ["id", "kind", "valve", "on", "filter", "where", "lane", "once_per", "affects", "if", "grant",
             "cooldown", "quicken", "choices", "requires", "ops", "initiative"]
    keys = sorted(block, key=lambda key: order.index(key) if key in order else len(order))
    return {key: block[key] for key in keys}


def valve_cards(root):
    cards = {}
    for path in VALVE_SETS:
        raw = read_json(root, path, required=False)
        if raw is None:
            continue
        for card in json.loads(raw).get("card_set", {}).get("card_list", []):
            cards[int(card["card_id"])] = card
    return cards


def find_draft(drafts, tags, valve, query):
    by_id = {str(card["id"]): card for card in drafts}
    by_source = {int(card["source_id"]): card for card in drafts}
    if query.isdigit():
        return by_source.get(int(query))
    if query in by_id:
        return by_id[query]
    wanted = query.strip().lower()
    for card in tags:
        if str(card.get("name", "")).lower() == wanted and int(card["source_id"]) in by_source:
            return by_source[int(card["source_id"])]
    for source_id, card in valve.items():
        if str(card.get("card_name", {}).get("english", "")).lower() == wanted and source_id in by_source:
            return by_source[source_id]
    return None


## Stats are only replaced right before their own word ("+2 Attack", "2攻击").
STAT_WORDS = {"attack": "attack|攻击", "armor": "armor|护甲", "health": "health|体力"}
## A number after one of these is a cooldown: only {ability_cooldown} may replace it.
NOT_COOLDOWN = r"(?<!Active )(?<!cooldown )(?<!冷却)(?<!主动)"
## A cost threshold ("costing 2 or less") is never a card parameter: the
## card_played filter's cost_max is a literal number.
NOT_COST = r"(?!\s*or less)(?!或更低)(?!以下)"


def number(value, draft):
    """An int field of a draft, or the value of the {"param": name} it reads."""
    if isinstance(value, dict) and "param" in value:
        value = draft.get(value["param"], 0)
    return int(value or 0)


def candidate_params(draft):
    """Parameters a card text may show as {placeholders} anywhere."""
    names = [key for key, value in draft.items() if isinstance(value, int) and not isinstance(value, bool)
             and key not in CARD_FIELDS and key != "ability_cooldown"]
    if isinstance(draft.get("charges"), int):
        names.append("charges")
    return names


def placeholders(text, draft, notes, label):
    """Replaces numbers that are card parameters with {placeholders}: stats before
    their word, a cooldown after its word, and any other number that equals
    exactly one parameter. Every replacement is reported for review."""
    if not text:
        return text

    def replace(pattern, name, value, flags=0):
        nonlocal text
        text, count = re.subn(pattern, "{%s}" % name, text, flags=flags)
        if count:
            notes.append("%s: %d -> {%s} (%d time%s)" % (label, value, name, count, "" if count == 1 else "s"))

    for stat, words in STAT_WORDS.items():
        # "+2 Attack" is a modification, never the card's own printed stat.
        if isinstance(draft.get(stat), int):
            replace(r"(?<![\d{+\-−])%d(?=\s*(?:%s))" % (draft[stat], words), stat, draft[stat], re.IGNORECASE)
    if isinstance(draft.get("ability_cooldown"), int):
        value = draft["ability_cooldown"]
        replace(r"(?<=Active )%d(?![\d}])|(?<=cooldown )%d(?![\d}])|(?<=冷却)%d(?![\d}])|(?<=主动)%d(?![\d}])"
                % (value, value, value, value), "ability_cooldown", value)
    values = {}
    for name in candidate_params(draft):
        values.setdefault(int(draft[name]), []).append(name)
    for value, names in sorted(values.items(), key=lambda item: -len(str(item[0]))):
        pattern = NOT_COOLDOWN + r"(?<![\d{])%d(?![\d}])" % value + NOT_COST
        if len(names) != 1:
            if re.search(pattern, text):
                notes.append("%s: %d matches %s; left as a number" % (label, value, " and ".join(names)))
            continue
        replace(pattern, names[0], value)
    return text


def ability_card(draft, tags_by_source, valve):
    """The Valve ability card of a hero or item (first listed ability), or None."""
    for ability in draft.get("abilities", []):
        if "valve" in ability:
            source = int(ability["valve"])
            return ability, tags_by_source.get(source, {}), valve.get(source, {})
    return None, {}, {}


def strip_marker(name):
    return re.sub(r"\s*[（(][^）)]*[）)]\s*$", "", name or "").strip()


def build_entry(root, draft, tags_entry, valve_card, ability, ability_tags, ability_valve, pack_ids, notes):
    entry = {"id": draft["id"], "source_id": draft["source_id"]}
    entry["name"] = valve_card.get("card_name", {}).get("english") or tags_entry.get("name") or draft["id"]
    entry["color"] = draft.get("color", "neutral")
    entry["kind"] = draft["kind"]
    entry["cost"] = int(draft.get("cost", 0))
    entry["image"] = "res://assets/classic_cards/%d_card.png" % int(draft["source_id"])
    if valve_card.get("illustrator"):
        entry["artist"] = valve_card["illustrator"]
    text = classic_text(draft, tags_entry, valve_card, ability, ability_tags, ability_valve, "english")
    entry["text"] = placeholders(text, draft, notes, "classic en text")
    if ability is not None:
        entry["ability_name"] = ability_tags.get("name") or ability_valve.get("card_name", {}).get("english", "")
    if draft["kind"] == "hero":
        for reference in valve_card.get("references", []):
            if reference.get("ref_type") == "includes":
                signature = pack_ids.get(int(reference["card_id"]))
                if signature:
                    entry["signature"] = signature
                else:
                    notes.append("signature card %d is not in the pack yet: add it, then set \"signature\"" % int(reference["card_id"]))
    skip = {"id", "source_id", "kind", "color", "cost", "status", "valve_text", "rq"} | set(RULE_BLOCKS)
    for key, value in draft.items():
        if key not in skip and key not in entry:
            entry[key] = value
    if draft["kind"] in ("hero", "creep"):
        # Valve omits a printed 0; the validator requires unit stats.
        entry.setdefault("attack", 0)
        entry.setdefault("health", 0)
    entry["status"] = "draft"
    for key in RULE_BLOCKS:
        if key in draft:
            value = draft[key]
            if key == "play":
                value = ordered(value)
            elif key in ("abilities", "grants"):
                value = [ordered(ability) for ability in value]
            entry[key] = value
    if draft.get("rq"):
        entry["rq"] = draft["rq"]
    entry["valve_text"] = tags_entry.get("text") or draft.get("valve_text", "")
    return entry


def classic_text(draft, tags_entry, valve_card, ability, ability_tags, ability_valve, language):
    """Valve's card text; a hero's is its ability name, text and cooldown."""
    if draft["kind"] == "hero" and ability is not None:
        if language == "english":
            name = ability_tags.get("name") or ability_valve.get("card_name", {}).get("english", "")
            body = ability_tags.get("text") or strip_html(ability_valve.get("card_text", {}).get("english", ""))
            text = "%s: %s" % (name, body) if name else body
            if ability.get("kind") == "active":
                text += " Active ability; cooldown %d." % number(ability.get("cooldown", 0), draft)
            return text
        name = ability_valve.get("card_name", {}).get(language, "")
        body = strip_html(ability_valve.get("card_text", {}).get(language, ""), chinese=True)
        if not body:
            return ""
        text = "%s：%s" % (name, body) if name else body
        if ability.get("kind") == "active":
            text += "主动技能，冷却%d。" % number(ability.get("cooldown", 0), draft)
        return text
    if language == "english":
        return (tags_entry.get("text") or strip_html(valve_card.get("card_text", {}).get("english", ""))).replace(" | ", " ")
    return strip_html(valve_card.get("card_text", {}).get(language, ""), chinese=True)


def locale_entries(draft, mapping, tags_entry, valve_card, ability, ability_tags, ability_valve, notes):
    tk = {}
    classic = {}
    if mapping:
        tk["name"] = {"en": mapping["en_name"], "zh_CN": mapping["zh_name"]}
        tk["text"] = {"en": placeholders(mapping.get("en_text", ""), draft, notes, "three_kingdoms en text"),
                      "zh_CN": placeholders(mapping.get("zh_text", ""), draft, notes, "three_kingdoms zh_CN text")}
        faction = str(mapping.get("faction", ""))
        tk["faction"] = next((value for key, value in FACTIONS.items() if faction.endswith(key)), "neutral")
        if mapping.get("ability_en"):
            tk["ability_name"] = {"en": strip_marker(mapping["ability_en"]), "zh_CN": strip_marker(mapping["ability_zh"])}
    else:
        notes.append("no three_kingdoms mapping in %s: the skin falls back to the classic text" % MAPPING)
    names = valve_card.get("card_name", {})
    classic["name"] = {"en": names.get("english") or tags_entry.get("name") or draft["id"]}
    if names.get("schinese"):
        classic["name"]["zh_CN"] = names["schinese"]
    classic["text"] = {"en": placeholders(classic_text(draft, tags_entry, valve_card, ability, ability_tags, ability_valve, "english"),
                                          draft, notes, "classic en text")}
    zh = classic_text(draft, tags_entry, valve_card, ability, ability_tags, ability_valve, "schinese")
    if zh:
        classic["text"]["zh_CN"] = placeholders(zh, draft, notes, "classic zh_CN text")
    if ability is not None:
        ability_names = ability_valve.get("card_name", {})
        classic["ability_name"] = {"en": ability_tags.get("name") or ability_names.get("english", "")}
        if ability_names.get("schinese"):
            classic["ability_name"]["zh_CN"] = ability_names["schinese"]
    if not names.get("schinese"):
        notes.append("Valve's Simplified Chinese text is unavailable (%s): the classic skin has English only" % " / ".join(VALVE_SETS))
    return tk, classic


def card_spec(draft, tags_entry):
    covers = []
    for key in ("triggers", "verbs", "targets", "durations"):
        for tag in tags_entry.get(key, []):
            if tag not in covers:
                covers.append(tag)
    cases = []
    for index, clause in enumerate(tags_entry.get("clauses", [])):
        tags = [clause["trigger"]] if clause.get("trigger") else []
        for key in ("verbs", "targets", "durations"):
            tags += [tag for tag in clause.get(key, []) if tag not in tags]
        cases.append({"name": "clause %d: %s" % (index, clause.get("text", "")), "clause": index, "tags": tags,
                      "board": {}, "do": [], "expect": {}})
    return {"card": draft["id"], "source_id": draft["source_id"], "text": tags_entry.get("text", ""),
            "covers": covers, "cases": cases}


def font_warnings(root, texts):
    known = set()
    for path in FONT_TEXT:
        raw = read_json(root, path, required=False)
        if raw:
            known.update(raw)
    missing = []
    for text in texts:
        for character in text:
            if ord(character) < 0x2E80 or character in known or character in missing:
                continue
            try:
                encoded = character.encode("gb2312")
                if len(encoded) == 2 and 0xB0 <= encoded[0] <= 0xD7:
                    continue
            except UnicodeEncodeError:
                pass
            missing.append(character)
    return missing


def main():
    # The dry run prints zh_CN text; a cp1252 console (PowerShell 5.1) cannot.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("card", help="Valve name, Valve card id or snake_case id")
    parser.add_argument("--dry-run", action="store_true", help="print the files' new content instead of writing")
    parser.add_argument("--root", default=ROOT, help="project root to read and write (default: this checkout)")
    args = parser.parse_args()
    root = os.path.abspath(args.root)

    drafts = json.loads(read_json(root, DRAFTS))["cards"]
    tags = json.loads(read_json(root, TAGS))["cards"]
    mapping = {int(entry["card_id"]): entry for entry in json.loads(read_json(root, MAPPING))}
    valve = valve_cards(root)
    draft = find_draft(drafts, tags, valve, args.card)
    if draft is None:
        sys.exit("new_card: no draft for %r in %s (a Valve name, Valve id or id)" % (args.card, DRAFTS))
    source_id = int(draft["source_id"])
    tags_by_source = {int(card["source_id"]): card for card in tags}
    tags_entry = tags_by_source.get(source_id, {})
    valve_card = valve.get(source_id, {})

    classic_raw = read_json(root, CLASSIC)
    classic_data = json.loads(classic_raw)
    pack = classic_data["heroes"] + classic_data["cards"]
    if any(card["id"] == draft["id"] or int(card.get("source_id", -1)) == source_id for card in pack):
        sys.exit("new_card: %s (%d) is already in %s" % (draft["id"], source_id, CLASSIC))
    locale_raw = read_json(root, LOCALE)
    locale_data = json.loads(locale_raw)
    for skin in ("three_kingdoms", "classic"):
        if draft["id"] in locale_data["skins"][skin]["cards"]:
            sys.exit("new_card: %s already has %s locale text in %s" % (draft["id"], skin, LOCALE))
    spec_path = "%s/%s.json" % (CARD_TESTS, draft["id"])
    if os.path.exists(os.path.join(root, spec_path)):
        sys.exit("new_card: %s already exists" % spec_path)

    notes = []
    ability, ability_tags, ability_valve = ability_card(draft, tags_by_source, valve)
    pack_ids = {int(card["source_id"]): card["id"] for card in pack if "source_id" in card}
    entry = build_entry(root, draft, tags_entry, valve_card, ability, ability_tags, ability_valve, pack_ids, notes)
    tk, classic = locale_entries(draft, mapping.get(source_id), tags_entry, valve_card, ability, ability_tags, ability_valve, notes)
    spec = card_spec(draft, tags_entry)

    classic_data["heroes" if draft["kind"] == "hero" else "cards"].append(entry)
    art_raw = read_json(root, ART_MANIFEST, required=False)
    art_data = json.loads(art_raw) if art_raw else None
    art_url = valve_card.get("large_image", {}).get("default", "")
    if art_data is not None and art_url and all(int(asset["id"]) != source_id for asset in art_data["assets"]):
        art_data["assets"].append({"id": source_id, "name": entry["name"], "artist": entry.get("artist", ""),
                                   "url": art_url, "local_file": "%d_card.png" % source_id})
    elif not art_url:
        notes.append("no Valve art URL: add the card's image to %s by hand" % ART_MANIFEST)
    if tk:
        locale_data["skins"]["three_kingdoms"]["cards"][draft["id"]] = tk
    locale_data["skins"]["classic"]["cards"][draft["id"]] = classic
    outputs = [(CLASSIC, dump_like(classic_raw, classic_data)), (LOCALE, dump_like(locale_raw, locale_data)),
               (spec_path, json.dumps(spec, indent=1, ensure_ascii=False) + "\n")]
    if art_data is not None and art_url:
        outputs.append((ART_MANIFEST, dump_like(art_raw, art_data)))
    zh_texts = [value for section in (tk, classic) for field in section.values() if isinstance(field, dict)
                for key, value in field.items() if key == "zh_CN"]
    missing = font_warnings(root, zh_texts)
    if missing:
        notes.append("characters outside the font subsets: %s (run tools/build_fonts.py)" % "".join(missing))

    if args.dry_run:
        print("== %s: new entry" % CLASSIC)
        print(json.dumps(entry, indent=2, ensure_ascii=False))
        print("== %s: three_kingdoms" % LOCALE)
        print(json.dumps(tk, indent=2, ensure_ascii=False))
        print("== %s: classic" % LOCALE)
        print(json.dumps(classic, indent=2, ensure_ascii=False))
        print("== %s" % spec_path)
        print(outputs[2][1], end="")
        if art_url:
            print("== %s: %s" % (ART_MANIFEST, art_url))
    else:
        os.makedirs(os.path.join(root, CARD_TESTS), exist_ok=True)
        for path, text in outputs:
            with open(os.path.join(root, path), "w", encoding="utf-8", newline="") as handle:
                handle.write(text)
            print("wrote %s" % path)
    for note in dict.fromkeys(notes):
        print("note: " + note)
    print("next: review the rules (docs/EFFECTS.md), fill in %s, run tests/rules_schema_test.gd and"
          " python tools/rules_hash.py; set \"status\": \"verified\" only when the spec cases pass;"
          " tools/fetch_classic_art.ps1 downloads the art." % spec_path)
    if args.dry_run:
        print("dry run: nothing was written")


if __name__ == "__main__":
    main()
