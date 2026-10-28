class_name Equipment
extends Node3D
## Elde tutulan eşya: hızlı erişim seçimi, görünüm, sallama/vuruş, yeme-içme
## ve meşale ışığı. Kameranın altında, sağ alt köşede durur.

signal selection_changed(index: int)

const REST_POS := Vector3(0.36, -0.4, -0.62)
const REST_ROT := Vector3(-0.35, 0.25, -0.15)
const WINDUP_ROT := Vector3(0.6, 0.45, 0.25)
const STRIKE_ROT := Vector3(-1.1, -0.05, -0.35)
const HAND_REACH := 1.6
const HIT_MASK := 1 | 8

var player: Player
var selected := 0

var _pivot: Node3D
var _held: MeshInstance3D
var _held_id := ""
var _busy := false
var _eat_cooldown := 0.0
var _torch_light: OmniLight3D
var _flame: MeshInstance3D
var _bob := 0.0
## Yayın gerilme oranı (0..1); Vur basılı tutuldukça artar, bırakınca ok atılır.
var draw := 0.0
const DRAW_TIME := 0.9


func _ready() -> void:
	position = REST_POS
	_pivot = Node3D.new()
	_pivot.rotation = REST_ROT
	add_child(_pivot)
	_held = MeshInstance3D.new()
	_held.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(_held)

	_flame = MeshInstance3D.new()
	_flame.mesh = MeshFactory.sphere(0.07, 5, 3)
	_flame.material_override = MeshFactory.glow_material(Color(1.0, 0.55, 0.15), 6.0)
	_flame.position = Vector3(0, 0.62, 0)
	_flame.scale = Vector3(1.0, 1.6, 1.0)
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_held.add_child(_flame)
	_torch_light = OmniLight3D.new()
	_torch_light.light_color = Color(1.0, 0.68, 0.38)
	_torch_light.light_energy = 2.2
	_torch_light.omni_range = 13.0
	_torch_light.shadow_enabled = not GameState.low_quality()
	_torch_light.position = Vector3(0, 0.75, 0)
	_held.add_child(_torch_light)
	_refresh(true)


func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.input_locked:
		return
	for i in Inventory.HOTBAR:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			select(i)
	if event.is_action_pressed("hotbar_next"):
		select((selected + 1) % Inventory.HOTBAR)
	elif event.is_action_pressed("hotbar_prev"):
		select((selected + Inventory.HOTBAR - 1) % Inventory.HOTBAR)


func _process(delta: float) -> void:
	if player == null:
		return
	_refresh()
	_eat_cooldown = maxf(0.0, _eat_cooldown - delta)
	var item := held_item()
	var lit := item != null and item.category == ItemData.Category.LIGHT
	_torch_light.visible = lit
	_flame.visible = lit
	if lit:
		_torch_light.light_energy = 2.0 + sin(Time.get_ticks_msec() * 0.02) * 0.25 + randf() * 0.15
		if player.inventory.wear(selected, delta):
			player.notify(tr("Meşalen söndü."))

	# Yürürken elin hafifçe sallanması.
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	_bob += delta * speed * 1.8
	position = position.lerp(REST_POS + Vector3(cos(_bob) * 0.012, sin(_bob * 2.0) * 0.01, 0) * minf(speed, 7.0) / 4.0, clampf(delta * 10.0, 0.0, 1.0))

	if player.input_locked or player.stats.dead or _busy:
		return
	if player.build and player.build.is_placing():
		return
	if item and item.id == "bow":
		_update_bow(delta)
		return
	if Input.is_action_pressed("attack"):
		use_primary()
	elif Input.is_action_just_pressed("alt_action"):
		use_secondary()


func select(i: int) -> void:
	selected = clampi(i, 0, Inventory.HOTBAR - 1)
	selection_changed.emit(selected)
	_refresh(true)


func held_item() -> ItemData:
	return player.inventory.slot_item(selected) if player else null


## Torch elde ve yanıyorsa true; kurtlar bundan korkar.
func has_light() -> bool:
	var item := held_item()
	return item != null and item.category == ItemData.Category.LIGHT


func use_primary() -> void:
	var item := held_item()
	if item and item.is_consumable():
		if _eat_cooldown <= 0.0 and Input.is_action_just_pressed("attack"):
			_consume(item)
		return
	if item and (item.category == ItemData.Category.CONTAINER or item.id == "fishing_rod"):
		return
	_swing(item)


## Sağ tık: fırlatılabilir silahı (mızrak) bakılan yöne atar.
func use_secondary() -> void:
	var item := held_item()
	if item == null or item.throw_damage <= 0.0:
		return
	if not player.stats.use_stamina(Balance.d.swing_stamina * 1.5):
		player.notify(tr("Fırlatmak için çok yorgunsun."))
		return
	var stack := player.inventory.take_from(selected, 1)
	var spear := SpearProjectile.new()
	spear.damage = item.throw_damage
	spear.durability = float(stack.get("dur", item.durability))
	spear.thrower = player
	spear.velocity = player.look_direction() * 24.0 + Vector3.UP * 1.5
	player.get_parent().add_child(spear)
	spear.global_position = player.camera.global_position + player.look_direction() * 0.6


## Yay: Vur basılı tutulunca gerilir, bırakınca ok atılır.
func _update_bow(delta: float) -> void:
	if Input.is_action_pressed("attack"):
		if not player.inventory.has("arrow"):
			if Input.is_action_just_pressed("attack"):
				player.notify(tr("Okun yok. 1 dal, 1 taş ve 1 liften ok yap."))
			return
		draw = minf(1.0, draw + delta / DRAW_TIME)
		_pivot.position = Vector3(0, 0, 0.12 * draw)
		Events.interaction_changed.emit(tr("Yay geriliyor... bırak ve at"), draw)
	elif draw > 0.0:
		shoot_arrow(draw)


