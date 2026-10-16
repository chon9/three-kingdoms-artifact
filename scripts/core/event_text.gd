class_name EventText
extends RefCounted
## Pure formatter from the engine's structured events (and coded results) to
## display text in the current locale and card skin. Templates live in
## i18n/ui.csv (EV_*, ERR_*, STEAM_*) with named {placeholders}; card names
## come from CardLibrary.loc(). Engine state never contains display text.
##
## Event shape: {"k": key, ...}. Keys and their fields:
##   match_start                        -
##   pass               p
##   lane_open          lane, p        (p = player with initiative)
##   shop_open                          -
##   play               p, card [, target (a unit uid or an improvement oid), target_card]
##   ability            p, uid, card, ability   (uid = unit uid, item or improvement oid)
##   buy                p, gold        (cost only, never the item identity; below 0 it paid gold)
##   hold               p, gold
##   combat             lane, damage, strikes  (damage = [player 1 dealt, player 2 dealt])
##   death              p, uid, card, gold   (p = owner; the opponent earns gold)
##   tower_fall         p              (p = defender)
##   ancient_fall       p
##   concede            p              (p = player who conceded)
##   win                p
##   draw                               -  (the match is drawn)
##   deployment         round, creeps  (creeps = [[lane, ...], [lane, ...]])
##   deployment_placed  units          ([{uid, p, card, hero, lane, slot}] in placement order)
##   deployment_revealed                -
## Rules engine events (EFFECT_SYSTEM_SPEC.md §6.5); `src` is the source card:
##   trigger            src, card, ability, p
##   damage             src, p, hits [[uid, n]], pierce
##   tower_damage       src, p, hits [[lane, p, n]]
##   heal               src, p, hits [[uid, n]] (towers [[lane, p, n]])
##   mod                id, card | tower, st, kw, perm, src [, ab]  (ab = "<card>#<i>": granted text)
##   status             id, card | tower, st, kw, until, src [, ab]
##   purge              id, card, n
##   condemn            id, card
##   summon             uid, card, p, lane, slot
##   move               uid, card, from, to, slot
##   swap               a, b
##   retarget           uid, card, target
##   control            uid, card, from, to
##   fountain           uid, card, p
##   battle             a, card, p, bs, hits
##   shield             uid, card
##   charges            id, card, n
##   gold               p, n
##   mana               lane, p, n
##   draw_cards         p, n           (the drawer also gets iids)
##   discard            p, n           (the owner also gets cards)
##   lock               p, n
##   gain_card          p              (the receiver also gets card)
##   charged            p, n
##   hack               p, n
##   improvement        oid, card, p, lane
##   improvement_gone   oid, card
##   item_gone          uid, slot, card
##   pulse                              -
##   rules_overflow                     -

const Library = preload("res://scripts/core/card_library.gd")
const KEYS = ["match_start", "pass", "lane_open", "shop_open", "play", "ability",
	"buy", "hold", "combat", "death", "tower_fall", "ancient_fall", "concede", "win", "draw",
	"deployment", "deployment_placed", "deployment_revealed",
	"trigger", "damage", "tower_damage", "heal", "mod", "status", "purge", "condemn", "summon", "move",
	"swap", "retarget", "control", "fountain", "battle", "shield", "charges", "gold", "mana", "draw_cards",
	"discard", "lock", "gain_card", "charged", "hack", "improvement", "improvement_gone", "item_gone",
	"pulse", "rules_overflow"]
## Keys the board animates (the rest only reach the log, EFFECT_SYSTEM_SPEC.md
## §8.7); in a burst, animated events past ANIMATED_LIMIT apply without
## animation.
const ANIMATED = ["play", "ability", "combat", "death", "tower_fall", "ancient_fall", "lane_open", "shop_open",
	"deployment", "deployment_placed", "deployment_revealed", "win", "draw", "pass", "trigger", "damage",
	"tower_damage", "heal", "summon", "move", "swap", "control", "fountain", "battle", "condemn", "status", "mod",
	"purge", "shield", "retarget", "improvement", "improvement_gone", "lock", "hack", "charged", "gold", "mana",
	"pulse"]
const ANIMATED_LIMIT = 60
const LANE_KEYS = ["LANE_LEFT", "LANE_MIDDLE", "LANE_RIGHT"]
const ANCIENT_HEALTH = 80
const STAT_KEYS = {"attack": "STAT_ATTACK", "armor": "STAT_ARMOR", "max_health": "STAT_HEALTH", "mana": "TERM_MANA"}
const DURATION_KEYS = {"round": "EV_UNTIL_ROUND", "next_combat": "EV_UNTIL_NEXT_COMBAT", "death": "EV_UNTIL_DEATH",
	"equip": "EV_UNTIL_EQUIP", "used": "EV_UNTIL_USED"}

