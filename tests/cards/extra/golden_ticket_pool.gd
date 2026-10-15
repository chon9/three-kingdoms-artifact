extends RefCounted
## Golden Ticket spec: "a random item from the Secret Shop" is a uniform pick
## from the whole Secret Shop pool, independent of the pool's size: over 400
## fresh matches (seeds 1 to 400) every gained card is from the pool, and
## every pool item is gained at least once when the pool has 25 or fewer
## items (at least 25 distinct items otherwise).

const Kernel = preload("res://scripts/core/rules/kernel.gd")
const RUNS = 400

func check(engine, labels: Dictionary) -> Array:
	var pool: Array = engine.library.catalog.get("secret_shop", [])
	if pool.is_empty():
		return ["the Secret Shop pool is empty"]
	var counts: Dictionary = {}
	for seed_value in range(1, RUNS + 1):
		var match_engine = engine.get_script().new()
		match_engine.library = engine.library
		match_engine.start(seed_value)
		var player = int(match_engine.state.active_player)
		var owner: Dictionary = match_engine.state.players[player]
		owner.hand.append("golden_ticket")
		owner.hand_state.append({"iid": Kernel.next_oid(match_engine)})
		var size = owner.hand.size()
		var result = match_engine.apply_action(player, {"type": "play", "hand": size - 1})
		if not result.ok:
			return ["seed %d: Golden Ticket could not be played (%s)" % [seed_value, result.get("code", "")]]
		if owner.hand.size() != size:
			return ["seed %d: the hand went from %d to %d cards" % [seed_value, size, owner.hand.size()]]
		var gained = str(owner.hand.back())
		if gained not in pool:
			return ["seed %d: %s is not in the Secret Shop pool" % [seed_value, gained]]
		counts[gained] = int(counts.get(gained, 0)) + 1
	var wanted = mini(pool.size(), 25)
	if counts.size() < wanted:
		return ["only %d distinct items over %d plays (pool of %d): %s" % [counts.size(), RUNS, pool.size(), counts]]
	return []
