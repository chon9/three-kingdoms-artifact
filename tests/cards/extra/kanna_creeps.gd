extends RefCounted
## Spec "gd" escape (tests/card_specs_test.gd): Kanna (RQ-22). The lane
## creeps published by the last "deployment" event: player 0's are -1
## ("Kanna's lane") exactly when the Kanna labelled "k" is in a lane after the
## reveal (she was in a lane or deployed that phase), otherwise both are real
## lanes; the opponent's are never redirected. Each lane creep the reveal
## placed for player 0 then stands in Kanna's lane when they were redirected.

func check(engine, labels: Dictionary) -> Array:
	var problems: Array = []
	if not labels.has("k"):
		return ["the case labels Kanna \"k\""]
	var kanna: Dictionary = labels.k
	var announced = engine.state.events.filter(func(event): return str(event.get("k", "")) == "deployment")
	if announced.is_empty():
		return ["a deployment phase ran"]
	var creeps: Array = announced[announced.size() - 1].get("creeps", [[], []])
	var follows = int(kanna.get("lane", -1)) >= 0
	for value in creeps[0]:
		if follows and int(value) != -1:
			problems.append("Kanna is in play: player 0's lane creeps are published as -1, not %s" % [creeps[0]])
		elif not follows and int(value) < 0:
			problems.append("Kanna cannot deploy: player 0's lane creeps keep random lanes, not %s" % [creeps[0]])
	if creeps[0].size() != 2:
		problems.append("player 0 has two lane creeps (%s)" % [creeps[0]])
	for value in creeps[1]:
		if int(value) < 0 or int(value) > 2:
			problems.append("the opponent's lane creeps are never redirected (%s)" % [creeps[1]])
	var placed = engine.state.events.filter(func(event): return str(event.get("k", "")) == "deployment_placed")
	if placed.is_empty():
		return problems + ["the reveal placed units"]
	var lane_creeps = 0
	for unit in placed[placed.size() - 1].get("units", []):
		if int(unit.get("p", -1)) == 0 and str(unit.get("card", "")) == "melee_creep" and not bool(unit.get("hero", false)):
			lane_creeps += 1
			if follows and int(unit.get("lane", -1)) != int(kanna.lane):
				problems.append("a redirected lane creep was placed in lane %d, not Kanna's lane %d" % [int(unit.lane), int(kanna.lane)])
	if lane_creeps != 2:
		problems.append("the reveal placed two lane creeps for player 0 (%d)" % lane_creeps)
	return problems
