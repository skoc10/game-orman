class_name AnimalBase
extends CharacterBody3D
## Hayvanların ortak davranışı: arazide yürüme, sudan/dik yamaçtan/engelden
## kaçınma, hasar alma, ölüm ve leşten et/deri alma. Türler think() ile karar verir.

enum State { IDLE, WANDER, ALERT, FLEE, STALK, CHASE, ATTACK, RETREAT, DEAD }

## Oyuncuya bu mesafeden uzak hayvanlar seyrek ve basit güncellenir.
const FAR_DISTANCE := 130.0
## Leş bu kadar gün sonra kaybolur.
const CORPSE_DAYS := 2

var species := ""
var display_name := ""
var max_health := 50.0
var health := -1.0
var walk_speed := 2.0
var run_speed := 7.0
var drops := {}
var state: State = State.IDLE
## Dolaşma merkezi (sürünün otladığı yer).
var home := Vector3.ZERO
var wander_radius := 30.0
var died_day := -1

var model: Node3D
## Dışarıdan yüklenen animasyonlu model; yoksa yer tutucu kullanılır.
var ext: AnimalModel
var rng := RandomNumberGenerator.new()

var _legs: Array[Node3D] = []
var _state_time := 0.0
var _target := Vector3.ZERO
var _move_dir := Vector3.ZERO
var _speed := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _far_timer := 0.0
var _stuck_time := 0.0
var _last_pos := Vector3.ZERO
var _anim_t := 0.0
var _flash := 0.0
var _idle_for := 3.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 2 | 8
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.5
	add_to_group("animal")
	add_to_group("persist_dynamic")
	rng.randomize()
	if health < 0.0:
		health = max_health
	_build_shape()
	ext = AnimalModel.try_load(model_files(), model_height())
	model = ext.root if ext else _build_model()
	add_child(model)
	if home == Vector3.ZERO:
		home = global_position
	_last_pos = global_position
	TimeOfDay.day_changed.connect(_on_day_changed)
	if died_day >= 0:
		_become_corpse(false)
	else:
		_pick_wander_target()
		set_state(State.IDLE)


## Türün kararı: _move_dir ve _speed'i ayarlar, durum değiştirir.
func think(_delta: float, _player: Player, _dist: float) -> void:
	pass


## Türün tepkisi: hasar alınca.
func on_hurt(_attacker: Node3D) -> void:
	pass


## assets/models/animals altında aranacak model dosyaları.
func model_files() -> Array:
	return []


## Dış modelin ölçekleneceği boy (m).
func model_height() -> float:
	return 1.5


## Türün görünümü (yer tutucu). Bacak pivotları _legs dizisine eklenir.
func _build_model() -> Node3D:
	return Node3D.new()


func _build_shape() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.4
	shape.shape = capsule
	shape.rotation.x = PI * 0.5
	shape.position.y = 0.75
	add_child(shape)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		if not is_on_floor():
			velocity = Vector3(0, velocity.y - _gravity * delta, 0)
			move_and_slide()
		return
	var player := _player()
	var dist := INF if player == null else global_position.distance_to(player.global_position)
	if dist > FAR_DISTANCE:
		_far_update(delta)
		return
	_state_time += delta
	think(delta, player, dist)
	_apply_movement(delta)
	_animate(delta)


func set_state(s: State) -> void:
	state = s
	_state_time = 0.0


func is_alive() -> bool:
	return state != State.DEAD


func take_hit(damage: float, attacker: Node3D) -> void:
	if state == State.DEAD:
		return
	health -= damage
	_flash = 1.0
	Effects.burst(get_parent(), global_position + Vector3(0, 0.9, 0), Color(0.55, 0.04, 0.04), 12, 2.5)
	if health <= 0.0:
		die()
	else:
		on_hurt(attacker)


func die() -> void:
	set_state(State.DEAD)
	died_day = TimeOfDay.day
	_become_corpse(true)


func get_interaction(player: Player, _shape_idx: int) -> Dictionary:
	if state != State.DEAD:
		return {}
	if not _has_butcher_tool(player):
		return {"text": tr("%s leşi: kesmek için bıçak gerekli") % display_name}
	return {"text": tr("%s leşini kes") % display_name, "hold": 1.2, "action": _butcher.bind(player)}


