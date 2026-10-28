class_name Villager
extends AnimalBase
## Yerli köylü: köyün içinde dolaşır, ateşin başında oturur, selam verir.
## Şef yerinde durur; onunla konuşunca takas ekranı açılır. Köylüler barışçıldır,
## zarar görmez ve kayda girmez (köy her açılışta tohumdan kurulur).

const GREETINGS := [
	"Hoş geldin, yabancı. Ormanda yalnız kalmak zordur.",
	"Takas için şefle konuş.",
	"Kurtlar ateşimize yaklaşmaz. Geceyi burada geçirebilirsin.",
	"Gölde timsah var, suya dikkat et.",
	"Ayı ininden uzak dur.",
	"Denizden iyi balık çıkar; salın varsa açığa git.",
	"Misafir çadırında uyuyabilirsin.",
]

var is_chief := false
var village: Node3D

var _arms: Array[Node3D] = []
var _greet_cd := 0.0


func _init() -> void:
	species = "villager"
	display_name = "Yerli"
	max_health = 100.0
	walk_speed = 1.3
	run_speed = 3.5
	drops = {}
	wander_radius = 9.0
	bound_height = 0.0


func _ready() -> void:
	super._ready()
	# Köy tohumdan yeniden kurulur; köylüler kayda yazılmaz.
	remove_from_group("persist_dynamic")
	remove_from_group("animal")
	add_to_group("villager")


func is_threat() -> bool:
	return false


func think(delta: float, player: Player, dist: float) -> void:
	_greet_cd -= delta
	if player and dist < 4.0:
		stop()
		face(player.global_position, delta)
		if dist < 2.5 and _greet_cd <= 0.0 and not is_chief:
			_greet_cd = 40.0
		return
	if is_chief:
		stop()
		if village:
			face(village.global_position, delta)
		return
	wander(delta)


func take_hit(_damage: float, attacker: Node3D) -> void:
	if attacker is Player:
		(attacker as Player).notify(tr("%s: \"Hey! Biz dostuz!\"") % display_name)
	_flash = 1.0


func get_interaction(player: Player, _shape_idx: int) -> Dictionary:
	if is_chief:
		return {"text": tr("Şef %s ile takas yap") % display_name, "action": _open_trade}
	return {"text": tr("%s ile konuş") % display_name, "action": _talk.bind(player)}


func _talk(player: Player) -> void:
	player.notify("%s: \"%s\"" % [display_name, tr(GREETINGS[rng.randi() % GREETINGS.size()])])


func _open_trade() -> void:
	var screen := GameState.world.get_node_or_null("TradeScreen") if GameState.world else null
	if screen:
		screen.open(self)


func _walkable(p: Vector3) -> bool:
	if village and not village.contains(p):
		return false
	return super._walkable(p)


func _far_update(_delta: float) -> void:
	pass


func _animate(delta: float) -> void:
	super._animate(delta)
	# Kollar bacaklara ters sallanır.
	var speed := Vector2(velocity.x, velocity.z).length()
	for i in _arms.size():
		_arms[i].rotation.x = -sin(_anim_t + (PI if i == 0 else 0.0)) * clampf(speed / 2.0, 0.0, 0.6)
	if model:
		model.rotation.x = 0.0


func _build_shape() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.88
	add_child(shape)


func _build_model() -> Node3D:
	var root := Node3D.new()
	var skins := [Color(0.62, 0.42, 0.3), Color(0.52, 0.35, 0.24), Color(0.7, 0.5, 0.36)]
	var tunics := [Color(0.62, 0.45, 0.28), Color(0.5, 0.36, 0.22), Color(0.72, 0.58, 0.4)]
	var skin: Color = skins[rng.randi() % skins.size()]
	var tunic: Color = tunics[rng.randi() % tunics.size()]
	var hair := Color(0.08, 0.07, 0.06)
	var trim: Color = [Color(0.7, 0.2, 0.15), Color(0.2, 0.45, 0.6), Color(0.85, 0.7, 0.2)][rng.randi() % 3]
	var h := 1.12 if is_chief else 1.0
	# Gövde: deri tunik ve renkli kemer.
	_blob(root, Vector3(0, 1.15 * h, 0), Vector3(0.42, 0.62, 0.26) * h, tunic)
	_blob(root, Vector3(0, 0.86 * h, 0), Vector3(0.44, 0.08, 0.28) * h, trim)
	_blob(root, Vector3(0, 0.78 * h, 0), Vector3(0.4, 0.22, 0.26) * h, tunic.darkened(0.15))
	# Baş, saç ve örgüler.
	_blob(root, Vector3(0, 1.62 * h, 0), Vector3(0.22, 0.26, 0.23) * h, skin)
	_blob(root, Vector3(0, 1.7 * h, 0.03), Vector3(0.24, 0.16, 0.25) * h, hair)
	for side in [-1.0, 1.0]:
		_seg(root, Vector3(0.1 * side, 1.62, 0.05) * h, Vector3(0.12 * side, 1.25, 0.08) * h, 0.03 * h, 0.02 * h, hair)
		_blob(root, Vector3(0.055 * side, 1.64 * h, -0.105 * h), Vector3(0.03, 0.03, 0.02), hair)
	if is_chief:
		# Şefin tüylü başlığı.
		for k in 7:
			var a := -0.9 + k * 0.3
			_seg(root, Vector3(sin(a) * 0.12, 1.76, cos(a) * 0.06 + 0.04) * h, Vector3(sin(a) * 0.3, 2.15, cos(a) * 0.12 + 0.1) * h, 0.03, 0.01, Color(0.95, 0.93, 0.88) if k % 2 == 0 else trim)
	# Kollar ve bacaklar (pivotlar; yürürken sallanır).
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.25 * side, 1.4, 0) * h
		root.add_child(arm)
		_seg(arm, Vector3.ZERO, Vector3(0.03 * side, -0.55, 0) * h, 0.06 * h, 0.05 * h, tunic)
		_blob(arm, Vector3(0.03 * side, -0.6, 0) * h, Vector3(0.08, 0.09, 0.08) * h, skin)
		_arms.append(arm)
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.1 * side, 0.7, 0) * h
		root.add_child(leg)
		_seg(leg, Vector3.ZERO, Vector3(0, -0.66, 0) * h, 0.07 * h, 0.06 * h, tunic.darkened(0.3))
		_blob(leg, Vector3(0, -0.68, -0.04) * h, Vector3(0.1, 0.06, 0.18) * h, Color(0.35, 0.24, 0.15))
		_legs.append(leg)
	return root
