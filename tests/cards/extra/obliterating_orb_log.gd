extends RefCounted
## Obliterating Orb spec: the play event names the chosen improvement (its oid
## and card), so the log reads "... plays Obliterating Orb on <improvement>"
## like a unit-targeted play. Before the fix the event had no target.
const EventText = preload("res://scripts/core/event_text.gd")
const Library = preload("res://scripts/core/card_library.gd")

func check(engine, labels: Dictionary) -> Array:
	var failures: Array = []
	var plays: Array = engine.state.events.filter(func(event): return str(event.get("k", "")) == "play")
	if plays.size() != 1:
		return ["expected one play event, found %d" % plays.size()]
	var played: Dictionary = plays[0]
	var chosen: Dictionary = labels.get("s", {})
	if int(played.get("target", -1)) != int(chosen.get("oid", -2)):
		failures.append("play event target %s, expected the improvement oid %s" % [played.get("target"), chosen.get("oid")])
	if str(played.get("target_card", "")) != "steel_reinforcement":
		failures.append("play event target_card %s, expected steel_reinforcement" % played.get("target_card"))
	var line = EventText.format(played)
	var name = Library.loc("steel_reinforcement")
	if name.is_empty() or not line.contains(name):
		failures.append("log line %s does not name %s" % [line, name])
	return failures
