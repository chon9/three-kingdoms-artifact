class_name EventText
extends RefCounted
## Pure formatter from the engine's structured events to English display text.
## Events carry only stable keys and ids, so localization can later replace
## these templates (e.g. with tr()) without touching engine state or replays.
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
##   win                p
##   draw                               -
##   deployment         round, creeps  (creeps = [[lane, ...], [lane, ...]])
##   deployment_revealed                -

const KEYS = ["match_start", "pass", "lane_open", "shop_open", "play", "ability",
	"buy", "hold", "combat", "death", "tower_fall", "ancient_fall", "win", "draw",
	"deployment", "deployment_revealed"]
const LANE_NAMES = ["Left", "Middle", "Right"]

static func format(event: Dictionary, library = null) -> String:
	match str(event.get("k", "")):
		"match_start":
			return "Round 1. Left lane opens. Destroy two towers or one ancient to win."
		"pass":
			return "%s passes." % _player(event.get("p", 0))
		"lane_open":
			return "%s lane opens. %s has initiative." % [_lane(event.get("lane", 0)), _player(event.get("p", 0))]
		"shop_open":
			return "Shopping. Spend kill gold on equipment, or keep it for later."
		"play":
			var text = "%s plays %s" % [_player(event.get("p", 0)), _card_name(library, event.get("card", ""))]
			if event.has("target_card"):
				text += " on " + _card_name(library, event.target_card)
			return text + "."
		"ability":
			var definition = _definition(library, event.get("card", ""))
			var ability = str(definition.get("ability_name", "its ability"))
			return "%s uses %s: draw a card." % [_card_name(library, event.get("card", "")), ability]
		"buy":
			return "%s spends %d gold in the shop." % [_player(event.get("p", 0)), int(event.get("gold", 0))]
		"hold":
			return "%s pays %d gold to hold the Secret Shop item." % [_player(event.get("p", 0)), int(event.get("gold", 0))]
		"combat":
			var damage = event.get("damage", [0, 0])
			return "%s lane combat: Player 1 deals %d structure damage; Player 2 deals %d." % [
				_lane(event.get("lane", 0)), int(damage[0]), int(damage[1])]
		"death":
			return "%s falls. %s earns %d gold." % [_card_name(library, event.get("card", "")),
				_player(1 - int(event.get("p", 0))), int(event.get("gold", 0))]
		"tower_fall":
			return "%s's tower falls. An 80-health ancient is exposed." % _player(event.get("p", 0))
		"ancient_fall":
			return "%s's ancient falls." % _player(event.get("p", 0))
		"win":
			return "%s wins." % _player(event.get("p", 0))
		"draw":
			return "Draw."
		"deployment":
			var parts: Array = []
			var creeps = event.get("creeps", [[], []])
			for player in range(creeps.size()):
				var lanes: Array = []
				for lane_index in creeps[player]:
					lanes.append(_lane(lane_index))
				parts.append("%s: %s" % [_player(player), ", ".join(lanes) if not lanes.is_empty() else "none"])
			return "Round %d. Lane creeps: %s. Choose lanes for available heroes; choices reveal together." % [
				int(event.get("round", 1)), "; ".join(parts)]
		"deployment_revealed":
			return "Deployment revealed. Left lane opens."
	return "?"

static func _player(player) -> String:
	return "Player %d" % (int(player) + 1)

static func _lane(lane_index) -> String:
	var index = int(lane_index)
	return LANE_NAMES[index] if index >= 0 and index < LANE_NAMES.size() else "Lane %d" % (index + 1)

static func _definition(library, card_id) -> Dictionary:
	if library == null:
		return {}
	return library.definition(str(card_id))

static func _card_name(library, card_id) -> String:
	var definition = _definition(library, card_id)
	return str(definition.get("name", card_id))
