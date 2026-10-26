class_name CaveSystem
extends Node3D
## Adadaki mağaraları kurar: yamaçlardaki ağızlar, adanın altındaki iç kısımlar
## ve labirent mağaranın deniz kıyısındaki ikinci ağzı. Ağız yerleri tohumdan
## gelir; içerideki hayvan ve erzak yalnızca yeni oyunda yerleşir (sonra kayıtla gelir).

const DEPTH := -80.0
const LOOT := ["rope", "bandage", "knife", "canteen", "hide", "torch", "hide_clothes", "fishing_rod"]

var caves: Array[Cave] = []
var gen: WorldGen
var _rng := RandomNumberGenerator.new()


func build(p_gen: WorldGen, spawn: Vector3, resources: ResourceSpawner) -> void:
	gen = p_gen
	_rng.seed = gen.seed_value + 600
	var used: Array[Vector3] = [spawn]
	var kinds := [Cave.Kind.DEN, Cave.Kind.MAZE, Cave.Kind.SNAKES]
	for i in kinds.size():
		var mouth := _hill_spot(used)
		if mouth.is_empty():
			continue
		used.append(mouth.pos)
		var cave := Cave.new()
		cave.name = "Cave_%d" % i
		add_child(cave)
		cave.position = Vector3(mouth.pos.x, DEPTH - i * 25.0, mouth.pos.z)
		cave.build(kinds[i], gen.seed_value + 600 + i)
		_link(cave, mouth.pos, mouth.uphill, cave.entrance, "")
		if cave.kind == Cave.Kind.MAZE:
			var coast := _coast_spot(used)
			if not coast.is_empty():
				used.append(coast.pos)
				_link(cave, coast.pos, coast.uphill, cave.far_end, tr("Kıyıya çık"))
		# Işıldayan mağara mantarları toplanabilir kaynaktır.
		for k in 3:
			var c := cave.random_cell(1)
			var p := cave.cell_center(c) + Vector3(cave.rng().randf_range(-1.5, 1.5), 0, cave.rng().randf_range(-1.5, 1.5))
			resources.add_at("mushroom", p, cave.rng().randf() * TAU)
		caves.append(cave)


## Yeni oyunda mağaralara hayvan ve erzak koyar.
func populate(animals: AnimalSpawner, world: Node) -> void:
	for cave in caves:
		var rng := cave.rng()
		match cave.kind:
			Cave.Kind.DEN:
				var center := cave.cell_center(cave.far_end) - Vector3(Cave.CELL * 0.5, 0, Cave.CELL * 0.5)
				var bear := _indoor_animal(animals, "bear", center) as Bear
				bear.sleeping = true
				_loot_pile(world, rng, center + Vector3(2.0, 0, 1.5), 4)
			Cave.Kind.MAZE:
				for i in 2:
					_indoor_animal(animals, "snake", cave.cell_center(cave.random_cell(3)))
				for i in 2:
					_loot_pile(world, rng, cave.cell_center(cave.random_cell(4)), 2)
			Cave.Kind.SNAKES:
				for i in 3:
					_indoor_animal(animals, "snake", cave.cell_center(cave.random_cell(1)) + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)))
				_loot_pile(world, rng, cave.cell_center(cave.far_end), 2)
				world.spawn_pickup("stone", 4, cave.cell_center(cave.random_cell(1)) + Vector3(1, 0, 0))


func cave_at(p: Vector3) -> Cave:
	for c in caves:
		if c.contains(p):
			return c
	return null


func mouths() -> Array:
	return get_tree().get_nodes_in_group("cave_mouth").filter(func(m: CaveMouth) -> bool: return m.outside)


func _indoor_animal(animals: AnimalSpawner, species: String, pos: Vector3) -> AnimalBase:
	var a := animals.spawn_animal(species, pos + Vector3.UP * 0.2)
	a.indoor = true
	a.home = pos
	a.wander_radius = 4.0
	return a


