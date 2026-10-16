extends RefCounted
## Spec "gd" escape (tests/card_specs_test.gd): Kanna and hidden plans
## (RQ-22, spec §5.18). The DSL's end_round step runs the whole deployment
## phase, so this script drives it on the case's engine (the case has no
## expect_illegal that would see the changed state). The deployment phase
## begins; the lane creeps are published at once: in Kanna's lane when she
## ("k") is in a lane, otherwise in lanes that do not depend on her. Player 0
## then plans the Fountain hero "h" (Kanna herself when she is in the
## Fountain) into lane 2 through a real "deploy" command; player 1's view
## never shows the plan (no plan, no lane, no event) and the published creeps
## do not change. After both confirm, the reveal puts the hero into lane 2 and
## the creeps into their published lanes.

const Invariants = preload("res://tests/invariants.gd")

func check(engine, labels: Dictionary) -> Array:
	var problems: Array = []
	var kanna: Dictionary = labels.get("k", {})
	if kanna.is_empty():
		return ["the case labels Kanna \"k\""]
	var in_lane = int(kanna.get("lane", -1)) >= 0
	var hero: Dictionary = kanna if not in_lane else labels.get("h", {})
	if hero.is_empty():
		return ["with Kanna in a lane the case labels a Fountain hero \"h\""]
	engine._begin_deployment()
	var published: Array = engine.state.pending_creeps.duplicate(true)
	if in_lane and published[0] != [int(kanna.lane), int(kanna.lane)]:
		problems.append("Kanna in lane %d: player 0's creeps are published in her lane (%s)" % [int(kanna.lane), published[0]])
	if published[0].any(func(value): return int(value) < 0 or int(value) > 2):
		problems.append("player 0's creeps are published in real lanes (%s)" % [published[0]])
	var seen = int(engine.state.event_seq)
	var result = engine.apply_action(0, {"type": "deploy", "unit": int(hero.uid), "lane": 2})
	if not result.ok:
		return problems + ["deploying the Fountain hero is legal: %s" % result]
	if int(engine.state.event_seq) != seen:
		problems.append("planning a hero emits no event")
	var view = engine.player_view(1)
	if not view.players[0].get("plans", {}).is_empty():
		problems.append("player 1 does not see player 0's plans")
	if view.pending_creeps != published:
		problems.append("the plan changes no published creep lane (%s, then %s)" % [published, view.pending_creeps])
	if int(view.players[0].roster.filter(func(entry): return int(entry.uid) == int(hero.uid))[0].get("lane", -1)) != -1:
		problems.append("player 1 does not see the planned lane")
	for player in range(2):
		engine.state.players[player].finished = true
	engine._reveal_deployment()
	engine._settle_transient()
	if int(hero.lane) != 2:
		problems.append("at the reveal the planned hero is in lane 2 (lane %d)" % int(hero.lane))
	var creeps: Array = []
	for lane_index in range(3):
		for unit in engine.state.lanes[lane_index].units[0]:
			if unit != null and str(unit.card) == "melee_creep":
				creeps.append(lane_index)
	var want: Array = published[0].map(func(value): return int(value))
	want.sort()
	if creeps != want:
		problems.append("at the reveal player 0's lane creeps stand in lanes %s, published %s" % [creeps, want])
	var broken = Invariants.violations(engine)
	if not broken.is_empty():
		problems.append("invariants after the reveal: %s" % [broken])
	return problems
