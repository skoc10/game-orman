class_name Wolf
extends AnimalBase
## Kurt: sürüyle dolaşır, geceleri daha uzaktan fark eder. Oyuncuyu fark edince
## önce etrafında döner, sonra saldırır. Yanan ateşin çevresine girmez; elinde
## meşale olana mesafe korur ama ara sıra yine de atılır. Canı azalınca kaçar.

const DAY_AWARENESS := 18.0
const NIGHT_AWARENESS := 36.0
const BITE_RANGE := 1.9
const BITE_COOLDOWN := 1.3

## Sürü lideri; null ise bu kurt liderdir.
var leader: Wolf

var _orbit_dir := 1.0
var _stalk_for := 5.0
var _bite_cd := 0.0
var _lunge_cd := 0.0
var _bites := 0
var _offset := Vector3.ZERO


func _init() -> void:
	species = "wolf"
	display_name = "Kurt"
	max_health = 50.0
	walk_speed = 2.4
	run_speed = 7.6
	drops = {"meat_raw": 2, "hide": 1}
	wander_radius = 45.0


func _ready() -> void:
	super._ready()
	add_to_group("wolf")
	if is_alive():
		add_to_group("hostile")
	_orbit_dir = 1.0 if rng.randf() < 0.5 else -1.0
	_offset = Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))


func set_state(s: State) -> void:
	if s == State.CHASE and state != State.CHASE and is_inside_tree():
		Sfx.play_at("wolf_growl", global_position + Vector3.UP * 0.7, 0.0, 35.0, 0.15)
	super.set_state(s)


func is_threat() -> bool:
	return is_alive() and state != State.RETREAT


func think(delta: float, player: Player, dist: float) -> void:
	_bite_cd -= delta
	_lunge_cd -= delta
	var b := Balance.d

	# Yanan ateşin içine asla girmez.
	var fire := nearest_fire(global_position, b.fire_fear_radius)
	if fire:
		move_away(fire.global_position, run_speed)
		if state in [State.CHASE, State.ATTACK]:
			set_state(State.STALK)
		return

	if state != State.RETREAT and health < max_health * 0.35:
		set_state(State.RETREAT)
		var away := (global_position - (player.global_position if player else home))
		away.y = 0.0
		_target = global_position + away.normalized() * 40.0
	if player == null or player.stats.dead:
		if state != State.RETREAT:
			_follow_or_wander(delta)
		return

	var keep := _keep_distance(player)
	var aware := NIGHT_AWARENESS if TimeOfDay.is_night() else DAY_AWARENESS
	if player.is_crouching:
		aware *= 0.7

	match state:
		State.IDLE, State.WANDER:
			if dist < aware or (leader and leader.is_alive() and leader.state in [State.STALK, State.CHASE, State.ATTACK]):
				_start_stalk()
			else:
				_follow_or_wander(delta)
		State.STALK:
			_orbit(player, maxf(9.0, keep + 2.0), delta)
			if dist > aware * 2.0:
				set_state(State.WANDER)
			elif _state_time > _stalk_for:
				if keep <= 0.0:
					set_state(State.CHASE)
				elif _lunge_cd <= 0.0:
					_lunge_cd = rng.randf_range(7.0, 12.0)
					if rng.randf() < 0.35:
						set_state(State.CHASE)
					else:
						_state_time = 0.0
		State.CHASE:
			move_to(player.global_position, run_speed)
			face(player.global_position, delta)
			if dist < BITE_RANGE:
				set_state(State.ATTACK)
			elif keep > 0.0 and dist < keep and _state_time > 1.2:
				_start_stalk()
			elif dist > aware * 2.2:
				set_state(State.WANDER)
		State.ATTACK:
			stop()
			face(player.global_position, delta)
			if dist > BITE_RANGE + 0.8:
				set_state(State.CHASE)
			elif _bite_cd <= 0.0:
				_bite(player)
				if (keep > 0.0 and _bites >= 1) or rng.randf() < Balance.d.wolf_retreat_after_bite:
					_start_stalk()
		State.RETREAT:
			move_to(_target, run_speed)
			health = minf(max_health, health + delta * 0.5)
			if _state_time > 12.0 or global_position.distance_to(_target) < 3.0:
				home = global_position
				set_state(State.WANDER)
		_:
			_follow_or_wander(delta)


func on_hurt(_attacker: Node3D) -> void:
	if state in [State.IDLE, State.WANDER, State.STALK]:
		set_state(State.CHASE)
	for other in get_tree().get_nodes_in_group("wolf"):
		if other != self and other.is_alive() and other.global_position.distance_to(global_position) < 25.0 \
				and other.state in [State.IDLE, State.WANDER]:
			other._start_stalk()


## Oyuncu ateşin yanındaysa ya da elinde meşale varsa korunacak mesafe; yoksa 0.
func _keep_distance(player: Player) -> float:
	var b := Balance.d
	var keep := 0.0
	var fire := nearest_fire(player.global_position, b.fire_fear_radius)
	if fire:
		keep = b.fire_fear_radius + 2.0
	if player.equipment and player.equipment.has_light():
		keep = maxf(keep, b.torch_fear_radius)
	return keep


