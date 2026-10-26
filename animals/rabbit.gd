class_name Rabbit
extends AnimalBase
## Tavşan: açıklıklarda otlar, sekerek dolaşır. Fark edince keskin zikzaklarla
## kaçar ve bir süre sonra durup saklanır. Küçük ama hızlıdır; mızrak ya da
## sessizce yaklaşmak gerekir.

const PERCEPTION := 14.0
const FLEE_TIME := 5.0

var _threat := Vector3.ZERO
var _zig_timer := 0.0
var _zig_angle := 0.0


func _init() -> void:
	species = "rabbit"
	display_name = "Tavşan"
	max_health = 8.0
	walk_speed = 1.3
	run_speed = 9.5
	drops = {"meat_raw": 1}
	wander_radius = 14.0
	bound_height = 0.35
	graze_angle = -0.5


func _ready() -> void:
	super._ready()
	add_to_group("rabbit")


func think(delta: float, player: Player, dist: float) -> void:
	match state:
		State.FLEE:
			_zig_timer -= delta
			if _zig_timer <= 0.0:
				_zig_timer = rng.randf_range(0.35, 0.7)
				_zig_angle = rng.randf_range(0.5, 1.1) * (1.0 if _zig_angle <= 0.0 else -1.0)
			move_away(_threat, run_speed)
			_move_dir = _move_dir.rotated(Vector3.UP, _zig_angle)
			if _state_time > FLEE_TIME:
				home = global_position
				_idle_for = rng.randf_range(4.0, 8.0)
				set_state(State.IDLE)
		_:
			if player and not player.stats.dead and dist < _perception(player):
				flee_from(player.global_position)
				return
			wander(delta)


func _perception(player: Player) -> float:
	var r := PERCEPTION
	if player.is_crouching:
		r *= 0.45
	elif player.is_sprinting:
		r *= 1.4
	return r


func flee_from(pos: Vector3) -> void:
	_threat = pos
	_zig_timer = 0.0
	set_state(State.FLEE)


func on_hurt(attacker: Node3D) -> void:
	flee_from(attacker.global_position if attacker else global_position)


func _build_shape() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.15
	capsule.height = 0.45
	shape.shape = capsule
	shape.rotation.x = PI * 0.5
	shape.position.y = 0.18
	add_child(shape)


func _build_model() -> Node3D:
	var root := Node3D.new()
	var fur := Color(0.55, 0.47, 0.38).lerp(Color(0.45, 0.43, 0.42), rng.randf())
	var white := Color(0.92, 0.9, 0.86)
	var dark := Color(0.15, 0.12, 0.1)
	_blob(root, Vector3(0, 0.2, 0.04), Vector3(0.2, 0.22, 0.32), fur)
	_blob(root, Vector3(0, 0.17, 0.12), Vector3(0.21, 0.2, 0.2), fur)
	_blob(root, Vector3(0, 0.14, 0.0), Vector3(0.14, 0.1, 0.24), white)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.26, -0.12)
	root.add_child(_head)
	_blob(_head, Vector3(0, 0.04, -0.06), Vector3(0.12, 0.12, 0.15), fur)
	_blob(_head, Vector3(0, 0.02, -0.13), Vector3(0.03, 0.025, 0.02), dark)
	for side in [-1.0, 1.0]:
		_seg(_head, Vector3(0.03 * side, 0.09, -0.04), Vector3(0.05 * side, 0.24, 0.02), 0.025, 0.018, fur)
		_blob(_head, Vector3(0.05 * side, 0.06, -0.09), Vector3(0.02, 0.02, 0.02), dark)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.22, 0.22)
	root.add_child(_tail)
	_blob(_tail, Vector3.ZERO, Vector3(0.07, 0.07, 0.07), white)
	for side in [-1.0, 1.0]:
		_leg2(root, Vector3(0.05 * side, 0.13, -0.07), 0.06, 0.07, 0.016, fur, fur.darkened(0.2), true)
	for side in [-1.0, 1.0]:
		_leg2(root, Vector3(0.07 * side, 0.15, 0.12), 0.07, 0.08, 0.022, fur, fur.darkened(0.2), false)
	return root
