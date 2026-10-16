extends RefCounted
## RQ-24 for improvements (M7): an improvement played this round can use its
## active ability at once, as a new item instance can (actives start ready).
## The DSL labels only board-placed improvements, so this finds the newest
## improvement of the active player in the active lane (the one the case just
## played, after the opponent passed) and checks that it starts at cooldown 0
## and that one of its ability commands is legal.

func check(engine, labels: Dictionary) -> Array:
	var player = int(engine.state.active_player)
	var row: Array = engine.state.lanes[int(engine.state.lane)].get("improvements", [[], []])[player]
	if row.is_empty():
		return ["no improvement of player %d in the active lane" % player]
	var newest: Dictionary = row[0]
	for improvement in row:
		if int(improvement.get("order", 0)) > int(newest.get("order", 0)):
			newest = improvement
	if int(newest.get("cd", 0)) != 0:
		return ["the played %s starts at cooldown %d" % [str(newest.card), int(newest.cd)]]
	for command in engine.legal_actions(player):
		if str(command.get("type", "")) == "ability" and int(command.get("unit", -1)) == int(newest.oid):
			return []
	return ["the played %s has no legal ability command" % str(newest.card)]
