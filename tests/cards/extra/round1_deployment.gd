extends RefCounted
## Spec "gd" escape (tests/card_specs_test.gd): RQ-49 / CF-7. Round 1's
## initial placement is a deployment phase (Kernel.ROUND1_DEPLOYMENT_HOOKS):
## a fresh match whose heroes 1 to 3 include Venomancer and Prellex starts
## with one Plague Ward in Venomancer's lane and an extra Melee Creep in
## Prellex's lane, for each player, and every unit (summons included) has a
## rolled arrow. The default is pinned (the switch off fails this case, which
## then expects no round-1 summons). The case's own
## engine is not used. The preset is the starter one with Venomancer and
## Prellex in place of Axe and J'Muy (their signatures swapped likewise).

const EngineClass = preload("res://scripts/core/match_engine.gd")
const Library = preload("res://scripts/core/card_library.gd")
const Kernel = preload("res://scripts/core/rules/kernel.gd")
const Invariants = preload("res://tests/invariants.gd")
const PRESET = "m4_round1_summoners"

func check(_engine, _labels: Dictionary) -> Array:
	var problems: Array = []
	var library = Library.new()
	library.catalog = library.catalog.duplicate(true)
	var preset: Dictionary = library.preset("starter").duplicate(true)
	if preset.is_empty():
		return ["the starter preset exists"]
	preset.id = PRESET
	var swaps = {"axe": "venomancer", "jmuy": "prellex"}
	for index in range(preset.heroes.size()):
		var hero_id = str(preset.heroes[index])
		if swaps.has(hero_id):
			preset.cards.erase(str(library.definition(hero_id).get("signature", "")))
			preset.cards[str(library.definition(swaps[hero_id]).signature)] = 3
			preset.heroes[index] = swaps[hero_id]
	if preset.heroes.find("venomancer") > 2 or preset.heroes.find("prellex") > 2 or preset.heroes.find("venomancer") < 0:
		return ["Venomancer and Prellex are among heroes 1 to 3 of the test preset"]
	library.catalog.presets.append(preset)
	var validation = library.validate_preset(preset)
	if not validation.ok:
		return ["the test preset validates: %s" % validation]
	# The RQ-49 default is pinned here: flipping the switch must update this case.
	if not Kernel.ROUND1_DEPLOYMENT_HOOKS:
		problems.append("rq_49 default: Kernel.ROUND1_DEPLOYMENT_HOOKS is true (round 1's placement is a deployment phase)")
	var summons = 1 if Kernel.ROUND1_DEPLOYMENT_HOOKS else 0
	for seed_value in [1, 2, 3, 4, 5]:
		var engine = EngineClass.new()
		engine.library = library
		var result = engine.start(seed_value, [PRESET, PRESET])
		if not result.ok:
			return ["start: %s" % result]
		for player in range(2):
			var venomancer: Dictionary = {}
			var prellex: Dictionary = {}
			for hero in engine.state.players[player].roster:
				if str(hero.card) == "venomancer":
					venomancer = hero
				elif str(hero.card) == "prellex":
					prellex = hero
			if int(venomancer.get("lane", -1)) < 0 or int(prellex.get("lane", -1)) < 0:
				problems.append("seed %d p%d: Venomancer and Prellex are placed in round 1" % [seed_value, player])
				continue
			for lane_index in range(3):
				var wards = 0
				var creeps = 0
				for unit in engine.state.lanes[lane_index].units[player]:
					if unit == null:
						continue
					if str(unit.card) == "plague_ward":
						wards += 1
					elif str(unit.card) == "melee_creep":
						creeps += 1
					if int(unit.arrow) < -1 or int(unit.arrow) > 1:
						problems.append("seed %d: unit %s has a rolled arrow" % [seed_value, unit.card])
				var want_wards = summons if lane_index == int(venomancer.lane) else 0
				var want_creeps = 1 + (summons if lane_index == int(prellex.lane) else 0)
				if wards != want_wards:
					problems.append("seed %d p%d lane %d: %d Plague Wards, expected %d" % [seed_value, player, lane_index, wards, want_wards])
				if creeps != want_creeps:
					problems.append("seed %d p%d lane %d: %d Melee Creeps, expected %d" % [seed_value, player, lane_index, creeps, want_creeps])
		var broken = Invariants.violations(engine)
		if not broken.is_empty():
			problems.append("seed %d: invariants after round 1's placement: %s" % [seed_value, broken])
		if int(engine.state.round) != 1 or str(engine.state.phase) != "action":
			problems.append("seed %d: the match starts in round 1's action phase" % seed_value)
	return problems
