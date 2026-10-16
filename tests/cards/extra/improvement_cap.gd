extends RefCounted
## RQ-47 with a real improvement (M7 acceptance, "the 16 cap"): after a 17th
## Trebuchets is played into lane 0, player 0 still has 16 improvements on
## that side of the lane, the new one among them, and exactly one of the 16
## labelled ones (t1 to t16) has left play.

func check(engine, labels: Dictionary) -> Array:
	var row: Array = engine.state.lanes[0].get("improvements", [[], []])[0]
	if row.size() != 16:
		return ["player 0 has %d improvements in lane 0, expected 16" % row.size()]
	var labelled: Dictionary = {}
	for index in range(1, 17):
		var label = "t%d" % index
		if labels.has(label):
			labelled[int(labels[label].oid)] = label
	if labelled.size() != 16:
		return ["the board labelled %d of the 16 Trebuchets" % labelled.size()]
	var newcomers = row.filter(func(improvement): return not labelled.has(int(improvement.oid)))
	if newcomers.size() != 1 or str(newcomers[0].card) != "trebuchets":
		return ["expected the played Trebuchets among the 16, found %s" % [newcomers.map(func(improvement): return str(improvement.card))]]
	var gone = labelled.keys().filter(func(oid): return engine.find_object(int(oid)).is_empty())
	if gone.size() != 1:
		return ["%d of the 16 earlier Trebuchets left play, expected exactly 1" % gone.size()]
	return []
