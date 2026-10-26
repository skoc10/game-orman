extends CanvasLayer
## Dokunmatik kontroller (telefon ve tablet). Solda parmağın değdiği yerde beliren
## hareket çubuğu, sağda sürükleyerek bakma ve eylem düğmeleri. Düğmeler oyunun
## normal girdi eylemlerini (InputEventAction) üretir; böylece oyun kodu klavye ile
## dokunmatik arasında fark görmez. Menü ya da envanter açıkken gizlenir.

const STICK_RADIUS := 85.0
const LOOK_SENSITIVITY := 0.18

## [eylem, yazı, merkez (sağ alt köşeye göre negatif ya da sol/üst köşeye göre), yarıçap, tür]
## tür: "hold" basılı tutma, "toggle" aç/kapa, "tap" tek dokunuş.
const BUTTONS := [
	["attack", "Vur", Vector2(-150, -170), 72.0, "hold"],
	["interact", "E", Vector2(-150, -335), 52.0, "hold"],
	["jump", "Zıpla", Vector2(-300, -105), 50.0, "hold"],
	["alt_action", "Fırlat", Vector2(-305, -265), 44.0, "hold"],
	["sprint", "Koş", Vector2(95, -375), 42.0, "toggle"],
	["crouch", "Eğil", Vector2(215, -375), 42.0, "toggle"],
	["inventory", "Çanta", Vector2(-330, 95), 40.0, "tap"],
	["build", "İnşa", Vector2(-235, 95), 40.0, "tap"],
	["pause", "Menü", Vector2(-140, 95), 40.0, "tap"],
	["rotate_build", "Döndür", Vector2(-430, -265), 40.0, "tap"],
]

var player: Player
var enabled := false

var _root: Control
var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_touch := -1
## dokunuş indeksi -> eylem
var _held := {}
var _toggled := {}
var _move := Vector2.ZERO


func _ready() -> void:
	layer = 6
	player = get_parent().get_node("Player")
	enabled = GameState.touch_controls_enabled()
	visible = enabled
	if not enabled:
		set_process(false)
		set_process_input(false)
		return
	player.touch_mode = true
	player.mouse_look = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_strip_mouse_bindings()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_controls)
	add_child(_root)


## Dokunuşlardan türeyen fare tıklamaları vuruş ya da fırlatma sayılmasın.
func _strip_mouse_bindings() -> void:
	for action in ["attack", "alt_action", "hotbar_next", "hotbar_prev"]:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventMouseButton:
				InputMap.action_erase_event(action, ev)


func _process(_delta: float) -> void:
	var active := _is_active()
	if _root.visible != active:
		_root.visible = active
		if not active:
			_release_all()
	_root.queue_redraw()


func _is_active() -> bool:
	return enabled and not player.input_locked and not player.stats.dead and not get_tree().paused


func _input(event: InputEvent) -> void:
	if not _is_active():
		return
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)


func _on_touch(e: InputEventScreenTouch) -> void:
	var size := _root.get_viewport_rect().size
	if e.pressed:
		for b in BUTTONS:
			if not _button_visible(b):
				continue
			if e.position.distance_to(_center(b, size)) <= float(b[3]) * 1.15:
				_press_button(b, e.index)
				get_viewport().set_input_as_handled()
				return
		if _in_hotbar(e.position, size):
			return
		if e.position.x < size.x * 0.45 and _stick_touch == -1:
			_stick_touch = e.index
			_stick_origin = e.position
			_stick_pos = e.position
			get_viewport().set_input_as_handled()
		elif _look_touch == -1:
			_look_touch = e.index
			get_viewport().set_input_as_handled()
	else:
		if _held.has(e.index):
			_send(_held[e.index], false)
			_held.erase(e.index)
		if e.index == _stick_touch:
			_stick_touch = -1
			_set_move(Vector2.ZERO)
		if e.index == _look_touch:
			_look_touch = -1


