extends GutTest

var t: Trading
var inv: Inventory


func before_each() -> void:
	t = Trading.new()
	t.refresh(42, 3)
	inv = Inventory.new(10)


func test_pool_uses_known_items() -> void:
	for entry in Trading.POOL:
		for side in entry:
			for id in side:
				assert_true(ItemDB.has_item(id), "takas havuzunda bilinmeyen eşya: %s" % id)


func test_offers_are_deterministic_and_change_daily() -> void:
	var same := Trading.new()
	same.refresh(42, 3)
	assert_eq(same.offers, t.offers)
	var other := Trading.new()
	other.refresh(42, 4)
	assert_eq(other.offers.size(), Trading.PER_DAY)
	assert_ne(other.offers, t.offers, "teklifler gün gün değişmeli")


func test_trade_exchanges_items_and_uses_stock() -> void:
	var o: Dictionary = t.offers[0]
	for id in o.give:
		inv.add(id, int(o.give[id]) * 3)
	assert_true(t.trade(inv, 0))
	for id in o.get:
		assert_eq(inv.count_of(id), int(o.get[id]))
	assert_eq(int(t.offers[0].stock), Trading.STOCK - 1)
	assert_true(t.trade(inv, 0))
	assert_false(t.trade(inv, 0), "günlük stok bitince takas olmaz")


func test_trade_fails_without_items() -> void:
	assert_false(t.trade(inv, 0))
	assert_eq(int(t.offers[0].stock), Trading.STOCK)


func test_save_roundtrip_keeps_stock() -> void:
	var o: Dictionary = t.offers[1]
	for id in o.give:
		inv.add(id, int(o.give[id]))
	t.trade(inv, 1)
	var d: Dictionary = JSON.parse_string(JSON.stringify(t.to_dict()))
	var copy := Trading.new()
	copy.from_dict(d, 42)
	assert_eq(copy.day, 3)
	assert_eq(int(copy.offers[1].stock), Trading.STOCK - 1)


func test_medicine_cures_nausea() -> void:
	var s := SurvivalStats.new()
	s.nausea_time = 50.0
	s.health = 40.0
	s.consume(ItemDB.get_item("medicine"), RandomNumberGenerator.new())
	assert_false(s.is_nauseous())
	assert_eq(s.health, 80.0)
