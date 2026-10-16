extends "res://tests/cards/extra/chain_frost_pulses.gd"
## Chain Frost spec: the first bounce kills the target's only neighbor; the
## Pulse removes it, the next bounce looks to its surviving neighbor (the
## target again), and then the target has no neighbor left: three hits.

func _init() -> void:
	expected_hits = 3
