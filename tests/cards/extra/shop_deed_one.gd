extends RefCounted
## Shop Deed spec: one deed in player 0's deeds zone (RQ-41) makes every
## Secret Shop item free for player 0 (RQ-26), and nothing else changes.
const Prices = preload("res://tests/cards/extra/shop_deed_prices.gd")

func check(engine, labels: Dictionary) -> Array:
	return Prices.check_prices(engine, [1, 0])
