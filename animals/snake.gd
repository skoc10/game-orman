class_name Snake
extends AnimalBase
## Yılan: otların ve kayaların arasında kıvrılıp yatar, zor fark edilir.
## Çok yaklaşınca başını kaldırıp tıslar; geri çekilmezsen atılıp zehirli
## ısırır (mide bulantısı ve hasar). Kovalamaz; tehdit uzaklaşınca sakinleşir.

const WARN_RANGE := 3.5
const BITE_RANGE := 2.4
const BITE_DAMAGE := 6.0
const VENOM_TIME := 25.0
const SEGMENTS := 9

var _segments: Array[Node3D] = []
var _bite_cd := 0.0
var _rear := 0.0


func _init() -> void:
	species = "snake"
	display_name = "Yılan"
	max_health = 12.0
	walk_speed = 0.6
	run_speed = 2.6
	drops = {"meat_raw": 1}
	wander_radius = 6.0


func _ready() -> void:
	super._ready()
	add_to_group("snake")


func think(delta: float, player: Player, dist: float) -> void:
	_bite_cd -= delta
	if player == null or player.stats.dead:
		wander(delta)
		return
	match state:
		State.ALERT:
			stop()
			face(player.global_position, delta)
			if dist > WARN_RANGE * 1.6 and _state_time > 1.0:
				set_state(State.IDLE)
			elif dist < BITE_RANGE and _bite_cd <= 0.0 and _state_time > 0.6:
				_bite(player)
		State.RETREAT:
			move_away(player.global_position, run_speed)
			if _state_time > 2.5:
				home = global_position
				set_state(State.ALERT)
		_:
			if dist < WARN_RANGE:
				Sfx.play_at("snake_hiss", global_position + Vector3.UP * 0.2, 0.0, 15.0, 0.15)
				set_state(State.ALERT)
			elif rng.randf() < 0.2 * delta:
				wander(delta)
			elif state == State.WANDER:
				wander(delta)
			else:
				stop()


func _bite(player: Player) -> void:
	_bite_cd = 2.0
	player.take_damage(BITE_DAMAGE, "yılan")
	player.stats.nausea_time = maxf(player.stats.nausea_time, VENOM_TIME)
	player.notify(tr("Yılan ısırdı! Zehirlendin."))
	Sfx.play_at("bite", global_position, -4.0, 15.0, 0.3)
	_rear = 1.0
	set_state(State.RETREAT)


func on_hurt(_attacker: Node3D) -> void:
	set_state(State.RETREAT)


func _build_shape() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.12
	capsule.height = 0.9
	shape.shape = capsule
	shape.rotation.x = PI * 0.5
	shape.position.y = 0.12
	add_child(shape)


func _build_model() -> Node3D:
	var root := Node3D.new()
	var base := Color(0.36, 0.38, 0.2).lerp(Color(0.45, 0.36, 0.22), rng.randf())
	var band := base.darkened(0.45)
	var prev: Node3D = root
	for i in SEGMENTS:
		var seg := Node3D.new()
		seg.position = Vector3(0, 0.06 if i == 0 else 0.0, -0.15 if i == 0 else 0.13)
		prev.add_child(seg)
		var r := 0.055 * (1.0 - float(i) / SEGMENTS * 0.75)
		_blob(seg, Vector3.ZERO, Vector3(r * 2.0, r * 1.6, 0.16), base if i % 2 == 0 else band)
		_segments.append(seg)
		prev = seg
	_head = Node3D.new()
	_head.position = Vector3(0, 0.07, -0.2)
	root.add_child(_head)
	_blob(_head, Vector3(0, 0, -0.06), Vector3(0.1, 0.06, 0.14), base)
	for side in [-1.0, 1.0]:
		_blob(_head, Vector3(0.035 * side, 0.025, -0.09), Vector3(0.018, 0.018, 0.018), Color(0.9, 0.7, 0.1))
	return root


## Kıvrılarak sürünme: her halka bir öncekine göre sinüs dalgasıyla döner.
func _animate(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	_anim_t += delta * (2.0 + speed * 8.0)
	var wave := 0.25 + clampf(speed, 0.0, 2.0) * 0.2
	for i in _segments.size():
		_segments[i].rotation.y = sin(_anim_t - i * 0.9) * wave
	var target := 0.0
	if state == State.ALERT:
		target = 0.25
	_rear = maxf(0.0, _rear - delta * 3.0)
	_head.position.y = lerpf(_head.position.y, 0.07 + target + _rear * 0.1, clampf(delta * 6.0, 0.0, 1.0))
	_head.position.z = -0.2 - _rear * 0.4
	_head.rotation.y = sin(_anim_t * 0.5) * 0.2
	_flash = maxf(0.0, _flash - delta * 4.0)
	model.scale = Vector3.ONE * (1.0 + _flash * 0.1)
