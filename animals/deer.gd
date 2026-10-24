class_name Deer
extends AnimalBase
## Geyik: sürüyle otlar, oyuncuyu fark edince önce kulak kabartır, yaklaşılınca
## kaçar. Vurulunca bütün sürü kaçar. Eğilerek yaklaşmak gerekir.

const PERCEPTION := 24.0
const FLEE_TIME := 7.0

var is_stag := false

var _threat := Vector3.ZERO
var _alert_dist := 0.0


func _init() -> void:
	species = "deer"
	display_name = "Geyik"
	max_health = 60.0
	walk_speed = 1.6
	run_speed = 8.5
	drops = {"meat_raw": 3, "hide": 1}
	wander_radius = 28.0


func _ready() -> void:
	rng.randomize()
	is_stag = bool(get_meta("stag")) if has_meta("stag") else rng.randf() < 0.3
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
					set_state(State.ALERT)
				return
			wander(delta)
		State.ALERT:
			stop()
			face(player.global_position, delta)
			if not notices and _state_time > 2.5:
				set_state(State.IDLE)
			elif dist < perception_radius(player) * 0.5 or player.is_sprinting or (_state_time > 2.0 and dist < _alert_dist - 1.5):
				flee_from(player.global_position)
		State.FLEE:
			move_away(_threat, run_speed)
			if _state_time > FLEE_TIME:
				home = global_position
				_pick_wander_target()
				set_state(State.IDLE)
		_:
			wander(delta)


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


func flee_from(pos: Vector3) -> void:
	_threat = pos
	if state != State.FLEE:
		set_state(State.FLEE)
	else:
		_state_time = 0.0


func on_hurt(attacker: Node3D) -> void:
	var from := attacker.global_position if attacker else global_position
	flee_from(from)
	for other in get_tree().get_nodes_in_group("deer"):
		if other != self and other.is_alive() and other.global_position.distance_to(global_position) < 35.0:
			other.flee_from(from)


func save_state() -> Dictionary:
	var d := super.save_state()
	d["stag"] = is_stag
	return d


func _build_model() -> Node3D:
	var root := Node3D.new()
	var fur := Color(0.58, 0.4, 0.24)
	var belly := Color(0.78, 0.66, 0.5)
	var dark := Color(0.25, 0.18, 0.12)
	_part(root, Vector3(0.42, 0.45, 1.15), Vector3(0, 0.95, 0), fur)
	_part(root, Vector3(0.36, 0.12, 0.9), Vector3(0, 0.74, 0), belly)
	_part(root, Vector3(0.2, 0.55, 0.22), Vector3(0, 1.3, -0.55), fur, Vector3(0.45, 0, 0))
	_part(root, Vector3(0.22, 0.24, 0.42), Vector3(0, 1.58, -0.78), fur)
	_part(root, Vector3(0.1, 0.1, 0.12), Vector3(0, 1.53, -1.0), dark)
	_part(root, Vector3(0.06, 0.18, 0.04), Vector3(0.12, 1.75, -0.7), fur, Vector3(0, 0, -0.5))
	_part(root, Vector3(0.06, 0.18, 0.04), Vector3(-0.12, 1.75, -0.7), fur, Vector3(0, 0, 0.5))
	_part(root, Vector3(0.12, 0.14, 0.06), Vector3(0, 1.0, 0.6), belly)
	if is_stag:
		var antler := Color(0.82, 0.76, 0.62)
		for side in [-1.0, 1.0]:
			_part(root, Vector3(0.04, 0.4, 0.04), Vector3(0.1 * side, 1.9, -0.72), antler, Vector3(0.2, 0, -0.35 * side))
			_part(root, Vector3(0.04, 0.2, 0.04), Vector3(0.2 * side, 2.0, -0.82), antler, Vector3(-0.6, 0, -0.6 * side))
	for hip in [Vector3(0.14, 0.78, -0.42), Vector3(-0.14, 0.78, -0.42), Vector3(0.14, 0.78, 0.42), Vector3(-0.14, 0.78, 0.42)]:
		_leg(root, hip, 0.78, 0.09, fur.darkened(0.1))
	return root
