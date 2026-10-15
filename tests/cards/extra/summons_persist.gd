extends RefCounted
## Spec "gd" escape (tests/card_specs_test.gd): summoned units are permanent.
## Every unit a "summon" event created is still in play, for the summoning
## player and in the lane it was summoned into, at the end of the case (after
## a round end). Lane creeps added by the deployment phase make the DSL's
## unit counts random, so this checks the summoned units by uid.

func check(engine, _labels: Dictionary) -> Array:
	var problems: Array = []
	var summoned = engine.state.events.filter(func(event): return str(event.get("k", "")) == "summon")
	if summoned.is_empty():
		return ["something was summoned"]
	for event in summoned:
		var unit: Dictionary = engine.find_unit(int(event.uid))
		if unit.is_empty():
			problems.append("summoned %s (uid %d) is still in play" % [event.card, int(event.uid)])
		elif int(unit.owner) != int(event.p) or int(unit.lane) != int(event.lane):
			problems.append("summoned %s stays with player %d in lane %d" % [event.card, int(event.p), int(event.lane)])
	return problems
