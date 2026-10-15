extends RefCounted
## Golden Ticket spec: the card gained is an item of the Secret Shop pool
## (classic_cards.json "secret_shop"), it is the only card in the player's
## hand, and it stays private: the opponent's view has no hand cards of the
## player and its gain_card event carries no card, while the player's own
## view names it (spec §10.4).

func check(engine, labels: Dictionary) -> Array:
	var out: Array = []
	var pool: Array = engine.library.catalog.get("secret_shop", [])
	var hand: Array = engine.state.players[0].hand
	if hand.size() != 1:
		return ["player 0 holds %d cards after Golden Ticket, expected 1" % hand.size()]
	var gained = str(hand[0])
	if gained not in pool:
		out.append("%s is not in the Secret Shop pool %s" % [gained, pool])
	if str(engine.library.get_card(gained).get("kind", "")) != "item":
		out.append("%s is not an item" % gained)
	var theirs: Dictionary = engine.player_view(1)
	if not theirs.players[0].hand.is_empty():
		out.append("player 1's view shows player 0's hand")
	var seen_mine = false
	for event in theirs.events:
		if str(event.get("k", "")) == "gain_card" and event.has("card"):
			out.append("player 1's view of gain_card names %s" % event.card)
	for event in engine.player_view(0).events:
		if str(event.get("k", "")) == "gain_card" and str(event.get("card", "")) == gained:
			seen_mine = true
	if not seen_mine:
		out.append("player 0's own view does not name the gained %s" % gained)
	return out
