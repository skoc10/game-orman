class_name VillageTent
extends StaticBody3D
## Köydeki koni biçimli deri çadır. Misafir çadırında uyunabilir ve kaydedilebilir.

var guest := false
var chief := false
var size_scale := 1.0
var color := Color(0.82, 0.72, 0.55)


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	var s := size_scale
	var hide := MeshFactory.flat_material(color)
	var stripe := MeshFactory.flat_material(Color(0.7, 0.2, 0.15) if not chief else Color(0.2, 0.45, 0.6))
	var pole := MeshFactory.flat_material(MeshFactory.BARK)
	var dark := MeshFactory.flat_material(Color(0.08, 0.06, 0.05))
	var parts := [
		[MeshFactory.cylinder(0.25, 2.0, 3.4, 9), MeshFactory.at(Vector3(0, 1.7, 0)), hide],
		[MeshFactory.cylinder(1.62, 1.72, 0.25, 9), MeshFactory.at(Vector3(0, 0.75, 0)), stripe],
		[MeshFactory.cylinder(0.9, 0.98, 0.18, 9), MeshFactory.at(Vector3(0, 2.0, 0)), stripe],
		# Kapı açıklığı (merkeze bakan taraf).
		[MeshFactory.box(Vector3(0.9, 1.3, 0.05)), MeshFactory.at(Vector3(0, 0.65, 1.62), Vector3(-0.47, 0, 0)), dark],
	]
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		parts.append([MeshFactory.cylinder(0.03, 0.04, 1.2, 5), MeshFactory.at(Vector3(cos(a) * 0.15, 3.75, sin(a) * 0.15), Vector3(sin(a) * 0.25, 0, -cos(a) * 0.25)), pole])
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.combine(parts)
	mi.scale = Vector3.ONE * s
	add_child(mi)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.7 * s
	cyl.height = 3.0 * s
	shape.shape = cyl
	shape.position.y = 1.5 * s
	add_child(shape)


func get_interaction(player: Player, _shape_idx: int) -> Dictionary:
	if not guest:
		return {"text": tr("Şefin çadırı") if chief else tr("Bir yerlinin çadırı")}
	var world := GameState.world
	if world == null:
		return {}
	if world.is_sleep_time():
		var why: String = world.sleep_block_reason(player)
		if why != "":
			return {"text": why}
		return {"text": tr("Misafir çadırında uyu (sabaha kadar)"), "hold": 0.6, "action": world.sleep_until_morning}
	return {"text": tr("Misafir çadırında dinlen ve kaydet"), "action": world.rest_and_save}


## Çadırın içi rüzgarsız: yakında uyuyana ısı verir.
func warmth_for(pos: Vector3) -> float:
	return Balance.d.shelter_warmth if guest and pos.distance_to(global_position) < 3.0 else -1.0
