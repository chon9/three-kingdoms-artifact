extends "res://tests/cards/extra/chain_frost_pulses.gd"
## Chain Frost spec: the killed middle unit's position stays (the caster
## stands across it), so the outer units are not neighbors. The first bounce
## goes from the dead unit's look-back snapshot to one outer unit; that unit
## has no surviving neighbor, so the other six bounces fizzle: two hits, and
## the outer units took 3 damage between them.

func _init() -> void:
	expected_hits = 2

func check(engine, labels: Dictionary) -> Array:
	var out: Array = super.check(engine, labels)
	var x: int = int(labels.get("x", {}).get("health", 0))
	var y: int = int(labels.get("y", {}).get("health", 0))
	if (14 - x) + (14 - y) != 3:
		out.append("the outer units took %d damage, expected 3 (one bounce)" % [(14 - x) + (14 - y)])
	return out
