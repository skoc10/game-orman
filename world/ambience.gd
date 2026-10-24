class_name Ambience
extends Node
## Ortam sesleri: sürekli rüzgar, gündüz kuşlar, gece cırcır böcekleri ve
## gece arada bir uzaktan kurt uluması.

var _wind: AudioStreamPlayer
var _birds: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _howl_timer := 20.0


func _ready() -> void:
	_wind = _loop("wind_loop")
	_birds = _loop("birds_loop")
	_crickets = _loop("crickets_loop")


func _exit_tree() -> void:
	# Çalan döngüler kapanışta durdurulmazsa motor çıkışta sızıntı uyarısı verir.
	for p in [_wind, _birds, _crickets]:
		p.stop()


func _process(delta: float) -> void:
	var dl := TimeOfDay.daylight()
	_wind.volume_db = -17.0
	_birds.volume_db = linear_to_db(maxf(dl, 0.001)) - 13.0
	_crickets.volume_db = linear_to_db(maxf(1.0 - dl, 0.001)) - 16.0
	if TimeOfDay.is_night():
		_howl_timer -= delta
		if _howl_timer <= 0.0:
			_howl_timer = randf_range(35.0, 80.0)
			_howl()


func _howl() -> void:
	var wolves := get_tree().get_nodes_in_group("wolf").filter(func(w: Node) -> bool: return w.is_alive())
	if wolves.is_empty():
		return
	var w: Node3D = wolves[randi() % wolves.size()]
	Sfx.play_at("wolf_howl", w.global_position + Vector3.UP, 2.0, 220.0, 0.12)


func _loop(sound: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = Sfx.stream(sound)
	p.volume_db = -60.0
	add_child(p)
	p.play()
	return p
