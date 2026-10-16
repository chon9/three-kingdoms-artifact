extends RefCounted
## Chain Frost spec (RQ-15, RQ-16): the event log of the last Chain Frost
## play. Each hit damages exactly one unit; a Pulse comes between every two
## hits, so a unit a hit killed is removed (its "death" event) before the next
## bounce chooses; and no hit lands on a unit after its death. With
## `expected_hits` >= 0 (a subclass sets it) the chain made exactly that many
## hits: the first one plus the bounces before the rest fizzled.

var expected_hits: int = -1

func check(engine, labels: Dictionary) -> Array:
	var out: Array = []
	var events: Array = engine.state.events
	var start = -1
	for index in range(events.size()):
		var event: Dictionary = events[index]
		if str(event.get("k", "")) == "play" and str(event.get("card", "")) == "chain_frost":
			start = index
	if start == -1:
		return ["Chain Frost was played"]
	var hits = 0
	var pulsed = true
	var dead: Dictionary = {}
	for index in range(start + 1, events.size()):
		var event: Dictionary = events[index]
		match str(event.get("k", "")):
			"damage":
				if str(event.get("src", "")) != "chain_frost":
					continue
				var list: Array = event.get("hits", [])
				if list.size() != 1:
					out.append("hit %d damages one unit, not %d" % [hits + 1, list.size()])
					continue
				var uid = int(list[0][0])
				if not pulsed:
					out.append("hit %d comes after a Pulse" % [hits + 1])
				if dead.has(uid):
					out.append("hit %d lands on unit %d after it died" % [hits + 1, uid])
				hits += 1
				pulsed = false
			"pulse":
				pulsed = true
			"death":
				dead[int(event.get("uid", 0))] = true
	if hits < 1 or hits > 8:
		out.append("the chain made %d hits, expected 1 to 8" % hits)
	if expected_hits >= 0 and hits != expected_hits:
		out.append("the chain made %d hits, expected %d (the rest fizzle)" % [hits, expected_hits])
	return out
