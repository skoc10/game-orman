extends Node3D
## Oyun dünyası: tohumdan adayı üretir, suyu, bitki örtüsünü ve gece/gündüzü
## kurar, oyuncuyu başlangıç noktasına yerleştirir.

const WATER_SHADER := preload("res://world/water.gdshader")

@onready var player: Player = $Player

var gen: WorldGen
var terrain: IslandTerrain
var trees: TreeField
var vegetation: VegetationSpawner
var resources: ResourceSpawner
var animals: AnimalSpawner
var day_night: DayNight
## Çalışma anında oluşan ve kayıtla saklanan nesneler (yerdeki eşyalar, yapılar).
var dynamic_root: Node3D
var spawn_point := Vector3.ZERO


func _ready() -> void:
	GameState.world = self
	var save := GameState.pending_load
	var seed_value := int(save.get("seed", 0)) if not save.is_empty() else GameState.new_game_seed
	if seed_value == 0:
		seed_value = randi_range(1, 2_000_000_000)
	var started := Time.get_ticks_msec()
	gen = WorldGen.new(seed_value)
	spawn_point = gen.find_spawn()

	terrain = IslandTerrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(gen)

	trees = TreeField.new()
	trees.name = "Trees"
	add_child(trees)
	trees.build(gen, spawn_point)

	vegetation = VegetationSpawner.new()
	vegetation.name = "Vegetation"
	add_child(vegetation)
	vegetation.build(gen, spawn_point)

	resources = ResourceSpawner.new()
	resources.name = "Resources"
	add_child(resources)
	resources.build(gen, spawn_point)

	dynamic_root = Node3D.new()
	dynamic_root.name = "Dynamic"
	add_child(dynamic_root)
	_build_camp_props()

	animals = AnimalSpawner.new()
	animals.name = "Animals"
	add_child(animals)
	animals.setup(gen)

	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.water_mat = _add_water()

	if save.is_empty():
		TimeOfDay.reset()
		var to_lake := Vector3(gen.lake_center.x, 0, gen.lake_center.y) - spawn_point
		player.teleport(spawn_point + Vector3.UP * 0.2, rad_to_deg(atan2(-to_lake.x, -to_lake.z)))
		_spawn_camp_loot()
		animals.populate(spawn_point)
	else:
		_apply_save(save)
		GameState.pending_load = {}
	print("Dünya hazır: tohum %d, %d ağaç, %d ms" % [seed_value, trees.count(), Time.get_ticks_msec() - started])

	TimeOfDay.running = true
	var debug := get_node_or_null("/root/DebugCapture")
	if debug:
		debug.on_world_ready(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save") and not player.stats.dead:
		if GameState.save_game():
			player.notify(tr("Oyun kaydedildi."))


func _exit_tree() -> void:
	TimeOfDay.running = false
	if GameState.world == self:
		GameState.world = null


# --- Kayıt ve yükleme ---

func collect_save() -> Dictionary:
	var dynamic := []
	for node in get_tree().get_nodes_in_group("persist_dynamic"):
		if node.is_queued_for_deletion() or not node.has_method("save_state"):
			continue
		dynamic.append(node.save_state())
	return {
		"seed": gen.seed_value,
		"time": TimeOfDay.to_dict(),
		"player": player.save_state(),
		"trees": trees.felled_ids(),
		"resources": resources.save_state(),
		"dynamic": dynamic,
	}


func _apply_save(save: Dictionary) -> void:
	TimeOfDay.from_dict(save.get("time", {}))
	player.load_state(save.get("player", {}))
	trees.apply_felled(save.get("trees", []))
	resources.load_state(save.get("resources", {}))
	for entry in save.get("dynamic", []):
		if not entry is Dictionary:
			continue
		var pos := GameState.arr_to_vec3(entry.get("pos"))
		var yaw := float(entry.get("yaw", 0.0))
		match str(entry.get("type", "")):
			"pickup":
				spawn_pickup(str(entry.id), int(entry.count), pos, float(entry.get("dur", -1.0)), yaw)
			"build":
				var recipe := ItemDB.get_recipe(str(entry.get("recipe", "")))
				if recipe:
					BuildSystem.spawn(recipe, Transform3D(Basis(Vector3.UP, yaw), pos), entry)
			"animal":
				animals.restore(entry)
	player.notify(tr("Kayıt yüklendi: %d. gün") % TimeOfDay.day)


# --- Uyku ---

func is_sleep_time() -> bool:
	return TimeOfDay.hour >= Balance.d.sleep_from_hour or TimeOfDay.hour < TimeOfDay.DAWN


## Uyumayı engelleyen durum varsa açıklaması, yoksa boş metin.
func sleep_block_reason(p: Player) -> String:
	if p.stats.hunger < 15.0:
		return tr("Uyuyamayacak kadar açsın.")
	if p.stats.thirst < 15.0:
		return tr("Uyuyamayacak kadar susadın.")
	for threat in get_tree().get_nodes_in_group("hostile"):
		if threat.has_method("is_threat") and threat.is_threat() \
				and threat.global_position.distance_to(p.global_position) < Balance.d.sleep_danger_radius:
			return tr("Yakında tehlike var, uyuyamazsın!")
	return ""


func sleep_until_morning() -> void:
	if player.input_locked or not is_sleep_time() or sleep_block_reason(player) != "":
		return
	player.input_locked = true
	var hud := get_node_or_null("HUD")
	if hud:
		await hud.fade_to(1.0, 1.2).finished
	var secs := TimeOfDay.real_seconds_until(TimeOfDay.DAWN)
	TimeOfDay.skip_to(TimeOfDay.DAWN)
	for fire in get_tree().get_nodes_in_group("fire"):
		fire.skip_time(secs)
	animals.on_morning_skip()
	var b := Balance.d
	var s := player.stats
	s.hunger = maxf(0.0, s.hunger - b.sleep_hunger_cost)
	s.thirst = maxf(0.0, s.thirst - b.sleep_thirst_cost)
	s.heal(b.sleep_heal)
	s.stamina = SurvivalStats.MAX
	s.warmth = maxf(s.warmth, b.shelter_warmth)
	GameState.save_game()
	await get_tree().create_timer(0.5).timeout
	if hud:
		await hud.fade_to(0.0, 1.2).finished
	player.input_locked = false
	player.notify(tr("%d. gün başladı. Oyun kaydedildi.") % TimeOfDay.day)


func rest_and_save() -> void:
	player.stats.stamina = SurvivalStats.MAX
	if GameState.save_game():
		player.notify(tr("Dinlendin. Oyun kaydedildi."))


func spawn_pickup(id: String, count: int, pos: Vector3, dur := -1.0, yaw := 0.0) -> Pickup:
	var p := Pickup.create(id, count, pos, dur, yaw)
	dynamic_root.add_child(p)
	return p


## Göle göre başlangıcın arkasında kalan terk edilmiş kamp noktası.
func camp_position() -> Vector3:
	var away := spawn_point - Vector3(gen.lake_center.x, spawn_point.y, gen.lake_center.y)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.BACK
	var p := spawn_point + away * 6.0
	return Vector3(p.x, gen.height_at(p.x, p.z), p.z)


## Çadır, ateş çemberi ve sandık: her açılışta aynı yere kurulan dekor.
func _build_camp_props() -> void:
	var camp := camp_position()
	var body := StaticBody3D.new()
	body.name = "Camp"
	body.collision_layer = 1
	add_child(body)
	var face := atan2(spawn_point.x - camp.x, spawn_point.z - camp.z)
	var tent := MeshInstance3D.new()
	tent.mesh = MeshFactory.tent()
	body.add_child(tent)
	tent.global_transform = Transform3D(Basis(Vector3.UP, face), camp + Vector3(0, -0.05, 0))
	var tent_shape := CollisionShape3D.new()
	var tent_box := BoxShape3D.new()
	tent_box.size = Vector3(2.0, 1.4, 2.6)
	tent_shape.shape = tent_box
	body.add_child(tent_shape)
	tent_shape.global_transform = Transform3D(Basis(Vector3.UP, face), camp + Vector3(0, 0.7, 0))

	var side := Vector3(cos(face), 0, -sin(face))
	var ring_pos := camp + Basis(Vector3.UP, face) * Vector3(0, 0, 2.6)
	ring_pos.y = gen.height_at(ring_pos.x, ring_pos.z)
	var ring := MeshInstance3D.new()
	ring.mesh = MeshFactory.stone_ring()
	body.add_child(ring)
	ring.global_position = ring_pos
	var crate_pos := camp + side * 1.9
	crate_pos.y = gen.height_at(crate_pos.x, crate_pos.z)
	var crate := MeshInstance3D.new()
	crate.mesh = MeshFactory.crate()
	body.add_child(crate)
	crate.global_transform = Transform3D(Basis(Vector3.UP, face + 0.3), crate_pos)
	var crate_shape := CollisionShape3D.new()
	var crate_box := BoxShape3D.new()
	crate_box.size = Vector3(0.7, 0.5, 0.5)
	crate_shape.shape = crate_box
	body.add_child(crate_shape)
	crate_shape.global_transform = Transform3D(Basis(Vector3.UP, face + 0.3), crate_pos + Vector3(0, 0.25, 0))


## Yeni oyunda kampta bulunan başlangıç malzemeleri.
func _spawn_camp_loot() -> void:
	var camp := camp_position()
	var face := atan2(spawn_point.x - camp.x, spawn_point.z - camp.z)
	var side := Vector3(cos(face), 0, -sin(face))
	var crate_top := camp + side * 1.9
	crate_top.y = gen.height_at(crate_top.x, crate_top.z) + 0.45
	spawn_pickup("pot", 1, crate_top + side * 0.15)
	spawn_pickup("canteen", 1, crate_top - side * 0.2)
	var ring := camp + Basis(Vector3.UP, face) * Vector3(0, 0, 2.6)
	for i in 3:
		var p := ring + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
		spawn_pickup("stick", 1, Vector3(p.x, gen.height_at(p.x, p.z), p.z), -1.0, randf() * TAU)


func _add_water() -> ShaderMaterial:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400, 1400)
	plane.subdivide_width = 200
	plane.subdivide_depth = 200
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position.y = WorldGen.WATER_LEVEL
	add_child(water)

	# Arazinin bittiği yerden ötesi için düz deniz tabanı; kıyıdan bakınca su derinliği tutarlı kalır.
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(1400, 1400)
	var seabed := MeshInstance3D.new()
	seabed.name = "Seabed"
	seabed.mesh = floor_plane
	seabed.material_override = MeshFactory.flat_material(IslandTerrain.SEABED, 0.0, 1.0)
	seabed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	seabed.position.y = -7.2
	add_child(seabed)
	return mat
