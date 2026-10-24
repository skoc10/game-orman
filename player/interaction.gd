class_name Interaction
extends Node
## Oyuncunun baktığı şeyi bulur, HUD'a ipucu gönderir ve E ile etkileşimi yürütür.
##
## Etkileşilebilir nesneler şu metodu sağlar:
##   get_interaction(player: Player, shape_idx: int) -> Dictionary
## Dönen sözlük: {"text": String, "action": Callable, "hold": float (saniye, 0 = tek basış)}
## Boş sözlük etkileşim olmadığını belirtir. "action" yoksa yalnızca bilgi gösterilir.

const WATER_REACH := 4.0

var player: Player
var current: Dictionary = {}

var _hold := 0.0
var _key := ""


func _physics_process(delta: float) -> void:
	if player == null or player.stats.dead or player.input_locked:
		_set_current({}, "")
		return
	var info := {}
	var key := ""
	var ray := player.interact_ray
	if ray.is_colliding():
		var col := ray.get_collider()
		var shape := ray.get_collider_shape()
		if col and col.has_method("get_interaction"):
			info = col.get_interaction(player, shape)
			key = "%d:%d" % [col.get_instance_id(), shape]
	if info.is_empty():
		info = _water_interaction()
		key = "water"
	if not info.is_empty():
		key += ":" + str(info.get("text", ""))
	_set_current(info, key)

	var progress := -1.0
	var action: Callable = info.get("action", Callable())
	if action.is_valid():
		var hold := float(info.get("hold", 0.0))
		if hold <= 0.0:
			if Input.is_action_just_pressed("interact"):
				action.call()
		elif Input.is_action_pressed("interact"):
			_hold += delta
			progress = clampf(_hold / hold, 0.0, 1.0)
			if _hold >= hold:
				_hold = 0.0
				action.call()
		else:
			_hold = 0.0
	Events.interaction_changed.emit(_prompt_text(info), progress)


func _set_current(info: Dictionary, key: String) -> void:
	if key != _key:
		_hold = 0.0
		_key = key
		if info.is_empty():
			Events.interaction_changed.emit("", -1.0)
	current = info


func _prompt_text(info: Dictionary) -> String:
	if info.is_empty():
		return ""
	var text := str(info.get("text", ""))
	var action: Callable = info.get("action", Callable())
	if not action.is_valid():
		return text
	var verb := "E basılı tut" if float(info.get("hold", 0.0)) > 0.0 else "E"
	return "[%s] %s" % [verb, text]


## Bakış ışını su yüzeyine, araziden önce ve erişim mesafesi içinde değiyorsa su içme.
func _water_interaction() -> Dictionary:
	var world := GameState.world
	if world == null:
		return {}
	var from := player.camera.global_position
	var dir := player.look_direction()
	if dir.y > -0.05:
		return {}
	var t := (WorldGen.WATER_LEVEL - from.y) / dir.y
	if t < 0.0 or t > WATER_REACH:
		return {}
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * t, 1)
	query.exclude = [player.get_rid()]
	if not space.intersect_ray(query).is_empty():
		return {}
	var p := from + dir * t
	var gen: WorldGen = world.gen
	if gen.height_at(p.x, p.z) > WorldGen.WATER_LEVEL - 0.05:
		return {}
	if gen.is_fresh_water(p.x, p.z):
		return {"text": tr("Su iç"), "hold": Balance.d.sip_time, "action": player.drink_fresh_water}
	return {"text": tr("Deniz suyu iç (tuzlu)"), "hold": Balance.d.sip_time, "action": player.drink_sea_water}
