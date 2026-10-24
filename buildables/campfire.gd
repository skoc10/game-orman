extends Buildable
## Kamp ateşi: yakıtla yanar; ışık ve ısı verir, kurtları uzak tutar.
## Üstünde üç pişirme yeri ve su kaynatmak için kap yeri vardır.
## E ile yapılacak iş elde tutulan eşyaya ve ateşin durumuna göre seçilir.

const FOOD_RADIUS := 0.45

## -1: yeni inşa edildi, başlangıç yakıtıyla yanar.
var fuel := -1.0
var cooking := Cooking.new(Balance.d)

var _light: OmniLight3D
var _flames: Node3D
var _sparks: CPUParticles3D
var _smoke: CPUParticles3D
var _pot_mesh: MeshInstance3D
var _food: Array[MeshInstance3D] = []
var _food_ids: Array[String] = ["", "", ""]


func _ready() -> void:
	recipe_id = "campfire"
	footprint = Vector3(1.4, 0.6, 1.4)
	_build_visuals()
	if is_ghost:
		return
	super._ready()
	add_to_group("warmth_source")
	add_to_group("fire")
	collision_layer = 1 | 4
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.7
	cyl.height = 0.5
	shape.shape = cyl
	shape.position.y = 0.25
	add_child(shape)
	if fuel < 0.0:
		fuel = Balance.d.fire_start_fuel
	_update_visuals(0.0)


func _process(delta: float) -> void:
	var burning := is_burning()
	if burning:
		fuel = maxf(0.0, fuel - delta)
	cooking.tick(delta, burning)
	_update_visuals(delta)


func is_burning() -> bool:
	return fuel > 0.0


## Uyku gibi zaman atlamalarında ateşin o süre boyunca yanmasını uygular.
func skip_time(seconds: float) -> void:
	var burn := minf(maxf(fuel, 0.0), seconds)
	cooking.tick(burn, true)
	fuel = maxf(0.0, fuel - seconds)


func add_fuel(seconds: float) -> void:
	fuel = minf(Balance.d.fire_max_fuel, maxf(fuel, 0.0) + seconds)


## Oyuncunun hedef ısısına katkı. Ateşten uzaklaştıkça azalır.
func warmth_for(pos: Vector3) -> float:
	if not is_burning():
		return -1.0
	var r := Balance.d.fire_warm_radius
	var d := pos.distance_to(global_position)
	if d > r:
		return -1.0
	return lerpf(Balance.d.fire_warmth, Balance.d.fire_warmth * 0.5, clampf((d - r * 0.6) / (r * 0.4), 0.0, 1.0))


func get_interaction(player: Player, _shape_idx: int) -> Dictionary:
	var inv := player.inventory
	var held := player.equipment.held_item()
	var held_id := held.id if held else ""

	var ready := cooking.ready_slot()
	if ready >= 0:
		return {"text": tr("%s al") % ItemDB.display_name(cooking.result_id(ready)), "action": _take_food.bind(player, ready)}
	if cooking.pot_state() == "boiled":
		return {"text": tr("Kaynamış suyu al"), "action": _take_pot.bind(player)}

	if held and held.fuel > 0.0:
		return {"text": tr("Ateşe %s at") % held.display_name, "action": _add_fuel.bind(player, held_id)}
	if held and Cooking.can_cook(held_id) and cooking.free_slot() >= 0:
		return {"text": tr("%s pişir") % held.display_name, "action": _cook.bind(player, held_id)}
	if held_id in ["water_raw", "pot"] and _can_boil(inv):
		return {"text": tr("Suyu kaynat (%d yudum)") % mini(inv.count_of("water_raw"), 9), "action": _boil.bind(player)}

	if not is_burning():
		for id in ["stick", "log"]:
			if inv.has(id):
				return {"text": tr("Ateşi yak (%s ekle)") % ItemDB.display_name(id), "action": _add_fuel.bind(player, id)}
		return {"text": tr("Ateş söndü. Yakmak için dal ya da kütük gerekli.")}
	if inv.has("meat_raw") and cooking.free_slot() >= 0:
		return {"text": tr("Çiğ et pişir"), "action": _cook.bind(player, "meat_raw")}
	if _can_boil(inv):
		return {"text": tr("Suyu kaynat (%d yudum)") % mini(inv.count_of("water_raw"), 9), "action": _boil.bind(player)}
	if fuel < Balance.d.fire_max_fuel * 0.7:
		for id in ["stick", "log"]:
			if inv.has(id):
				return {"text": tr("Ateşe %s at (%d sn kaldı)") % [ItemDB.display_name(id), int(fuel)], "action": _add_fuel.bind(player, id)}
	return {"text": _status_text()}


