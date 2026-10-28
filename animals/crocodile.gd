class_name Crocodile
extends AnimalBase
## Timsah: gölde yalnızca gözleri ve sırtı sudan çıkacak şekilde yüzer, sıcak
## saatlerde kıyıda güneşlenir. Oyuncu suya girer ya da su kenarına gelirse sinsice
## yaklaşır ve tıslar; birkaç metreye gelince atılıp ağır ısırır. Sudan uzaklaşmaz:
## kıyıdan birkaç metre geri çekilen kurtulur. Ağır yaralanınca derine kaçar.

const NOTICE := 14.0
const LUNGE_RANGE := 4.5
const BITE_RANGE := 2.6
const BITE_DAMAGE := 24.0
## Oyuncu suya bu kadar yakınsa (m) av sayılır.
const PREY_SHORE := 2.5
## Timsah gölün kıyı çizgisinden en fazla bu orana kadar karaya çıkar.
const MAX_LAKE_DIST := 1.35
const SWIM_DEPTH := 0.32

var _bite_cd := 0.0
var _lunge_left := 0.0


func _init() -> void:
	species = "crocodile"
	display_name = "Timsah"
	max_health = 120.0
	walk_speed = 1.4
	run_speed = 9.0
	drops = {"meat_raw": 4, "hide": 2}
	wander_radius = 18.0
	bound_height = 0.0


func _ready() -> void:
	super._ready()
	add_to_group("crocodile")
	if is_alive():
		add_to_group("hostile")


func is_threat() -> bool:
	return is_alive() and state in [State.STALK, State.CHASE, State.ATTACK]


func think(delta: float, player: Player, dist: float) -> void:
	_bite_cd -= delta
	if state != State.RETREAT and health < max_health * 0.3:
		set_state(State.RETREAT)
		_target = _deep_point()
	if player == null or player.stats.dead:
		if state != State.RETREAT:
			_idle_behaviour(delta)
		return
	var prey := _is_prey(player)
	match state:
		State.IDLE, State.WANDER:
			if prey and dist < NOTICE:
				_vocal_cd = 0.0
				vocal("croc_hiss", 3.0, 6.0, 40.0)
				set_state(State.STALK)
			else:
				_idle_behaviour(delta)
		State.STALK:
			# Sinsice, yavaş yaklaşır; arada tıslar.
			move_to(player.global_position, walk_speed * 1.4)
			face(player.global_position, delta)
			vocal("croc_hiss", 4.0, 5.0, 40.0)
			if not prey or dist > NOTICE * 1.4:
				set_state(State.WANDER)
			elif dist < LUNGE_RANGE:
				_lunge_left = 1.2
				set_state(State.CHASE)
		State.CHASE:
			_lunge_left -= delta
			move_to(player.global_position, run_speed)
			face(player.global_position, delta)
			if dist < BITE_RANGE:
				set_state(State.ATTACK)
			elif _lunge_left <= 0.0:
				set_state(State.STALK if prey else State.WANDER)
		State.ATTACK:
			stop()
			face(player.global_position, delta)
			if dist > BITE_RANGE + 1.0:
				set_state(State.STALK if prey else State.WANDER)
			elif _bite_cd <= 0.0:
				_bite(player)
		State.RETREAT:
			move_to(_target, walk_speed * 2.5)
			health = minf(max_health, health + delta * 0.4)
			if _state_time > 15.0:
				set_state(State.WANDER)
		_:
			_idle_behaviour(delta)


## Avın suda ya da su kenarında olup olmadığı.
func _is_prey(player: Player) -> bool:
	var gen := _gen()
	if gen == null:
		return false
	var p := player.global_position
	if player.is_swimming or gen.height_at(p.x, p.z) < WorldGen.WATER_LEVEL + 0.2:
		return gen.lake_distance(Vector2(p.x, p.z)) < 1.6
	# Kıyıda: birkaç metre içinde su var mı?
	for a in 8:
		var d := Vector3(cos(a * TAU / 8.0), 0, sin(a * TAU / 8.0)) * PREY_SHORE
		var q := p + d
		if gen.height_at(q.x, q.z) < WorldGen.WATER_LEVEL and gen.lake_distance(Vector2(q.x, q.z)) < 1.4:
			return true
	return false


## Gündüz sıcak saatlerde kıyıda güneşlenir, diğer zamanlarda gölde yüzer.
func _idle_behaviour(delta: float) -> void:
	var basking := TimeOfDay.hour > 11.0 and TimeOfDay.hour < 16.0
	if basking and state == State.IDLE and _state_time < 1.0:
		_target = _shore_point()
	wander(delta)


func _bite(player: Player) -> void:
	_bite_cd = 2.0
	player.take_damage(BITE_DAMAGE, "timsah")
	Sfx.play_at("bite", global_position + Vector3.UP * 0.4, 4.0, 30.0)
	_vocal_cd = 0.0
	vocal("croc_hiss", 2.0, 6.0, 40.0)
	var tw := create_tween()
	tw.tween_property(model, "position:z", -0.4, 0.08)
	tw.tween_property(model, "position:z", 0.0, 0.25)
	# Isırdıktan sonra çoğu zaman suya geri çekilip yeniden pusuya yatar.
	if rng.randf() < 0.5:
		set_state(State.WANDER)
		_target = _deep_point()


func on_hurt(_attacker: Node3D) -> void:
	if state in [State.IDLE, State.WANDER, State.STALK]:
		_lunge_left = 1.5
		set_state(State.CHASE)


