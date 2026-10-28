class_name Dog
extends AnimalBase
## Köpek: ormanda kaybolmuş, inleyen bir yavru olarak bulunur. Et ya da balık
## verilince sahiplenilir ve oyuncuyu takip eder. Her gün büyür; 4 günde yetişkin
## olur. Yetişkin köpek tehlikeyi havlayarak haber verir ve saldıranlarla dövüşür.
## E ile "Otur" / "Takip et" komutu verilir, acıkınca beslenir. Ölmez: ağır
## yaralanınca bir süre yatıp toparlanır. Oyuncunun vuruşları ona işlemez.

const FOODS := ["meat_cooked", "fish_cooked", "meat_raw", "fish_raw"]
const ADULT_DAYS := 4.0
const FOLLOW_DIST := 4.0
const GUARD_RADIUS := 22.0
const BITE_RANGE := 1.8
const BITE_DAMAGE := 10.0

var adopted := false
var age_days := 0.0
## "follow" ya da "stay"
var command := "follow"
var fed_day := -1
var hurt_time := 0.0

var _threat: Node3D
var _bite_cd := 0.0
var _warned_cd := 0.0
var _wag := 0.0
var _sit := 0.0


func _init() -> void:
	species = "dog"
	display_name = "Köpek"
	max_health = 60.0
	walk_speed = 2.2
	run_speed = 8.0
	drops = {}
	wander_radius = 6.0
	graze_angle = -0.4


func _ready() -> void:
	super._ready()
	add_to_group("dog")
	TimeOfDay.day_changed.connect(_on_new_day)


func growth() -> float:
	return clampf(0.45 + 0.55 * age_days / ADULT_DAYS, 0.45, 1.0)


func is_adult() -> bool:
	return age_days >= ADULT_DAYS


func is_hungry() -> bool:
	return adopted and fed_day < TimeOfDay.day


func is_threat() -> bool:
	return false


func think(delta: float, player: Player, dist: float) -> void:
	_bite_cd -= delta
	_warned_cd -= delta
	if hurt_time > 0.0:
		hurt_time -= delta
		stop()
		health = minf(max_health, health + delta * 2.0)
		return
	if not adopted:
		_stray(delta, player, dist)
		return
	_threat = _find_threat(player)
	if _threat:
		_guard(delta, player)
		return
	if command == "stay":
		stop()
		if player:
			face(player.global_position, delta)
		return
	_follow(delta, player, dist)


## Sahipsiz yavru: olduğu yerde dolaşır, arada inler; oyuncu yaklaşınca kuyruk sallar.
func _stray(delta: float, player: Player, dist: float) -> void:
	if player and dist < 6.0:
		stop()
		face(player.global_position, delta)
		_wag = 1.0
		return
	vocal("dog_whine", rng.randf_range(7.0, 12.0), 2.0, 45.0)
	wander(delta)


func _follow(delta: float, player: Player, dist: float) -> void:
	if player == null:
		return
	# Sal ya da yüzme: kıyıda bekler.
	if player.vehicle or player.is_swimming:
		stop()
		face(player.global_position, delta)
		return
	if dist > 45.0 and _same_world(player):
		_teleport_near(player)
		return
	if dist > FOLLOW_DIST:
		var behind := player.global_position + player.global_transform.basis.z * 2.0
		move_to(behind, run_speed if dist > 12.0 else walk_speed * 1.6)
		face(global_position + _move_dir, delta)
	else:
		stop()
		_wag = 1.0
		face(player.global_position, delta)


