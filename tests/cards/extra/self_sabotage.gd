extends RefCounted
## Spec "gd" escape (tests/card_specs_test.gd) for Self Sabotage's hack:
## * every hack run ("trigger" event, ability "hack", card self_sabotage) is
##   followed by a "pulse" (Valve's marker) and then by exactly one
##   tower_damage event of self_sabotage hitting one tower of the player who
##   played the hacked card, for 6 minus that tower's armor;
## * nothing else of self_sabotage damages a tower;
## * the hacked card's own play comes before its hacks, and every other
##   trigger of that play (after-you-play abilities such as Zeus's Static
##   Field) comes after them (spec §3.12, RQ-36).

const Stats = preload("res://scripts/core/rules/stats.gd")

func check(engine, _labels: Dictionary) -> Array:
	var problems: Array = []
	var events: Array = engine.state.events
	var amount = int(engine.library.definition("self_sabotage").get("amount", 0))
	var hack_runs: Array = []
	var hack_damage: Array = []
	for index in range(events.size()):
		var event: Dictionary = events[index]
		if str(event.get("k", "")) == "trigger" and str(event.get("ability", "")) == "hack":
			hack_runs.append(index)
		elif str(event.get("k", "")) == "tower_damage" and str(event.get("src", "")) == "self_sabotage":
			hack_damage.append(index)
	if hack_runs.is_empty():
		problems.append("a hack ran (trigger event with ability hack)")
	if hack_runs.size() != hack_damage.size():
		problems.append("one tower_damage per hack run (%d runs, %d damage events)" % [hack_runs.size(), hack_damage.size()])
	for run in range(mini(hack_runs.size(), hack_damage.size())):
		var start = int(hack_runs[run])
		var hit_index = int(hack_damage[run])
		var trigger: Dictionary = events[start]
		if str(trigger.get("card", "")) != "self_sabotage":
			problems.append("hack run %d names self_sabotage (%s)" % [run, trigger])
		if hit_index < start:
			problems.append("hack run %d: its damage follows the run" % run)
			continue
		var pulsed = false
		for between in range(start + 1, hit_index):
			if str(events[between].get("k", "")) == "pulse":
				pulsed = true
		if not pulsed:
			problems.append("hack run %d: a Pulse comes before the damage" % run)
		var damage: Dictionary = events[hit_index]
		var hits: Array = damage.get("hits", [])
		var holder = int(trigger.get("p", -1))
		if hits.size() != 1:
			problems.append("hack run %d hits exactly one tower (%s)" % [run, hits])
			continue
		var lane = int(hits[0][0])
		var side = int(hits[0][1])
		var armor = int(Stats.tower(engine, lane, side).armor)
		if side != holder:
			problems.append("hack run %d hits the tower of the player who played the hacked card (p%d, hit p%d)" % [run, holder, side])
		if int(hits[0][2]) != maxi(0, amount - armor):
			problems.append("hack run %d deals %d minus armor %d (dealt %d)" % [run, amount, armor, int(hits[0][2])])
	# The hacked card is played before its hacks run.
	var play_index = -1
	for index in range(events.size()):
		if str(events[index].get("k", "")) == "play" and not hack_runs.is_empty() and index < int(hack_runs[0]) \
				and int(events[index].get("p", -1)) == int(events[hack_runs[0]].get("p", -2)):
			play_index = index
	if not hack_runs.is_empty() and play_index == -1:
		problems.append("the hacked card's play event comes before its hack")
	# Other triggers of the same play (card_played listeners) come after the hacks.
	if not hack_damage.is_empty():
		var last_hack = int(hack_damage.back())
		for index in range(play_index + 1, events.size()):
			var event: Dictionary = events[index]
			if str(event.get("k", "")) == "trigger" and str(event.get("ability", "")) != "hack" and index < last_hack:
				problems.append("trigger %s of the same play resolves after the hack" % event.get("ability", ""))
	return problems
