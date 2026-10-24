extends Buildable
## Dal barınak (sundurma): önü yüksek ve açık, arkası yere inen eğik çatı.
## Altında ısı kaybı azalır. Gece uyuyup sabaha atlanır, gündüz dinlenip kaydedilir.

const WIDTH := 3.0
const FRONT_Z := -1.0
const BACK_Z := 1.2
const FRONT_H := 1.9
const BACK_H := 0.15
const WARM_RADIUS := 2.2


func _ready() -> void:
	recipe_id = "shelter"
	footprint = Vector3(3.0, 1.8, 2.4)
	_build_visuals()
	if is_ghost:
		return
	super._ready()
	add_to_group("warmth_source")
	add_to_group("shelter")
	collision_layer = 1 | 4
	collision_mask = 0
	_build_collision()


func warmth_for(pos: Vector3) -> float:
	var center := global_transform * Vector3(0, 0.5, 0.1)
	return Balance.d.shelter_warmth if pos.distance_to(center) < WARM_RADIUS else -1.0


func get_interaction(player: Player, _shape_idx: int) -> Dictionary:
	var world := GameState.world
	if world == null:
		return {}
	if world.is_sleep_time():
		var why: String = world.sleep_block_reason(player)
		if why != "":
			return {"text": why}
		return {"text": tr("Uyu (sabaha kadar)"), "hold": 0.6, "action": world.sleep_until_morning}
	return {"text": tr("Dinlen ve oyunu kaydet"), "action": world.rest_and_save}


func _roof_basis() -> Basis:
	var angle := atan2(FRONT_H - BACK_H, BACK_Z - FRONT_Z)
	return Basis(Vector3.RIGHT, angle)


func _build_visuals() -> void:
	var bark := MeshFactory.flat_material(MeshFactory.BARK)
	var stick := MeshFactory.flat_material(Color(0.5, 0.36, 0.22))
	var leaves := MeshFactory.flat_material(Color(0.24, 0.4, 0.17), 0.15)
	var bed := MeshFactory.flat_material(Color(0.42, 0.4, 0.22))
	var roof_len := Vector2(BACK_Z - FRONT_Z, FRONT_H - BACK_H).length()
	var roof_mid := Vector3(0, (FRONT_H + BACK_H) * 0.5, (FRONT_Z + BACK_Z) * 0.5)
	var roof := _roof_basis()
	var parts := []
	for x in [-WIDTH * 0.45, WIDTH * 0.45]:
		parts.append([MeshFactory.cylinder(0.08, 0.1, FRONT_H, 6), MeshFactory.at(Vector3(x, FRONT_H * 0.5, FRONT_Z)), bark])
	parts.append([MeshFactory.cylinder(0.09, 0.09, WIDTH + 0.3, 6), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, FRONT_H, FRONT_Z)), bark])
	for i in 9:
		var x := lerpf(-WIDTH * 0.45, WIDTH * 0.45, i / 8.0)
		var t := Transform3D(roof * Basis(Vector3.RIGHT, PI * 0.5), roof_mid + Vector3(x, 0, 0))
		parts.append([MeshFactory.cylinder(0.045, 0.05, roof_len + 0.3, 5), t, stick])
	parts.append([MeshFactory.box(Vector3(WIDTH + 0.2, 0.1, roof_len + 0.2)), Transform3D(roof, roof_mid + roof * Vector3(0, 0.08, 0)), leaves])
	parts.append([MeshFactory.box(Vector3(1.0, 0.12, 1.7)), MeshFactory.at(Vector3(0, 0.06, 0.15)), bed])
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.combine(parts)
	add_child(mi)


func _build_collision() -> void:
	var roof_len := Vector2(BACK_Z - FRONT_Z, FRONT_H - BACK_H).length()
	var roof_shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(WIDTH + 0.2, 0.15, roof_len + 0.2)
	roof_shape.shape = slab
	roof_shape.transform = Transform3D(_roof_basis(), Vector3(0, (FRONT_H + BACK_H) * 0.5 + 0.05, (FRONT_Z + BACK_Z) * 0.5))
	add_child(roof_shape)
	for x in [-WIDTH * 0.45, WIDTH * 0.45]:
		var post := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.12
		cyl.height = FRONT_H
		post.shape = cyl
		post.position = Vector3(x, FRONT_H * 0.5, FRONT_Z)
		add_child(post)