## `_library` is accepted for older callers; names come from CardLibrary.loc.
## `names` optionally names the players by index (the HUD's "You" / "AI");
## otherwise they are "Player 1" / "Player 2".
static func format(event: Dictionary, _library = null, names: Array = []) -> String:
	var player = _player(event.get("p", 0), names)
	match str(event.get("k", "")):
		"match_start":
			return t("EV_MATCH_START")
		"pass":
			return t("EV_PASS", {"player": player})
		"lane_open":
			return t("EV_LANE_OPEN", {"lane": lane_name(event.get("lane", 0)), "player": player})
		"shop_open":
			return t("EV_SHOP_OPEN")
		"play":
			var card = Library.loc(str(event.get("card", "")))
			if event.has("target_card"):
				return t("EV_PLAY_TARGET", {"player": player, "card": card,
					"target": Library.loc(str(event.target_card))})
			return t("EV_PLAY", {"player": player, "card": card})
		"ability":
			var card_id = str(event.get("card", ""))
			return t("EV_ABILITY", {"card": Library.loc(card_id), "ability": ability_name(card_id)})
		"buy":
			# A negative price pays gold (Shop Deeds on the Secret Shop, RQ-26).
			var gold = int(event.get("gold", 0))
			if gold < 0:
				return t("EV_BUY_PAID", {"player": player, "gold": -gold})
			return t("EV_BUY", {"player": player, "gold": gold})
		"hold":
			return t("EV_HOLD", {"player": player, "gold": int(event.get("gold", 0))})
		"combat":
			var damage = event.get("damage", [0, 0])
			return t("EV_COMBAT", {"lane": lane_name(event.get("lane", 0)),
				"player1": _player(0, names), "player2": _player(1, names),
				"damage1": int(damage[0]), "damage2": int(damage[1])})
		"death":
			return t("EV_DEATH", {"card": Library.loc(str(event.get("card", ""))),
				"player": _player(1 - int(event.get("p", 0)), names), "gold": int(event.get("gold", 0))})
		"tower_fall":
			return t("EV_TOWER_FALL", {"player": player, "health": ANCIENT_HEALTH})
		"ancient_fall":
			return t("EV_ANCIENT_FALL", {"player": player})
		"concede":
			return t("EV_CONCEDE", {"player": player})
		"win":
			return t("EV_WIN", {"player": player})
		"draw":
			return t("EV_DRAW")
		"deployment":
			var parts: Array = []
			var creeps = event.get("creeps", [[], []])
			for side in range(creeps.size()):
				var lanes: Array = []
				for lane_index in creeps[side]:
					lanes.append(lane_name(lane_index))
				parts.append(t("EV_DEPLOYMENT_CREEPS", {"player": _player(side, names),
					"lanes": t("LIST_SEPARATOR").join(lanes) if not lanes.is_empty() else t("WORD_NONE")}))
			return t("EV_DEPLOYMENT", {"round": int(event.get("round", 1)),
				"creeps": t("LIST_GROUP_SEPARATOR").join(parts)})
		"deployment_placed":
			# Heroes grouped by player; the creeps were announced by "deployment".
			var groups: Array = []
			for side in range(2):
				var heroes: Array = []
				for unit in event.get("units", []):
					if bool(unit.get("hero", false)) and int(unit.get("p", 0)) == side:
						heroes.append(t("EV_DEPLOYMENT_PLACED_HERO", {"card": Library.loc(str(unit.get("card", ""))),
							"lane": lane_name(unit.get("lane", 0))}))
				if not heroes.is_empty():
					groups.append(t("EV_DEPLOYMENT_PLACED_GROUP", {"player": _player(side, names),
						"heroes": t("LIST_SEPARATOR").join(heroes)}))
			if groups.is_empty():
				return t("EV_DEPLOYMENT_PLACED_NONE")
			return t("EV_DEPLOYMENT_PLACED", {"groups": t("LIST_GROUP_SEPARATOR").join(groups)})
		"deployment_revealed":
			return t("EV_DEPLOYMENT_REVEALED")
	return _format_rules_event(event, player, names)

