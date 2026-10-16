extends RefCounted
## Spec "gd" escape (tests/card_specs_test.gd): Kanna (RQ-22). The lane
## creeps published by the last "deployment" event follow Kanna exactly when
## the Kanna labelled "k" was alive in a lane as they were assigned: she is in
## a lane now and the last reveal did not place her (a hero deployed from the
## Fountain that phase was not on the board yet). Then both of player 0's
## creeps name her lane; otherwise they keep their random lanes. The
## opponent's are never redirected, and the reveal places every lane creep in
## the lane it was published with.

func check(engine, labels: Dictionary) -> Array:
	var problems: Array = []
	if not labels.has("k"):
		return ["the case labels Kanna \"k\""]
	var kanna: Dictionary = labels.k
	var announced = engine.state.events.filter(func(event): return str(event.get("k", "")) == "deployment")
	if announced.is_empty():
		return ["a deployment phase ran"]
	var creeps: Array = announced[announced.size() - 1].get("creeps", [[], []])
	var placed = engine.state.events.filter(func(event): return str(event.get("k", "")) == "deployment_placed")
	if placed.is_empty():
		return ["the reveal placed units"]
	var units: Array = placed[placed.size() - 1].get("units", [])
	var deployed_now = units.any(func(unit): return int(unit.get("uid", -1)) == int(kanna.uid))
	var follows = int(kanna.get("lane", -1)) >= 0 and not deployed_now
	if creeps[0].size() != 2:
		problems.append("player 0 has two lane creeps (%s)" % [creeps[0]])
	for value in creeps[0]:
		if int(value) < 0 or int(value) > 2:
			problems.append("player 0's lane creeps name real lanes (%s)" % [creeps[0]])
		elif follows and int(value) != int(kanna.lane):
			problems.append("Kanna was in lane %d: player 0's lane creeps go there, not %s" % [int(kanna.lane), creeps[0]])
	for value in creeps[1]:
		if int(value) < 0 or int(value) > 2:
			problems.append("the opponent's lane creeps are never redirected (%s)" % [creeps[1]])
	for player in range(2):
		var lanes: Array = []
		for unit in units:
			if int(unit.get("p", -1)) == player and str(unit.get("card", "")) == "melee_creep" and not bool(unit.get("hero", false)):
				lanes.append(int(unit.get("lane", -1)))
		lanes.sort()
		var published: Array = creeps[player].map(func(value): return int(value))
		published.sort()
		if lanes != published:
			problems.append("player %d's lane creeps were placed in lanes %s, published as %s" % [player, lanes, published])
	return problems
