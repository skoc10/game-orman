class_name AnimalSpawner
extends Node3D
## Hayvanları yerleştirir: geyik ve kurt sürüleri, tavşanlar, ayılar, yılanlar
## ve kuş sürüleri. Geceleri oyuncunun çevresine ek kurt sürüleri gelir; sabah
## uzaktakiler çekilir. Azalan geyik ve tavşanlar yenilenir.

const SPECIES := {
	"deer": preload("res://animals/deer.gd"),
	"wolf": preload("res://animals/wolf.gd"),
	"rabbit": preload("res://animals/rabbit.gd"),
	"bear": preload("res://animals/bear.gd"),
	"snake": preload("res://animals/snake.gd"),
}
const RABBITS := 10
const BEARS := 2
const SNAKES := 12
const SONGBIRD_FLOCKS := 7
const GULL_FLOCKS := 3
const NIGHT_MIN_DIST := 70.0
const NIGHT_MAX_DIST := 110.0

var gen: WorldGen
var rng := RandomNumberGenerator.new()


func setup(p_gen: WorldGen) -> void:
	gen = p_gen
	rng.randomize()
	TimeOfDay.night_started.connect(_on_night)
	TimeOfDay.day_started.connect(_on_morning)
	TimeOfDay.day_changed.connect(_on_new_day)
	add_to_group("night_only_manager")


## Yeni oyunun başlangıç hayvanları.
func populate(spawn: Vector3) -> void:
	var b := Balance.d
	for i in b.deer_herds:
		var p := _random_spot(spawn, 50.0, 400.0, true)
		if p != Vector3.INF:
			spawn_herd(p, rng.randi_range(2, 4))
	for i in b.day_wolf_packs:
		var p := _random_spot(spawn, 120.0, 400.0, false)
		if p != Vector3.INF:
			spawn_pack(p, 2, false)
	for i in RABBITS:
		var p := _random_spot(spawn, 25.0, 400.0, true)
		if p != Vector3.INF:
			spawn_animal("rabbit", p)
	for i in BEARS:
		var p := _forest_spot(spawn, 140.0)
		if p != Vector3.INF:
			spawn_animal("bear", p)
	for i in SNAKES:
		var p := _random_spot(spawn, 35.0, 400.0, false)
		if p != Vector3.INF:
			spawn_animal("snake", p)


## Kuş sürüleri kayda girmez; her açılışta yeniden yerleşir.
func spawn_birds(spawn: Vector3) -> void:
	for i in SONGBIRD_FLOCKS:
		var p := _random_spot(spawn, 20.0, 300.0, true)
		if p != Vector3.INF:
			var flock := BirdFlock.new()
			flock.count = rng.randi_range(3, 6)
			flock.position = p
			add_child(flock)
	for i in GULL_FLOCKS:
		var a := rng.randf() * TAU
		var r := WorldGen.ISLAND_RADIUS * 0.95
		var flock := BirdFlock.new()
		flock.kind = BirdFlock.Kind.GULL
		flock.count = rng.randi_range(2, 4)
		flock.position = Vector3(cos(a) * r, 0, sin(a) * r)
		add_child(flock)


## Sık ormanda, oyuncudan uzak bir nokta (ayı inleri için).
func _forest_spot(around: Vector3, min_d: float) -> Vector3:
	for i in 80:
		var p := _random_spot(around, min_d, 400.0, false)
		if p != Vector3.INF and gen.forest_density(p.x, p.z) > 0.6:
			return p
	return _random_spot(around, min_d, 400.0, false)


func spawn_animal(species: String, pos: Vector3) -> AnimalBase:
	var cls: GDScript = SPECIES.get(species)
	if cls == null:
		return null
	var a: AnimalBase = cls.new()
	a.position = pos
	add_child(a)
	return a


func spawn_herd(center: Vector3, count: int) -> void:
	for i in count:
		var p := center + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5))
		var deer := spawn_animal("deer", _ground(p))
		deer.home = center


func spawn_pack(center: Vector3, count: int, night: bool) -> void:
	var leader: Wolf = null
	for i in count:
		if wolf_count() >= Balance.d.max_wolves:
			return
		var p := center + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
		var wolf := spawn_animal("wolf", _ground(p)) as Wolf
		wolf.home = center
		if leader == null:
			leader = wolf
		else:
			wolf.leader = leader
		if night:
			wolf.add_to_group("night_only")


func wolf_count() -> int:
	return get_tree().get_nodes_in_group("wolf").filter(func(w: Node) -> bool: return w.is_alive() and not w.is_queued_for_deletion()).size()


func deer_count() -> int:
	return get_tree().get_nodes_in_group("deer").filter(func(d: Node) -> bool: return d.is_alive() and not d.is_queued_for_deletion()).size()


## Kayıttan hayvan oluşturur.
func restore(entry: Dictionary) -> void:
	var cls: GDScript = SPECIES.get(str(entry.get("species", "")))
	if cls == null:
		return
	var a: AnimalBase = cls.new()
	a.position = GameState.arr_to_vec3(entry.get("pos"))
	a.rotation.y = float(entry.get("yaw", 0.0))
	if entry.has("stag"):
		a.set_meta("stag", bool(entry.stag))
	a.load_state(entry)
	add_child(a)


func _on_night() -> void:
	var player := _player()
	if player == null:
		return
	for i in Balance.d.night_wolf_packs:
		var p := _random_spot(player.global_position, NIGHT_MIN_DIST, NIGHT_MAX_DIST, false)
		if p != Vector3.INF:
			spawn_pack(p, rng.randi_range(2, 3), true)


## Sabah: uzaktaki gece kurtları çekilir.
func _on_morning() -> void:
	on_morning_skip()


func on_morning_skip() -> void:
	var player := _player()
	for w in get_tree().get_nodes_in_group("night_only"):
		if not w.is_alive():
			continue
		if player == null or w.global_position.distance_to(player.global_position) > 35.0:
			w.queue_free()


func _on_new_day(_day: int) -> void:
	var player := _player()
	if player == null:
		return
	if deer_count() < Balance.d.deer_herds * 2:
		var p := _random_spot(player.global_position, 90.0, 400.0, true)
		if p != Vector3.INF:
			spawn_herd(p, rng.randi_range(2, 4))
	if wolf_count() == 0:
		var p := _random_spot(player.global_position, 120.0, 400.0, false)
		if p != Vector3.INF:
			spawn_pack(p, 2, false)
	if get_tree().get_nodes_in_group("rabbit").size() < RABBITS / 2:
		for i in 3:
			var p := _random_spot(player.global_position, 60.0, 400.0, true)
			if p != Vector3.INF:
				spawn_animal("rabbit", p)


## Oyuncudan min..max uzaklıkta yürünebilir bir nokta; bulunamazsa Vector3.INF.
func _random_spot(around: Vector3, min_d: float, max_d: float, prefer_open: bool) -> Vector3:
	for i in 60:
		var a := rng.randf() * TAU
		var r := rng.randf_range(min_d, max_d)
		var p := Vector2(around.x + cos(a) * r, around.z + sin(a) * r)
		if p.length() > WorldGen.ISLAND_RADIUS * 0.9:
			continue
		if not gen.is_land(p.x, p.y, 0.8) or gen.slope_at(p.x, p.y) > 0.4:
			continue
		if prefer_open and gen.forest_density(p.x, p.y) > 0.55 and i < 40:
			continue
		return _ground(Vector3(p.x, 0, p.y))
	return Vector3.INF


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, gen.height_at(p.x, p.z) + 0.1, p.z)


func _player() -> Player:
	var w := GameState.world
	return w.player if w else null