func _loot_pile(world: Node, rng: RandomNumberGenerator, pos: Vector3, n: int) -> void:
	for i in n:
		var id: String = LOOT[rng.randi() % LOOT.size()]
		var count := 2 if id in ["rope", "hide", "bandage"] else 1
		world.spawn_pickup(id, count, pos + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)), -1.0, rng.randf() * TAU)


## Yüzeydeki ağzı ve içerideki eşini kurar, birbirine bağlar.
func _link(cave: Cave, surface: Vector3, uphill: Vector3, cell: Vector2i, inside_label: String) -> void:
	var yaw := atan2(uphill.x, uphill.z)
	var outer := CaveMouth.new()
	outer.cave = cave
	outer.outside = true
	if inside_label != "":
		outer.label = tr("%s (kıyı ağzı): içeri gir") % cave.display_name()
	add_child(outer)
	outer.global_transform = Transform3D(Basis(Vector3.UP, yaw), surface - Vector3.UP * 0.3)
	var inner := CaveMouth.new()
	inner.cave = cave
	inner.outside = false
	inner.label = inside_label
	add_child(inner)
	inner.global_position = cave.cell_center(cell)
	# Ağzın önüne çıkılır, yokuş aşağı bakılır.
	var front := surface - uphill * 3.2
	front.y = gen.height_at(front.x, front.z) + 0.1
	inner.target = front
	inner.target_yaw = rad_to_deg(yaw)
	outer.target = cave.cell_center(cell) + Vector3(1.6, 0.1, 1.6)
	outer.target_yaw = rad_to_deg(yaw)


func _uphill(x: float, z: float) -> Vector3:
	var n := gen.normal_at(x, z)
	var u := Vector3(-n.x, 0, -n.z)
	return u.normalized() if u.length() > 0.001 else Vector3.FORWARD


func _far_from(p: Vector3, used: Array[Vector3], dist: float) -> bool:
	for u in used:
		if Vector2(p.x - u.x, p.z - u.z).length() < dist:
			return false
	return true


## Yamaçta, ağzın önü yürünebilir olan bir yer.
func _hill_spot(used: Array[Vector3]) -> Dictionary:
	for i in 600:
		var x := _rng.randf_range(-WorldGen.ISLAND_RADIUS * 0.75, WorldGen.ISLAND_RADIUS * 0.75)
		var z := _rng.randf_range(-WorldGen.ISLAND_RADIUS * 0.75, WorldGen.ISLAND_RADIUS * 0.75)
		var h := gen.height_at(x, z)
		var slope := gen.slope_at(x, z)
		# Oyuncunun tırmanabileceği (50° altı) ama belirgin bir yamaç.
		if h < 5.0 or slope < 0.08 or slope > 0.28:
			continue
		var p := Vector3(x, h, z)
		if not _far_from(p, used, 70.0) or gen.distance_to_stream(Vector2(x, z)) < 15.0:
			continue
		var u := _uphill(x, z)
		var front := p - u * 3.2
		if not gen.is_land(front.x, front.z, 1.0) or gen.slope_at(front.x, front.z) > 0.3 \
				or gen.slope_at(p.x - u.x * 8.0, p.z - u.z * 8.0) > 0.32:
			continue
		return {"pos": p, "uphill": u}
	return {}


## Kıyıda, denize bakan alçak bir yer.
func _coast_spot(used: Array[Vector3]) -> Dictionary:
	for i in 600:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(WorldGen.ISLAND_RADIUS * 0.7, WorldGen.ISLAND_RADIUS * 0.95)
		var x := cos(a) * r
		var z := sin(a) * r
		var h := gen.height_at(x, z)
		if h < 1.4 or h > 4.0 or gen.slope_at(x, z) > 0.35 or gen.is_fresh_water(x, z):
			continue
		var p := Vector3(x, h, z)
		if not _far_from(p, used, 60.0):
			continue
		# Ağzın arkası adanın içine, önü denize baksın.
		var inland := -Vector3(x, 0, z).normalized()
		var front := p - inland * 3.2
		if gen.height_at(front.x, front.z) < 0.3:
			continue
		return {"pos": p, "uphill": inland}
	return {}
