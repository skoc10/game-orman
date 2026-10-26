extends CanvasLayer
## Dokunmatik kontroller (telefon ve tablet). Sol altta hareket çubuğu, sağ tarafta
## sürükleyerek bakış ve eylem düğmeleri. Düğmeler oyunun normal girdi eylemlerini
## (InputEventAction) üretir; böylece oyun kodu klavye ile dokunmatik arasında fark
## görmez. Menü ya da envanter açıkken gizlenir. Konumlar arayüzün 600 birim
## yüksekliğine göredir (GameState.TOUCH_UI_SIZE).

const STICK_RADIUS := 80.0
## Sol alttaki sabit çubuk tabanı (sol-alt köşeye göre).
const STICK_HOME := Vector2(150, -150)
## Derece / birim. Ayarlardaki bakış hassasiyeti (varsayılan 0.25) ile çarpılır.
const LOOK_SENSITIVITY := 0.2
## Bakış yumuşatma hızı: büyüdükçe daha keskin.
const LOOK_SMOOTHING := 22.0

## [eylem, yazı, merkez (negatif = sağ/alt kenardan), yarıçap, tür]
## tür: "hold" basılı tutma, "toggle" aç/kapa, "tap" tek dokunuş.
const BUTTONS := [
	["attack", "Vur", Vector2(-120, -125), 82.0, "hold"],
	["interact", "E", Vector2(-125, -300), 60.0, "hold"],
	["jump", "Zıpla", Vector2(-275, -72), 54.0, "hold"],
	["alt_action", "Fırlat", Vector2(-275, -215), 52.0, "hold"],
	["rotate_build", "Döndür", Vector2(-395, -175), 48.0, "tap"],
	["sprint", "Koş", Vector2(70, -315), 46.0, "toggle"],
	["crouch", "Eğil", Vector2(180, -315), 46.0, "toggle"],
	["inventory", "Çanta", Vector2(-290, 115), 44.0, "tap"],
	["build", "İnşa", Vector2(-190, 115), 44.0, "tap"],
	["pause", "Menü", Vector2(-90, 115), 44.0, "tap"],
]

var player: Player
var enabled := false

var _root: Control
var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_touch := -1
## Vur düğmesine basılıyken sürüklenirse nişan da alınır.
var _attack_touch := -1
var _look_pending := Vector2.ZERO
## dokunuş indeksi -> eylem
var _held := {}
var _toggled := {}
var _move := Vector2.ZERO
var _asked_fullscreen := false


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	_setup_orientation_lock()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_controls)
	add_child(_root)
	add_child(RotateHint.new())


## Dokunuşlardan türeyen fare tıklamaları vuruş ya da fırlatma sayılmasın.
func _strip_mouse_bindings() -> void:
	for action in ["attack", "alt_action", "hotbar_next", "hotbar_prev"]:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventMouseButton:
				InputMap.action_erase_event(action, ev)