## Tehlike varken: yavru havlayıp sahibinin yanında kalır; yetişkin saldırana atılır.
func _guard(delta: float, player: Player) -> void:
	vocal("dog_bark" if is_adult() else "puppy_yip", 1.6, 6.0, 60.0)
	if _warned_cd <= 0.0 and player:
		_warned_cd = 60.0
		player.notify(tr("Köpeğin havlıyor: yakında tehlike var!"))
	var tpos := _threat.global_position
	if not is_adult() or health < max_health * 0.3:
		_follow(delta, player, global_position.distance_to(player.global_position))
		face(tpos, delta)
		return
	var d := global_position.distance_to(tpos)
	if d > BITE_RANGE:
		move_to(tpos, run_speed)
		face(tpos, delta)
	else:
		stop()
		face(tpos, delta)
		if _bite_cd <= 0.0 and _threat.has_method("take_hit"):
			_bite_cd = 1.2
			_threat.take_hit(BITE_DAMAGE, self)
			Sfx.play_at("bite", tpos + Vector3.UP * 0.5, 0.0, 25.0)


## Oyuncunun yakınındaki, saldırgan durumdaki ya da çok yakın tehlikeli hayvan.
func _find_threat(player: Player) -> Node3D:
	if player == null:
		return null
	var best: Node3D = null
	var best_d := GUARD_RADIUS
	for group in ["hostile", "snake"]:
		for a in get_tree().get_nodes_in_group(group):
			if a == self or not a.is_alive():
				continue
			var d: float = a.global_position.distance_to(player.global_position)
			var active: bool = a.state in [State.STALK, State.CHASE, State.ATTACK, State.ALERT]
			if d < best_d and (active or d < 10.0):
				best_d = d
				best = a
	return best


func take_hit(damage: float, attacker: Node3D) -> void:
	# Oyuncunun yanlışlıkla vuruşları ve okları köpeğe işlemez.
	if attacker is Player or hurt_time > 0.0:
		vocal("dog_whine", 1.0, 2.0, 30.0)
		return
	health -= damage
	_flash = 1.0
	vocal("dog_whine", 0.8, 4.0, 40.0)
	if health <= 0.0:
		health = 1.0
		hurt_time = 60.0
		var p := _player()
		if p:
			p.notify(tr("Köpeğin yaralandı! Bir süre dinlenecek."))


func get_interaction(player: Player, _shape_idx: int) -> Dictionary:
	var food := _food_in(player)
	if not adopted:
		if food == "":
			return {"text": tr("Kaybolmuş bir yavru köpek. Aç görünüyor: et ya da balık ver.")}
		return {"text": tr("Yavruyu besle ve sahiplen"), "action": _feed.bind(player, food)}
	if hurt_time > 0.0:
		return {"text": tr("Köpeğin yaralı, dinleniyor (%d sn)") % int(hurt_time)}
	if is_hungry() and food != "":
		return {"text": tr("Köpeği besle"), "action": _feed.bind(player, food)}
	if command == "follow":
		return {"text": tr("Köpek: otur"), "action": _set_command.bind("stay")}
	return {"text": tr("Köpek: takip et"), "action": _set_command.bind("follow")}


func _food_in(player: Player) -> String:
	for id in FOODS:
		if player.inventory.has(id):
			return id
	return ""


func _feed(player: Player, food: String) -> void:
	if not player.inventory.remove(food, 1):
		return
	fed_day = TimeOfDay.day
	health = max_health
	_wag = 1.0
	Sfx.play_at("puppy_yip" if not is_adult() else "dog_bark", global_position, 0.0, 30.0)
	if not adopted:
		adopted = true
		home = global_position
		add_to_group("pet")
		player.notify(tr("Yavru köpeği sahiplendin! Her gün beslersen büyür ve seni korur."))
	else:
		player.notify(tr("Köpeğin karnı doydu."))


func _set_command(c: String) -> void:
	command = c
	_wag = 1.0


func _on_new_day(_day: int) -> void:
	# Beslenen köpek büyür; aç kalırsa büyümez.
	if adopted and fed_day >= TimeOfDay.day - 1:
		age_days += 1.0


func _same_world(player: Player) -> bool:
	var w := GameState.world
	return w == null or w.is_underground(player.global_position) == w.is_underground(global_position)


