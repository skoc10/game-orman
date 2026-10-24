class_name MeshFactory
extends RefCounted
## Yer tutucu low-poly modeller ve ortak malzemeler. Sanat geçişinde (adım 9)
## modeller gerçek CC0 paketleriyle değiştirilecek; çağıran kod aynı kalır.

const FLAT_SHADER := preload("res://world/flat.gdshader")
const GRASS_SHADER := preload("res://world/grass.gdshader")

const BARK := Color(0.36, 0.24, 0.15)
const PINE_LEAVES := Color(0.17, 0.36, 0.20)
const LEAFY_LEAVES := Color(0.30, 0.50, 0.22)
const BIRCH_BARK := Color(0.85, 0.83, 0.78)
const BIRCH_LEAVES := Color(0.47, 0.62, 0.26)
const ROCK := Color(0.47, 0.46, 0.44)

static var _materials := {}
static var _meshes := {}


static func flat_material(color: Color, sway := 0.0, roughness := 0.9) -> ShaderMaterial:
	var key := "%s|%.2f|%.2f" % [color.to_html(), sway, roughness]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = FLAT_SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("roughness", roughness)
	_materials[key] = m
	return m


## Kendi rengini taşıyan, ışık saçan malzeme (ateş, meşale alevi).
static func glow_material(color: Color, energy: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLAT_SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("emission", color)
	m.set_shader_parameter("emission_energy", energy)
	return m


## [mesh, transform, material] parçalarını birleştirir. Aynı malzemeli parçalar
## tek yüzeyde toplanır, böylece her model en fazla birkaç çizim çağrısı yapar.
static func combine(parts: Array) -> ArrayMesh:
	var tools := {}
	var order: Array = []
	for part in parts:
		var mat: Material = part[2]
		if not tools.has(mat):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[mat] = st
			order.append(mat)
		(tools[mat] as SurfaceTool).append_from(part[0], 0, part[1])
	var mesh := ArrayMesh.new()
	for mat in order:
		var st: SurfaceTool = tools[mat]
		st.set_material(mat)
		st.commit(mesh)
	return mesh


static func cylinder(top: float, bottom: float, height: float, segments := 7) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	c.rings = 0
	return c


static func sphere(radius: float, segments := 7, rings := 4) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = segments
	s.rings = rings
	return s


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func at(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled(scl), pos)


static func pine_tree() -> ArrayMesh:
	return _cached("pine", func() -> ArrayMesh:
		var leaves := flat_material(PINE_LEAVES, 1.0)
		return combine([
			[cylinder(0.12, 0.22, 2.2), at(Vector3(0, 1.1, 0)), flat_material(BARK)],
			[cylinder(0.0, 1.7, 2.6), at(Vector3(0, 2.7, 0)), leaves],
			[cylinder(0.0, 1.35, 2.3), at(Vector3(0, 3.75, 0)), leaves],
			[cylinder(0.0, 0.95, 2.0), at(Vector3(0, 4.7, 0)), leaves],
		]))


static func leafy_tree() -> ArrayMesh:
	return _cached("leafy", func() -> ArrayMesh:
		var leaves := flat_material(LEAFY_LEAVES, 0.8)
		return combine([
			[cylinder(0.15, 0.26, 3.0), at(Vector3(0, 1.5, 0)), flat_material(BARK)],
			[sphere(1.8, 7, 4), at(Vector3(0, 3.7, 0)), leaves],
			[sphere(1.3, 6, 3), at(Vector3(0.9, 3.1, 0.4)), leaves],
			[sphere(1.2, 6, 3), at(Vector3(-0.8, 3.3, -0.5)), leaves],
		]))


static func birch_tree() -> ArrayMesh:
	return _cached("birch", func() -> ArrayMesh:
		var leaves := flat_material(BIRCH_LEAVES, 0.9)
		return combine([
			[cylinder(0.09, 0.14, 4.2), at(Vector3(0, 2.1, 0)), flat_material(BIRCH_BARK)],
			[sphere(1.2, 6, 3), at(Vector3(0, 4.3, 0)), leaves],
			[sphere(0.9, 6, 3), at(Vector3(0.4, 3.5, 0.2)), leaves],
		]))


static func rock() -> ArrayMesh:
	return _cached("rock", func() -> ArrayMesh:
		return combine([[sphere(1.0, 6, 3), at(Vector3.ZERO), flat_material(ROCK, 0.0, 1.0)]]))


static func stump() -> ArrayMesh:
	return _cached("stump", func() -> ArrayMesh:
		return combine([
			[cylinder(0.2, 0.26, 0.5), at(Vector3(0, 0.25, 0)), flat_material(BARK)],
			[cylinder(0.19, 0.19, 0.02), at(Vector3(0, 0.51, 0)), flat_material(Color(0.72, 0.58, 0.38))],
		]))


## Yatay kütük, merkezi orijinde ve X ekseni boyunca uzanır.
static func log_mesh(length := 2.0, radius := 0.2) -> ArrayMesh:
	return _cached("log_%.2f_%.2f" % [length, radius], func() -> ArrayMesh:
		return combine([
			[cylinder(radius, radius, length), at(Vector3.ZERO, Vector3(0, 0, PI * 0.5)), flat_material(BARK)],
		]))


## Birkaç ince üçgenden oluşan çimen öbeği.
static func grass_tuft() -> ArrayMesh:
	return _cached("grass", func() -> ArrayMesh:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 6:
			var a := rng.randf() * TAU
			var r := rng.randf_range(0.0, 0.18)
			var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
			var side := Vector3(cos(a + PI * 0.5), 0.0, sin(a + PI * 0.5)) * 0.06
			var h := rng.randf_range(0.35, 0.6)
			var lean := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.05, 0.15)
			st.add_vertex(base - side)
			st.add_vertex(base + Vector3(0, h, 0) + lean)
			st.add_vertex(base + side)
		var mesh := st.commit()
		var mat := ShaderMaterial.new()
		mat.shader = GRASS_SHADER
		mesh.surface_set_material(0, mat)
		return mesh)


static func _cached(key: String, maker: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		_meshes[key] = maker.call()
	return _meshes[key]
