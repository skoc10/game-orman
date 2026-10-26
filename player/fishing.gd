class_name Fishing
extends Node3D
## Oltayla balık avı: olta suya atılır, şamandıra bir süre bekler. Balık vurunca
## şamandıra batar; o kısa anda E'ye basılırsa balık tutulur, geç kalırsan kaçar.
## Yakında balık sürüsü varsa balık daha çabuk vurur. Uzaklaşmak ya da başka
## eşyaya geçmek avı bırakır.

signal caught(id: String)

const BITE_WINDOW := 1.3
## Atış menzilinden (9 m) biraz fazla; oyuncu bundan uzaklaşırsa olta toplanır.
const MAX_DISTANCE := 12.0

var player: Player
var active := false
var biting := false

var _point := Vector3.ZERO
var _wait := 0.0
var _bite_left := 0.0
var _bobber: MeshInstance3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true
	_rng.randomize()
	_bobber = MeshInstance3D.new()
	_bobber.mesh = MeshFactory.combine([
		[MeshFactory.sphere(0.06, 6, 4), MeshFactory.at(Vector3(0, 0.02, 0)), MeshFactory.flat_material(Color(0.9, 0.15, 0.1))],
		[MeshFactory.sphere(0.045, 6, 3), MeshFactory.at(Vector3(0, 0.08, 0)), MeshFactory.flat_material(Color(0.95, 0.95, 0.9))],
	])
	_bobber.visible = false
	add_child(_bobber)


## Oltayı bu su noktasına atar.
func cast(point: Vector3) -> void:
	active = true
	biting = false
	_point = Vector3(point.x, WorldGen.WATER_LEVEL, point.z)
	_bobber.global_position = _point
	_bobber.visible = true
	var fish_near := false
	for school in get_tree().get_nodes_in_group("fish_school"):
		if school.near(_point):
			fish_near = true
			break
	_wait = _rng.randf_range(2.0, 5.0) if fish_near else _rng.randf_range(6.0, 14.0)
	Sfx.play_at("splash", _point, -14.0, 20.0, 0.3)
	player.notify(tr("Olta atıldı. Şamandıra batınca E'ye bas."))


func stop() -> void:
	active = false
	biting = false
	_bobber.visible = false


## Etkileşim ipucu: av sürerken Interaction bunu gösterir.
func interaction_info() -> Dictionary:
	if biting:
		return {"text": tr("Balık vurdu! Çek!"), "action": reel}
	return {"text": tr("Bekle... (oltayı toplamak için E)"), "action": stop}


func reel() -> void:
	if not active:
		return
	if biting:
		var id := "fish_raw"
		player.give(id, 1)
		player.inventory.wear(player.equipment.selected, 1.0)
		Sfx.play_at("splash", _point, -4.0, 20.0, 0.2)
		caught.emit(id)
	stop()


func _process(delta: float) -> void:
	if not active:
		return
	var held := player.equipment.held_item()
	if held == null or held.id != "fishing_rod" or player.stats.dead \
			or Vector2(player.global_position.x - _point.x, player.global_position.z - _point.z).length() > MAX_DISTANCE:
		stop()
		return
	var t := Time.get_ticks_msec() * 0.001
	var dip := 0.0
	if biting:
		_bite_left -= delta
		dip = -0.12 + sin(t * 25.0) * 0.03
		if _bite_left <= 0.0:
			player.notify(tr("Balık kaçtı."))
			biting = false
			_wait = _rng.randf_range(4.0, 10.0)
	else:
		_wait -= delta
		if _wait <= 0.0:
			biting = true
			_bite_left = BITE_WINDOW
			Sfx.play_at("splash", _point, -10.0, 20.0, 0.3)
	_bobber.global_position = _point + Vector3(0, sin(t * 2.0) * 0.02 + dip, 0)
