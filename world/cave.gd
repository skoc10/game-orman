class_name Cave
extends Node3D
## Adanın altındaki mağara içi. Hücrelerden oluşan bir labirent olarak tohumdan
## üretilir: zemin, tavan ve duvarlar düzensiz kayalarla kaplanır. Girişte gün
## ışığı süzülür; içerisi meşalesiz zifiri karanlıktır.
##
## Türler:
## - DEN: ayı ini. Uç kısımda geniş bir oda, uyuyan ayı ve eski bir erzak.
## - MAZE: labirent. Öbür ucu deniz kıyısındaki ikinci bir ağıza çıkar.
## - SNAKES: küçük mağara, yılanlar ve biraz ganimet.

enum Kind { DEN, MAZE, SNAKES }

const CELL := 5.0
const HEIGHT := 3.4
const WALL := 0.7

const NAMES := {Kind.DEN: "Ayı ini", Kind.MAZE: "Labirent mağara", Kind.SNAKES: "Yılan mağarası"}
const SIZES := {Kind.DEN: Vector2i(4, 4), Kind.MAZE: Vector2i(7, 6), Kind.SNAKES: Vector2i(3, 3)}

var kind: Kind = Kind.MAZE
var cave_seed := 0
var size := Vector2i(4, 4)
## Hücre -> açık kenarlar (0: kuzey/-z, 1: doğu/+x, 2: güney/+z, 3: batı/-x)
var open := {}
var entrance := Vector2i(0, 0)
var far_end := Vector2i(0, 0)
## Mağaranın yüzeydeki ağızları: [giriş, (labirentte) kıyı çıkışı]
var mouths: Array[CaveMouth] = []

var _rng := RandomNumberGenerator.new()
var _rock_xforms: Array[Transform3D] = []
var _body: StaticBody3D


func build(p_kind: Kind, p_seed: int) -> void:
	kind = p_kind
	cave_seed = p_seed
	size = SIZES[kind]
	_rng.seed = p_seed
	add_to_group("cave")
	add_to_group("warmth_source")
	_carve_maze()
	if kind == Kind.DEN:
		_open_chamber()
	_build_geometry()
	_build_lights()


func display_name() -> String:
	return tr(NAMES[kind])


func cell_center(c: Vector2i) -> Vector3:
	return global_position + Vector3(c.x * CELL, 0.05, c.y * CELL)


## Girişteki ve uçtaki hücrede oyuncunun duracağı nokta.
func entrance_point() -> Vector3:
	return cell_center(entrance)


func far_point() -> Vector3:
	return cell_center(far_end)


func contains(p: Vector3) -> bool:
	var local := p - global_position
	return local.y > -2.0 and local.y < HEIGHT + 2.0 \
		and local.x > -CELL and local.x < size.x * CELL \
		and local.z > -CELL and local.z < size.y * CELL


## Mağara içi rüzgarsızdır: geceleri açıktan daha ılık.
func warmth_for(pos: Vector3) -> float:
	return 55.0 if contains(pos) else -1.0


## Rastgele bir iç hücre (girişten uzak olanlar tercih edilir).
func random_cell(min_steps := 2) -> Vector2i:
	for i in 40:
		var c := Vector2i(_rng.randi_range(0, size.x - 1), _rng.randi_range(0, size.y - 1))
		if absi(c.x - entrance.x) + absi(c.y - entrance.y) >= min_steps:
			return c
	return far_end


func rng() -> RandomNumberGenerator:
	return _rng


# --- Labirent ---

func _carve_maze() -> void:
	for x in size.x:
		for y in size.y:
			open[Vector2i(x, y)] = [false, false, false, false]
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var stack: Array[Vector2i] = [entrance]
	var seen := {entrance: true}
	var depth := {entrance: 0}
	far_end = entrance
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var options := []
		for d in 4:
			var n: Vector2i = c + dirs[d]
			if n.x >= 0 and n.y >= 0 and n.x < size.x and n.y < size.y and not seen.has(n):
				options.append(d)
		if options.is_empty():
			stack.pop_back()
			continue
		var d: int = options[_rng.randi() % options.size()]
		var n: Vector2i = c + dirs[d]
		open[c][d] = true
		open[n][(d + 2) % 4] = true
		seen[n] = true
		depth[n] = depth[c] + 1
		if depth[n] > depth[far_end]:
			far_end = n
		stack.push_back(n)
	# Labirent dışındakilerde birkaç ek geçit: tek yollu tünel yerine döngüler.
	if kind != Kind.MAZE:
		for i in size.x * size.y / 3:
			var c := Vector2i(_rng.randi_range(0, size.x - 2), _rng.randi_range(0, size.y - 1))
			open[c][1] = true
			open[c + Vector2i(1, 0)][3] = true


## Ayı ini: en uzak köşede 2x2 hücrelik geniş oda.
func _open_chamber() -> void:
	far_end = Vector2i(size.x - 1, size.y - 1)
	var a := far_end - Vector2i(1, 1)
	for c in [a, a + Vector2i(1, 0), a + Vector2i(0, 1), a + Vector2i(1, 1)]:
		if c.x < size.x - 1:
			open[c][1] = true
			open[c + Vector2i(1, 0)][3] = true
		if c.y < size.y - 1:
			open[c][2] = true
			open[c + Vector2i(0, 1)][0] = true
	# Odaya en az bir yol: komşusuna aç.
	open[a][3] = true
	open[a + Vector2i(-1, 0)][1] = true


