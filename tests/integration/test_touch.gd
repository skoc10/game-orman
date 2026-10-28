extends GutTest
## Dokunmatik kontroller: çubuk hareket eylemi üretir, düğmeler eylemleri basar,
## sağ tarafta sürüklemek bakışı çevirir, menü açıkken kontroller gizlenir.

const WORLD := preload("res://world/world.tscn")

var world: Node3D
var player: Player
var touch: CanvasLayer
var _saved_touch := ""


func before_all() -> void:
	_saved_touch = str(GameState.settings.touch_controls)
	GameState.settings.touch_controls = "on"
	GameState.save_path = "user://test_saves/touch.json"
	GameState.pending_load = {}
	GameState.new_game_seed = 42
	world = WORLD.instantiate()
	add_child(world)
	player = world.player
	touch = world.get_node("TouchControls")
	await wait_physics_frames(3)


func after_all() -> void:
	world.queue_free()
	await wait_physics_frames(2)
	GameState.settings.touch_controls = _saved_touch
	GameState.save_path = GameState.SAVE_PATH
	InputSetup._enter_tree()
	GameState.apply_ui_scale()


func _screen() -> Vector2:
	return touch.get_viewport().get_visible_rect().size


func _tap(pos: Vector2, index: int, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	touch._input(e)


func _drag(pos: Vector2, rel: Vector2, index: int) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = rel
	touch._input(e)


func test_touch_mode_is_on() -> void:
	assert_true(touch.enabled)
	assert_true(player.touch_mode)
	for ev in InputMap.action_get_events("attack"):
		assert_false(ev is InputEventMouseButton, "dokunuştan türeyen tık vuruş sayılmamalı")


func test_stick_moves_player() -> void:
	var size := _screen()
	var start := Vector2(200, size.y - 200)
	_tap(start, 0, true)
	_drag(start + Vector2(0, -80), Vector2(0, -80), 0)
	await wait_physics_frames(1)
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	assert_lt(v.y, -0.7, "çubuk yukarı itilince ileri yürünmeli")
	_tap(start + Vector2(0, -80), 0, false)
	await wait_physics_frames(1)
	assert_eq(Input.get_vector("move_left", "move_right", "move_forward", "move_back"), Vector2.ZERO)


func test_attack_button_holds_action() -> void:
	var size := _screen()
	var c: Vector2 = touch._center(touch.BUTTONS[0], size)
	_tap(c, 1, true)
	await wait_physics_frames(1)
	assert_true(Input.is_action_pressed("attack"))
	_tap(c, 1, false)
	await wait_physics_frames(1)
	assert_false(Input.is_action_pressed("attack"))


func test_sprint_toggle() -> void:
	var size := _screen()
	var b: Array = touch.BUTTONS.filter(func(x: Array) -> bool: return x[0] == "sprint")[0]
	var c: Vector2 = touch._center(b, size)
	_tap(c, 2, true)
	_tap(c, 2, false)
	await wait_physics_frames(1)
	assert_true(Input.is_action_pressed("sprint"), "koş açık kalmalı")
	_tap(c, 2, true)
	_tap(c, 2, false)
	await wait_physics_frames(1)
	assert_false(Input.is_action_pressed("sprint"))


func test_drag_right_side_turns_camera() -> void:
	var size := _screen()
	var yaw := player.rotation.y
	var p := Vector2(size.x * 0.65, size.y * 0.4)
	_tap(p, 3, true)
	_drag(p + Vector2(120, 0), Vector2(120, 0), 3)
	_tap(p + Vector2(120, 0), 3, false)
	await wait_seconds(0.4)
	assert_ne(player.rotation.y, yaw, "sürükleyince bakış dönmeli")
	assert_lt(touch._look_pending.length(), 1.0, "yumuşatılan bakış birkaç karede tamamlanmalı")


func test_hidden_while_inventory_open() -> void:
	world.get_node("InventoryScreen").open()
	await wait_process_frames(2)
	assert_false(touch._is_active())
	world.get_node("InventoryScreen").close()
	await wait_process_frames(2)
	assert_true(touch._is_active())


func test_ui_is_scaled_up_for_touch() -> void:
	assert_eq(get_window().content_scale_size, GameState.TOUCH_UI_SIZE)
	assert_gt(UITheme.scale(), 1.0)


func test_throw_button_only_with_spear() -> void:
	var b: Array = touch.BUTTONS.filter(func(x: Array) -> bool: return x[0] == "alt_action")[0]
	player.inventory.set_slot(0, {})
	player.equipment.select(0)
	assert_false(touch._button_visible(b), "mızraksız fırlat düğmesi görünmemeli")
	player.inventory.set_slot(0, {"id": "spear", "count": 1, "dur": 60.0})
	assert_true(touch._button_visible(b))
	player.inventory.set_slot(0, {})


func test_attack_drag_also_aims() -> void:
	var size := _screen()
	var c: Vector2 = touch._center(touch.BUTTONS[0], size)
	var yaw := player.rotation.y
	_tap(c, 4, true)
	_drag(c + Vector2(-90, 0), Vector2(-90, 0), 4)
	await wait_seconds(0.3)
	assert_ne(player.rotation.y, yaw, "Vur'a basılıyken sürüklemek nişan aldırmalı")
	_tap(c + Vector2(-90, 0), 4, false)


func test_stick_starts_from_home_base() -> void:
	var size := _screen()
	var home: Vector2 = touch._stick_home(size)
	_tap(home + Vector2(20, 10), 5, true)
	assert_eq(touch._stick_origin, home, "taban yakınına dokununca çubuk tabandan başlamalı")
	_tap(home + Vector2(20, 10), 5, false)


func test_fast_swipe_turns_moderately() -> void:
	var size := _screen()
	var yaw := player.rotation.y
	var p := Vector2(size.x * 0.6, size.y * 0.4)
	_tap(p, 6, true)
	for i in 10:
		# Hızlı kaydırma: olay başına 80 birim.
		p += Vector2(80, 0)
		_drag(p, Vector2(80, 0), 6)
	_tap(p, 6, false)
	await wait_seconds(1.0)
	var turned := absf(rad_to_deg(angle_difference(yaw, player.rotation.y)))
	assert_between(turned, 20.0, 70.0, "hızlı kaydırma kamerayı savurmamalı (%.1f°)" % turned)


func test_vertical_look_is_slower() -> void:
	touch._look_pending = Vector2.ZERO
	var p := Vector2(_screen().x * 0.6, _screen().y * 0.5)
	_tap(p, 7, true)
	_drag(p + Vector2(30, 30), Vector2(30, 30), 7)
	_tap(p + Vector2(30, 30), 7, false)
	assert_lt(absf(touch._look_pending.y), absf(touch._look_pending.x))
	touch._look_pending = Vector2.ZERO
