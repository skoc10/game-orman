class_name Player
extends CharacterBody3D
## Birinci şahıs oyuncu: yürüme, koşma, eğilme, zıplama, yüzme ve bakış.
## Hayatta kalma değerleri SurvivalStats'ta, etkileşim Interaction düğümünde tutulur.

signal landed(impact_speed: float)
signal footstep

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.1
const STAND_EYE := 1.62
const CROUCH_EYE := 0.95
## Ayaklar su yüzeyinin bu kadar altına inince yüzmeye geçilir.
const SWIM_DEPTH := 1.25
const GAMEPAD_LOOK_SPEED := 160.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var _shape: CollisionShape3D = $CollisionShape3D

var stats := SurvivalStats.new(Balance.d)
var inventory := Inventory.new()
var interaction: Interaction
var equipment: Equipment
var build: BuildSystem
var rng := RandomNumberGenerator.new()

var is_sprinting := false
var is_crouching := false
var is_swimming := false
var is_moving := false
## Hata ayıklama: yerçekimsiz serbest uçuş.
var debug_fly := false
## Menü ya da envanter açıkken hareket ve bakış durur.
var input_locked := false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _bob_time := 0.0
var _last_step_phase := 0
var _air_speed := 0.0
var _was_on_floor := true
var _shake := 0.0
var _warmth_timer := 0.0
var _warmth_target := 80.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.fov = float(GameState.settings.fov)
	rng.randomize()
	interaction = Interaction.new()
	interaction.name = "Interaction"
	interaction.player = self
	add_child(interaction)
	equipment = Equipment.new()
	equipment.name = "Equipment"
	equipment.player = self
	camera.add_child(equipment)
	build = BuildSystem.new()
	build.name = "BuildSystem"
	build.player = self
	add_child(build)
	stats.damaged.connect(_on_damaged)
	stats.died.connect(_on_died)
	landed.connect(_on_landed)


func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := float(GameState.settings.mouse_sensitivity)
		_look(Vector2(event.relative.x, event.relative.y) * sens)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if input_locked:
		return
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick != Vector2.ZERO:
		var sens := float(GameState.settings.mouse_sensitivity) * 4.0
		_look(stick * GAMEPAD_LOOK_SPEED * sens * delta)


