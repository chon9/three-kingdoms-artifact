extends RefCounted
## Spec "gd" escape (tests/card_specs_test.gd): Kanna's hidden plan (RQ-22,
## spec §5.18). The DSL's end_round step runs the whole deployment phase, so
## this script drives it on the case's engine (the case has no expect_illegal
## that would see the changed state): the deployment phase begins with a ready
## Kanna ("k") in the Fountain; the lane creeps are published as -1 without
## changing the random lane draws; player 0 plans Kanna into lane 2 through a
## real "deploy" command, which player 1's view never shows (no plan, no
## lane, no event); after both confirm, the reveal puts both lane creeps
## into lane 2.

const Invariants = preload("res://tests/invariants.gd")

func check(engine, labels: Dictionary) -> Array:
	var problems: Array = []
	var kanna: Dictionary = labels.get("k", {})
	if kanna.is_empty():
		return ["the case labels Kanna \"k\""]
	engine._begin_deployment()
	if engine.state.pending_creeps[0] != [-1, -1]:
		problems.append("a ready Kanna in the Fountain publishes player 0's creeps as -1 (%s)" % [engine.state.pending_creeps[0]])
	var seen = int(engine.state.event_seq)
	var result = engine.apply_action(0, {"type": "deploy", "unit": int(kanna.uid), "lane": 2})
	if not result.ok:
		return problems + ["deploying Kanna is legal: %s" % result]
	if int(engine.state.event_seq) != seen:
		problems.append("planning Kanna emits no event")
	var view = engine.player_view(1)
	if not view.players[0].get("plans", {}).is_empty():
		problems.append("player 1 does not see player 0's plans")
	if view.pending_creeps[0] != [-1, -1]:
		problems.append("player 1 sees \"Kanna's lane\" (-1), not %s" % [view.pending_creeps[0]])
	if int(view.players[0].roster.filter(func(hero): return int(hero.uid) == int(kanna.uid))[0].get("lane", -1)) != -1:
		problems.append("player 1 does not see Kanna's planned lane")
	for player in range(2):
		engine.state.players[player].finished = true
	engine._reveal_deployment()
	engine._settle_transient()
	var creeps = 0
	for unit in engine.state.lanes[2].units[0]:
		if unit != null and str(unit.card) == "melee_creep":
			creeps += 1
	if int(kanna.lane) != 2 or creeps != 2:
		problems.append("at the reveal Kanna (lane %d) and both lane creeps (%d in lane 2) are in lane 2" % [int(kanna.lane), creeps])
	var broken = Invariants.violations(engine)
	if not broken.is_empty():
		problems.append("invariants after the reveal: %s" % [broken])
	return problems
