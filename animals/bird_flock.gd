class_name BirdFlock
extends Node3D
## Kuş sürüsü: küçük kuşlar açıklıkta yerde gagalar; oyuncu yaklaşınca kanat
## çırparak havalanır, uzaktaki bir noktaya uçup oraya konar. Martılar kıyıda
## gökyüzünde daireler çizer. Fiziksiz, hafif görsel hayvanlardır.

enum Kind { SONGBIRD, GULL }
enum Mode { GROUND, FLYING, CIRCLING }

const SCARE_RADIUS := 9.0
const FAR := 140.0

var kind: Kind = Kind.SONGBIRD
var count := 5
var mode: Mode = Mode.GROUND

var _birds: Array[Dictionary] = []
var _target := Vector3.ZERO
var _from := Vector3.ZERO
var _flight_t := 0.0
var _flight_len := 1.0
var _circle_center := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _t := 0.0


func _ready() -> void:
	_rng.randomize()
	add_to_group("birds")
	for i in count:
		_birds.append(_make_bird(i))
	if kind == Kind.GULL:
		mode = Mode.CIRCLING
		_circle_center = global_position + Vector3.UP * _rng.randf_range(14.0, 22.0)


func _process(delta: float) -> void:
	var world := GameState.world
	var player: Player = world.player if world else null
	if player and global_position.distance_to(player.global_position) > FAR and mode != Mode.FLYING:
		visible = false
		return
	visible = true
	_t += delta
	match mode:
		Mode.GROUND:
			_update_ground(delta)
			if player and not player.stats.dead:
				var d := global_position.distance_to(player.global_position)
				if d < SCARE_RADIUS * (1.7 if player.is_sprinting else (0.6 if player.is_crouching else 1.0)):
					take_off(player.global_position)
		Mode.FLYING:
			_update_flight(delta)
		Mode.CIRCLING:
			_update_circle(delta)


## Tehditten uzağa havalanır ve 40–80 m ötede yere konar.
func take_off(threat: Vector3) -> void:
	if mode == Mode.FLYING:
		return
	var away := global_position - threat
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	away = away.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))
	var dest := global_position + away * _rng.randf_range(40.0, 80.0)
	var gen: WorldGen = GameState.world.gen if GameState.world else null
	if gen:
		if not gen.is_land(dest.x, dest.z, 0.5):
			dest = global_position - away * 50.0
		dest.y = gen.height_at(dest.x, dest.z)
	_from = global_position
	_target = dest
	_flight_t = 0.0
	_flight_len = _from.distance_to(_target) / 9.0
	mode = Mode.FLYING
	Sfx.play_at("bird_takeoff", global_position + Vector3.UP, -2.0, 35.0, 0.2)


func _update_ground(delta: float) -> void:
	for b in _birds:
		var node: Node3D = b.node
		b.hop -= delta
		if b.hop <= 0.0:
			b.hop = _rng.randf_range(0.6, 2.5)
			b.goal = Vector3(_rng.randf_range(-2.0, 2.0), 0, _rng.randf_range(-2.0, 2.0))
		node.position = node.position.move_toward(b.goal, delta * 0.8)
		node.position.y = absf(sin(_t * 9.0 + b.phase)) * 0.04 * float(node.position.distance_to(b.goal) > 0.05)
		# Gagalama.
		(b.body as Node3D).rotation.x = -0.5 if fmod(_t + b.phase, 1.6) < 0.25 else 0.0
		_flap(b, 0.0)


