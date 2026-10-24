extends Node3D
## Oyun dünyası: tohumdan adayı üretir, suyu, bitki örtüsünü ve gece/gündüzü
## kurar, oyuncuyu başlangıç noktasına yerleştirir.

const WATER_SHADER := preload("res://world/water.gdshader")

@onready var player: Player = $Player

var gen: WorldGen
var terrain: IslandTerrain
var trees: TreeField
var vegetation: VegetationSpawner
var day_night: DayNight
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

	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.water_mat = _add_water()

	if save.is_empty():
		TimeOfDay.reset()
		var to_lake := Vector3(gen.lake_center.x, 0, gen.lake_center.y) - spawn_point
		player.teleport(spawn_point + Vector3.UP * 0.2, rad_to_deg(atan2(-to_lake.x, -to_lake.z)))
	print("Dünya hazır: tohum %d, %d ağaç, %d ms" % [seed_value, trees.count(), Time.get_ticks_msec() - started])

	TimeOfDay.running = true
	var debug := get_node_or_null("/root/DebugCapture")
	if debug:
		debug.on_world_ready(self)


func _exit_tree() -> void:
	TimeOfDay.running = false
	if GameState.world == self:
		GameState.world = null


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