func _physics_process(delta: float) -> void:
	var b := Balance.d
	var input := Vector2.ZERO if input_locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (transform.basis * Vector3(input.x, 0.0, input.y))
	is_moving = input.length() > 0.1

	if debug_fly:
		_fly(delta, wish)
		return

	is_swimming = global_position.y < WorldGen.WATER_LEVEL - SWIM_DEPTH
	_update_crouch(delta, not input_locked and Input.is_action_pressed("crouch") and not is_swimming)
	is_sprinting = not input_locked and Input.is_action_pressed("sprint") and input.y < -0.1 \
		and not is_crouching and not is_swimming and can_sprint()

	var speed := b.walk_speed
	if is_swimming:
		speed = b.swim_speed
	elif is_crouching:
		speed = b.crouch_speed
	elif is_sprinting:
		speed = b.sprint_speed

	if is_swimming:
		# Baş suyun üstünde kalacak şekilde yüzeye doğru it.
		var target_y := WorldGen.WATER_LEVEL - SWIM_DEPTH - 0.1
		velocity.y = clampf((target_y - global_position.y) * 3.0, -2.0, 2.0)
	elif not is_on_floor():
		velocity.y -= _gravity * delta
	elif not input_locked and Input.is_action_just_pressed("jump") and try_jump():
		velocity.y = b.jump_velocity

	var accel := 10.0 if (is_on_floor() or is_swimming) else 2.0
	velocity.x = lerpf(velocity.x, wish.x * speed, clampf(accel * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, wish.z * speed, clampf(accel * delta, 0.0, 1.0))

	if not is_on_floor():
		_air_speed = maxf(_air_speed, -velocity.y)
	move_and_slide()
	_check_landing()
	_keep_inside_island()
	_head_bob(delta)
	_update_stats(delta)
	_camera_effects(delta)


func can_sprint() -> bool:
	return stats.can_sprint()


func try_jump() -> bool:
	return stats.use_stamina(Balance.d.jump_stamina)


func notify(text: String) -> void:
	Events.notify.emit(text)


## Envantere eşya ekler, bildirim gösterir ve sığmayan adedi döndürür.
func give(id: String, count := 1, dur := -1.0) -> int:
	var left := inventory.add(id, count, dur)
	var got := count - left
	if got > 0:
		notify("+%d %s" % [got, ItemDB.display_name(id)])
	if left > 0:
		notify(tr("Envanter dolu!"))
	return left


## Hata ayıklama: "axe:1,stick:10" biçiminde eşya verir.
func debug_give(spec: String) -> void:
	for part in spec.split(","):
		var kv := part.split(":")
		inventory.add(kv[0], int(kv[1]) if kv.size() > 1 else 1)


func take_damage(amount: float, cause: String) -> void:
	stats.damage(amount, cause)


func drink_fresh_water() -> void:
	var b := Balance.d
	if stats.drink(b.lake_sip_thirst, b.raw_water_nausea_chance, b.raw_water_nausea_time, rng):
		notify(tr("Kaynatılmamış su midene dokundu..."))


## Mataralara sığacak kadar ham su ekler.
func fill_canteen() -> void:
	var n := canteen_space()
	if n <= 0:
		notify(tr("Mataran dolu.") if inventory.has("canteen") else tr("Su taşımak için matara gerekli."))
		return
	var left := inventory.add("water_raw", n)
	if n - left > 0:
		notify(tr("Matara dolduruldu (+%d yudum ham su)") % (n - left))


## Mataralarda kaç yudumluk boş yer var.
func canteen_space() -> int:
	var capacity := inventory.count_of("canteen") * Balance.d.canteen_capacity
	return maxi(0, capacity - inventory.count_of("water_raw") - inventory.count_of("water_clean"))


func drink_sea_water() -> void:
	stats.drink(Balance.d.sea_sip_thirst, 0.0, 0.0, rng)
	notify(tr("Tuzlu su! Susuzluğun arttı."))


## Isı kaynaklarının ("warmth_source" grubu) ve saatin belirlediği hedef ısı.
func current_warmth_target() -> float:
	return _warmth_target


func _update_stats(delta: float) -> void:
	_warmth_timer -= delta
	if _warmth_timer <= 0.0:
		_warmth_timer = 0.25
		_warmth_target = _compute_warmth_target()
	stats.tick(delta, {
		"sprinting": is_sprinting and is_moving,
		"swimming": is_swimming,
		"warmth_target": _warmth_target,
		"cold_resist": cold_resist(),
	})


func _compute_warmth_target() -> float:
	var b := Balance.d
	var target := TimeOfDay.ambient_warmth()
	for source in get_tree().get_nodes_in_group("warmth_source"):
		if source.has_method("warmth_for"):
			target = maxf(target, source.warmth_for(global_position))
	if equipment and equipment.has_light():
		target = maxf(target, b.torch_warmth)
	if is_swimming:
		target = minf(target, b.water_warmth)
	return target


## Isı kaybı çarpanı; envanterdeki giysi bunu düşürür.
func cold_resist() -> float:
	return inventory.best_cold_resist()


func _on_landed(impact: float) -> void:
	var b := Balance.d
	if impact > b.fall_damage_speed and not is_swimming:
		take_damage((impact - b.fall_damage_speed) * b.fall_damage_per_speed, "düşme")


func _on_damaged(amount: float, _cause: String) -> void:
	# Açlık gibi sürekli küçük hasarlar sarsıntı yapmaz, yalnızca darbeler.
	if amount >= 1.0:
		_shake = minf(_shake + amount * 0.02, 0.6)
		Events.player_damaged.emit(amount)


func _on_died(cause: String) -> void:
	input_locked = true
	is_sprinting = false
	velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tw := create_tween().set_parallel()
	tw.tween_property(head, "position:y", 0.35, 1.2).set_ease(Tween.EASE_IN)
	tw.tween_property(head, "rotation:z", deg_to_rad(70.0), 1.2).set_ease(Tween.EASE_IN)
	Events.player_died.emit(cause)


func _camera_effects(delta: float) -> void:
	var offset := Vector3.ZERO
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.5)
		offset = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 0.0) * _shake * 0.08
	if stats.is_nauseous() and not stats.dead:
		var t := Time.get_ticks_msec() * 0.001
		camera.rotation.z = sin(t * 1.3) * 0.03
		offset.x += sin(t * 0.9) * 0.03
	elif not stats.dead:
		camera.rotation.z = lerpf(camera.rotation.z, 0.0, clampf(delta * 5.0, 0.0, 1.0))
	camera.h_offset = offset.x
	camera.v_offset = offset.y


