extends RefCounted
## The Oath spec: the owner's rules layer carries the restriction the UI
## reports as REASON_FORBIDDEN (match_screen._reason reads
## rules_of(viewer).forbid_play and compares its lane with the active lane):
## spells and creeps, in The Oath's own lane. The opponent's layer is empty.

func check(engine, labels: Dictionary) -> Array:
	var failures: Array = []
	var oath: Dictionary = labels.get("o", {})
	var mine: Array = engine.rules_of(0).forbid_play
	if mine.size() != 1:
		return ["player 0 has %d forbid_play entries, expected 1" % mine.size()]
	var entry: Dictionary = mine[0]
	if Array(entry.get("kinds", [])) != ["spell", "creep"]:
		failures.append("forbid_play kinds %s, expected [spell, creep]" % [entry.get("kinds")])
	if int(entry.get("lane", -1)) != int(oath.get("lane", -2)):
		failures.append("forbid_play lane %s, expected The Oath's lane %s" % [entry.get("lane"), oath.get("lane")])
	if not engine.rules_of(1).forbid_play.is_empty():
		failures.append("the opponent's rules layer forbids plays too: %s" % [engine.rules_of(1).forbid_play])
	return failures