func _on_drag(e: InputEventScreenDrag) -> void:
	if e.index == _stick_touch:
		var d := e.position - _stick_origin
		if d.length() > STICK_RADIUS:
			# Parmak çok uzaklaşırsa çubuk merkezi peşinden gelir.
			_stick_origin = e.position - d.normalized() * STICK_RADIUS
			d = e.position - _stick_origin
		_stick_pos = e.position
		_set_move(d / STICK_RADIUS)
		get_viewport().set_input_as_handled()
	elif e.index == _look_touch:
		var sens := float(GameState.settings.mouse_sensitivity) / 0.25 * LOOK_SENSITIVITY
		player.look_by(e.relative * sens)
		get_viewport().set_input_as_handled()


func _press_button(b: Array, index: int) -> void:
	var action: StringName = b[0]
	match str(b[4]):
		"hold":
			_held[index] = action
			_send(action, true)
		"toggle":
			var on := not bool(_toggled.get(action, false))
			_toggled[action] = on
			_send(action, on)
		"tap":
			_send(action, true)
			_send.call_deferred(action, false)


func _set_move(v: Vector2) -> void:
	v = v.limit_length(1.0)
	if v.length() < 0.15:
		v = Vector2.ZERO
	if v == _move:
		return
	_move = v
	_send("move_right", v.x > 0.0, maxf(v.x, 0.0))
	_send("move_left", v.x < 0.0, maxf(-v.x, 0.0))
	_send("move_back", v.y > 0.0, maxf(v.y, 0.0))
	_send("move_forward", v.y < 0.0, maxf(-v.y, 0.0))
	# Çubuk sonuna kadar itilince koşu (koş düğmesi açık olmasa da).
	if not bool(_toggled.get("sprint", false)):
		_send("sprint", v.length() > 0.95 and v.y < -0.7)


func _send(action: StringName, pressed: bool, strength := 1.0) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = strength if pressed else 0.0
	Input.parse_input_event(ev)


func _release_all() -> void:
	for index in _held:
		_send(_held[index], false)
	_held.clear()
	_stick_touch = -1
	_look_touch = -1
	_set_move(Vector2.ZERO)


func _button_visible(b: Array) -> bool:
	if b[0] == "rotate_build":
		return player.build.is_placing()
	return true


func _center(b: Array, size: Vector2) -> Vector2:
	var p: Vector2 = b[2]
	return Vector2(p.x if p.x >= 0.0 else size.x + p.x, p.y if p.y >= 0.0 else size.y + p.y)


## Ekranın alt ortasındaki hızlı erişim çubuğu HUD'a bırakılır.
func _in_hotbar(p: Vector2, size: Vector2) -> bool:
	return absf(p.x - size.x * 0.5) < 170.0 and p.y > size.y - 110.0


func _draw_controls() -> void:
	var size := _root.get_viewport_rect().size
	var font := _root.get_theme_default_font()
	for b in BUTTONS:
		if not _button_visible(b):
			continue
		var c := _center(b, size)
		var r := float(b[3])
		var pressed := _held.values().has(b[0]) or bool(_toggled.get(b[0], false))
		_root.draw_circle(c, r, Color(1, 1, 1, 0.28) if pressed else Color(0, 0, 0, 0.32))
		_root.draw_arc(c, r, 0.0, TAU, 32, Color(1, 1, 1, 0.55 if pressed else 0.3), 2.0, true)
		var fs := 22 if r > 50.0 else 17
		_root.draw_string(font, c + Vector2(-r, fs * 0.35), tr(b[1]), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1, 1, 1, 0.9))
	if _stick_touch != -1:
		_root.draw_circle(_stick_origin, STICK_RADIUS, Color(0, 0, 0, 0.25))
		_root.draw_arc(_stick_origin, STICK_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.3), 2.0, true)
		_root.draw_circle(_stick_origin + (_stick_pos - _stick_origin).limit_length(STICK_RADIUS), 36.0, Color(1, 1, 1, 0.35))
	else:
		# Çubuğun nerede olduğunu hatırlatan soluk iz.
		var hint := Vector2(170, size.y - 185)
		_root.draw_arc(hint, STICK_RADIUS * 0.8, 0.0, TAU, 40, Color(1, 1, 1, 0.12), 2.0, true)
	if size.y > size.x:
		_root.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.85))
		_root.draw_string(font, Vector2(0, size.y * 0.5), tr("Telefonu yan çevir"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, Color.WHITE)
