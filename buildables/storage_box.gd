extends Buildable
## Saklama sandığı: kendi envanteri olan, kayıtla saklanan kutu.

const SLOTS := 12

var inventory := Inventory.new(SLOTS)


func _ready() -> void:
	recipe_id = "storage_box"
	footprint = Vector3(1.0, 0.8, 0.7)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.crate()
	mi.scale = Vector3(1.3, 1.3, 1.3)
	add_child(mi)
	if is_ghost:
		return
	super._ready()
	collision_layer = 1 | 4
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.92, 0.65, 0.66)
	shape.shape = box
	shape.position.y = 0.33
	add_child(shape)


func get_interaction(_player: Player, _shape_idx: int) -> Dictionary:
	return {"text": tr("Sandığı aç"), "action": _open}


func _open() -> void:
	var screen := GameState.world.get_node_or_null("StorageScreen")
	if screen:
		screen.open(self)


func save_extra() -> Dictionary:
	return {"inventory": inventory.to_array()}


func load_extra(d: Dictionary) -> void:
	inventory.from_array(d.get("inventory", []))