func _status_text() -> String:
	var parts := [tr("Ateş: %d sn") % int(fuel)]
	for i in Cooking.SLOTS:
		if cooking.state(i) == "cooking":
			parts.append(tr("pişiyor"))
			break
	if cooking.pot_state() == "boiling":
		parts.append(tr("su kaynıyor"))
	return " · ".join(parts)


func _can_boil(inv: Inventory) -> bool:
	return not cooking.has_pot and inv.has("pot") and inv.has("water_raw")


func _take_food(player: Player, slot: int) -> void:
	var id := cooking.result_id(slot)
	if player.inventory.space_for(id) <= 0:
		player.notify(tr("Envanter dolu!"))
		return
	cooking.take(slot)
	player.give(id, 1)


func _take_pot(player: Player) -> void:
	var out := cooking.take_pot()
	player.give("water_clean" if out.clean else "water_raw", int(out.water))
	player.give("pot", 1)


func _add_fuel(player: Player, id: String) -> void:
	var item := ItemDB.get_item(id)
	if fuel >= Balance.d.fire_max_fuel - 1.0:
		player.notify(tr("Ateş zaten harlı."))
		return
	if player.inventory.remove(id, 1):
		var was_out := not is_burning()
		add_fuel(item.fuel)
		player.notify(tr("Ateş yandı.") if was_out else tr("+%d sn yakıt") % int(item.fuel))


func _cook(player: Player, id: String) -> void:
	if cooking.free_slot() >= 0 and player.inventory.remove(id, 1):
		cooking.add(id)


func _boil(player: Player) -> void:
	var inv := player.inventory
	var n := mini(inv.count_of("water_raw"), 9)
	if n <= 0 or not inv.remove("pot", 1):
		return
	inv.remove("water_raw", n)
	cooking.place_pot(n)
	player.notify(tr("Su kaynamaya başladı."))


func save_extra() -> Dictionary:
	return {"fuel": fuel, "cooking": cooking.to_dict()}


func load_extra(d: Dictionary) -> void:
	fuel = float(d.get("fuel", 0.0))
	cooking.from_dict(d.get("cooking", {}))