func _start_stalk() -> void:
	set_state(State.STALK)
	_stalk_for = rng.randf_range(4.0, 8.0)
	_bites = 0


func _orbit(player: Player, radius: float, delta: float) -> void:
	var from_player := global_position - player.global_position
	from_player.y = 0.0
	if from_player.length() < 0.1:
		from_player = Vector3.FORWARD
	var tangent := from_player.normalized().rotated(Vector3.UP, 0.5 * _orbit_dir)
	move_to(player.global_position + tangent * radius, walk_speed * 1.6)
	face(player.global_position, delta)


func _bite(player: Player) -> void:
	_bite_cd = BITE_COOLDOWN
	_bites += 1
	var dmg := Balance.d.wolf_bite_damage * (1.2 if TimeOfDay.is_night() else 1.0)
	player.take_damage(dmg, "kurt")
	Sfx.play_at("bite", global_position + Vector3.UP * 0.7, 0.0, 30.0)
	var push := player.global_position - global_position
	push.y = 0.0
	player.velocity += push.normalized() * 3.0 + Vector3.UP * 1.5
	var tw := create_tween()
	tw.tween_property(model, "position:z", -0.35, 0.08)
	tw.tween_property(model, "position:z", 0.0, 0.2)


func _follow_or_wander(delta: float) -> void:
	if leader and leader.is_alive() and leader.state in [State.WANDER, State.IDLE]:
		var spot := leader.global_position + _offset
		if global_position.distance_to(spot) > 3.0:
			if state != State.WANDER:
				set_state(State.WANDER)
			move_to(spot, walk_speed * 1.3)
			face(global_position + _move_dir, delta)
		else:
			stop()
		return
	wander(delta)


func model_files() -> Array:
	return ["Wolf.gltf", "Wolf.glb"]


func model_height() -> float:
	return 1.05


func _build_model() -> Node3D:
	var root := Node3D.new()
	# Kurtlar zayıf ve uzun bacaklıdır: derin göğüs, içe çekik bel, dar kalça.
	var coats := [Color(0.46, 0.46, 0.48), Color(0.5, 0.45, 0.38), Color(0.32, 0.32, 0.34)]
	var fur: Color = coats[rng.randi() % coats.size()]
	var light := fur.lightened(0.35)
	var dark := Color(0.12, 0.12, 0.13)
	_blob(root, Vector3(0, 0.8, -0.24), Vector3(0.27, 0.4, 0.48), fur)
	_blob(root, Vector3(0, 0.77, 0.12), Vector3(0.19, 0.26, 0.46), fur)
	_blob(root, Vector3(0, 0.78, 0.36), Vector3(0.22, 0.27, 0.28), fur)
	_blob(root, Vector3(0, 0.66, -0.24), Vector3(0.17, 0.16, 0.36), light)
	_blob(root, Vector3(0, 0.92, -0.36), Vector3(0.24, 0.16, 0.24), fur.darkened(0.15))
	_head = Node3D.new()
	_head.position = Vector3(0, 0.9, -0.46)
	root.add_child(_head)
	_seg(_head, Vector3.ZERO, Vector3(0, 0.1, -0.16), 0.1, 0.085, fur)
	_blob(_head, Vector3(0, 0.14, -0.24), Vector3(0.19, 0.17, 0.23), fur)
	_seg(_head, Vector3(0, 0.11, -0.32), Vector3(0, 0.07, -0.53), 0.06, 0.032, light)
	_blob(_head, Vector3(0, 0.075, -0.54), Vector3(0.05, 0.04, 0.04), dark)
	for side in [-1.0, 1.0]:
		_seg(_head, Vector3(0.06 * side, 0.21, -0.19), Vector3(0.08 * side, 0.34, -0.17), 0.035, 0.004, fur)
		_blob(_head, Vector3(0.06 * side, 0.17, -0.34), Vector3(0.03, 0.022, 0.02), Color(0.95, 0.75, 0.2))
	# Gür, aşağı sarkan kuyruk.
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.82, 0.48)
	root.add_child(_tail)
	_seg(_tail, Vector3.ZERO, Vector3(0, -0.22, 0.24), 0.04, 0.075, fur)
	_seg(_tail, Vector3(0, -0.22, 0.24), Vector3(0, -0.4, 0.3), 0.075, 0.025, fur.darkened(0.25))
	for side in [-1.0, 1.0]:
		_leg2(root, Vector3(0.085 * side, 0.7, -0.3), 0.33, 0.35, 0.028, fur, dark, true)
	for side in [-1.0, 1.0]:
		_leg2(root, Vector3(0.085 * side, 0.73, 0.36), 0.36, 0.36, 0.03, fur, dark, false)
	return root


func _build_shape() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.1
	shape.shape = capsule
	shape.rotation.x = PI * 0.5
	shape.position.y = 0.6
	add_child(shape)
