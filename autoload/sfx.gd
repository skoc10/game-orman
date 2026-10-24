extends Node
## Ses efektleri. Sesler tools/gen_sfx.gd ile üretilir ve assets/audio altında
## AudioStreamWAV kaynağı olarak durur. Konumlu sesler için havuzlanmış 3D
## oynatıcılar, arayüz ve oyuncunun kendi sesleri için 2D oynatıcılar kullanılır.

const DIR := "res://assets/audio/"
const POOL_3D := 24
const POOL_2D := 8

## Headless çalışmada (testler, sunucu) ses kapalıdır; kapanışta motor uyarısını önler.
var enabled := DisplayServer.get_name() != "headless"
var _streams := {}
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []


func stream(sound: String) -> AudioStream:
	if not enabled:
		return null
	if not _streams.has(sound):
		var path := DIR + sound + ".res"
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sound]


## Sesi çalar. pos verilirse dünyada o noktadan duyulur.
func play(sound: String, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	var s := stream(sound)
	if s == null:
		return
	var p := _free_2d()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func play_at(sound: String, pos: Vector3, volume_db := 0.0, max_distance := 60.0, pitch_jitter := 0.08) -> void:
	var s := stream(sound)
	if s == null:
		return
	var p := _free_3d()
	p.stream = s
	p.global_position = pos
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.unit_size = maxf(4.0, max_distance * 0.12)
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## Bir düğüme bağlı, sürekli dönen 3D ses (kamp ateşi gibi).
func attach_loop(sound: String, parent: Node3D, volume_db := 0.0, max_distance := 25.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.unit_size = 3.0
	parent.add_child(p)
	return p


func _free_2d() -> AudioStreamPlayer:
	for p in _pool2d:
		if not p.playing:
			return p
	if _pool2d.size() < POOL_2D:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool2d.append(p)
		return p
	return _pool2d[0]


func _free_3d() -> AudioStreamPlayer3D:
	for p in _pool3d:
		if not p.playing:
			return p
	if _pool3d.size() < POOL_3D:
		var p := AudioStreamPlayer3D.new()
		add_child(p)
		_pool3d.append(p)
		return p
	return _pool3d[0]
