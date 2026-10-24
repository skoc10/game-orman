class_name TreeField
extends Node3D
## Adadaki tüm ağaçlar. Görüntü 64 m'lik parçalara bölünmüş MultiMesh'lerle
## çizilir; her ağacın sabit bir kimliği ve çarpışma şekli vardır.

const CHUNK_SIZE := 64.0
const CHUNKS := 8
const VIEW_DISTANCE := 260.0
const SPACING := 4.2

enum Kind { PINE, LEAFY, BIRCH }

const TreeChunkBody := preload("res://world/tree_chunk_body.gd")

var positions := PackedVector3Array()
var kinds := PackedInt32Array()
var scales := PackedFloat32Array()
var yaws := PackedFloat32Array()

var _meshes: Array[Mesh] = []
## (parça * tür sayısı + tür) -> MultiMesh
var _multimeshes := {}
## Ağaç kimliği -> MultiMesh içindeki sıra
var _slot := PackedInt32Array()
var _bodies := {}


func build(gen: WorldGen, spawn: Vector3) -> void:
	_meshes = [MeshFactory.pine_tree(), MeshFactory.leafy_tree(), MeshFactory.birch_tree()]
	_scatter(gen, spawn)
	_build_chunks()


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
