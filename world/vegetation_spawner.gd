class_name VegetationSpawner
extends Node3D
## Çimen öbekleri ve büyük kayalar. Çimen yalnızca görseldir; kayaların
## çarpışması vardır ama toplanamaz.

const GRASS_SPACING := 2.0
const GRASS_VIEW := 55.0
const ROCK_COUNT := 160

var _rock_body: StaticBody3D


func build(gen: WorldGen, spawn: Vector3) -> void:
	_build_grass(gen)
	_build_rocks(gen, spawn)


func _build_grass(gen: WorldGen) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = gen.seed_value + 200
	var groups := {}
	var spacing := GRASS_SPACING * (1.5 if GameState.low_quality() else 1.0)
	var n := int(WorldGen.SIZE / spacing)
	for gz in n:
		for gx in n:
			var x := -WorldGen.HALF + (gx + rng.randf()) * spacing
			var z := -WorldGen.HALF + (gz + rng.randf()) * spacing
			var roll := rng.randf()
			var s := rng.randf_range(0.7, 1.4)
			var yaw := rng.randf() * TAU
			var shade := rng.randf_range(0.8, 1.15)
			var h := gen.height_at(x, z)
			if h < 1.2 or gen.slope_at(x, z) > 0.25:
				continue
			# Ormanın içi daha seyrek, açıklıklar daha gür.
			var chance := lerpf(0.75, 0.3, gen.forest_density(x, z)) * (0.6 + gen.tint_at(x, z) * 0.6)
			if roll > chance:
				continue
			var key := TreeField.chunk_index(Vector3(x, 0, z))
			if not groups.has(key):
				groups[key] = []
			groups[key].append([Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), Vector3(x, h - 0.05, z)), shade])

	var mesh := MeshFactory.grass_tuft()
	for key in groups:
		var items: Array = groups[key]
		var center := TreeField.chunk_center(key)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = items.size()
		for i in items.size():
			var t: Transform3D = items[i][0]
			t.origin -= center
			mm.set_instance_transform(i, t)
			var sh: float = items[i][1]
			mm.set_instance_color(i, Color(sh, sh, sh))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.position = center
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = GRASS_VIEW * (0.6 if GameState.low_quality() else 1.0)
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)


func _build_rocks(gen: WorldGen, spawn: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = gen.seed_value + 300
	_rock_body = StaticBody3D.new()
	_rock_body.name = "Rocks"
	_rock_body.collision_layer = 1
	_rock_body.collision_mask = 0
	# Büyük kayalar baltayla kırılıp taş verir (Equipment._strike).
	_rock_body.set_meta("rock", true)
	add_child(_rock_body)
	var groups := {}
	var placed := 0
	var attempts := 0
	while placed < ROCK_COUNT and attempts < ROCK_COUNT * 20:
		attempts += 1
		var x := rng.randf_range(-WorldGen.ISLAND_RADIUS, WorldGen.ISLAND_RADIUS)
		var z := rng.randf_range(-WorldGen.ISLAND_RADIUS, WorldGen.ISLAND_RADIUS)
		var s := rng.randf_range(0.5, 2.2)
		var squash := Vector3(rng.randf_range(0.8, 1.4), rng.randf_range(0.5, 0.9), rng.randf_range(0.8, 1.4))
		var yaw := rng.randf() * TAU
		if not gen.is_land(x, z, 0.8):
			continue
		if Vector2(x - spawn.x, z - spawn.z).length() < 8.0:
			continue
		# Kayalar eğimli yamaçlarda daha sık.
		if rng.randf() > 0.25 + gen.slope_at(x, z) * 2.0:
			continue
		var pos := Vector3(x, gen.height_at(x, z) - 0.25 * s, z)
		var key := TreeField.chunk_index(pos)
		if not groups.has(key):
			groups[key] = []
		groups[key].append(Transform3D(Basis(Vector3.UP, yaw).scaled(squash * s), pos))
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = s * 0.85
		shape.shape = sphere
		shape.position = pos
		_rock_body.add_child(shape)
		placed += 1

	var mesh := MeshFactory.rock()
	for key in groups:
		var items: Array = groups[key]
		var center := TreeField.chunk_center(key)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = items.size()
		for i in items.size():
			var t: Transform3D = items[i]
			t.origin -= center
			mm.set_instance_transform(i, t)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.position = center
		mmi.visibility_range_end = TreeField.view_distance()
		add_child(mmi)
