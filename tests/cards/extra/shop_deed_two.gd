extends RefCounted
## Shop Deed spec, rq_26_negative_price: two deeds make a Secret Shop price
## minus the base cost, and buying the Claymore (base 14) pays 14 gold.
const Prices = preload("res://tests/cards/extra/shop_deed_prices.gd")

func check(engine, labels: Dictionary) -> Array:
	var out = Prices.check_prices(engine, [2, 0])
	out.append_array(Prices.buy_secret(engine, "claymore", 0))
	return out
