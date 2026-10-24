class_name WorldGen
extends RefCounted
## Tohuma bağlı prosedürel ada. Aynı tohum her zaman aynı araziyi, gölü ve
## dereyi üretir. Sahneden bağımsızdır; arazi, bitki ve hayvan yerleşimi bunu kullanır.

const SIZE := 512.0
const HALF := SIZE * 0.5
const CELL := 2.0
const RES := 256
const VERTS := RES + 1
const WATER_LEVEL := 0.0
const ISLAND_RADIUS := 215.0
## Oyuncunun açılabileceği en uzak mesafe (merkezden).
const BOUNDARY_RADIUS := 270.0

var seed_value := 0
var heights := PackedFloat32Array()
var lake_center := Vector2.ZERO
var lake_radius := 24.0
## Dere orta çizgisi: gölden denize.
var stream := PackedVector2Array()

var _hill: FastNoiseLite
var _detail: FastNoiseLite
var _coast: FastNoiseLite
var _forest: FastNoiseLite
var _tint: FastNoiseLite
var _shore: FastNoiseLite


func _init(p_seed: int) -> void:
	seed_value = p_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	_hill = _make_noise(p_seed, 0.0045, 4)
	_detail = _make_noise(p_seed + 1, 0.035, 2)
	_coast = _make_noise(p_seed + 2, 0.009, 3)
	_forest = _make_noise(p_seed + 3, 0.012, 3)
	_tint = _make_noise(p_seed + 4, 0.06, 1)
	_shore = _make_noise(p_seed + 5, 0.02, 2)
	var angle := rng.randf() * TAU
	lake_center = Vector2(cos(angle), sin(angle)) * rng.randf_range(45.0, 80.0)
	lake_radius = rng.randf_range(20.0, 27.0)
	_build_stream(rng, angle)
	_build_heights()


## Izgaradan, mesh üçgenleriyle birebir aynı biçimde yükseklik okur.
func height_at(x: float, z: float) -> float:
	var gx := clampf((x + HALF) / CELL, 0.0, RES - 0.0001)
	var gz := clampf((z + HALF) / CELL, 0.0, RES - 0.0001)
	var ix := int(gx)
	var iz := int(gz)
	var fx := gx - ix
	var fz := gz - iz
	var i := iz * VERTS + ix
	var h00 := heights[i]
	var h10 := heights[i + 1]
	var h01 := heights[i + VERTS]
	var h11 := heights[i + VERTS + 1]
	if fx >= fz:
		return h00 + fx * (h10 - h00) + fz * (h11 - h10)
	return h00 + fz * (h01 - h00) + fx * (h11 - h01)


func normal_at(x: float, z: float) -> Vector3:
	var e := CELL * 0.5
	var dx := height_at(x + e, z) - height_at(x - e, z)
	var dz := height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


## 0 düz, 1 dikey.
func slope_at(x: float, z: float) -> float:
	return 1.0 - normal_at(x, z).y


func is_land(x: float, z: float, margin := 0.4) -> bool:
	return height_at(x, z) > WATER_LEVEL + margin


func is_water(x: float, z: float) -> bool:
	return height_at(x, z) < WATER_LEVEL