func _build_visuals() -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = MeshFactory.stone_ring(0.55, 9)
	add_child(ring)
	var logs := MeshInstance3D.new()
	logs.mesh = MeshFactory.combine([
		[MeshFactory.cylinder(0.06, 0.07, 0.8, 6), MeshFactory.at(Vector3(0, 0.12, 0), Vector3(0, 0, PI * 0.5 - 0.35)), MeshFactory.flat_material(Color(0.25, 0.17, 0.11))],
		[MeshFactory.cylinder(0.06, 0.07, 0.8, 6), MeshFactory.at(Vector3(0, 0.12, 0), Vector3(0, PI * 0.66, PI * 0.5 - 0.35)), MeshFactory.flat_material(Color(0.25, 0.17, 0.11))],
		[MeshFactory.cylinder(0.06, 0.07, 0.8, 6), MeshFactory.at(Vector3(0, 0.12, 0), Vector3(0, PI * 1.33, PI * 0.5 - 0.35)), MeshFactory.flat_material(Color(0.25, 0.17, 0.11))],
	])
	add_child(logs)

	_flames = Node3D.new()
	add_child(_flames)
	var colors := [Color(1.0, 0.45, 0.1), Color(1.0, 0.7, 0.2), Color(1.0, 0.85, 0.4)]
	for i in 3:
		var f := MeshInstance3D.new()
		f.mesh = MeshFactory.cylinder(0.0, 0.22 - i * 0.05, 0.6 - i * 0.12, 5)
		f.material_override = MeshFactory.glow_material(colors[i], 4.0 + i * 2.0)
		f.position = Vector3(0, 0.3 - i * 0.04, 0)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flames.add_child(f)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.32)
	_light.omni_range = 14.0
	_light.light_energy = 3.0
	_light.shadow_enabled = true
	_light.position = Vector3(0, 0.8, 0)
	add_child(_light)

	_sparks = CPUParticles3D.new()
	_sparks.amount = 14
	_sparks.lifetime = 1.4
	_sparks.direction = Vector3.UP
	_sparks.spread = 20.0
	_sparks.initial_velocity_min = 0.8
	_sparks.initial_velocity_max = 1.8
	_sparks.gravity = Vector3(0, 0.3, 0)
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = 0.2
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.025, 0.025, 0.025)
	spark_mesh.material = MeshFactory.glow_material(Color(1.0, 0.6, 0.2), 8.0)
	_sparks.mesh = spark_mesh
	_sparks.position.y = 0.4
	add_child(_sparks)

	_smoke = CPUParticles3D.new()
	_smoke.amount = 10
	_smoke.lifetime = 3.5
	_smoke.direction = Vector3.UP
	_smoke.spread = 12.0
	_smoke.initial_velocity_min = 0.8
	_smoke.initial_velocity_max = 1.2
	_smoke.gravity = Vector3(0.15, 0.2, 0)
	_smoke.scale_amount_min = 0.8
	_smoke.scale_amount_max = 1.8
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.albedo_color = Color(0.4, 0.4, 0.42, 1.0)
	smoke_mat.vertex_color_use_as_albedo = true
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.07))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	_smoke.color_ramp = fade
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.16
	smoke_mesh.height = 0.32
	smoke_mesh.radial_segments = 6
	smoke_mesh.rings = 3
	smoke_mesh.material = smoke_mat
	_smoke.mesh = smoke_mesh
	_smoke.position.y = 0.9
	add_child(_smoke)

	for i in Cooking.SLOTS:
		var a := TAU * i / Cooking.SLOTS + 0.5
		var spit := MeshInstance3D.new()
		spit.mesh = MeshFactory.cylinder(0.012, 0.012, 0.9, 4)
		spit.material_override = MeshFactory.flat_material(Color(0.45, 0.32, 0.2))
		spit.position = Vector3(cos(a) * FOOD_RADIUS, 0.4, sin(a) * FOOD_RADIUS)
		spit.rotation = Vector3(0, -a, 0.9)
		add_child(spit)
		var food := MeshInstance3D.new()
		food.position = Vector3(cos(a) * FOOD_RADIUS * 0.7, 0.62, sin(a) * FOOD_RADIUS * 0.7)
		food.visible = false
		add_child(food)
		_food.append(food)

	_pot_mesh = MeshInstance3D.new()
	_pot_mesh.mesh = MeshFactory.item_mesh("pot")
	_pot_mesh.position = Vector3(0, 0.42, 0)
	_pot_mesh.visible = false
	add_child(_pot_mesh)


func _update_visuals(_delta: float) -> void:
	var burning := is_burning()
	_flames.visible = burning
	_light.visible = burning
	_sparks.emitting = burning
	_smoke.emitting = burning
	if burning:
		var t := Time.get_ticks_msec() * 0.001
		var strength := clampf(fuel / 60.0, 0.35, 1.0)
		_flames.scale = Vector3(1.0, strength * (1.0 + sin(t * 9.0) * 0.12 + sin(t * 23.0) * 0.06), 1.0)
		_flames.rotation.y = t * 0.6
		_light.light_energy = 3.0 * strength + sin(t * 11.0) * 0.3 + sin(t * 29.0) * 0.15
	for i in Cooking.SLOTS:
		var id := cooking.result_id(i)
		if id != _food_ids[i]:
			_food_ids[i] = id
			_food[i].visible = id != ""
			if id != "":
				_food[i].mesh = MeshFactory.item_mesh(id)
	_pot_mesh.visible = cooking.has_pot