## Ok atar; güç gerilme oranına bağlıdır.
func shoot_arrow(power: float) -> void:
	var bow := held_item()
	draw = 0.0
	_pivot.position = Vector3.ZERO
	Events.interaction_changed.emit("", -1.0)
	if bow == null or bow.id != "bow" or not player.inventory.remove("arrow", 1):
		return
	power = clampf(power, 0.15, 1.0)
	var arrow := SpearProjectile.new()
	arrow.item_id = "arrow"
	arrow.recover_chance = 0.7
	arrow.damage = lerpf(12.0, ItemDB.get_item("arrow").throw_damage, power)
	arrow.thrower = player
	arrow.velocity = player.look_direction() * lerpf(14.0, 42.0, power) + Vector3.UP * 0.6
	player.get_parent().add_child(arrow)
	arrow.global_position = player.camera.global_position + player.look_direction() * 0.5
	Sfx.play("bow_release", -4.0, 0.1)
	if player.inventory.wear(selected, 1.0):
		player.notify(tr("Yayın kırıldı!"))


func _consume(item: ItemData) -> void:
	_eat_cooldown = 0.6
	var sick := player.stats.consume(item, player.rng)
	player.inventory.take_from(selected, 1)
	Sfx.play("drink" if item.category == ItemData.Category.DRINK else "eat", -8.0)
	var verb := tr("içtin") if item.category == ItemData.Category.DRINK else (tr("kullandın") if item.category == ItemData.Category.MEDICAL else tr("yedin"))
	player.notify("%s %s" % [item.display_name, verb])
	if sick:
		player.notify(tr("Midem bulanıyor..."))
	var tw := create_tween()
	tw.tween_property(_pivot, "position", Vector3(-0.15, 0.2, 0.2), 0.15)
	tw.tween_property(_pivot, "position", Vector3.ZERO, 0.25)


func _swing(item: ItemData) -> void:
	_busy = true
	var t := item.swing_time if item else 0.45
	var damage := item.damage if item else Balance.d.unarmed_damage
	var weak := not player.stats.use_stamina(Balance.d.swing_stamina)
	if weak:
		damage *= 0.5
		t *= 1.3
	var tw := create_tween()
	tw.tween_callback(Sfx.play.bind("swing", -14.0, 0.15)).set_delay(t * 0.3)
	tw.tween_property(_pivot, "rotation", WINDUP_ROT, t * 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_pivot, "rotation", STRIKE_ROT, t * 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_strike.bind(item, damage, weak))
	tw.tween_property(_pivot, "rotation", REST_ROT, t * 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: _busy = false)


func _strike(item: ItemData, damage: float, weak: bool) -> void:
	var reach := item.reach if item else HAND_REACH
	var cam := player.camera
	var from := cam.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + player.look_direction() * reach, HIT_MASK)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var col: Object = hit.collider
	if col is Dog:
		# Köpeğe vurulmaz; sevilir.
		col._wag = 1.0
		return
	if col.has_method("take_tree_hit"):
		if item and item.chop_power > 0.0:
			col.take_tree_hit(hit.shape, item.chop_power * (0.5 if weak else 1.0), player)
			Sfx.play_at("chop", hit.position, -2.0, 50.0)
			_wear()
		else:
			player.notify(tr("Ağaç kesmek için balta gerekli."))
	elif col is Node and (col as Node).get_meta("rock", false):
		if item and item.chop_power > 0.0:
			Effects.burst(player.get_parent(), hit.position, Color(0.55, 0.54, 0.5), 8, 2.0)
			Sfx.play_at("chop", hit.position, -6.0, 30.0, 0.25)
			if player.rng.randf() < 0.6:
				player.give("stone", 1)
			_wear()
		else:
			player.notify(tr("Kayadan taş kırmak için balta gerekli."))
	elif col.has_method("take_hit"):
		col.take_hit(damage, player)
		Sfx.play_at("hit_flesh", hit.position, 0.0, 30.0)
		_wear()
	else:
		Sfx.play_at("chop", hit.position, -12.0, 20.0, 0.2)
		Effects.burst(player.get_parent(), hit.position, Color(0.5, 0.48, 0.45), 5, 1.5)


func _wear() -> void:
	var item := held_item()
	if item and item.has_durability() and item.category != ItemData.Category.LIGHT:
		if player.inventory.wear(selected, 1.0):
			player.notify(tr("%s kırıldı!") % item.display_name)


func _refresh(force := false) -> void:
	var slot := player.inventory.get_slot(selected) if player else {}
	var id: String = slot.get("id", "")
	if id == _held_id and not force:
		return
	_held_id = id
	_held.visible = id != ""
	if id == "":
		return
	_held.mesh = MeshFactory.item_mesh(id)
	# Küçük eşyalar avuçta, uzun aletler sapından tutulur.
	var item := ItemDB.get_item(id)
	var long := id in ["axe", "spear", "torch", "knife", "stick", "log", "bow", "fishing_rod"]
	_held.position = Vector3(0, -0.05, 0) if long else Vector3(0, 0, -0.05)
	_held.rotation = Vector3.ZERO if long else Vector3(0.4, 0, 0)
	_held.scale = Vector3.ONE * (0.5 if id == "log" else 0.8)
	if item and item.id == "spear":
		_held.position = Vector3(0, -0.7, 0)