func save_state() -> Dictionary:
	return {
		"pos": GameState.vec3_to_arr(global_position),
		"yaw": rotation.y,
		"pitch": head.rotation.x,
		"stats": stats.to_dict(),
		"inventory": inventory.to_array(),
		"selected": equipment.selected,
	}


func load_state(d: Dictionary) -> void:
	teleport(GameState.arr_to_vec3(d.get("pos"), global_position), rad_to_deg(float(d.get("yaw", 0.0))), rad_to_deg(float(d.get("pitch", 0.0))))
	stats.from_dict(d.get("stats", {}))
	if stats.health <= 0.0:
		stats.health = 50.0
	inventory.from_array(d.get("inventory", []))
	equipment.select(int(d.get("selected", 0)))


func teleport(pos: Vector3, yaw_deg := NAN, pitch_deg := NAN) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	if not is_nan(yaw_deg):
		rotation.y = deg_to_rad(yaw_deg)
	if not is_nan(pitch_deg):
		head.rotation.x = deg_to_rad(pitch_deg)


func look_direction() -> Vector3:
	return -camera.global_transform.basis.z


func _look(delta_deg: Vector2) -> void:
	rotate_y(deg_to_rad(-delta_deg.x))
	head.rotation.x = clampf(head.rotation.x - deg_to_rad(delta_deg.y), deg_to_rad(-88.0), deg_to_rad(88.0))


func _update_crouch(delta: float, want: bool) -> void:
	if not want and is_crouching and _blocked_above():
		want = true
	is_crouching = want
	var capsule := _shape.shape as CapsuleShape3D
	var target_h := CROUCH_HEIGHT if want else STAND_HEIGHT
	capsule.height = move_toward(capsule.height, target_h, delta * 4.0)
	_shape.position.y = capsule.height * 0.5
	head.position.y = move_toward(head.position.y, CROUCH_EYE if want else STAND_EYE, delta * 4.0)


func _blocked_above() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * CROUCH_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * (STAND_HEIGHT - CROUCH_HEIGHT + 0.1), 1)
	query.exclude = [get_rid()]
	return not space.intersect_ray(query).is_empty()


func _check_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		landed.emit(_air_speed)
		_air_speed = 0.0
	if on_floor:
		_air_speed = 0.0
	_was_on_floor = on_floor


func _keep_inside_island() -> void:
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() > WorldGen.BOUNDARY_RADIUS:
		flat = flat.normalized() * WorldGen.BOUNDARY_RADIUS
		global_position.x = flat.x
		global_position.z = flat.y


func _head_bob(delta: float) -> void:
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if (is_on_floor() or is_swimming) and horizontal > 0.5:
		_bob_time += delta * horizontal * 1.8
		var amp := 0.6 if is_crouching else (1.3 if is_sprinting else 1.0)
		if is_swimming:
			amp = 0.4
		camera.position.y = sin(_bob_time * 2.0) * 0.035 * amp
		camera.position.x = cos(_bob_time) * 0.025 * amp
		var phase := int(_bob_time / PI)
		if phase != _last_step_phase and not is_swimming:
			_last_step_phase = phase
			footstep.emit()
	else:
		camera.position = camera.position.lerp(Vector3.ZERO, clampf(delta * 8.0, 0.0, 1.0))


func _fly(delta: float, wish: Vector3) -> void:
	var dir := wish
	if Input.is_action_pressed("jump"):
		dir.y += 1.0
	if Input.is_action_pressed("crouch"):
		dir.y -= 1.0
	var speed := 30.0 if Input.is_action_pressed("sprint") else 12.0
	global_position += dir * speed * delta