func save_state() -> Dictionary:
	return {
		"type": "animal", "species": species,
		"pos": GameState.vec3_to_arr(global_position), "yaw": rotation.y,
		"home": GameState.vec3_to_arr(home), "health": health,
		"died_day": died_day, "night": is_in_group("night_only"),
	}


func load_state(d: Dictionary) -> void:
	health = float(d.get("health", max_health))
	home = GameState.arr_to_vec3(d.get("home"), Vector3.ZERO)
	died_day = int(d.get("died_day", -1))
	if bool(d.get("night", false)):
		add_to_group("night_only")


# --- Hareket ---

func move_to(target: Vector3, speed: float) -> void:
	var d := target - global_position
	d.y = 0.0
	_move_dir = d.normalized() if d.length() > 0.2 else Vector3.ZERO
	_speed = speed


func move_away(from: Vector3, speed: float) -> void:
	var d := global_position - from
	d.y = 0.0
	_move_dir = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	_speed = speed


func stop() -> void:
	_speed = 0.0


func face(target: Vector3, delta: float) -> void:
	var d := target - global_position
	if Vector2(d.x, d.z).length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), clampf(delta * 6.0, 0.0, 1.0))


## Basit dolaşma: hedefe yürü, varınca bir süre dur (otla), sonra yeni hedef.
func wander(delta: float) -> void:
	if state == State.IDLE:
		stop()
		if _state_time > _idle_for:
			_pick_wander_target()
			set_state(State.WANDER)
		return
	if state != State.WANDER:
		set_state(State.WANDER)
	move_to(_target, walk_speed)
	if Vector2(global_position.x - _target.x, global_position.z - _target.z).length() < 1.5 or _state_time > 25.0:
		_idle_for = rng.randf_range(3.0, 9.0)
		set_state(State.IDLE)
	face(global_position + _move_dir, delta)


func _pick_wander_target() -> void:
	var gen := _gen()
	for i in 12:
		var a := rng.randf() * TAU
		var r := rng.randf_range(4.0, wander_radius)
		var p := home + Vector3(cos(a) * r, 0, sin(a) * r)
		if gen == null or _walkable(p):
			_target = p
			return
	_target = home


func _apply_movement(delta: float) -> void:
	var desired := _move_dir * _speed
	if _speed > 0.1 and not _walkable(global_position + _move_dir * 2.0):
		desired = Vector3.ZERO
		on_blocked()
	velocity.x = lerpf(velocity.x, desired.x, clampf(delta * 6.0, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, desired.z, clampf(delta * 6.0, 0.0, 1.0))
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= _gravity * delta
	move_and_slide()
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.4:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), clampf(delta * 8.0, 0.0, 1.0))
	if _speed > 0.5 and global_position.distance_to(_last_pos) < _speed * delta * 0.15:
		_stuck_time += delta
		if _stuck_time > 0.6:
			_stuck_time = 0.0
			on_blocked()
	else:
		_stuck_time = 0.0
	_last_pos = global_position


## Önü kapalı: yön değiştir. Dolaşıyorsa yeni hedef seç.
func on_blocked() -> void:
	if state in [State.WANDER, State.IDLE]:
		_pick_wander_target()
	else:
		var turn := rng.randf_range(0.6, 1.4) * (1.0 if rng.randf() < 0.5 else -1.0)
		_move_dir = _move_dir.rotated(Vector3.UP, turn)


func _walkable(p: Vector3) -> bool:
	var gen := _gen()
	if gen == null:
		return true
	return gen.height_at(p.x, p.z) > WorldGen.WATER_LEVEL + 0.3 and gen.slope_at(p.x, p.z) < 0.55 \
		and Vector2(p.x, p.z).length() < WorldGen.ISLAND_RADIUS


