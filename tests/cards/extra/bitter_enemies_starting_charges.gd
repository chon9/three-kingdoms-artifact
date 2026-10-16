extends RefCounted
## Bitter Enemies spec, rq_27_starting_charges: a Bitter Enemies played from
## the hand enters with Valve's starting charges (set 01 `"charges": 3`, RQ-27,
## CF-8). The DSL can only label board-placed improvements, so this finds the
## played one in lane 1.

const VALVE_CHARGES = 3

func check(engine, labels: Dictionary) -> Array:
	var data_charges = int(engine.library.get_card("bitter_enemies").get("charges", -1))
	if data_charges != VALVE_CHARGES:
		return ["bitter_enemies data charges %d, Valve gives %d" % [data_charges, VALVE_CHARGES]]
	var lane: Dictionary = engine.state.lanes[1]
	for improvement in lane.get("improvements", [[], []])[0]:
		if str(improvement.card) == "bitter_enemies":
			if int(improvement.charges) == VALVE_CHARGES:
				return []
			return ["the played Bitter Enemies has %d charges, expected %d" % [int(improvement.charges), VALVE_CHARGES]]
	return ["the played Bitter Enemies is not in lane 1"]
