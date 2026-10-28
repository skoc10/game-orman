class_name Interaction
extends Node
## Oyuncunun baktığı şeyi bulur, HUD'a ipucu gönderir ve E ile etkileşimi yürütür.
##
## Etkileşilebilir nesneler şu metodu sağlar:
##   get_interaction(player: Player, shape_idx: int) -> Dictionary
## Dönen sözlük: {"text": String, "action": Callable, "hold": float (saniye, 0 = tek basış)}
## Boş sözlük etkileşim olmadığını belirtir. "action" yoksa yalnızca bilgi gösterilir.
## "auto": true olan hızlı toplamalar E basılı tutulurken sırayla tekrarlanır.
##
## Hedef bulma bağışlayıcıdır: tam nişan ışını bir şeye değmezse, bakış yönü
## boyunca küçük kürelerle yerdeki eşyalar aranır. E basışı olay olarak anında işlenir.

const WATER_REACH := 4.0
const REACH := 3.0
const ASSIST_RADIUS := 0.45
const ASSIST_MASK := 4 | 8
const AUTO_REPEAT := 0.3

var player: Player
var current: Dictionary = {}

var _hold := 0.0
var _key := ""
var _auto_timer := 0.0
var _assist_shape := SphereShape3D.new()


func _ready() -> void:
	_assist_shape.radius = ASSIST_RADIUS


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or event.is_echo():
		return
	if player == null or player.stats.dead or player.input_locked:
		return
	# Basış anında hedefi yeniden bul: bir önceki fizik karesinin hedefini beklemeden çalış.
	_scan()
	var action: Callable = current.get("action", Callable())
	if action.is_valid() and float(current.get("hold", 0.0)) <= 0.0:
		action.call()
		_auto_timer = AUTO_REPEAT
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if player == null or player.stats.dead or player.input_locked:
		_set_current({}, "")
		return
	var info := _scan()

	var progress := -1.0
	var action: Callable = info.get("action", Callable())
	_auto_timer = maxf(0.0, _auto_timer - delta)
	if action.is_valid():
		var hold := float(info.get("hold", 0.0))
		if hold <= 0.0:
			# E basılı tutulurken yerdeki eşyalar art arda toplanır.
			if info.get("auto", false) and Input.is_action_pressed("interact") and _auto_timer <= 0.0:
				action.call()
				_auto_timer = AUTO_REPEAT
		elif Input.is_action_pressed("interact"):
			_hold += delta
			progress = clampf(_hold / hold, 0.0, 1.0)
			if _hold >= hold:
				_hold = 0.0
				action.call()
		else:
			_hold = 0.0
	Events.interaction_changed.emit(_prompt_text(info), progress)


## Bakılan hedefi bulur, current'ı günceller ve etkileşim sözlüğünü döndürür.
func _scan() -> Dictionary:
	if player.fishing and player.fishing.active:
		var fishing_info := player.fishing.interaction_info()
		_set_current(fishing_info, "fishing:" + str(fishing_info.text))
		return fishing_info
	var info := {}
	var key := ""
	var ray := player.interact_ray
	if ray.is_colliding():
		var col := ray.get_collider()
		var shape := ray.get_collider_shape()
		if col and col.has_method("get_interaction"):
			info = col.get_interaction(player, shape)
			key = "%d:%d" % [col.get_instance_id(), shape]
	if not (info.get("action", Callable()) as Callable).is_valid():
		var assisted := _assist_target()
		if not assisted.is_empty():
			info = assisted.info
			key = assisted.key
	if info.is_empty():
		info = _water_interaction()
		key = "water"
	if player.vehicle:
		# Saldayken E iner; elde olta ya da matara varsa önce suyla ilgili iş yapılır.
		var held := player.equipment.held_item()
		var water_tool := held != null and held.id in ["fishing_rod", "canteen", "water_raw", "water_clean"]
		if not (water_tool and key == "water" and not info.is_empty()):
			info = {"text": tr("Saldan in"), "hold": 0.4, "action": player.vehicle.leave}
			key = "raft"
	if not info.is_empty():
		key += ":" + str(info.get("text", ""))
	_set_current(info, key)
	return info


## Bakış yönü boyunca küreler bırakıp en yakın etkileşilebilir nesneyi arar.
## Yerdeki küçük eşyalara tam nişan almak gerekmez.
func _assist_target() -> Dictionary:
	var from := player.camera.global_position
	var dir := player.look_direction()
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _assist_shape
	query.collision_mask = ASSIST_MASK
	query.exclude = [player.get_rid()]
	var d := 0.6
	while d <= REACH:
		query.transform = Transform3D(Basis(), from + dir * d)
		for hit in space.intersect_shape(query, 4):
			var col: Object = hit.collider
			if col and col.has_method("get_interaction"):
				var info: Dictionary = col.get_interaction(player, int(hit.shape))
				if (info.get("action", Callable()) as Callable).is_valid():
					return {"info": info, "key": "%d:%d" % [col.get_instance_id(), int(hit.shape)]}
		d += 0.4
	return {}


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
	var held_rod := player.equipment.held_item()
	var reach := 9.0 if held_rod and held_rod.id == "fishing_rod" else WATER_REACH
	if t < 0.0 or t > reach:
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
	var rod := player.equipment.held_item()
	if rod and rod.id == "fishing_rod":
		return {"text": tr("Oltayı at"), "action": player.fishing.cast.bind(p)}
	if gen.is_fresh_water(p.x, p.z):
		var held := player.equipment.held_item()
		if held and held.id in ["canteen", "water_raw", "water_clean"] and player.canteen_space() > 0:
			return {"text": tr("Matarayı doldur"), "action": player.fill_canteen}
		return {"text": tr("Su iç"), "hold": Balance.d.sip_time, "action": player.drink_fresh_water}
	return {"text": tr("Deniz suyu iç (tuzlu)"), "hold": Balance.d.sip_time, "action": player.drink_sea_water}
