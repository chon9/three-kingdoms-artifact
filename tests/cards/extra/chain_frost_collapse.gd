extends RefCounted
## Chain Frost spec: when the middle unit dies, its emptied position collapses
## (nothing stands across it), so the two outer units become neighbors and
## the chain keeps bouncing between them. After the first hit (which kills the
## middle unit) come seven bounces: the first from the dead unit's look-back
## snapshot to an outer unit, then six more alternating between the two outer
## units, so they take seven hits of 3 between them, 4 and 3.

func check(engine, labels: Dictionary) -> Array:
	var out: Array = []
	var x: int = int(labels.get("x", {}).get("health", 0))
	var y: int = int(labels.get("y", {}).get("health", 0))
	if (14 - x) + (14 - y) != 21:
		out.append("the outer units took %d damage, expected 21 (seven bounces of 3)" % [(14 - x) + (14 - y)])
	if absi(x - y) != 3:
		out.append("the bounces alternate between the outer units: their health differs by %d, expected 3" % absi(x - y))
	return out
