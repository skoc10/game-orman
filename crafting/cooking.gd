class_name Cooking
extends RefCounted
## Ateş üstündeki pişirme yerleri ve su kabı. Yalnızca ateş yanarken ilerler.
## Çiğ yiyecek cook_time sonra pişer, burn_time sonra yanar.

const SLOTS := 3

## Her slot boş ({}) ya da {"id": konulan çiğ eşya, "t": ateşte geçen süre}.
var slots: Array[Dictionary] = []
var has_pot := false
## Kaptaki su (yudum adedi).
var pot_water := 0
var pot_t := 0.0

var _b: BalanceData


func _init(balance: BalanceData = null) -> void:
	_b = balance if balance else BalanceData.new()
	slots.resize(SLOTS)
	for i in SLOTS:
		slots[i] = {}


func tick(delta: float, burning: bool) -> void:
	if not burning:
		return
	for s in slots:
		if not s.is_empty():
			s.t = float(s.t) + delta
	if has_pot and pot_water > 0:
		pot_t += delta


static func can_cook(id: String) -> bool:
	var item := ItemDB.get_item(id)
	return item != null and item.cooks_into != ""


func free_slot() -> int:
	for i in SLOTS:
		if slots[i].is_empty():
			return i
	return -1


## Çiğ eşyayı boş bir yere koyar. Slot indeksini, yer yoksa -1 döndürür.
func add(id: String) -> int:
	if not can_cook(id):
		return -1
	var i := free_slot()
	if i >= 0:
		slots[i] = {"id": id, "t": 0.0}
	return i


## "empty", "cooking", "cooked" ya da "burnt".
func state(i: int) -> String:
	var s := slots[i]
	if s.is_empty():
		return "empty"
	var t := float(s.t)
	if t < _b.cook_time:
		return "cooking"
	if t < _b.burn_time:
		return "cooked"
	return "burnt"


## Slottan alınınca elde edilecek eşya.
func result_id(i: int) -> String:
	var s := slots[i]
	if s.is_empty():
		return ""
	var item := ItemDB.get_item(s.id)
	match state(i):
		"cooked":
			return item.cooks_into
		"burnt":
			return item.burns_into if item.burns_into != "" else item.cooks_into
	return s.id


## Pişmiş ya da yanmış ilk slot; yoksa -1.
func ready_slot() -> int:
	for i in SLOTS:
		if state(i) in ["cooked", "burnt"]:
			return i
	return -1


func take(i: int) -> String:
	var id := result_id(i)
	slots[i] = {}
	return id


func place_pot(water: int) -> void:
	has_pot = true
	pot_water = water
	pot_t = 0.0


## "none", "empty", "boiling" ya da "boiled".
func pot_state() -> String:
	if not has_pot:
		return "none"
	if pot_water <= 0:
		return "empty"
	return "boiled" if pot_t >= _b.boil_time else "boiling"


## Kabı ateşten alır: {"water": adet, "clean": kaynadı mı}.
func take_pot() -> Dictionary:
	var out := {"water": pot_water, "clean": pot_state() == "boiled"}
	has_pot = false
	pot_water = 0
	pot_t = 0.0
	return out


func to_dict() -> Dictionary:
	return {"slots": slots.duplicate(true), "pot": has_pot, "pot_water": pot_water, "pot_t": pot_t}


func from_dict(d: Dictionary) -> void:
	var saved: Array = d.get("slots", [])
	for i in SLOTS:
		slots[i] = {}
		if i < saved.size() and saved[i] is Dictionary and not saved[i].is_empty():
			slots[i] = {"id": str(saved[i].id), "t": float(saved[i].t)}
	has_pot = bool(d.get("pot", false))
	pot_water = int(d.get("pot_water", 0))
	pot_t = float(d.get("pot_t", 0.0))
