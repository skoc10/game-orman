class_name Pickup
extends StaticBody3D
## Yerde duran, alınabilir eşya yığını: kesilen ağaçtan düşen kütükler,
## oyuncunun attığı eşyalar, kamptaki malzemeler. Kayıtla birlikte saklanır.

var item_id := ""
var count := 1
var dur := -1.0
## Su yüzeyinde yüzen eşya (vurulan balık) hafifçe dalgalanır.
var floating := false:
	set(v):
		floating = v
		set_process(v)

var _shape: CollisionShape3D


static func create(p_id: String, p_count: int, pos: Vector3, p_dur := -1.0, yaw := 0.0) -> Pickup:
	var p := Pickup.new()
	p.item_id = p_id
	p.count = p_count
	p.dur = p_dur
	p.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	return p


func _ready() -> void:
	add_to_group("persist_dynamic")
	floating = floating or (position.y <= WorldGen.WATER_LEVEL + 0.05 and item_id.begins_with("fish"))
	collision_layer = 4
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.55
	_shape.shape = sphere
	_shape.position.y = 0.15
	add_child(_shape)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.item_mesh(item_id)
	mi.visibility_range_end = 80.0
	var item := ItemDB.get_item(item_id)
	# Uzun eşyalar yere yatırılır.
	if item and item_id in ["stick", "log", "axe", "spear", "torch", "knife", "fiber", "fishing_rod"]:
		mi.rotation.z = PI * 0.5
		mi.position.y = 0.18 if item_id == "log" else 0.04
	add_child(mi)


func _process(_delta: float) -> void:
	if floating:
		position.y = WorldGen.WATER_LEVEL - 0.05 + sin(Time.get_ticks_msec() * 0.002 + position.x) * 0.04


func get_interaction(player: Player, _shape_idx: int) -> Dictionary:
	var label := ItemDB.display_name(item_id)
	if count > 1:
		label += " ×%d" % count
	return {"text": tr("Al: %s") % label, "action": _pick.bind(player), "auto": true}


func _pick(player: Player) -> void:
	var left := player.give(item_id, count, dur)
	if left <= 0:
		queue_free()
	else:
		count = left


func save_state() -> Dictionary:
	return {
		"type": "pickup", "id": item_id, "count": count, "dur": dur,
		"pos": GameState.vec3_to_arr(global_position), "yaw": rotation.y,
	}
