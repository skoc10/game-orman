class_name TreeField
extends Node3D
## Adadaki tüm ağaçlar. Görüntü 64 m'lik parçalara bölünmüş MultiMesh'lerle
## çizilir; her ağacın sabit bir kimliği ve çarpışma şekli vardır. Baltayla
## kesilen ağaç devrilir, yerinde kütük kalır ve kütük/dal düşürür.

signal tree_felled(id: int)

const CHUNK_SIZE := 64.0
const CHUNKS := 8
const VIEW_DISTANCE := 260.0
const SPACING := 4.2
const TREE_HP := 100.0
## Tür başına düşen kütük sayısı.
const LOGS := [3, 3, 2]

enum Kind { PINE, LEAFY, BIRCH }

const TreeChunkBody := preload("res://world/tree_chunk_body.gd")

var positions := PackedVector3Array()
var kinds := PackedInt32Array()
var scales := PackedFloat32Array()
var yaws := PackedFloat32Array()

var health := PackedFloat32Array()
## Kesilen ağaç kimlikleri.
var felled := {}

var _meshes: Array[Mesh] = []
var _shapes := {}
var _stumps: Node3D
## (parça * tür sayısı + tür) -> MultiMesh
var _multimeshes := {}
## Ağaç kimliği -> MultiMesh içindeki sıra
var _slot := PackedInt32Array()
var _bodies := {}


func build(gen: WorldGen, spawn: Vector3) -> void:
	_meshes = [MeshFactory.pine_tree(), MeshFactory.leafy_tree(), MeshFactory.birch_tree()]
	_scatter(gen, spawn)
	health.resize(positions.size())
	health.fill(TREE_HP)
	_build_chunks()
	_stumps = Node3D.new()
	_stumps.name = "Stumps"
	add_child(_stumps)


func count() -> int:
	return positions.size()


func tree_transform(id: int) -> Transform3D:
	var s := scales[id]
	return Transform3D(Basis(Vector3.UP, yaws[id]).scaled(Vector3(s, s, s)), positions[id])


static func chunk_index(p: Vector3) -> int:
	var cx := clampi(int((p.x + WorldGen.HALF) / CHUNK_SIZE), 0, CHUNKS - 1)
	var cz := clampi(int((p.z + WorldGen.HALF) / CHUNK_SIZE), 0, CHUNKS - 1)
	return cz * CHUNKS + cx


static func chunk_center(index: int) -> Vector3:
	var cx := index % CHUNKS
	var cz := index / CHUNKS
	return Vector3((cx + 0.5) * CHUNK_SIZE - WorldGen.HALF, 0.0, (cz + 0.5) * CHUNK_SIZE - WorldGen.HALF)


func _scatter(gen: WorldGen, spawn: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = gen.seed_value + 100
	var n := int(WorldGen.SIZE / SPACING)
	for gz in n:
		for gx in n:
			# Tüm rastgele değerler önce çekilir; böylece eleme sonucu ne olursa olsun dizi aynı kalır.
			var x := -WorldGen.HALF + (gx + rng.randf()) * SPACING
			var z := -WorldGen.HALF + (gz + rng.randf()) * SPACING
			var roll := rng.randf()
			var kind_roll := rng.randf()
			var s := rng.randf_range(0.8, 1.3)
			var yaw := rng.randf() * TAU
			if not gen.is_land(x, z, 1.0) or gen.slope_at(x, z) > 0.45:
				continue
			var density := gen.forest_density(x, z)
			if roll > smoothstep(0.2, 0.75, density) * 0.85:
				continue
			if Vector2(x - spawn.x, z - spawn.z).length() < 10.0:
				continue
			var kind := Kind.PINE
			if kind_roll > 0.88:
				kind = Kind.BIRCH
			elif kind_roll > 0.6:
				kind = Kind.LEAFY
			positions.append(Vector3(x, gen.height_at(x, z) - 0.1, z))
			kinds.append(kind)
			scales.append(s)
			yaws.append(yaw)


func _build_chunks() -> void:
	var groups := {}
	for id in positions.size():
		var key := chunk_index(positions[id]) * Kind.size() + kinds[id]
		if not groups.has(key):
			groups[key] = PackedInt32Array()
		groups[key].append(id)
	_slot.resize(positions.size())

	for key in groups:
		var ids: PackedInt32Array = groups[key]
		var chunk: int = key / Kind.size()
		var center := chunk_center(chunk)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _meshes[key % Kind.size()]
		mm.instance_count = ids.size()
		for i in ids.size():
			var t := tree_transform(ids[i])
			t.origin -= center
			mm.set_instance_transform(i, t)
			_slot[ids[i]] = i
		_multimeshes[key] = mm
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.position = center
		mmi.visibility_range_end = VIEW_DISTANCE
		mmi.visibility_range_end_margin = 20.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)

	for id in positions.size():
		var body := _body_for(chunk_index(positions[id]))
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.3 * scales[id]
		cyl.height = 4.0 * scales[id]
		shape.shape = cyl
		shape.position = positions[id] + Vector3(0, cyl.height * 0.5, 0)
		shape.set_meta("tree_id", id)
		body.add_child(shape)
		_shapes[id] = shape


