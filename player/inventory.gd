class_name Inventory
extends RefCounted
## Slot tabanlı envanter. Her slot boş ({}) ya da {"id", "count", "dur"} sözlüğüdür.
## İlk HOTBAR slot hızlı erişim çubuğudur. Dayanıklılığı olan eşyalar yığılmaz.

signal changed

const HOTBAR := 5

var slots: Array[Dictionary] = []


func _init(size := 20) -> void:
	slots.resize(size)
	for i in size:
		slots[i] = {}


func size() -> int:
	return slots.size()


func get_slot(i: int) -> Dictionary:
	return slots[i] if i >= 0 and i < slots.size() else {}


func slot_item(i: int) -> ItemData:
	var s := get_slot(i)
	return ItemDB.get_item(s.id) if not s.is_empty() else null


func count_of(id: String) -> int:
	var n := 0
	for s in slots:
		if not s.is_empty() and s.id == id:
			n += int(s.count)
	return n


func has(id: String, count := 1) -> bool:
	return count_of(id) >= count


func has_all(requirements: Dictionary) -> bool:
	for id in requirements:
		if not has(id, int(requirements[id])):
			return false
	return true


## Bu eşyadan kaç adet daha alınabilir.
func space_for(id: String) -> int:
	var item := ItemDB.get_item(id)
	if item == null:
		return 0
	var space := 0
	for s in slots:
		if s.is_empty():
			space += item.max_stack
		elif s.id == id and _stackable(item):
			space += item.max_stack - int(s.count)
	return space


## Eşya ekler, sığmayan adedi döndürür. dur < 0 ise eşyanın tam dayanıklılığı kullanılır.
func add(id: String, count := 1, dur := -1.0) -> int:
	var item := ItemDB.get_item(id)
	if item == null:
		push_error("Bilinmeyen eşya: %s" % id)
		return count
	var left := count
	if _stackable(item):
		for s in slots:
			if left <= 0:
				break
			if not s.is_empty() and s.id == id and int(s.count) < item.max_stack:
				var take := mini(left, item.max_stack - int(s.count))
				s.count = int(s.count) + take
				left -= take
	for i in slots.size():
		if left <= 0:
			break
		if slots[i].is_empty():
			var take := mini(left, item.max_stack)
			slots[i] = {"id": id, "count": take, "dur": dur if dur >= 0.0 else item.durability}
			left -= take
	if left != count:
		changed.emit()
	return left


## Yeterli adet varsa çıkarır. Önce sondaki slotlardan alır, böylece hızlı
## erişim çubuğundaki eşyalar en son tükenir.
func remove(id: String, count := 1) -> bool:
	if not has(id, count):
		return false
	var left := count
	for i in range(slots.size() - 1, -1, -1):
		var s := slots[i]
		if left <= 0:
			break
		if s.is_empty() or s.id != id:
			continue
		var take := mini(left, int(s.count))
		s.count = int(s.count) - take
		left -= take
		if int(s.count) <= 0:
			slots[i] = {}
	changed.emit()
	return true


func remove_all(requirements: Dictionary) -> bool:
	if not has_all(requirements):
		return false
	for id in requirements:
		remove(id, int(requirements[id]))
	return true


## Slottan adet çıkarır ve çıkarılan yığını döndürür.
func take_from(i: int, count := 1) -> Dictionary:
	var s := get_slot(i)
	if s.is_empty():
		return {}
	var take := mini(count, int(s.count))
	var out := {"id": s.id, "count": take, "dur": float(s.get("dur", 0.0))}
	s.count = int(s.count) - take
	if int(s.count) <= 0:
		slots[i] = {}
	changed.emit()
	return out


func set_slot(i: int, data: Dictionary) -> void:
	slots[i] = data.duplicate()
	changed.emit()


## İki slotu yer değiştirir; aynı yığılabilir eşyaysa birleştirir.
func move(from: int, to: int) -> void:
	if from == to:
		return
	var a := slots[from]
	var b := slots[to]
	if not a.is_empty() and not b.is_empty() and a.id == b.id:
		var item := ItemDB.get_item(a.id)
		if item and _stackable(item):
			var take := mini(int(a.count), item.max_stack - int(b.count))
			b.count = int(b.count) + take
			a.count = int(a.count) - take
			if int(a.count) <= 0:
				slots[from] = {}
			changed.emit()
			return
	slots[from] = b
	slots[to] = a
	changed.emit()


## Aletin dayanıklılığını düşürür. Kırılırsa slotu boşaltıp true döner.
func wear(i: int, amount: float) -> bool:
	var s := get_slot(i)
	if s.is_empty() or float(s.get("dur", 0.0)) <= 0.0:
		return false
	s.dur = float(s.dur) - amount
	if float(s.dur) <= 0.0:
		slots[i] = {}
		changed.emit()
		return true
	return false


## Envanterdeki en iyi giysinin ısı kaybı çarpanı (1 = korumasız).
func best_cold_resist() -> float:
	var best := 1.0
	for s in slots:
		if s.is_empty():
			continue
		var item := ItemDB.get_item(s.id)
		if item and item.category == ItemData.Category.CLOTHING:
			best = minf(best, item.cold_resist)
	return best


func to_array() -> Array:
	var out := []
	for s in slots:
		out.append(s.duplicate())
	return out


func from_array(data: Array) -> void:
	for i in slots.size():
		slots[i] = {}
		if i < data.size() and data[i] is Dictionary and not data[i].is_empty():
			var d: Dictionary = data[i]
			if ItemDB.has_item(str(d.get("id", ""))):
				slots[i] = {"id": str(d.id), "count": int(d.get("count", 1)), "dur": float(d.get("dur", 0.0))}
	changed.emit()


static func _stackable(item: ItemData) -> bool:
	return item.max_stack > 1 and not item.has_durability()
