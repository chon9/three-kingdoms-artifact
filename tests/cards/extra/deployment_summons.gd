extends RefCounted
## Spec "gd" escape (tests/card_specs_test.gd) for deployment-phase summoners
## (Venomancer, Prellex, Barracks; RQ-23): lane creeps are placed without a
## "summon" event, so the DSL cannot tell Prellex's Melee Creep from a random
## lane creep. Every source still in play at the end of the case must have
## summoned exactly one unit of its card, for its owner, into its own lane, in
## each deployment phase of the case ("deployment_revealed" events), and no
## other summon may have happened. The cases keep their sources in one lane.

const SUMMONS = {"venomancer": "plague_ward", "prellex": "melee_creep", "barracks": "melee_creep"}

func check(engine, _labels: Dictionary) -> Array:
	var phases = engine.state.events.filter(func(event): return str(event.get("k", "")) == "deployment_revealed").size()
	var expected: Dictionary = {}
	for lane_index in range(3):
		var lane: Dictionary = engine.state.lanes[lane_index]
		for player in range(2):
			var sources: Array = []
			for unit in lane.units[player]:
				if unit != null:
					sources.append(str(unit.card))
			for improvement in lane.get("improvements", [[], []])[player]:
				sources.append(str(improvement.card))
			for card_id in sources:
				if SUMMONS.has(card_id):
					var key = "p%d lane %d %s" % [player, lane_index, SUMMONS[card_id]]
					expected[key] = int(expected.get(key, 0)) + phases
	var actual: Dictionary = {}
	for event in engine.state.events:
		if str(event.get("k", "")) == "summon":
			var key = "p%d lane %d %s" % [int(event.get("p", -1)), int(event.get("lane", -1)), str(event.get("card", ""))]
			actual[key] = int(actual.get(key, 0)) + 1
	var problems: Array = []
	var keys: Dictionary = {}
	for key in expected:
		keys[key] = true
	for key in actual:
		keys[key] = true
	for key in keys:
		if int(expected.get(key, 0)) != int(actual.get(key, 0)):
			problems.append("%s: %d summons over %d deployment phases, expected %d" % [key, int(actual.get(key, 0)), phases, int(expected.get(key, 0))])
	if phases == 0:
		problems.append("no deployment phase ran")
	return problems