## The rules engine's events (spec §6.5).
static func _format_rules_event(event: Dictionary, player: String, names: Array) -> String:
	var source = Library.loc(str(event.get("src", ""))) if not str(event.get("src", "")).is_empty() else t("EV_AN_EFFECT")
	match str(event.get("k", "")):
		"trigger":
			var card_id = str(event.get("card", ""))
			return t("EV_TRIGGER", {"card": Library.loc(card_id), "ability": ability_name(card_id)})
		"damage":
			return t("EV_DAMAGE_PIERCING" if bool(event.get("pierce", false)) else "EV_DAMAGE",
				{"card": source, "n": _total(event.get("hits", []), 1)})
		"tower_damage":
			var hits: Array = event.get("hits", [])
			var defender = int(hits[0][1]) if not hits.is_empty() else 0
			return t("EV_TOWER_DAMAGE", {"card": source, "n": _total(hits, 2), "player": _player(defender, names)})
		"heal":
			return t("EV_HEAL", {"card": source, "n": _total(event.get("hits", []), 1) + _total(event.get("towers", []), 2)})
		"mod":
			return t("EV_MOD", {"card": source, "target": _subject(event, names), "changes": changes(event)})
		"status":
			return t("EV_STATUS", {"card": source, "target": _subject(event, names), "changes": changes(event),
				"duration": t(DURATION_KEYS.get(str(event.get("until", "round")), "EV_UNTIL_ROUND"))})
		"purge":
			return counted("EV_PURGE", int(event.get("n", 0)), {"target": _subject(event, names)})
		"condemn":
			return t("EV_CONDEMN", {"card": Library.loc(str(event.get("card", "")))})
		"summon":
			return t("EV_SUMMON", {"player": player, "card": Library.loc(str(event.get("card", ""))),
				"lane": lane_name(event.get("lane", 0))})
		"move":
			return t("EV_MOVE", {"card": Library.loc(str(event.get("card", ""))), "lane": lane_name(event.get("to", 0))})
		"swap":
			return t("EV_SWAP")
		"retarget":
			return t("EV_RETARGET", {"card": Library.loc(str(event.get("card", "")))})
		"control":
			return t("EV_CONTROL", {"player": _player(event.get("to", 0), names), "card": Library.loc(str(event.get("card", "")))})
		"fountain":
			return t("EV_FOUNTAIN", {"card": Library.loc(str(event.get("card", "")))})
		"battle":
			return counted("EV_BATTLE", event.get("bs", []).size(), {"card": Library.loc(str(event.get("card", "")))})
		"shield":
			return t("EV_SHIELD", {"card": Library.loc(str(event.get("card", "")))})
		"charges":
			return counted("EV_CHARGES", int(event.get("n", 0)), {"card": Library.loc(str(event.get("card", "")))})
		"gold":
			var amount = int(event.get("n", 0))
			return t("EV_GOLD" if amount >= 0 else "EV_GOLD_LOSE", {"player": player, "n": absi(amount)})
		"mana":
			return t("EV_MANA", {"player": player, "n": int(event.get("n", 0)), "lane": lane_name(event.get("lane", 0))})
		"draw_cards":
			var count = int(event.get("n", 0))
			return t("EV_DRAW_ONE", {"player": player}) if count == 1 else t("EV_DRAW_CARDS", {"player": player, "n": count})
		"discard":
			var count = int(event.get("n", 0))
			return t("EV_DISCARD_ONE", {"player": player}) if count == 1 else t("EV_DISCARD", {"player": player, "n": count})
		"lock":
			return counted("EV_LOCK", int(event.get("n", 0)), {"player": player})
		"gain_card":
			return t("EV_GAIN_CARD", {"player": player})
		"charged":
			return counted("EV_CHARGED", int(event.get("n", 0)), {"player": player})
		"hack":
			return counted("EV_HACK", int(event.get("n", 0)), {"player": player})
		"improvement":
			return t("EV_IMPROVEMENT", {"player": player, "card": Library.loc(str(event.get("card", ""))),
				"lane": lane_name(event.get("lane", 0))})
		"improvement_gone":
			return t("EV_IMPROVEMENT_GONE", {"card": Library.loc(str(event.get("card", "")))})
		"item_gone":
			return t("EV_ITEM_GONE", {"card": Library.loc(str(event.get("card", "")))})
		"pulse":
			return t("EV_PULSE")
		"rules_overflow":
			return t("EV_RULES_OVERFLOW")
	return "?"

## The localized name of a card's ability, or "its ability".
static func ability_name(card_id: String) -> String:
	var name = Library.loc(card_id, "ability_name")
	return name if not name.is_empty() else t("EV_ITS_ABILITY")