func _teleport_near(player: Player) -> void:
	var p := player.global_position - player.global_transform.basis.z * -2.0
	global_position = p + Vector3.UP * 0.3
	var w := GameState.world
	indoor = w != null and w.is_underground(player.global_position)


## Mağara geçişlerinde sahibiyle birlikte gelir.
func follow_through(player: Player) -> void:
	if adopted and command == "follow":
		_teleport_near(player)
		home = global_position


func _walkable(p: Vector3) -> bool:
	return indoor or super._walkable(p)


func _animate(delta: float) -> void:
	super._animate(delta)
	_wag = maxf(0.0, _wag - delta * 0.3)
	if _tail:
		_tail.rotation.y = sin(Time.get_ticks_msec() * 0.025) * (0.2 + _wag * 0.7)
	var sitting := (command == "stay" and adopted) or hurt_time > 0.0
	_sit = lerpf(_sit, 1.0 if sitting else 0.0, clampf(delta * 4.0, 0.0, 1.0))
	if model:
		model.scale = Vector3.ONE * growth() * (1.0 + _flash * 0.08)
		model.rotation.x += _sit * 0.35
		model.position.y -= _sit * 0.12 * growth()


func save_state() -> Dictionary:
	var d := super.save_state()
	d.merge({"adopted": adopted, "age": age_days, "command": command, "fed": fed_day, "hurt": hurt_time})
	return d


func load_state(d: Dictionary) -> void:
	super.load_state(d)
	adopted = bool(d.get("adopted", false))
	age_days = float(d.get("age", 0.0))
	command = str(d.get("command", "follow"))
	fed_day = int(d.get("fed", -1))
	hurt_time = float(d.get("hurt", 0.0))
	if adopted:
		add_to_group("pet")


func _build_shape() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.2
	capsule.height = 0.8
	shape.shape = capsule
	shape.rotation.x = PI * 0.5
	shape.position.y = 0.4
	add_child(shape)


func _build_model() -> Node3D:
	var root := Node3D.new()
	var coats := [Color(0.78, 0.58, 0.32), Color(0.2, 0.18, 0.17), Color(0.55, 0.38, 0.25)]
	var fur: Color = coats[rng.randi() % coats.size()]
	var light := Color(0.92, 0.88, 0.8)
	var dark := Color(0.1, 0.08, 0.07)
	_blob(root, Vector3(0, 0.55, -0.12), Vector3(0.28, 0.32, 0.42), fur)
	_blob(root, Vector3(0, 0.53, 0.16), Vector3(0.24, 0.27, 0.36), fur)
	_blob(root, Vector3(0, 0.45, -0.18), Vector3(0.18, 0.14, 0.3), light)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.66, -0.32)
	root.add_child(_head)
	_blob(_head, Vector3(0, 0.08, -0.08), Vector3(0.2, 0.19, 0.2), fur)
	_seg(_head, Vector3(0, 0.05, -0.15), Vector3(0, 0.02, -0.3), 0.06, 0.045, light)
	_blob(_head, Vector3(0, 0.03, -0.31), Vector3(0.05, 0.04, 0.03), dark)
	for side in [-1.0, 1.0]:
		# Sarkık kulaklar.
		_blob(_head, Vector3(0.1 * side, 0.08, -0.04), Vector3(0.05, 0.13, 0.08), fur.darkened(0.25), Vector3(0, 0, 0.3 * side))
		_blob(_head, Vector3(0.05 * side, 0.12, -0.17), Vector3(0.025, 0.025, 0.02), dark)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.6, 0.32)
	root.add_child(_tail)
	_seg(_tail, Vector3.ZERO, Vector3(0, 0.16, 0.18), 0.04, 0.02, fur)
	for side in [-1.0, 1.0]:
		_leg2(root, Vector3(0.08 * side, 0.45, -0.2), 0.22, 0.22, 0.03, fur, light, true)
	for side in [-1.0, 1.0]:
		_leg2(root, Vector3(0.08 * side, 0.47, 0.22), 0.23, 0.22, 0.033, fur, light, false)
	return root
