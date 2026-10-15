extends RefCounted
## Chain Frost spec: a target between two neighbors that survive. The chain
## alternates between the target and a random neighbor: the target takes the
## first hit and three bounces (12 damage), the two neighbors share the other
## four bounces (12 damage between them).

func check(engine, labels: Dictionary) -> Array:
	var out: Array = []
	var x: int = int(labels.get("x", {}).get("health", 0))
	var y: int = int(labels.get("y", {}).get("health", 0))
	if (14 - x) + (14 - y) != 12:
		out.append("the neighbors took %d damage between them, expected 12 (four bounces of 3)" % [(14 - x) + (14 - y)])
	return out
