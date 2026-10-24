class_name Player
extends CharacterBody3D
## Birinci şahıs oyuncu: yürüme, koşma, eğilme, zıplama, yüzme ve bakış.

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


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.fov = float(GameState.settings.fov)


func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := float(GameState.settings.mouse_sensitivity)
		_look(Vector2(event.relative.x, event.relative.y) * sens)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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


## Dayanıklılık sistemi (adım 3) bu iki fonksiyonu genişletir.
func can_sprint() -> bool:
	return true


func try_jump() -> bool:
	return true


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
