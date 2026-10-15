extends RefCounted
## Demagicking Maul spec: "Condemn a random enemy improvement" condemns exactly
## one of the two enemy improvements (the expect_rate keys cannot say "never
## both"), and the condemned one leaves its lane's row.

func check(engine, labels: Dictionary) -> Array:
	var row: Array = engine.state.lanes[0].get("improvements", [[], []])[1]
	if row.size() != 1:
		return ["the enemy row holds %d improvements after the Maul, expected 1" % row.size()]
	return []