## Web'de tam ekrana geçilince ekranı yatayda kilitlemeyi dener (Android Chrome).
func _setup_orientation_lock() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		document.addEventListener('fullscreenchange', function () {
			if (document.fullscreenElement && screen.orientation && screen.orientation.lock) {
				screen.orientation.lock('landscape').catch(function () {});
			}
		});
	""", true)


func _process(delta: float) -> void:
	var active := _is_active()
	if _root.visible != active:
		_root.visible = active
		if not active:
			_release_all()
	# Bakışı birkaç kareye yayarak uygula: titreme yerine akıcı dönüş.
	if _look_pending != Vector2.ZERO and active:
		var step := _look_pending * (1.0 - exp(-LOOK_SMOOTHING * delta))
		if _look_pending.length() < 0.05:
			step = _look_pending
		_look_pending -= step
		player.look_by(step)
	_root.queue_redraw()


func _is_active() -> bool:
	return enabled and not player.input_locked and not player.stats.dead and not get_tree().paused


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch and event.pressed and not _asked_fullscreen and OS.has_feature("web"):
		# İlk dokunuşta tam ekran (tarayıcı izin verirse); ardından yatay kilit.
		_asked_fullscreen = true
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
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
			if e.position.distance_to(_center(b, size)) <= float(b[3]) * 1.2:
				_press_button(b, e.index)
				if b[0] == "attack":
					_attack_touch = e.index
				get_viewport().set_input_as_handled()
				return
		if _in_hotbar(e.position, size):
			return
		if e.position.x < size.x * 0.42 and _stick_touch == -1:
			_stick_touch = e.index
			# Taban yakınına dokunulursa çubuk sabit tabandan, değilse parmağın altından başlar.
			var home := _stick_home(size)
			_stick_origin = home if e.position.distance_to(home) < STICK_RADIUS * 1.6 else e.position
			_stick_pos = e.position
			_set_move((_stick_pos - _stick_origin) / STICK_RADIUS)
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
		if e.index == _attack_touch:
			_attack_touch = -1


func _on_drag(e: InputEventScreenDrag) -> void:
	if e.index == _stick_touch:
		var d := e.position - _stick_origin
		if d.length() > STICK_RADIUS * 1.3:
			# Parmak çok uzaklaşırsa çubuk tabanı peşinden gelir.
			_stick_origin = e.position - d.normalized() * STICK_RADIUS * 1.3
			d = e.position - _stick_origin
		_stick_pos = e.position
		_set_move(d / STICK_RADIUS)
		get_viewport().set_input_as_handled()
	elif e.index == _look_touch or e.index == _attack_touch:
		var sens := float(GameState.settings.mouse_sensitivity) / 0.25 * LOOK_SENSITIVITY
		# Hızlı kaydırmada biraz hızlanır, yavaş sürüklemede hassas kalır.
		var accel := 1.0 + clampf(e.relative.length() / 40.0, 0.0, 1.0) * 0.6
		_look_pending += e.relative * sens * accel
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
	if v.length() < 0.12:
		v = Vector2.ZERO
	if v == _move:
		return
	_move = v
	_send("move_right", v.x > 0.0, maxf(v.x, 0.0))
	_send("move_left", v.x < 0.0, maxf(-v.x, 0.0))
	_send("move_back", v.y > 0.0, maxf(v.y, 0.0))
	_send("move_forward", v.y < 0.0, maxf(-v.y, 0.0))
	# Çubuk sonuna kadar ileri itilince koşu (koş düğmesi açık olmasa da).
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
	_attack_touch = -1
	_look_pending = Vector2.ZERO
	_set_move(Vector2.ZERO)


func _button_visible(b: Array) -> bool:
	match str(b[0]):
		"rotate_build":
			return player.build.is_placing()
		"alt_action":
			var held := player.equipment.held_item()
			return player.build.is_placing() or (held != null and held.throw_damage > 0.0)
	return true


func _button_label(b: Array) -> String:
	if b[0] == "alt_action" and player.build.is_placing():
		return tr("İptal")
	if b[0] == "attack" and player.build.is_placing():
		return tr("Kur")
	return tr(b[1])


func _center(b: Array, size: Vector2) -> Vector2:
	var p: Vector2 = b[2]
	return Vector2(p.x if p.x >= 0.0 else size.x + p.x, p.y if p.y >= 0.0 else size.y + p.y)


func _stick_home(size: Vector2) -> Vector2:
	return Vector2(STICK_HOME.x, size.y + STICK_HOME.y)


## Ekranın alt ortasındaki hızlı erişim çubuğu HUD'a bırakılır.
func _in_hotbar(p: Vector2, size: Vector2) -> bool:
	return absf(p.x - size.x * 0.5) < 200.0 and p.y > size.y - 125.0


func _draw_controls() -> void:
	var size := _root.get_viewport_rect().size
	var font := _root.get_theme_default_font()
	if size.y > size.x:
		return
	for b in BUTTONS:
		if not _button_visible(b):
			continue
		var c := _center(b, size)
		var r := float(b[3])
		var pressed := _held.values().has(b[0]) or bool(_toggled.get(b[0], false))
		_root.draw_circle(c, r, Color(1, 1, 1, 0.3) if pressed else Color(0, 0, 0, 0.35))
		_root.draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.6 if pressed else 0.35), 2.5, true)
		var fs := 26 if r > 70.0 else (22 if r > 50.0 else 19)
		_root.draw_string_outline(font, c + Vector2(-r, fs * 0.35), _button_label(b), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, 4, Color(0, 0, 0, 0.5))
		_root.draw_string(font, c + Vector2(-r, fs * 0.35), _button_label(b), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1, 1, 1, 0.95))
	var origin := _stick_origin if _stick_touch != -1 else _stick_home(size)
	var knob := origin + ((_stick_pos - _stick_origin).limit_length(STICK_RADIUS) if _stick_touch != -1 else Vector2.ZERO)
	_root.draw_circle(origin, STICK_RADIUS, Color(0, 0, 0, 0.28 if _stick_touch != -1 else 0.18))
	_root.draw_arc(origin, STICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.35 if _stick_touch != -1 else 0.2), 2.5, true)
	_root.draw_circle(knob, 34.0, Color(1, 1, 1, 0.4 if _stick_touch != -1 else 0.22))