# --- Geometri ---

func _build_geometry() -> void:
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	var rock := MeshFactory.flat_material(Color(0.33, 0.31, 0.29), 0.0, 1.0)
	var floor_mat := MeshFactory.flat_material(Color(0.27, 0.24, 0.21), 0.0, 1.0)
	var parts := []
	var half := CELL * 0.5
	for x in size.x:
		for y in size.y:
			var c := Vector2i(x, y)
			var center := Vector3(x * CELL, 0, y * CELL)
			_box(parts, center + Vector3(0, -0.3, 0), Vector3(CELL + 0.1, 0.6, CELL + 0.1), floor_mat)
			var ceil_h := HEIGHT + _rng.randf_range(-0.3, 0.4)
			_box(parts, center + Vector3(0, ceil_h + 0.4, 0), Vector3(CELL + 0.1, 0.8, CELL + 0.1), rock)
			var sides: Array = open[c]
			if not sides[0]:
				_wall(parts, center + Vector3(0, 0, -half), Vector3(CELL + WALL, 0, WALL), rock)
			if not sides[3]:
				_wall(parts, center + Vector3(-half, 0, 0), Vector3(WALL, 0, CELL + WALL), rock)
			if x == size.x - 1 and not sides[1]:
				_wall(parts, center + Vector3(half, 0, 0), Vector3(WALL, 0, CELL + WALL), rock)
			if y == size.y - 1 and not sides[2]:
				_wall(parts, center + Vector3(0, 0, half), Vector3(CELL + WALL, 0, WALL), rock)
			# Köşelerde ve duvar diplerinde düzensiz kayalar, sarkıt ve dikitler.
			for k in 3:
				var a := _rng.randf() * TAU
				var p := center + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.6, 2.2)
				var s := _rng.randf_range(0.4, 0.9)
				_rock_xforms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.5, 1.2), s)), p))
			if _rng.randf() < 0.6:
				var sp := center + Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5))
				var h := _rng.randf_range(0.6, 1.4)
				parts.append([MeshFactory.cylinder(0.0, 0.18, h, 5), Transform3D(Basis(Vector3.RIGHT, PI), sp + Vector3(0, ceil_h - h * 0.5, 0)), rock])
				parts.append([MeshFactory.cylinder(0.0, 0.15, h * 0.6, 5), MeshFactory.at(sp + Vector3(0.3, h * 0.3, 0.2)), rock])
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.combine(parts)
	add_child(mi)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = MeshFactory.rock()
	mm.instance_count = _rock_xforms.size()
	for i in _rock_xforms.size():
		mm.set_instance_transform(i, _rock_xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _wall(parts: Array, pos: Vector3, footprint: Vector3, mat: Material) -> void:
	var tilt := Vector3(_rng.randf_range(-0.05, 0.05), 0, _rng.randf_range(-0.05, 0.05))
	_box(parts, pos + Vector3(0, HEIGHT * 0.5, 0), Vector3(footprint.x, HEIGHT + 1.0, footprint.z), mat, tilt)


func _box(parts: Array, pos: Vector3, box_size: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	parts.append([MeshFactory.box(box_size), MeshFactory.at(pos, rot), mat])
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	shape.transform = MeshFactory.at(pos, rot)
	_body.add_child(shape)


func _build_lights() -> void:
	# Girişten süzülen soluk gün ışığı: içeride yön bulmaya yardım eder.
	for c in ([entrance, far_end] if kind == Kind.MAZE else [entrance]):
		var light := OmniLight3D.new()
		light.light_color = Color(0.75, 0.85, 1.0)
		light.light_energy = 0.9
		light.omni_range = 7.0
		light.position = Vector3(c.x * CELL, HEIGHT - 0.5, c.y * CELL)
		light.set_meta("daylight", true)
		add_child(light)
		var shaft := MeshInstance3D.new()
		shaft.mesh = MeshFactory.cylinder(0.9, 1.4, HEIGHT, 8)
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.85, 0.92, 1.0, 0.045)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		shaft.material_override = mat
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shaft.position = Vector3(c.x * CELL, HEIGHT * 0.5, c.y * CELL)
		add_child(shaft)
	# Ayı ininde ve labirentte ışıldayan mantarların mavi parıltısı.
	if kind != Kind.SNAKES:
		var glow := OmniLight3D.new()
		glow.light_color = Color(0.3, 0.8, 0.9)
		glow.light_energy = 0.6
		glow.omni_range = 6.0
		var c := random_cell(3)
		glow.position = Vector3(c.x * CELL, 0.6, c.y * CELL)
		add_child(glow)


func _process(_delta: float) -> void:
	# Girişteki ışık gece söner.
	var dl := TimeOfDay.daylight()
	for c in get_children():
		if c is OmniLight3D and c.has_meta("daylight"):
			(c as OmniLight3D).light_energy = lerpf(0.1, 0.9, dl)
