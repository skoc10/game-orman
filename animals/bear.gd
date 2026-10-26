class_name Bear
extends AnimalBase
## Ayı: ormanın derinliklerinde ve mağaralarda yaşar. Bölgesine girilince arka
## ayakları üstüne kalkıp kükrer; uzaklaşırsan bırakır, yaklaşırsan saldırır.
## Koşarak kaçılamaz. Ateşe yaklaşmaz ama meşaleden korkmaz. Ağır yaralanınca çekilir.
## Mağaradaki ayı uyur; yanına kadar sessizce gidilebilir.

const DAY_TERRITORY := 14.0
const NIGHT_TERRITORY := 18.0
const SWIPE_RANGE := 2.4
const SWIPE_COOLDOWN := 1.8
const SWIPE_DAMAGE := 22.0

var sleeping := false

var _swipe_cd := 0.0
var _swipes := 0


func _init() -> void:
	species = "bear"
	display_name = "Ayı"
	max_health = 160.0
	walk_speed = 1.6
	run_speed = 8.0
	drops = {"meat_raw": 5, "hide": 3}
	wander_radius = 30.0
	bound_height = 0.08
	graze_angle = -0.6


func _ready() -> void:
	super._ready()
	add_to_group("bear")
	if is_alive():
		add_to_group("hostile")


func is_threat() -> bool:
	return is_alive() and state != State.RETREAT


func think(delta: float, player: Player, dist: float) -> void:
	_swipe_cd -= delta
	var fire := nearest_fire(global_position, Balance.d.fire_fear_radius * 0.7)
	if fire:
		move_away(fire.global_position, walk_speed * 2.0)
		if state in [State.CHASE, State.ATTACK]:
			set_state(State.ALERT)
		return
	if state != State.RETREAT and health < max_health * 0.25:
		sleeping = false
		set_state(State.RETREAT)
		var away := global_position - (player.global_position if player else home)
		away.y = 0.0
		_target = global_position + away.normalized() * 50.0
	if player == null or player.stats.dead:
		if state != State.RETREAT:
			wander(delta)
		return

	var territory := NIGHT_TERRITORY if TimeOfDay.is_night() else DAY_TERRITORY
	if sleeping:
		stop()
		var wake := dist < 5.0 or (player.is_sprinting and dist < 12.0)
		if not wake:
			return
		sleeping = false
		_roar()
	match state:
		State.IDLE, State.WANDER:
			if dist < territory:
				_roar()
				set_state(State.ALERT)
			else:
				wander(delta)
		State.ALERT:
			# Arka ayakları üstüne kalkıp uyarır.
			stop()
			face(player.global_position, delta)
			if _state_time > 1.8:
				if dist < territory * 0.85:
					set_state(State.CHASE)
				elif dist > territory * 1.4:
					set_state(State.WANDER)
		State.CHASE:
			move_to(player.global_position, run_speed)
			face(player.global_position, delta)
			if dist < SWIPE_RANGE:
				set_state(State.ATTACK)
			elif dist > territory * 2.5:
				set_state(State.WANDER)
		State.ATTACK:
			stop()
			face(player.global_position, delta)
			if dist > SWIPE_RANGE + 1.0:
				set_state(State.CHASE)
			elif _swipe_cd <= 0.0:
				_swipe(player)
				if _swipes >= 2 and rng.randf() < 0.4:
					# Blöf: geri çekilip yeniden uyarır.
					_swipes = 0
					set_state(State.ALERT)
		State.RETREAT:
			move_to(_target, run_speed * 0.8)
			if _state_time > 14.0 or global_position.distance_to(_target) < 3.0:
				home = global_position
				set_state(State.WANDER)
		_:
			wander(delta)


func on_hurt(_attacker: Node3D) -> void:
	sleeping = false
	if state in [State.IDLE, State.WANDER, State.ALERT]:
		_roar()
		set_state(State.CHASE)


func _roar() -> void:
	Sfx.play_at("bear_roar", global_position + Vector3.UP, 4.0, 70.0, 0.1)


func _swipe(player: Player) -> void:
	_swipe_cd = SWIPE_COOLDOWN
	_swipes += 1
	player.take_damage(SWIPE_DAMAGE, "ayı")
	var push := player.global_position - global_position
	push.y = 0.0
	player.velocity += push.normalized() * 5.0 + Vector3.UP * 2.0
	Sfx.play_at("hit_flesh", player.global_position, 2.0, 30.0)
	var tw := create_tween()
	tw.tween_property(model, "rotation:x", -0.25, 0.12)
	tw.tween_property(model, "rotation:x", 0.0, 0.3)


func _animate(delta: float) -> void:
	super._animate(delta)
	if model and ext == null:
		# Uyarırken arka ayakları üstüne kalkar.
		var rear := -0.55 if state == State.ALERT and _state_time < 1.6 else 0.0
		model.rotation.x = lerpf(model.rotation.x, rear, clampf(delta * 5.0, 0.0, 1.0))


func save_state() -> Dictionary:
	var d := super.save_state()
	d["sleeping"] = sleeping
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	sleeping = bool(d.get("sleeping", false))


func model_files() -> Array:
	return ["Bear.gltf", "Bear.glb"]


func model_height() -> float:
	return 1.4


func _build_shape() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.8
	shape.shape = capsule
	shape.rotation.x = PI * 0.5
	shape.position.y = 0.8
	add_child(shape)


func _build_model() -> Node3D:
	var root := Node3D.new()
	var fur := Color(0.32, 0.22, 0.14).lerp(Color(0.24, 0.19, 0.15), rng.randf())
	var muzzle := fur.lightened(0.35)
	var dark := Color(0.08, 0.06, 0.05)
	_blob(root, Vector3(0, 0.95, -0.35), Vector3(0.8, 0.85, 0.9), fur)
	_blob(root, Vector3(0, 0.9, 0.3), Vector3(0.75, 0.78, 0.95), fur)
	_blob(root, Vector3(0, 1.22, -0.45), Vector3(0.6, 0.4, 0.55), fur.darkened(0.08))
	_head = Node3D.new()
	_head.position = Vector3(0, 1.05, -0.78)
	root.add_child(_head)
	_blob(_head, Vector3(0, 0.05, -0.15), Vector3(0.42, 0.38, 0.42), fur)
	_seg(_head, Vector3(0, 0.0, -0.3), Vector3(0, -0.05, -0.52), 0.13, 0.09, muzzle)
	_blob(_head, Vector3(0, -0.04, -0.54), Vector3(0.09, 0.07, 0.06), dark)
	for side in [-1.0, 1.0]:
		_blob(_head, Vector3(0.16 * side, 0.24, -0.08), Vector3(0.1, 0.1, 0.06), fur.darkened(0.1))
		_blob(_head, Vector3(0.11 * side, 0.1, -0.33), Vector3(0.035, 0.035, 0.03), dark)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 1.0, 0.75)
	root.add_child(_tail)
	_blob(_tail, Vector3.ZERO, Vector3(0.12, 0.12, 0.1), fur)
	for side in [-1.0, 1.0]:
		_leg2(root, Vector3(0.24 * side, 0.7, -0.5), 0.35, 0.33, 0.1, fur, dark, true)
	for side in [-1.0, 1.0]:
		_leg2(root, Vector3(0.24 * side, 0.72, 0.5), 0.37, 0.33, 0.11, fur, dark, false)
	return root