## Uzaktaki hayvan: fizik olmadan yarım saniyede bir araziye yapışarak yürür.
func _far_update(delta: float) -> void:
	_far_timer += delta
	if _far_timer < 0.5:
		return
	var dt := _far_timer
	_far_timer = 0.0
	if state != State.WANDER and state != State.IDLE:
		set_state(State.WANDER)
	var to := _target - global_position
	to.y = 0.0
	if to.length() < 2.0:
		_pick_wander_target()
		return
	var next := global_position + to.normalized() * walk_speed * dt
	if _walkable(next):
		global_position = Vector3(next.x, _gen().height_at(next.x, next.z) + 0.05, next.z)
		rotation.y = atan2(-to.x, -to.z)
	else:
		_pick_wander_target()


func _animate(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if ext:
		if state == State.ATTACK and ext.has_anim("attack"):
			ext.play("attack")
		elif speed > run_speed * 0.55 and ext.has_anim("run"):
			ext.play("run", clampf(speed / run_speed, 0.6, 1.4))
		elif speed > 0.3:
			ext.play("walk", clampf(speed / maxf(walk_speed, 0.1), 0.6, 1.6))
		elif state == State.IDLE and ext.has_anim("eat") and species == "deer":
			ext.play("eat")
		else:
			ext.play("idle")
		_flash = maxf(0.0, _flash - delta * 4.0)
		model.scale = Vector3.ONE * (1.0 + _flash * 0.08)
		return
	_anim_t += delta * (2.0 + speed * 2.2)
	var amp := clampf(speed / maxf(run_speed, 0.1), 0.0, 1.0) * 0.7 + (0.15 if speed > 0.2 else 0.0)
	for i in _legs.size():
		var phase := 0.0 if i % 3 == 0 else PI
		_legs[i].rotation.x = sin(_anim_t + phase) * amp
	if model:
		model.position.y = absf(sin(_anim_t)) * 0.04 * amp
		_flash = maxf(0.0, _flash - delta * 4.0)
		model.scale = Vector3.ONE * (1.0 + _flash * 0.08)


# --- Ölüm ve leş ---

func _become_corpse(animate: bool) -> void:
	state = State.DEAD
	collision_layer = 4
	collision_mask = 1
	velocity = Vector3.ZERO
	remove_from_group("hostile")
	add_to_group("corpse")
	for leg in _legs:
		leg.rotation.x = 0.0
	if ext and ext.has_anim("death"):
		if animate:
			ext.play("death")
		else:
			ext.hold_last.call_deferred("death")
		return
	if animate:
		var tw := create_tween().set_parallel()
		tw.tween_property(model, "rotation:z", PI * 0.5, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(model, "position:y", -0.25, 0.6)
	else:
		model.rotation.z = PI * 0.5
		model.position.y = -0.25


func _has_butcher_tool(player: Player) -> bool:
	for s in player.inventory.slots:
		if s.is_empty():
			continue
		var item := ItemDB.get_item(s.id)
		if item and item.can_butcher:
			return true
	return false


func _butcher(player: Player) -> void:
	for id in drops:
		player.give(id, int(drops[id]))
	Effects.burst(get_parent(), global_position + Vector3(0, 0.4, 0), Color(0.55, 0.04, 0.04), 16, 2.0)
	queue_free()


func _on_day_changed(day: int) -> void:
	if died_day >= 0 and day - died_day >= CORPSE_DAYS:
		queue_free()


# --- Yardımcılar ---

func _player() -> Player:
	var w := GameState.world
	return w.player if w else null


func _gen() -> WorldGen:
	var w := GameState.world
	return w.gen if w else null


## Etrafında yanan en yakın ateş (radius içinde), yoksa null.
func nearest_fire(pos: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for fire in get_tree().get_nodes_in_group("fire"):
		if fire.is_burning():
			var d := pos.distance_to(fire.global_position)
			if d < best_d:
				best_d = d
				best = fire
	return best


## Kutu parçalarından yer tutucu model için yardımcı.
func _part(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.box(size)
	mi.material_override = MeshFactory.flat_material(color)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Kalça noktasından dönen bacak.
func _leg(parent: Node3D, hip: Vector3, length: float, thickness: float, color: Color) -> void:
	var pivot := Node3D.new()
	pivot.position = hip
	parent.add_child(pivot)
	_part(pivot, Vector3(thickness, length, thickness), Vector3(0, -length * 0.5, 0), color)
	_legs.append(pivot)
