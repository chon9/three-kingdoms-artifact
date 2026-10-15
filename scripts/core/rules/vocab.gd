extends RefCounted
## The closed rules vocabulary of card data schema 4 (EFFECT_SYSTEM_SPEC.md
## §3). RulesDB validates every card against these tables; the VM, Select,
## Stats and Kernel implement them. Adding a word here without implementing it
## is caught by tests/rules_schema_test.gd.

const SCHEMA_CLASSIC = 4
const SCHEMA_TRAINING = 2

## Top-level card fields that are not rule parameters. Any other top-level
## int is a parameter, read by rules with {"param": name} and by locale
## {placeholders}.
const CARD_FIELDS = ["id", "source_id", "kind", "color", "cost", "price", "attack", "armor", "health",
	"signature", "slot", "text", "image", "artist", "image_patch", "consumable", "cross_lane", "status",
	"token", "rq", "keywords", "charges", "play", "enter", "abilities", "grants", "ai", "valve_text",
	"name", "ability_name", "grant_text"]
const KINDS = ["hero", "creep", "spell", "improvement", "item"]
const COLORS = ["red", "green", "blue", "black", "neutral", "item"]
const SLOTS = ["weapon", "armor", "accessory", "deed"]
const EQUIPMENT_SLOTS = ["weapon", "armor", "accessory"]
const STATUSES = ["verified", "draft"]

## Op name -> allowed fields (besides "op").
const OPS = {
	"damage": ["to", "amount", "piercing"],
	"damage_split": ["to", "total"],
	"tower_damage": ["to", "amount", "piercing"],
	"heal": ["to", "amount"],
	"tower_heal": ["to", "amount"],
	"modify": ["to", "stats", "keywords", "grant"],
	"give": ["to", "stats", "keywords", "grant", "until"],
	"purge": ["to", "from"],
	"condemn": ["to"],
	"summon": ["card", "count", "lane", "for", "as"],
	"move": ["unit", "lane", "position"],
	"swap": ["a", "b"],
	"retarget": ["unit", "to"],
	"taunt": ["unit"],
	"battle": ["a", "b"],
	"to_fountain": ["unit"],
	"control": ["unit", "to"],
	"draw": ["player", "n"],
	"discard": ["cards"],
	"lock": ["cards", "n"],
	"add_card": ["player", "card", "from_pool", "base"],
	"card_counter": ["cards", "counter", "add"],
	"charges": ["on", "add", "set", "min"],
	"gold": ["player", "add", "set", "as"],
	"mana": ["to", "restore"],
	"initiative": [],
	"end_action_phase": [],
	"let": ["name", "value"],
	"if": ["cond", "then", "else"],
	"repeat": ["times", "ops"],
	"for_each": ["in", "as", "ops"],
	"chance": ["pct", "then", "else"],
	"pulse": [],
	"break": [],
	"native": ["fn", "args"],
}
## Op fields the VM reads without a default: the validator requires them, so
## a card that compiles can never crash at play time.
const OP_REQUIRED = {
	"damage": ["to", "amount"],
	"damage_split": ["to", "total"],
	"tower_damage": ["to", "amount"],
	"heal": ["to", "amount"],
	"tower_heal": ["to", "amount"],
	"modify": ["to"],
	"give": ["to", "until"],
	"purge": ["to"],
	"condemn": ["to"],
	"summon": ["card"],
	"move": ["unit"],
	"swap": ["a", "b"],
	"retarget": ["unit", "to"],
	"taunt": ["unit"],
	"battle": ["a", "b"],
	"to_fountain": ["unit"],
	"control": ["unit"],
	"discard": ["cards"],
	"lock": ["cards"],
	"card_counter": ["cards"],
	"charges": ["on"],
	"mana": ["to", "restore"],
	"let": ["name", "value"],
	"if": ["cond"],
	"repeat": ["times"],
	"for_each": ["in", "as"],
	"chance": ["pct"],
	"native": ["fn"],
}
## Op fields that hold a set (a Ref, a selector, a shorthand or a list).
const SET_FIELDS = {"damage": ["to"], "damage_split": ["to"], "tower_damage": ["to"], "heal": ["to"],
	"tower_heal": ["to"], "modify": ["to"], "give": ["to"], "purge": ["to"], "condemn": ["to"],
	"move": ["unit"], "retarget": ["unit"], "taunt": ["unit"], "battle": ["b"], "to_fountain": ["unit"],
	"control": ["unit"], "discard": ["cards"], "lock": ["cards"], "card_counter": ["cards"],
	"mana": ["to"], "for_each": ["in"]}
