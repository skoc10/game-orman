class_name ResourceSpawner
extends Node3D
## Toplanabilir kaynakları tohuma göre yerleştirir ve toplananların yeniden
## yetişmesini gün değişiminde kontrol eder. Kimlikler tohumdan türetildiği için
## kayıtta yalnızca "hangi kaynak hangi gün toplandı" bilgisi tutulur.

## tür -> adet
const COUNTS := {
	"stick": 380,
	"stone": 300,
	"fiber_plant": 220,
	"bush": 110,
	"mushroom": 60,
	"mushroom_red": 40,
}
## Başlangıç noktasının yakınına mutlaka konan kaynaklar.
const NEAR_SPAWN := {"stick": 10, "stone": 8, "fiber_plant": 6, "bush": 3}

var nodes: Array[ResourceNode] = []
## kaynak kimliği -> toplandığı gün
var harvested := {}


func build(gen: WorldGen, spawn: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = gen.seed_value + 400
	for kind in NEAR_SPAWN:
		var placed := 0
		var tries := 0
		while placed < NEAR_SPAWN[kind] and tries < 300:
			tries += 1
			var a := rng.randf() * TAU
			var r := rng.randf_range(4.0, 22.0)
			var p := Vector2(spawn.x + cos(a) * r, spawn.z + sin(a) * r)
			if gen.is_land(p.x, p.y, 0.8) and gen.slope_at(p.x, p.y) < 0.3:
				_add(gen, kind, p, rng.randf() * TAU)
				placed += 1
	for kind in COUNTS:
		var placed := 0
		var tries := 0
		while placed < COUNTS[kind] and tries < COUNTS[kind] * 40:
			tries += 1
			var p := Vector2(rng.randf_range(-WorldGen.ISLAND_RADIUS, WorldGen.ISLAND_RADIUS), rng.randf_range(-WorldGen.ISLAND_RADIUS, WorldGen.ISLAND_RADIUS))
			var roll := rng.randf()
			var yaw := rng.randf() * TAU
			if not gen.is_land(p.x, p.y, 0.8) or gen.slope_at(p.x, p.y) > 0.32:
				continue
			if roll > _chance(gen, kind, p):
				continue
			_add(gen, kind, p, yaw)
			placed += 1
	TimeOfDay.day_changed.connect(_on_day_changed)


func _chance(gen: WorldGen, kind: String, p: Vector2) -> float:
	var forest := gen.forest_density(p.x, p.y)
	match kind:
		"stick", "mushroom", "mushroom_red":
			return 0.15 + forest * 0.85
		"bush":
			# Orman kenarı: ne çok sık ne tamamen açık.
			return 1.0 - absf(forest - 0.45) * 1.6
		"fiber_plant":
			var near_water := gen.lake_distance(p) < 2.5 or gen.distance_to_stream(p) < 25.0
			return 0.9 if near_water else 0.35 * (1.0 - forest)
	return 0.6


## Mağara gibi arazi dışı yerlere kaynak ekler; kimlik sırası her açılışta aynıdır.
func add_at(kind: String, pos: Vector3, yaw: float) -> void:
	var node := ResourceNode.new()
	node.setup(nodes.size(), kind, Transform3D(Basis(Vector3.UP, yaw), pos))
	node.harvested.connect(_on_harvested)
	add_child(node)
	nodes.append(node)


func _add(gen: WorldGen, kind: String, p: Vector2, yaw: float) -> void:
	var node := ResourceNode.new()
	var pos := Vector3(p.x, gen.height_at(p.x, p.y) - 0.02, p.y)
	node.setup(nodes.size(), kind, Transform3D(Basis(Vector3.UP, yaw), pos))
	node.harvested.connect(_on_harvested)
	add_child(node)
	nodes.append(node)


func _on_harvested(node: ResourceNode) -> void:
	harvested[node.node_id] = TimeOfDay.day


func _on_day_changed(day: int) -> void:
	for id in harvested.keys():
		var node := nodes[int(id)]
		if day - int(harvested[id]) >= node.regrow_days():
			node.set_available(true)
			harvested.erase(id)


func save_state() -> Dictionary:
	var out := {}
	for id in harvested:
		out[str(id)] = harvested[id]
	return out


func load_state(data: Dictionary) -> void:
	harvested.clear()
	for key in data:
		var id := int(key)
		if id >= 0 and id < nodes.size():
			harvested[id] = int(data[key])
			nodes[id].set_available(false)
	_on_day_changed(TimeOfDay.day)