## Göl ya da dere suyu içilebilir; deniz suyu tuzludur.
func is_fresh_water(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	if p.length() > ISLAND_RADIUS * 0.85:
		return false
	return lake_distance(p) < 1.4 or distance_to_stream(p) < 9.0


## Göl merkezine uzaklığın, o yöndeki kıyı yarıçapına oranı (1 = kıyı çizgisi civarı).
func lake_distance(p: Vector2) -> float:
	var offset := p - lake_center
	var dir := offset.normalized() if offset.length() > 0.001 else Vector2.RIGHT
	var r := lake_radius * (1.0 + 0.3 * _shore.get_noise_2d(dir.x * 60.0, dir.y * 60.0))
	return offset.length() / r


func distance_to_stream(p: Vector2) -> float:
	var best := INF
	for i in stream.size() - 1:
		var c := Geometry2D.get_closest_point_to_segment(p, stream[i], stream[i + 1])
		best = minf(best, c.distance_to(p))
	return best


## 0..1 orman yoğunluğu. Göl ve dere çevresi açıklık kalır.
func forest_density(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := _forest.get_noise_2d(x, z) * 0.5 + 0.55
	var clearing := smoothstep(1.3, 2.2, lake_distance(p))
	clearing = minf(clearing, smoothstep(6.0, 18.0, distance_to_stream(p)))
	return clampf(d, 0.0, 1.0) * clearing


## Arazi rengi için 0..1 arası yumuşak gürültü.
func tint_at(x: float, z: float) -> float:
	return _tint.get_noise_2d(x, z) * 0.5 + 0.5


## Göl kenarında, düz ve kuru bir başlangıç noktası.
func find_spawn() -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 99
	var fallback := Vector3(lake_center.x, 0.0, lake_center.y)
	for attempt in 400:
		var a := rng.randf() * TAU
		var r := lake_radius + rng.randf_range(14.0, 32.0)
		var p := lake_center + Vector2(cos(a), sin(a)) * r
		if p.length() > ISLAND_RADIUS * 0.8 or distance_to_stream(p) < 14.0 or lake_distance(p) < 1.5:
			continue
		var h := height_at(p.x, p.y)
		if h < 1.2 or h > 10.0 or slope_at(p.x, p.y) > 0.12:
			continue
		return Vector3(p.x, h, p.y)
	return fallback


func vertex_height(ix: int, iz: int) -> float:
	return heights[iz * VERTS + ix]


func vertex_pos(ix: int, iz: int) -> Vector3:
	return Vector3(ix * CELL - HALF, heights[iz * VERTS + ix], iz * CELL - HALF)


## Analitik yükseklik (ızgara üretimi için).
func raw_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := p.length() / ISLAND_RADIUS + _coast.get_noise_2d(x, z) * 0.12
	var hills := _hill.get_noise_2d(x, z) * 0.5 + 0.5
	var land := 2.4 + pow(clampf(hills, 0.0, 1.0), 1.7) * 28.0 + (1.0 - clampf(d, 0.0, 1.0)) * 5.0
	land += _detail.get_noise_2d(x, z) * 0.6

	# Göl ve dere çevresinde vadi: tepeler alçalır.
	var lake_d := lake_distance(p)
	var stream_d := distance_to_stream(p)
	var valley := minf(smoothstep(1.0, 1.0 + 70.0 / lake_radius, lake_d), smoothstep(5.0, 55.0, stream_d))
	land = lerpf(2.3 + _detail.get_noise_2d(x, z) * 0.4, land, valley)

	var island := 1.0 - smoothstep(0.8, 1.0, d)
	var h := lerpf(-7.0, land, island)

	var lake_t := smoothstep(0.55, 1.3, lake_d)
	h = lerpf(-2.8, h, lake_t)
	if stream_d < 10.0:
		h = minf(h, lerpf(-1.1, h, smoothstep(1.6, 7.5, stream_d)))
	return h


func _build_heights() -> void:
	heights.resize(VERTS * VERTS)
	for iz in VERTS:
		var z := iz * CELL - HALF
		for ix in VERTS:
			heights[iz * VERTS + ix] = raw_height(ix * CELL - HALF, z)


func _build_stream(rng: RandomNumberGenerator, lake_angle: float) -> void:
	var dir_angle := lake_angle + rng.randf_range(-0.5, 0.5)
	var dir := Vector2(cos(dir_angle), sin(dir_angle))
	var side := Vector2(-dir.y, dir.x)
	var start := lake_center + dir * lake_radius * 0.6
	var end := dir * (ISLAND_RADIUS + 35.0)
	var steps := 9
	var control := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / steps
		var p := start.lerp(end, t)
		if i > 0 and i < steps:
			p += side * rng.randf_range(-14.0, 14.0)
		control.append(p)
	# Catmull-Rom ile yumuşat: köşeli zikzak yerine kıvrımlı dere.
	stream.clear()
	for i in control.size() - 1:
		var p0 := control[maxi(i - 1, 0)]
		var p1 := control[i]
		var p2 := control[i + 1]
		var p3 := control[mini(i + 2, control.size() - 1)]
		for k in 5:
			var t := k / 5.0
			var t2 := t * t
			var t3 := t2 * t
			stream.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	stream.append(control[control.size() - 1])


static func _make_noise(p_seed: int, frequency: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = p_seed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	return n
