extends RefCounted
## March of the Machines spec, rq_27_starting_charges: a March played from the
## hand enters with Valve's starting charges (set 01 `"charges": 3`, RQ-27,
## CF-8), before it has fired. The DSL can only label board-placed
## improvements, so this finds the played one in lane 1.

const VALVE_CHARGES = 3

func check(engine, labels: Dictionary) -> Array:
	var data_charges = int(engine.library.get_card("march_of_the_machines").get("charges", -1))
	if data_charges != VALVE_CHARGES:
		return ["march_of_the_machines data charges %d, Valve gives %d" % [data_charges, VALVE_CHARGES]]
	var lane: Dictionary = engine.state.lanes[1]
	for improvement in lane.get("improvements", [[], []])[0]:
		if str(improvement.card) == "march_of_the_machines":
			if int(improvement.charges) == VALVE_CHARGES:
				return []
			return ["the played March has %d charges, expected %d" % [int(improvement.charges), VALVE_CHARGES]]
	return ["the played March is not in lane 1"]
