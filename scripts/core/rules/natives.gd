extends RefCounted
## Sanctioned native handlers (EFFECT_SYSTEM_SPEC.md §3.13), called by the op
## {"op": "native", "fn": name, "args": {...}} as `static func name(e, ctx,
## args)`. The budget is 5 and the plan uses 0: every Classic card is written
## in the schema, so this registry is empty. A native may call only Kernel,
## Zones, Stats, Select and VM, write no other state, draw randomness only
## through Kernel.rand_*, and needs its own test.

const REGISTRY: Array = []

static func run(_e, fn: String, _ctx: Dictionary, _args: Dictionary) -> void:
	push_error("Unknown native rules handler %s" % fn)
