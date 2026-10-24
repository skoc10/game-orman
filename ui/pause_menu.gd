extends CanvasLayer
## Duraklatma menüsü (Esc): devam, kaydet, ayarlar, ana menüye dön.
## Oyun ağacı duraklatılır; bu menü duraklatmadan etkilenmez.

var player: Player
var is_open := false

var _root: Control
var _main: VBoxContainer
var _confirm: VBoxContainer
var _settings: SettingsPanel
var _status: Label


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = get_parent().get_node("Player")
	_build()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if is_open:
		if _settings.visible:
			_show(_main)
		else:
			close()
		get_viewport().set_input_as_handled()
		return
	if player.stats.dead:
		return
	if player.build.is_placing():
		player.build.cancel()
		get_viewport().set_input_as_handled()
		return
	if player.input_locked:
		return
	open()
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Pencere odağı kaybolunca oyunu otomatik duraklat.
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT or is_open or player == null or player.stats.dead or player.input_locked:
		return
	var debug := get_node_or_null("/root/DebugCapture")
	if DisplayServer.get_name() != "headless" and not (debug and debug.args.has("shot")):
		open()


func open() -> void:
	is_open = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_status.text = tr("%d. Gün  %s") % [TimeOfDay.day, TimeOfDay.clock_text()]
	_show(_main)


func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if player:
		player.camera.fov = float(GameState.settings.fov)


func _show(panel: Control) -> void:
	_main.visible = panel == _main
	_confirm.visible = panel == _confirm
	_settings.visible = panel == _settings


func _save() -> void:
	if GameState.save_game():
		_status.text = tr("Oyun kaydedildi.")
	else:
		_status.text = tr("Kaydedilemedi!")


func _build() -> void:
	_root = Control.new()
	_root.theme = UITheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var stack := VBoxContainer.new()
	center.add_child(stack)

	_main = _menu_box(stack, tr("DURAKLATILDI"))
	_status = UITheme.label("", 16, UITheme.TEXT_DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main.add_child(_status)
	_main.add_child(_button(tr("Devam et"), close))
	_main.add_child(_button(tr("Kaydet"), _save))
	_main.add_child(_button(tr("Ayarlar"), func() -> void: _show(_settings)))
	_main.add_child(_button(tr("Ana menü"), func() -> void: _show(_confirm)))

	_confirm = _menu_box(stack, tr("Ana menüye dön"))
	var warn := UITheme.label(tr("Kaydedilmemiş ilerleme kaybolur."), 16, UITheme.TEXT_DIM)
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm.add_child(warn)
	_confirm.add_child(_button(tr("Kaydet ve çık"), func() -> void:
		GameState.save_game()
		GameState.go_to_menu()))
	_confirm.add_child(_button(tr("Kaydetmeden çık"), GameState.go_to_menu))
	_confirm.add_child(_button(tr("Vazgeç"), func() -> void: _show(_main)))

	_settings = SettingsPanel.new()
	_settings.closed.connect(func() -> void: _show(_main))
	stack.add_child(_settings)
	_show(_main)


func _menu_box(parent: Control, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_box(UITheme.BG, 10, 26))
	parent.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size.x = 320
	panel.add_child(v)
	var t := UITheme.label(title, 30, UITheme.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	# Görünürlük paneli (PanelContainer) üzerinden yönetilir.
	v.visibility_changed.connect(func() -> void: panel.visible = v.visible)
	return v


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 46)
	b.pressed.connect(func() -> void: Sfx.play("ui_click", -10.0))
	b.pressed.connect(action)
	return b