func _update_flight(delta: float) -> void:
	_flight_t += delta / maxf(_flight_len, 0.1)
	var t := clampf(_flight_t, 0.0, 1.0)
	var arc := sin(t * PI) * clampf(_flight_len * 2.0, 8.0, 18.0)
	var pos := _from.lerp(_target, t) + Vector3.UP * arc
	var dir := _target - _from
	look_at_from_position(pos, pos + Vector3(dir.x, 0, dir.z), Vector3.UP)
	for b in _birds:
		var node: Node3D = b.node
		node.position = b.offset + Vector3(0, sin(_t * 2.0 + b.phase) * 0.3, 0)
		(b.body as Node3D).rotation.x = 0.0
		_flap(b, 1.0)
	if t >= 1.0:
		global_position = _target
		rotation = Vector3.ZERO
		for b in _birds:
			(b.node as Node3D).position = Vector3(_rng.randf_range(-2, 2), 0, _rng.randf_range(-2, 2))
		mode = Mode.GROUND


func _update_circle(delta: float) -> void:
	for i in _birds.size():
		var b := _birds[i]
		var node: Node3D = b.node
		var a: float = _t * 0.25 + b.phase
		var r := 10.0 + i * 3.0
		var p := _circle_center + Vector3(cos(a) * r, sin(_t * 0.5 + b.phase) * 1.5, sin(a) * r)
		node.global_position = p
		node.look_at(p + Vector3(-sin(a), 0, cos(a)), Vector3.UP)
		_flap(b, 0.4 + 0.6 * float(fmod(_t + b.phase, 4.0) < 1.5))


func _flap(b: Dictionary, amount: float) -> void:
	var angle := sin(_t * 22.0 + b.phase) * 0.9 * amount + (0.0 if amount > 0.0 else 1.2)
	(b.wing_l as Node3D).rotation.z = angle
	(b.wing_r as Node3D).rotation.z = -angle


func _make_bird(i: int) -> Dictionary:
	var gull := kind == Kind.GULL
	var s := 1.6 if gull else 1.0
	var body_col: Color = Color(0.92, 0.92, 0.9) if gull else [Color(0.45, 0.32, 0.22), Color(0.3, 0.3, 0.32), Color(0.6, 0.45, 0.25)][i % 3]
	var wing_col: Color = Color(0.55, 0.57, 0.6) if gull else (body_col as Color).darkened(0.25)
	var node := Node3D.new()
	node.position = Vector3(_rng.randf_range(-2, 2), 0, _rng.randf_range(-2, 2))
	add_child(node)
	var body := Node3D.new()
	body.position.y = 0.06 * s
	node.add_child(body)
	_mesh(body, MeshFactory.sphere(0.5, 6, 4), Transform3D(Basis().scaled(Vector3(0.07, 0.07, 0.14) * s), Vector3.ZERO), body_col)
	_mesh(body, MeshFactory.sphere(0.5, 6, 4), Transform3D(Basis().scaled(Vector3(0.06, 0.06, 0.06) * s), Vector3(0, 0.04, -0.07) * s), body_col)
	_mesh(body, MeshFactory.cylinder(0.0, 0.012 * s, 0.04 * s, 4), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.04, -0.115) * s), Color(0.9, 0.65, 0.15))
	var wl := Node3D.new()
	wl.position = Vector3(-0.03, 0.02, 0) * s
	body.add_child(wl)
	_mesh(wl, MeshFactory.box(Vector3(0.16, 0.01, 0.07) * s), Transform3D(Basis(), Vector3(-0.08, 0, 0) * s), wing_col)
	var wr := Node3D.new()
	wr.position = Vector3(0.03, 0.02, 0) * s
	body.add_child(wr)
	_mesh(wr, MeshFactory.box(Vector3(0.16, 0.01, 0.07) * s), Transform3D(Basis(), Vector3(0.08, 0, 0) * s), wing_col)
	return {
		"node": node, "body": body, "wing_l": wl, "wing_r": wr,
		"phase": _rng.randf() * TAU, "hop": _rng.randf() * 2.0, "goal": node.position,
		"offset": Vector3(_rng.randf_range(-2.5, 2.5), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-2.5, 2.5)),
	}


func _mesh(parent: Node3D, mesh: Mesh, xform: Transform3D, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = MeshFactory.flat_material(color)
	mi.transform = xform
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