## "+2 Attack, Silence" from an event's st and kw deltas.
static func changes(event: Dictionary) -> String:
	var parts: Array = []
	var stats: Dictionary = event.get("st", {})
	for stat in ["attack", "armor", "max_health", "mana"]:
		if stats.has(stat) and int(stats[stat]) != 0:
			parts.append(_signed(int(stats[stat]), t(STAT_KEYS[stat])))
	var keywords: Dictionary = event.get("kw", {})
	for keyword in keywords:
		var amount = int(keywords[keyword])
		if amount == 0:
			continue
		var label = keyword_name(str(keyword))
		if str(keyword) in ["siege", "cleave", "retaliate", "regeneration", "bounty", "bonus_hero", "bonus_tower"]:
			parts.append(_signed(amount, label))
		else:
			parts.append(label if amount > 0 else t("EV_CHANGE_LOSE", {"keyword": label}))
	# Granted text ("ab": "<card>#<index>"), e.g. Soul of Spring's trigger.
	var granted = str(event.get("ab", "")).split("#")
	if granted.size() == 2:
		var text = Library.loc(granted[0], "grant_" + granted[1])
		if not text.is_empty():
			parts.append(t("EV_CHANGE_GRANT", {"text": text.trim_suffix(".").trim_suffix("。")}))
	return t("LIST_SEPARATOR").join(parts) if not parts.is_empty() else t("WORD_NONE")

## Display name of a keyword, flag or status (KEYWORD_<NAME> in ui.csv).
static func keyword_name(keyword: String) -> String:
	return t("KEYWORD_" + keyword.to_upper())

static func _signed(amount: int, label: String) -> String:
	return t("EV_CHANGE_STAT", {"sign": "+" if amount >= 0 else "-", "n": absi(amount), "stat": label})

## The changed object of a mod/status/purge event: a card name or a tower.
static func _subject(event: Dictionary, names: Array) -> String:
	if event.has("tower"):
		return t("EV_TOWER_OF", {"player": _player(event.tower[1], names), "lane": lane_name(event.tower[0])})
	return Library.loc(str(event.get("card", ""))) if not str(event.get("card", "")).is_empty() else t("EV_AN_EFFECT")

static func _total(hits: Array, column: int) -> int:
	var total = 0
	for hit in hits:
		if hit is Array and hit.size() > column:
			total += int(hit[column])
	return total

## True when the board animates this event key.
static func animated(event: Dictionary) -> bool:
	return str(event.get("k", "")) in ANIMATED

## Display text for a failed engine/library result ({"code", "args", "error"}).
## Card ids in `card` and `hero` args (deck rules, deck codes) show as the
## card's name in the current skin and language.
static func error_text(result: Dictionary) -> String:
	var args = result.get("args", {})
	if args is Dictionary and (args.has("card") or args.has("hero")):
		args = args.duplicate()
		for key in ["card", "hero"]:
			if args.has(key):
				args[key] = Library.loc(str(args[key]))
	return _coded("ERR_", str(result.get("code", "")), args, str(result.get("error", "")))

## Display text for a SteamBridge status code and its args.
static func steam_status(code: String, args: Dictionary = {}, fallback: String = "") -> String:
	return _coded("STEAM_", code, args, fallback)

## Translated UI string `key`, with {named} placeholders filled from `args`.
static func t(key: String, args: Dictionary = {}) -> String:
	var text = String(TranslationServer.translate(key))
	return text.format(args) if not args.is_empty() else text

## A counted message: `key`_ONE when n is 1 ("1 effect ... is purged",
## not "1 effects ... are purged"), else `key` with {n}.
static func counted(key: String, n: int, args: Dictionary = {}) -> String:
	var filled = args.duplicate()
	filled["n"] = n
	return t(key + "_ONE", filled) if n == 1 else t(key, filled)

static func lane_name(lane_index) -> String:
	var index = int(lane_index)
	return t(LANE_KEYS[index]) if index >= 0 and index < LANE_KEYS.size() else t("LANE_N", {"n": index + 1})

static func _player(player, names: Array = []) -> String:
	var index = int(player)
	if index >= 0 and index < names.size() and not str(names[index]).is_empty():
		return str(names[index])
	return t("PLAYER_N", {"n": index + 1})

static func _coded(prefix: String, code: String, args, fallback: String) -> String:
	var key = prefix + code.to_upper()
	var text = String(TranslationServer.translate(key))
	if code.is_empty() or text == key:
		return fallback if not fallback.is_empty() else key
	return text.format(args) if args is Dictionary and not args.is_empty() else text
