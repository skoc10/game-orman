class_name Village
extends Node3D
## Yerli köyü: adanın düz bir açıklığında, başlangıçtan uzakta. Meydanda sönmeyen
## bir ateş, çevresinde çadırlar, kurutma rafları ve bir totem; dolaşan köylüler ve
## takas yapan şef. Misafir çadırında uyunabilir. Kurt ve ayı köye girmez.
## Köy her açılışta tohumdan aynı yere kurulur; kayda yalnızca takas stoğu yazılır.

const RADIUS := 18.0
const TENTS := 5
const VILLAGERS := 4
const NAMES := ["Ayaş", "Kaya", "Tolun", "Ece", "Bora", "Ilgın", "Atak", "Sena"]

var gen: WorldGen
var trading := Trading.new()
var chief: Villager
var fire: Node3D

var _rng := RandomNumberGenerator.new()


## Düz, kuru, sudan ve mağaralardan uzak, başlangıca 70–160 m mesafede bir yer.
static func find_center(p_gen: WorldGen, spawn: Vector3, avoid: Array = []) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_gen.seed_value + 700
	var best := Vector3.INF
	var best_score := INF
	for i in 400:
		var a := rng.randf() * TAU
		var r := rng.randf_range(70.0, 160.0)
		var x := spawn.x + cos(a) * r
		var z := spawn.z + sin(a) * r
		if Vector2(x, z).length() > WorldGen.ISLAND_RADIUS * 0.75:
			continue
		if not p_gen.is_land(x, z, 1.5) or p_gen.slope_at(x, z) > 0.12:
			continue
		if p_gen.lake_distance(Vector2(x, z)) < 2.8 or p_gen.distance_to_stream(Vector2(x, z)) < 22.0:
			continue
		var ok := true
		for p in avoid:
			if Vector2(x - p.x, z - p.z).length() < 45.0:
				ok = false
				break
		var worst_slope := 0.0
		for k in 8:
			var q := Vector2(x, z) + Vector2(cos(k * TAU / 8.0), sin(k * TAU / 8.0)) * RADIUS * 0.8
			worst_slope = maxf(worst_slope, p_gen.slope_at(q.x, q.y))
			if not p_gen.is_land(q.x, q.y, 1.0):
				ok = false
		if not ok or worst_slope > 0.25:
			continue
		var score := worst_slope * 3.0 + p_gen.forest_density(x, z)
		if score < best_score:
			best_score = score
			best = Vector3(x, p_gen.height_at(x, z), z)
	return best


func build(p_gen: WorldGen, center: Vector3) -> void:
	gen = p_gen
	_rng.seed = gen.seed_value + 701
	global_position = center
	add_to_group("village")
	_build_fire()
	_build_tents()
	_build_props()
	_build_villagers()
	_build_sound()
	trading.refresh(gen.seed_value, TimeOfDay.day)
	TimeOfDay.day_changed.connect(func(d: int) -> void: trading.refresh(gen.seed_value, d))


func contains(p: Vector3) -> bool:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length() < RADIUS


func ground(p: Vector3) -> Vector3:
	return Vector3(p.x, gen.height_at(p.x, p.z), p.z)


## Halkadaki k. yerin konumu ve merkeze bakan yönü.
func ring_point(k: int, count: int, radius: float, offset := 0.3) -> Vector3:
	var a := TAU * k / count + offset
	return ground(global_position + Vector3(cos(a), 0, sin(a)) * radius)


func save_state() -> Dictionary:
	return {"trade": trading.to_dict()}


func load_state(d: Dictionary) -> void:
	trading.from_dict(d.get("trade", {}), gen.seed_value)
	trading.refresh(gen.seed_value, TimeOfDay.day)


func _build_fire() -> void:
	fire = (load("res://buildables/campfire.tscn") as PackedScene).instantiate()
	fire.eternal = true
	add_child(fire)
	fire.global_position = ground(global_position)
	fire.scale = Vector3.ONE * 1.4
	# Köy ateşi kayda girmez; her açılışta yeniden yanar.
	fire.remove_from_group("persist_dynamic")
	fire.remove_from_group("buildable")
	# Meydanı çevreleyen oturma kütükleri.
	for k in 4:
		var p := ring_point(k, 4, 3.2, 0.785)
		var log := MeshInstance3D.new()
		log.mesh = MeshFactory.log_mesh(1.6, 0.2)
		add_child(log)
		log.global_transform = Transform3D(Basis(Vector3.UP, TAU * k / 4.0 + 0.785 + PI * 0.5), p + Vector3.UP * 0.18)


