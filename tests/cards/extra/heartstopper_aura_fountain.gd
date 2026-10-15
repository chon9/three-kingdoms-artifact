extends RefCounted
## Heartstopper Aura spec: the granted text is a Modify, so the hero keeps it
## in the Fountain (RQ-13). The DSL cannot read granted text, so this checks
## the hero's modifier entries for the grant reference.

func check(engine, labels: Dictionary) -> Array:
	var hero: Dictionary = labels.get("n", {})
	for entry in hero.get("mods", []):
		if str(entry.get("k", "")) == "modify" and str(entry.get("ab", "")) == "heartstopper_aura#0":
			return []
	return ["the hero in the Fountain lost the granted text (mods: %s)" % [hero.get("mods", [])]]
