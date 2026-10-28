class_name Trading
extends RefCounted
## Yerli köyünün takas teklifleri. Her gün havuzdan tohuma bağlı 5 teklif seçilir;
## her teklif o gün sınırlı sayıda yapılabilir. Para yoktur: eşya eşyayla değişilir.

const PER_DAY := 5
const STOCK := 2
## [verilen, alınan]
const POOL := [
	[{"hide": 2}, {"bow": 1}],
	[{"fish_cooked": 2}, {"arrow": 8}],
	[{"meat_raw": 2}, {"bandage": 2}],
	[{"log": 4}, {"rope": 4}],
	[{"berries": 6}, {"water_clean": 3}],
	[{"hide": 3}, {"hide_clothes": 1}],
	[{"meat_cooked": 2}, {"medicine": 1}],
	[{"mushroom": 4}, {"medicine": 1}],
	[{"fiber": 8}, {"rope": 3}],
	[{"fish_raw": 3}, {"fishing_rod": 1}],
	[{"meat_cooked": 3}, {"axe": 1}],
	[{"stone": 6, "stick": 4}, {"spear": 1}],
	[{"fish_raw": 4}, {"meat_cooked": 2}],
	[{"log": 2}, {"torch": 2}],
]

var day := -1
## Günün teklifleri: [{"give": {}, "get": {}, "stock": int}]
var offers: Array = []


func refresh(seed_value: int, p_day: int) -> void:
	if p_day == day:
		return
	day = p_day
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + p_day * 7919
	var indices := range(POOL.size())
	# Fisher–Yates: ilk PER_DAY eleman günün teklifleri olur.
	for i in range(indices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: int = indices[i]
		indices[i] = indices[j]
		indices[j] = tmp
	offers.clear()
	for k in mini(PER_DAY, indices.size()):
		var entry: Array = POOL[indices[k]]
		offers.append({"give": entry[0], "get": entry[1], "stock": STOCK})


func can_trade(inv: Inventory, i: int) -> bool:
	if i < 0 or i >= offers.size():
		return false
	var o: Dictionary = offers[i]
	return int(o.stock) > 0 and inv.has_all(o.give)


## Takası yapar; malzeme eksikse, stok bittiyse ya da envanterde yer yoksa
## hiçbir şey değişmez ve false döner.
func trade(inv: Inventory, i: int) -> bool:
	if not can_trade(inv, i):
		return false
	var o: Dictionary = offers[i]
	var snapshot := inv.to_array()
	inv.remove_all(o.give)
	for id in o.get:
		if inv.add(id, int(o.get[id])) > 0:
			inv.from_array(snapshot)
			return false
	o.stock = int(o.stock) - 1
	return true


static func describe(items: Dictionary) -> String:
	var parts := PackedStringArray()
	for id in items:
		parts.append("%d %s" % [int(items[id]), ItemDB.display_name(id)])
	return ", ".join(parts)


func to_dict() -> Dictionary:
	return {"day": day, "stock": offers.map(func(o: Dictionary) -> int: return int(o.stock))}


## Kayıttan: aynı günse kalan stoklar geri yüklenir.
func from_dict(d: Dictionary, seed_value: int) -> void:
	var saved_day := int(d.get("day", -1))
	if saved_day < 0:
		return
	day = -1
	refresh(seed_value, saved_day)
	var stock: Array = d.get("stock", [])
	for i in mini(stock.size(), offers.size()):
		offers[i].stock = int(stock[i])
