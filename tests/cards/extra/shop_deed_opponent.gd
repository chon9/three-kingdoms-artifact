extends RefCounted
## Shop Deed spec: the opponent's deed discounts only the opponent's Secret
## Shop ("your Secret Shop"); player 0 pays the base cost.
const Prices = preload("res://tests/cards/extra/shop_deed_prices.gd")

func check(engine, labels: Dictionary) -> Array:
	var out = Prices.check_prices(engine, [0, 1])
	out.append_array(Prices.buy_secret(engine, "claymore", 14))
	return out