func _pick_wander_target() -> void:
	var gen := _gen()
	if gen == null:
		_target = home
		return
	for i in 20:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.0, gen.lake_radius * 0.9)
		var p := gen.lake_center + Vector2(cos(a), sin(a)) * r
		if gen.height_at(p.x, p.y) < WorldGen.WATER_LEVEL - 0.5:
			_target = Vector3(p.x, 0, p.y)
			return
	_target = Vector3(gen.lake_center.x, 0, gen.lake_center.y)


func _deep_point() -> Vector3:
	var gen := _gen()
	return Vector3(gen.lake_center.x, 0, gen.lake_center.y) if gen else home


func _shore_point() -> Vector3:
	var gen := _gen()
	if gen == null:
		return home
	var dir := Vector2(global_position.x, global_position.z) - gen.lake_center
	dir = dir.normalized() if dir.length() > 0.1 else Vector2.RIGHT
	for i in 60:
		var p := gen.lake_center + dir * gen.lake_radius * (0.8 + i * 0.03)
		if gen.height_at(p.x, p.y) > WorldGen.WATER_LEVEL + 0.15:
			return Vector3(p.x, 0, p.y)
	return home


## Göl ve kıyısının dışına çıkmaz.
func _walkable(p: Vector3) -> bool:
	var gen := _gen()
	if gen == null:
		return true
	return gen.lake_distance(Vector2(p.x, p.z)) < MAX_LAKE_DIST and gen.slope_at(p.x, p.z) < 0.45


## Fizik yerine arazi ve su yüzeyine yapışarak hareket: suda yüzer, karada sürünür.
func _apply_movement(delta: float) -> void:
	var gen := _gen()
	if gen == null:
		super._apply_movement(delta)
		return
	var desired := _move_dir * _speed
	if _speed > 0.1 and not _walkable(global_position + _move_dir * 1.5):
		desired = Vector3.ZERO
		on_blocked()
	velocity.x = lerpf(velocity.x, desired.x, clampf(delta * 4.0, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, desired.z, clampf(delta * 4.0, 0.0, 1.0))
	var next := global_position + Vector3(velocity.x, 0, velocity.z) * delta
	var ground := gen.height_at(next.x, next.z)
	var y := WorldGen.WATER_LEVEL - SWIM_DEPTH if ground < WorldGen.WATER_LEVEL - SWIM_DEPTH - 0.1 else ground
	global_position = Vector3(next.x, lerpf(global_position.y, y, clampf(delta * 6.0, 0.0, 1.0)), next.z)
	if Vector2(velocity.x, velocity.z).length() > 0.3:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), clampf(delta * 5.0, 0.0, 1.0))


func _far_update(_delta: float) -> void:
	pass


func in_water() -> bool:
	var gen := _gen()
	return gen != null and gen.height_at(global_position.x, global_position.z) < WorldGen.WATER_LEVEL - SWIM_DEPTH - 0.1


func _animate(delta: float) -> void:
	super._animate(delta)
	if _tail:
		var speed := Vector2(velocity.x, velocity.z).length()
		_tail.rotation.y = sin(_anim_t * 1.5) * (0.15 + clampf(speed / 4.0, 0.0, 1.0) * 0.35)
	if model:
		model.position.y = 0.0
		model.rotation.x = 0.0


func _build_shape() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 2.6
	shape.shape = capsule
	shape.rotation.x = PI * 0.5
	shape.position.y = 0.25
	add_child(shape)


func _build_model() -> Node3D:
	var root := Node3D.new()
	var skin := Color(0.25, 0.3, 0.17).lerp(Color(0.3, 0.32, 0.2), rng.randf())
	var belly := Color(0.62, 0.6, 0.42)
	var dark := skin.darkened(0.35)
	# Yassı, uzun gövde ve sırt pulları.
	_blob(root, Vector3(0, 0.22, 0.0), Vector3(0.62, 0.28, 1.4), skin)
	_blob(root, Vector3(0, 0.14, 0.0), Vector3(0.5, 0.14, 1.3), belly)
	for i in 6:
		_blob(root, Vector3(0, 0.36, -0.55 + i * 0.22), Vector3(0.12, 0.06, 0.12), dark)
	# Uzun, yassı çene; çıkık gözler.
	_head = Node3D.new()
	_head.position = Vector3(0, 0.24, -0.72)
	root.add_child(_head)
	_blob(_head, Vector3(0, 0.0, -0.12), Vector3(0.42, 0.22, 0.36), skin)
	_seg(_head, Vector3(0, 0.0, -0.25), Vector3(0, -0.02, -0.85), 0.14, 0.07, skin)
	_blob(_head, Vector3(0, -0.06, -0.55), Vector3(0.22, 0.06, 0.6), belly)
	for side in [-1.0, 1.0]:
		_blob(_head, Vector3(0.11 * side, 0.12, -0.18), Vector3(0.09, 0.08, 0.09), skin)
		_blob(_head, Vector3(0.12 * side, 0.15, -0.21), Vector3(0.04, 0.035, 0.03), Color(0.85, 0.7, 0.15))
	# Uzun, sivrilen kuyruk.
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.2, 0.68)
	root.add_child(_tail)
	_seg(_tail, Vector3.ZERO, Vector3(0, -0.02, 0.6), 0.22, 0.14, skin)
	_seg(_tail, Vector3(0, -0.02, 0.6), Vector3(0, -0.04, 1.25), 0.14, 0.03, skin)
	# Yana açılan kısa bacaklar.
	for side in [-1.0, 1.0]:
		_leg2(root, Vector3(0.28 * side, 0.18, -0.42), 0.12, 0.12, 0.05, skin, dark, true)
	for side in [-1.0, 1.0]:
		_leg2(root, Vector3(0.28 * side, 0.18, 0.4), 0.12, 0.12, 0.055, skin, dark, false)
	for leg in _legs:
		leg.rotation.z = 0.7 * signf(leg.position.x)
	return root