## Op fields that hold exactly one object (CF-3).
const ONE_FIELDS = {"battle": ["a"], "swap": ["a", "b"], "charges": ["on"]}
## Op fields that hold an expression.
const EXPR_FIELDS = {"damage": ["amount"], "damage_split": ["total"], "tower_damage": ["amount"],
	"heal": ["amount"], "tower_heal": ["amount"], "summon": ["count"], "draw": ["n"], "lock": ["n"],
	"card_counter": ["add"], "charges": ["add", "set"], "gold": ["add", "set"], "mana": ["restore"],
	"repeat": ["times"], "chance": ["pct"]}

## Trigger events -> payload fields readable as $e.<field>.
const EVENTS = {
	"before_action": ["lane"],
	"after_combat": ["lane"],
	"deployment": [],
	"card_played": ["player", "card", "kind", "color", "cost", "lane", "target"],
	"unit_died": ["uid", "card", "owner", "hero", "color", "lane", "slot", "neighbors", "enemy_neighbors",
		"target", "attackers", "items", "attack", "armor", "max_health", "kw", "cause", "unit"],
	"death": ["uid", "card", "owner", "hero", "color", "lane", "slot", "neighbors", "enemy_neighbors",
		"target", "attackers", "items", "attack", "armor", "max_health", "kw", "cause", "unit"],
	"unit_entered": ["unit", "lane", "how"],
	"improvement_entered": ["oid", "card", "owner", "lane"],
	"battle_damage": ["source", "target", "amount", "lane", "in_combat", "part"],
	"card_drawn": ["player", "card"],
}
## Events whose default scope is the source's lane (the others have no lane).
const LANE_EVENTS = ["before_action", "after_combat", "card_played", "unit_died", "unit_entered",
	"improvement_entered", "battle_damage"]
## Filter keys per event (sugar evaluated before `where`).
const FILTERS = {
	"card_played": ["player", "kind", "not_kind", "color", "cost_max"],
	"unit_died": ["side", "kind", "card", "was"],
	"death": ["side", "kind", "card", "was"],
	"battle_damage": ["role", "target_kind", "source_kind", "in_combat"],
	"unit_entered": ["side", "how"],
	"improvement_entered": ["side"],
	"card_drawn": ["player"],
	"before_action": [],
	"after_combat": [],
	"deployment": [],
}

const SELECTOR_KEYS = ["s", "side", "lane", "kind", "card", "color", "slot", "rel", "not", "where",
	"zone", "player", "pick", "after", "use"]
const SELECTOR_KINDS = ["units", "towers", "improvements", "items", "cards", "lanes", "positions", "players"]
const SIDES = ["ally", "enemy", "any"]
const LANE_WORDS = ["active", "self", "all", "other", "fountain"]
const RELATIONS = ["allied_neighbors", "enemy_neighbors", "across", "blocker", "attackers", "equipped_on"]
const ZONES = ["hand", "deck"]
const PLAYER_WORDS = ["you", "opponent", "both"]
## Shorthand selector names and their expansions. Relational shorthands are
## relative to $host so they work unchanged on items and granted text.
const SHORTHANDS = {
	"units": {"s": "units"},
	"heroes": {"s": "units", "kind": "hero"},
	"creeps": {"s": "units", "kind": "creep"},
	"allies": {"s": "units", "side": "ally"},
	"enemies": {"s": "units", "side": "enemy"},
	"other_allies": {"s": "units", "side": "ally", "not": "$host"},
	"allied_heroes": {"s": "units", "side": "ally", "kind": "hero"},
	"enemy_heroes": {"s": "units", "side": "enemy", "kind": "hero"},
	"allied_creeps": {"s": "units", "side": "ally", "kind": "creep"},
	"enemy_creeps": {"s": "units", "side": "enemy", "kind": "creep"},
	"allied_neighbors": {"s": "units", "rel": {"allied_neighbors": "$host"}},
	"enemy_neighbors": {"s": "units", "rel": {"enemy_neighbors": "$host"}},
	"blocker": {"s": "units", "rel": {"blocker": "$host"}},
	"attackers": {"s": "units", "rel": {"attackers": "$host"}},
	"your_tower": {"s": "towers", "side": "ally"},
	"enemy_tower": {"s": "towers", "side": "enemy"},
	"both_towers": {"s": "towers", "side": "any"},
	"your_hand": {"s": "cards", "zone": "hand", "player": "you"},
	"opponent_hand": {"s": "cards", "zone": "hand", "player": "opponent"},
	"you": {"s": "players", "player": "you"},
	"opponent": {"s": "players", "player": "opponent"},
	"both_players": {"s": "players"},
}
## Shorthands that need a $host (not usable in a spell's play block).
const HOST_SHORTHANDS = ["other_allies", "allied_neighbors", "enemy_neighbors", "blocker", "attackers"]