func interaction_for(id: int, player: Player) -> Dictionary:
	if id < 0 or felled.has(id):
		return {}
	var item := player.equipment.held_item()
	if item and item.chop_power > 0.0:
		return {"text": tr("[Sol tık] Ağacı kes")}
	return {}


## Baltayla vuruş. Can biterse ağaç devrilir.
func hit(id: int, power: float, from: Vector3) -> void:
	if id < 0 or felled.has(id):
		return
	health[id] -= power
	var base := positions[id]
	Effects.burst(get_parent(), base + Vector3(0, 1.2, 0), MeshFactory.BARK.lightened(0.3), 8, 2.5)
	_shake(id)
	if health[id] <= 0.0:
		var dir := Vector3(base.x - from.x, 0.0, base.z - from.z)
		fell(id, dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD)


## Ağacı devirir: görüntüyü gizler, çarpışmayı kapatır, devrilme animasyonundan
## sonra kütük ve dal bırakır.
func fell(id: int, dir: Vector3) -> void:
	_remove(id)
	Sfx.play_at("tree_fall", positions[id] + Vector3.UP * 2.0, 2.0, 90.0, 0.1)
	var falling := MeshInstance3D.new()
	falling.mesh = _meshes[kinds[id]]
	add_child(falling)
	var start := tree_transform(id)
	falling.global_transform = start
	var axis := Vector3.UP.cross(dir).normalized()
	var tw := falling.create_tween()
	tw.tween_method(func(a: float) -> void:
		falling.global_transform = Transform3D(Basis(axis, a) * start.basis, start.origin),
		0.0, PI * 0.47, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_drop_wood(id, dir)
		falling.queue_free())
	tree_felled.emit(id)


## Kayıttan yüklerken animasyonsuz kesilmiş hale getirir.
func apply_felled(ids: Array) -> void:
	for id in ids:
		var i := int(id)
		if i >= 0 and i < positions.size() and not felled.has(i):
			_remove(i)


func felled_ids() -> Array:
	return felled.keys()


func _remove(id: int) -> void:
	felled[id] = true
	health[id] = 0.0
	var key := chunk_index(positions[id]) * Kind.size() + kinds[id]
	var mm: MultiMesh = _multimeshes[key]
	mm.set_instance_transform(_slot[id], Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	(_shapes[id] as CollisionShape3D).disabled = true
	var stump := MeshInstance3D.new()
	stump.mesh = MeshFactory.stump()
	stump.position = positions[id]
	stump.scale = Vector3.ONE * scales[id]
	stump.visibility_range_end = 120.0
	_stumps.add_child(stump)


func _drop_wood(id: int, dir: Vector3) -> void:
	var world := GameState.world
	if world == null:
		return
	var base := positions[id]
	var side := Vector3.UP.cross(dir)
	var yaw := atan2(dir.x, dir.z)
	for i in LOGS[kinds[id]]:
		var p: Vector3 = base + dir * (1.4 + i * 1.6) * scales[id]
		world.spawn_pickup("log", 1, _on_ground(p), -1.0, yaw + PI * 0.5)
	for i in 2:
		var p := base + dir * (2.0 + i * 1.5) * scales[id] + side * (0.8 if i == 0 else -0.8)
		world.spawn_pickup("stick", 1, _on_ground(p), -1.0, yaw)


func _on_ground(p: Vector3) -> Vector3:
	var gen: WorldGen = GameState.world.gen
	return Vector3(p.x, gen.height_at(p.x, p.z), p.z)


func _shake(id: int) -> void:
	var key := chunk_index(positions[id]) * Kind.size() + kinds[id]
	var mm: MultiMesh = _multimeshes[key]
	var slot := _slot[id]
	var center := chunk_center(chunk_index(positions[id]))
	var base := tree_transform(id)
	base.origin -= center
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		if felled.has(id):
			return
		var lean := sin(t * PI * 3.0) * (1.0 - t) * 0.03
		mm.set_instance_transform(slot, Transform3D(Basis(Vector3.RIGHT, lean) * base.basis, base.origin)),
		0.0, 1.0, 0.35)


func _body_for(chunk: int) -> StaticBody3D:
	if not _bodies.has(chunk):
		var body := TreeChunkBody.new()
		body.name = "Trees_%d" % chunk
		body.field = self
		body.collision_layer = 1
		body.collision_mask = 0
		add_child(body)
		_bodies[chunk] = body
	return _bodies[chunk]
