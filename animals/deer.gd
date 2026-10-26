class_name Deer
extends AnimalBase
## Geyik: sürüyle otlar, oyuncuyu fark edince başını kaldırıp bakar, yaklaşılınca
## sekerek kaçar. Kaçarken engellerin etrafından kıvrılır, sürü aynı yöne kaçar;
## yeterince uzaklaşınca durup geriye bakar. Eğilerek yaklaşmak gerekir.

const PERCEPTION := 24.0
const SAFE_DISTANCE := 45.0
const MAX_FLEE_TIME := 12.0

var is_stag := false

var _threat := Vector3.ZERO
var _alert_dist := 0.0
var _flee_dir := Vector3.ZERO
var _phase := 0.0
var _looking_back := false


func _init() -> void:
	species = "deer"
	display_name = "Geyik"
	max_health = 60.0
	walk_speed = 1.6
	run_speed = 8.5
	drops = {"meat_raw": 3, "hide": 1}
	wander_radius = 28.0
	bound_height = 0.3
	graze_angle = -1.15


func _ready() -> void:
	rng.randomize()
	is_stag = bool(get_meta("stag")) if has_meta("stag") else rng.randf() < 0.3
	_phase = rng.randf() * TAU
	super._ready()
	add_to_group("deer")


func think(delta: float, player: Player, dist: float) -> void:
	var notices := player != null and not player.stats.dead and dist < perception_radius(player)
	match state:
		State.IDLE, State.WANDER:
			if notices:
				if dist < perception_radius(player) * 0.5 or player.is_sprinting:
					flee_from(player.global_position)
				else:
					_alert_dist = dist
					_looking_back = false
					set_state(State.ALERT)
				return
			wander(delta)
		State.ALERT:
			stop()
			face(player.global_position if player else _threat, delta)
			var calm_after := 3.5 if _looking_back else 2.5
			if not notices and _state_time > calm_after:
				home = global_position
				_pick_wander_target()
				set_state(State.IDLE)
			elif notices and (dist < perception_radius(player) * 0.5 or player.is_sprinting \
					or (_state_time > 2.0 and dist < _alert_dist - 1.5)):
				flee_from(player.global_position)
		State.FLEE:
			_flee_step(delta, player, dist)
		_:
			wander(delta)


## Kaçış: yönü yavaşça tehditten uzağa çevirir (ani dönüş yok), hafif zikzak
## çizer, başta tam hız sonra tırısa düşer; güvenli mesafede durup geri bakar.
func _flee_step(delta: float, player: Player, dist: float) -> void:
	if player:
		_threat = player.global_position
	var away := global_position - _threat
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else -global_transform.basis.z
	if _flee_dir == Vector3.ZERO:
		_flee_dir = away
	_flee_dir = _flee_dir.slerp(away, clampf(delta * 1.2, 0.0, 1.0)).normalized()
	var wiggle := sin(_state_time * 1.7 + _phase) * 0.4
	_move_dir = _flee_dir.rotated(Vector3.UP, wiggle)
	_speed = run_speed if _state_time < 5.0 else run_speed * 0.55
	if (_state_time > 3.0 and dist > SAFE_DISTANCE) or _state_time > MAX_FLEE_TIME:
		_flee_dir = Vector3.ZERO
		_looking_back = true
		_alert_dist = dist
		set_state(State.ALERT)


## Oyuncuyu hangi mesafeden fark eder: eğilmek kısaltır, koşmak ve gündüz uzatır.
func perception_radius(player: Player) -> float:
	var r := PERCEPTION
	if player.is_crouching:
		r *= 0.4 if not player.is_moving else 0.5
	elif player.is_sprinting:
		r *= 1.5
	if TimeOfDay.is_night():
		r *= 0.7
	return r


func flee_from(pos: Vector3, shared_dir := Vector3.ZERO) -> void:
	_threat = pos
	if shared_dir != Vector3.ZERO:
		_flee_dir = shared_dir.rotated(Vector3.UP, rng.randf_range(-0.3, 0.3))
	if state != State.FLEE:
		if state != State.DEAD:
			Sfx.play_at("deer_alarm", global_position + Vector3.UP, -2.0, 45.0, 0.15)
		set_state(State.FLEE)
	else:
		_state_time = 0.0


