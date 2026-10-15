extends RefCounted
## Shop Deed spec: in the shop phase after the deed was played, player 0 buys
## a Claymore (base 14) from the Secret Shop for 0 gold.
const Prices = preload("res://tests/cards/extra/shop_deed_prices.gd")

func check(engine, labels: Dictionary) -> Array:
	var out = Prices.check_prices(engine, [1, 0])
	out.append_array(Prices.buy_secret(engine, "claymore", 0))
	return out
