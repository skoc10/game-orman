extends Buildable
## Sal: kıyıya yakın suya kurulur. E ile binilir; hareket tuşları (ya da dokunmatik
## çubuk) bakılan yöne kürek çektirir. Karaya çıkamaz. Saldan olta atılabilir;
## açık denizde daha çok balık vardır. E (elde olta yokken) en yakın kıyıya indirir.

const SPEED := 3.6
const FAST_SPEED := 5.2
const SEAT := Vector3(0, 0.25, 0.3)
## Bu derinlikten sığ yere sal giremez.
const MIN_DEPTH := 0.45

var rider: Player
var _velocity := Vector3.ZERO
var _bob_t := 0.0
var _visual: Node3D


func _ready() -> void:
	recipe_id = "raft"
	footprint = Vector3(2.4, 0.6, 3.0)
	placement = "water"
	_visual = Node3D.new()
	add_child(_visual)
	_build_visuals()
	if is_ghost:
		return
	super._ready()
	add_to_group("raft")
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.3, 0.5, 2.9)
	shape.shape = box
	shape.position.y = 0.1
	add_child(shape)


func get_interaction(player: Player, _shape_idx: int) -> Dictionary:
	if rider:
		return {}
	return {"text": tr("Sala bin"), "action": board.bind(player)}


func board(player: Player) -> void:
	if rider or player.vehicle:
		return
	rider = player
	player.vehicle = self
	player.teleport(seat_position(), rad_to_deg(player.rotation.y))
	player.notify(tr("Saldasın. Hareket tuşlarıyla kürek çek; E ile kıyıya in."))
	Sfx.play("splash", -10.0)


## Saldan iner: yakında kara varsa oraya, yoksa suya.
func leave() -> void:
	if rider == null:
		return
	var p := rider
	rider = null
	p.vehicle = null
	var land := nearest_land(6.0)
	if land != Vector3.INF:
		p.teleport(land + Vector3.UP * 0.1)
	else:
		p.teleport(global_position + global_transform.basis.x * 1.6 + Vector3.UP * 0.2)
		p.notify(tr("Suya indin."))


func seat_position() -> Vector3:
	return global_transform * SEAT


## Binicinin girdisiyle salı sürer. dir: dünya uzayında istenen yön (y = 0).
func drive(dir: Vector3, fast: bool, delta: float) -> void:
	var target := dir * (FAST_SPEED if fast else SPEED)
	_velocity = _velocity.lerp(target, clampf(delta * 1.6, 0.0, 1.0))
	var next := global_position + _velocity * delta
	if not can_float_at(next):
		_velocity = Vector3.ZERO
		return
	global_position = Vector3(next.x, global_position.y, next.z)
	if _velocity.length() > 0.4:
		rotation.y = lerp_angle(rotation.y, atan2(-_velocity.x, -_velocity.z), clampf(delta * 1.5, 0.0, 1.0))


func can_float_at(p: Vector3) -> bool:
	var world := GameState.world
	if world == null:
		return true
	var gen: WorldGen = world.gen
	if Vector2(p.x, p.z).length() > WorldGen.BOUNDARY_RADIUS:
		return false
	return gen.height_at(p.x, p.z) < WorldGen.WATER_LEVEL - MIN_DEPTH


## Yakındaki en yakın kuru kara noktası; yoksa Vector3.INF.
func nearest_land(radius: float) -> Vector3:
	var world := GameState.world
	if world == null:
		return Vector3.INF
	var gen: WorldGen = world.gen
	var best := Vector3.INF
	var best_d := INF
	for r in [1.5, 2.5, 3.5, 4.5, 5.5]:
		if r > radius:
			break
		for k in 16:
			var a := TAU * k / 16.0
			var q: Vector3 = global_position + Vector3(cos(a), 0, sin(a)) * r
			var h := gen.height_at(q.x, q.z)
			if h > WorldGen.WATER_LEVEL + 0.3 and gen.slope_at(q.x, q.z) < 0.4 and r < best_d:
				best_d = r
				best = Vector3(q.x, h, q.z)
		if best != Vector3.INF:
			return best
	return best


func _process(delta: float) -> void:
	if is_ghost:
		return
	_bob_t += delta
	# Su üstünde hafifçe sallanır.
	global_position.y = WorldGen.WATER_LEVEL - 0.05 + sin(_bob_t * 1.3) * 0.04
	_visual.rotation.x = sin(_bob_t * 1.1) * 0.03
	_visual.rotation.z = sin(_bob_t * 0.9 + 1.0) * 0.04
	if rider:
		if not is_instance_valid(rider) or rider.stats.dead:
			rider = null
			return
		rider.global_position = seat_position()


func save_extra() -> Dictionary:
	return {}


func _build_visuals() -> void:
	var parts := []
	var bark := MeshFactory.flat_material(MeshFactory.BARK)
	var light := MeshFactory.flat_material(MeshFactory.BARK.lightened(0.25))
	var rope := MeshFactory.flat_material(Color(0.78, 0.66, 0.45))
	for i in 6:
		var x := -1.0 + i * 0.4
		parts.append([MeshFactory.cylinder(0.18, 0.19, 2.9, 7), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.05, 0)), bark])
	for z in [-1.0, 0.0, 1.0]:
		parts.append([MeshFactory.cylinder(0.07, 0.07, 2.5, 6), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.25, z)), light])
		for i in 6:
			parts.append([MeshFactory.cylinder(0.2, 0.2, 0.06, 7), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-1.0 + i * 0.4, 0.05, z)), rope])
	# Kürek.
	parts.append([MeshFactory.cylinder(0.025, 0.03, 1.7, 5), Transform3D(Basis(Vector3.BACK, 1.2), Vector3(0.75, 0.35, 0.6)), light])
	parts.append([MeshFactory.box(Vector3(0.05, 0.35, 0.16)), Transform3D(Basis(Vector3.BACK, 1.2), Vector3(1.45, 0.05, 0.6)), light])
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.combine(parts)
	_visual.add_child(mi)
