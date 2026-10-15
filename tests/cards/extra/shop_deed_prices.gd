extends RefCounted
## Shop Deed spec helper (not a check script itself): the deeds each player
## holds and the Secret Shop prices they give (spec §3.11, RQ-26, RQ-41).
## shop_deed_one/_shop/_two/_opponent.gd call it with their expected counts.

static func deeds_of(engine, player: int) -> Array:
	return engine.state.players[player].get("deeds", []).map(func(deed): return str(deed.card))

## Prices of every Secret Shop pool item (and two fixed items) for both
## players: base - n * base in the Secret Shop with n deeds, base elsewhere.
static func check_prices(engine, counts: Array) -> Array:
	var out: Array = []
	for player in range(2):
		var deeds = deeds_of(engine, player)
		if deeds.size() != int(counts[player]) or deeds.any(func(card): return card != "shop_deed"):
			out.append("player %d holds deeds %s, expected %d Shop Deeds" % [player, deeds, int(counts[player])])
		var items: Array = engine.library.catalog.get("secret_shop", []).duplicate()
		for extra in ["short_sword", "claymore"]:
			if extra not in items:
				items.append(extra)
		for card_id in items:
			var base = int(engine.library.get_card(str(card_id)).get("price", 0))
			var secret = int(engine.price_of(player, "secret", str(card_id)))
			if secret != base - int(counts[player]) * base:
				out.append("player %d: %s costs %d in the Secret Shop, expected %d" % [player, card_id, secret, base - int(counts[player]) * base])
			for source in ["item", "consumable"]:
				if int(engine.price_of(player, source, str(card_id))) != base:
					out.append("player %d: %s from the %s shop costs %d, expected its base %d" % [player, card_id, source, int(engine.price_of(player, source, str(card_id))), base])
	return out

## Buys `card_id` from player 0's Secret Shop in the shop phase; returns
## failure messages unless it succeeds and changes gold by -price.
static func buy_secret(engine, card_id: String, gold: int) -> Array:
	if str(engine.state.phase) != "shop":
		return ["the case did not reach the shop phase (%s)" % engine.state.phase]
	var owner: Dictionary = engine.state.players[0]
	owner.shop["secret"] = card_id
	owner.gold = gold
	var price = int(engine.price_of(0, "secret", card_id))
	var command = {"type": "buy", "card": card_id, "source": "secret"}
	if not command in engine.legal_actions(0):
		return ["buying %s for %d with %d gold is not legal" % [card_id, price, gold]]
	var result = engine.apply_action(0, command)
	if not result.ok:
		return ["buying %s was rejected" % card_id]
	if int(owner.gold) != gold - price or owner.hand.count(card_id) != 1:
		return ["after buying %s for %d: gold %d (expected %d), hand %s" % [card_id, price, int(owner.gold), gold - price, owner.hand]]
	return []