## Stats that modify/give may change, and that a Grant may grant.
const STATS = ["attack", "armor", "max_health", "mana"]
## Derived values readable with {"stat": S, "of": Ref} / {"sum": Sel, "stat": S}.
const UNIT_READS = ["attack", "armor", "health", "max_health", "siege", "cleave", "retaliate",
	"regeneration", "bounty"]
const TOWER_READS = ["health", "armor", "mana", "max_mana", "retaliate", "regeneration"]
## Keywords: number keywords sum; flags and statuses are on when the sum > 0.
const NUMBER_KEYWORDS = ["siege", "cleave", "retaliate", "regeneration", "bounty", "bonus_hero", "bonus_tower"]
const FLAG_KEYWORDS = ["pierce", "lethal", "lethal_creeps", "lethal_heroes", "damage_immunity",
	"rapid_deployment", "soulbound"]
const STATUS_KEYWORDS = ["death_shield", "stun", "silence", "disarm"]
const KEYWORDS = NUMBER_KEYWORDS + FLAG_KEYWORDS + STATUS_KEYWORDS
## Keywords a tower may hold (besides its armor and mana stats).
const TOWER_KEYWORDS = ["retaliate", "regeneration"]
## An aura may not grant these (they would make derivation cyclic).
const AURA_FORBIDDEN = ["stun", "silence", "disarm", "death_shield"]
## Reserved words the validator rejects (no Classic card uses them).
const RESERVED_KEYWORDS = ["decay", "untargetable"]
const DURATIONS = ["round", "next_combat", "death", "equip", "used"]
const RULES_KEYS = ["round_draw", "forbid_play", "secret_shop_discount", "creep_lane"]

const ABILITY_KINDS = {
	"aura": ["id", "kind", "valve", "affects", "if", "grant"],
	"trigger": ["id", "kind", "valve", "on", "filter", "where", "lane", "once_per", "ops"],
	"active": ["id", "kind", "valve", "cooldown", "requires", "choices", "ops", "quicken"],
	"hack": ["kind", "ops"],
}
const PLAY_FIELDS = ["choices", "requires", "ops", "initiative"]
const CHOICE_KEYS = ["target", "destination", "lane", "position"]
const CHOICE_FIELDS = ["key", "from", "combat_target_of", "after"]

const EXPR_KEYS = ["param", "count", "sum", "stat", "of", "charges", "card_counter", "counter", "gold",
	"price", "half", "add", "sub", "mul", "neg", "min", "max", "card_of"]
const COND_KEYS = ["all", "any", "not", "cmp", "is", "in", "has", "empty", "in_play", "unblocked",
	"damaged", "flag", "log", "tower", "by", "kind", "active_lane"]
const CMP_OPS = ["==", "!=", "<", "<=", ">", ">="]
## Read-only fields on unit refs, e.g. "$self.lane".
const REF_FIELDS = ["lane", "owner", "card", "slot", "hero", "color", "uid"]
## Bare words some op fields accept besides refs.
const OP_WORDS = ["across", "full", "random_other"]
