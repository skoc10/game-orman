class_name IslandTerrain
extends Node3D
## WorldGen yükseklik ızgarasından parça parça arazi mesh'i ve çarpışması üretir.
## Renkler köşe başına hesaplanır (kum, çamur, çimen, toprak, kaya).

const CHUNK_CELLS := 32
const CHUNKS := WorldGen.RES / CHUNK_CELLS

const SAND := Color(0.86, 0.78, 0.55)
const SAND_DARK := Color(0.78, 0.70, 0.48)
const SEABED := Color(0.60, 0.55, 0.40)
const MUD := Color(0.38, 0.33, 0.24)
const GRASS_A := Color(0.24, 0.44, 0.14)
const GRASS_B := Color(0.38, 0.54, 0.17)
const FOREST_FLOOR := Color(0.20, 0.30, 0.12)
const DIRT := Color(0.42, 0.33, 0.22)
const STONE := Color(0.46, 0.45, 0.43)

var gen: WorldGen


func build(p_gen: WorldGen) -> void:
	gen = p_gen
	var colors := _vertex_colors()
	var mat := MeshFactory.flat_material(Color.WHITE, 0.0, 0.95)
	for cz in CHUNKS:
		for cx in CHUNKS:
			_build_chunk(cx, cz, colors, mat)


func _build_chunk(cx: int, cz: int, colors: PackedColorArray, mat: Material) -> void:
	var n := CHUNK_CELLS + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var cols := PackedColorArray()
	var indices := PackedInt32Array()
	verts.resize(n * n)
	normals.resize(n * n)
	cols.resize(n * n)
	var x0 := cx * CHUNK_CELLS
	var z0 := cz * CHUNK_CELLS
	for j in n:
		for i in n:
			var k := j * n + i
			var p := gen.vertex_pos(x0 + i, z0 + j)
			verts[k] = p
			normals[k] = gen.normal_at(p.x, p.z)
			cols[k] = colors[(z0 + j) * WorldGen.VERTS + x0 + i]
	# Üçgenler WorldGen.height_at ile aynı biçimde bölünür; Godot'da ön yüz saat yönüdür.
	for j in CHUNK_CELLS:
		for i in CHUNK_CELLS:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			indices.append_array([a, b, d, a, d, c])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.name = "Chunk_%d_%d" % [cx, cz]
	mi.mesh = mesh
	add_child(mi)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("terrain")
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	mi.add_child(body)


func _vertex_colors() -> PackedColorArray:
	var cols := PackedColorArray()
	cols.resize(WorldGen.VERTS * WorldGen.VERTS)
	for iz in WorldGen.VERTS:
		for ix in WorldGen.VERTS:
			cols[iz * WorldGen.VERTS + ix] = _color_for(ix, iz)
	return cols


func _color_for(ix: int, iz: int) -> Color:
	var p := gen.vertex_pos(ix, iz)
	var h := p.y
	var slope := 1.0 - gen.normal_at(p.x, p.z).y
	var t := gen.tint_at(p.x, p.z)
	var fresh := gen.is_fresh_water(p.x, p.z)
	var c: Color
	if h < -0.4:
		c = MUD if fresh else SEABED
	elif h < 1.1 and not fresh:
		c = SAND.lerp(SAND_DARK, t)
	elif h < 0.6:
		c = MUD
	elif slope > 0.42:
		c = STONE
	elif slope > 0.26:
		c = DIRT.lerp(STONE, (slope - 0.26) / 0.16 * 0.5)
	else:
		c = GRASS_A.lerp(GRASS_B, t)
		c = c.lerp(FOREST_FLOOR, gen.forest_density(p.x, p.z) * 0.65)
	# Komşu köşeler arasında hafif renk oynaması low-poly dokusunu belirginleştirir.
	var jitter := (fposmod(sin(ix * 12.9898 + iz * 78.233) * 43758.5453, 1.0) - 0.5) * 0.06
	return Color(c.r + jitter, c.g + jitter, c.b + jitter * 0.5)
