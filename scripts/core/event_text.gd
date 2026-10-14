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
##   play               p, card [, target, target_card]
##   ability            p, uid, card
##   buy                p, gold        (cost only, never the item identity)
##   hold               p, gold
##   combat             lane, damage   (damage = [player 1 dealt, player 2 dealt])
##   death              p, uid, card, gold   (p = owner; the opponent earns gold)
##   tower_fall         p              (p = defender)
##   ancient_fall       p
##   concede            p              (p = player who conceded)
##   win                p
##   draw                               -
##   deployment         round, creeps  (creeps = [[lane, ...], [lane, ...]])
##   deployment_revealed                -

const Library = preload("res://scripts/core/card_library.gd")
const KEYS = ["match_start", "pass", "lane_open", "shop_open", "play", "ability",
	"buy", "hold", "combat", "death", "tower_fall", "ancient_fall", "concede", "win", "draw",
	"deployment", "deployment_revealed"]
const LANE_KEYS = ["LANE_LEFT", "LANE_MIDDLE", "LANE_RIGHT"]
const ANCIENT_HEALTH = 80

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
			var ability = Library.loc(card_id, "ability_name")
			return t("EV_ABILITY", {"card": Library.loc(card_id),
				"ability": ability if not ability.is_empty() else t("EV_ITS_ABILITY")})
		"buy":
			return t("EV_BUY", {"player": player, "gold": int(event.get("gold", 0))})
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
		"deployment_revealed":
			return t("EV_DEPLOYMENT_REVEALED")
	return "?"

## Display text for a failed engine/library result ({"code", "args", "error"}).
static func error_text(result: Dictionary) -> String:
	return _coded("ERR_", str(result.get("code", "")), result.get("args", {}), str(result.get("error", "")))

## Display text for a SteamBridge status code and its args.
static func steam_status(code: String, args: Dictionary = {}, fallback: String = "") -> String:
	return _coded("STEAM_", code, args, fallback)

## Translated UI string `key`, with {named} placeholders filled from `args`.
static func t(key: String, args: Dictionary = {}) -> String:
	var text = String(TranslationServer.translate(key))
	return text.format(args) if not args.is_empty() else text

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