func _build_tents() -> void:
	for k in TENTS:
		var p := ring_point(k, TENTS, 11.0)
		var to_center := global_position - p
		var tent := VillageTent.new()
		tent.guest = k == 1
		tent.chief = k == 0
		tent.size_scale = 1.3 if k == 0 else _rng.randf_range(0.9, 1.1)
		tent.color = [Color(0.82, 0.72, 0.55), Color(0.72, 0.6, 0.45), Color(0.86, 0.78, 0.62)][k % 3]
		add_child(tent)
		tent.global_transform = Transform3D(Basis(Vector3.UP, atan2(to_center.x, to_center.z)), p)


func _build_props() -> void:
	var wood := MeshFactory.flat_material(MeshFactory.BARK.lightened(0.15))
	var paint := [MeshFactory.flat_material(Color(0.75, 0.2, 0.15)), MeshFactory.flat_material(Color(0.2, 0.45, 0.6)), MeshFactory.flat_material(Color(0.9, 0.85, 0.75))]
	# Totem: üst üste boyalı bloklar ve kanatlar.
	var tp := ring_point(0, 1, 6.0, 2.2)
	var parts := []
	for i in 4:
		parts.append([MeshFactory.cylinder(0.32, 0.36, 0.7, 8), MeshFactory.at(Vector3(0, 0.35 + i * 0.7, 0)), paint[i % 3] if i % 2 == 1 else wood])
	parts.append([MeshFactory.box(Vector3(1.8, 0.12, 0.3)), MeshFactory.at(Vector3(0, 2.6, 0)), paint[0]])
	parts.append([MeshFactory.cylinder(0.0, 0.3, 0.4, 6), MeshFactory.at(Vector3(0, 3.0, 0)), paint[2]])
	_static_prop(parts, tp, 0.4, 3.2)
	# Balık ve et kurutma rafları.
	for k in 2:
		var rp := ring_point(k, 2, 7.0, 1.2)
		var rack := []
		for side in [-0.9, 0.9]:
			rack.append([MeshFactory.cylinder(0.04, 0.05, 1.6, 5), MeshFactory.at(Vector3(side, 0.8, 0)), wood])
		rack.append([MeshFactory.cylinder(0.035, 0.035, 2.0, 5), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 1.5, 0)), wood])
		for f in 4:
			rack.append([MeshFactory.fish_mesh(Color(0.6, 0.5, 0.35), 0.3), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(-0.6 + f * 0.4, 1.3, 0)), MeshFactory.flat_material(Color.WHITE)])
		_static_prop(rack, rp, 0.3, 1.6)


func _static_prop(parts: Array, pos: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	body.global_position = pos
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.combine(parts)
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	shape.position.y = height * 0.5
	body.add_child(shape)


func _build_villagers() -> void:
	var names := NAMES.duplicate()
	for i in range(names.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: String = names[i]
		names[i] = names[j]
		names[j] = tmp
	var animals: Node = GameState.world.animals if GameState.world else self
	# Şef kendi çadırının önünde durur.
	var chief_pos := ring_point(0, TENTS, 8.5)
	chief = Villager.new()
	chief.is_chief = true
	chief.village = self
	chief.display_name = names[0]
	chief.position = chief_pos + Vector3.UP * 0.1
	animals.add_child(chief)
	chief.home = chief_pos
	for i in VILLAGERS:
		var v := Villager.new()
		v.village = self
		v.display_name = names[i + 1]
		var p := ring_point(i, VILLAGERS, _rng.randf_range(4.5, 8.0), 1.0)
		v.position = p + Vector3.UP * 0.1
		animals.add_child(v)
		v.home = global_position


func _build_sound() -> void:
	# Uzaktan duyulan davul: köyü sesinden bulmak mümkün.
	var drums := Sfx.attach_loop("drum_loop", self, -2.0, 150.0)
	if drums:
		drums.unit_size = 14.0
		drums.position.y = 2.0
		drums.play()