func on_hurt(attacker: Node3D) -> void:
	var from := attacker.global_position if attacker else global_position
	flee_from(from)
	# Sürü aynı yöne kaçar.
	var dir := global_position - from
	dir.y = 0.0
	dir = dir.normalized()
	for other in get_tree().get_nodes_in_group("deer"):
		if other != self and other.is_alive() and other.global_position.distance_to(global_position) < 35.0:
			other.flee_from(from, dir)


func model_files() -> Array:
	return ["Stag.gltf", "Stag.glb"] if is_stag else ["Deer.gltf", "Deer.glb"]


func model_height() -> float:
	return 2.1 if is_stag else 1.7


func save_state() -> Dictionary:
	var d := super.save_state()
	d["stag"] = is_stag
	return d


func _build_model() -> Node3D:
	var root := Node3D.new()
	var tint := rng.randf_range(-0.04, 0.04)
	var fur := Color(0.58 + tint, 0.40 + tint, 0.24)
	var dark := fur.darkened(0.35)
	var belly := Color(0.86, 0.77, 0.62)
	var hoof := Color(0.15, 0.12, 0.1)
	# Gövde: göğüs, karın ve sağrı ayrı kaslar; ince bel.
	_blob(root, Vector3(0, 1.0, -0.33), Vector3(0.36, 0.48, 0.6), fur)
	_blob(root, Vector3(0, 0.98, 0.0), Vector3(0.3, 0.4, 0.6), fur)
	_blob(root, Vector3(0, 1.02, 0.38), Vector3(0.34, 0.46, 0.5), fur)
	_blob(root, Vector3(0, 0.84, -0.05), Vector3(0.24, 0.16, 0.8), belly)
	# Boyun ve baş (otlarken eğilen pivot).
	_head = Node3D.new()
	_head.position = Vector3(0, 1.12, -0.52)
	root.add_child(_head)
	_seg(_head, Vector3.ZERO, Vector3(0, 0.45, -0.2), 0.12, 0.08, fur)
	_blob(_head, Vector3(0, 0.5, -0.27), Vector3(0.17, 0.19, 0.28), fur)
	_seg(_head, Vector3(0, 0.48, -0.36), Vector3(0, 0.41, -0.58), 0.075, 0.045, fur)
	_blob(_head, Vector3(0, 0.41, -0.59), Vector3(0.07, 0.06, 0.05), hoof)
	_blob(_head, Vector3(0, 0.44, -0.5), Vector3(0.1, 0.06, 0.12), belly)
	for side in [-1.0, 1.0]:
		_seg(_head, Vector3(0.06 * side, 0.58, -0.24), Vector3(0.19 * side, 0.7, -0.2), 0.045, 0.012, fur)
		_blob(_head, Vector3(0.075 * side, 0.53, -0.36), Vector3(0.03, 0.03, 0.03), hoof)
		if is_stag:
			var antler := Color(0.8, 0.74, 0.6)
			var base := Vector3(0.05 * side, 0.6, -0.3)
			var top := Vector3(0.24 * side, 1.02, -0.2)
			_seg(_head, base, top, 0.022, 0.012, antler)
			_seg(_head, base.lerp(top, 0.35), base.lerp(top, 0.35) + Vector3(0.02 * side, 0.18, -0.16), 0.016, 0.008, antler)
			_seg(_head, base.lerp(top, 0.7), base.lerp(top, 0.7) + Vector3(0.05 * side, 0.15, -0.12), 0.014, 0.007, antler)
	# Kısa beyaz kuyruk.
	_tail = Node3D.new()
	_tail.position = Vector3(0, 1.15, 0.6)
	root.add_child(_tail)
	_seg(_tail, Vector3.ZERO, Vector3(0, -0.06, 0.12), 0.05, 0.03, belly)
	# Uzun ince bacaklar: önce ön çift, sonra arka çift.
	for side in [-1.0, 1.0]:
		_leg2(root, Vector3(0.12 * side, 0.9, -0.42), 0.42, 0.47, 0.035, fur, hoof, true)
	for side in [-1.0, 1.0]:
		_leg2(root, Vector3(0.12 * side, 0.95, 0.42), 0.46, 0.48, 0.037, dark.lerp(fur, 0.6), hoof, false)
	return root
