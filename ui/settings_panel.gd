class_name SettingsPanel
extends PanelContainer
## Ayarlar: fare hassasiyeti, görüş alanı, ses ve tam ekran. Değişiklikler
## hemen uygulanır, kapanınca kaydedilir.

signal closed


func _ready() -> void:
	theme = UITheme.get_theme()
	add_theme_stylebox_override("panel", UITheme.panel_box(UITheme.BG, 10, 24))
	custom_minimum_size = Vector2(600, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	v.add_child(UITheme.label(tr("AYARLAR"), 26, UITheme.ACCENT))
	var touch := GameState.touch_controls_enabled()
	_slider(v, tr("Bakış hassasiyeti") if touch else tr("Fare hassasiyeti"), "mouse_sensitivity", 0.05, 1.0, 0.01)
	_slider(v, tr("Görüş alanı (FOV)"), "fov", 60.0, 100.0, 1.0)
	_slider(v, tr("Ses"), "master_volume", 0.0, 1.0, 0.01)
	_choice(v, tr("Grafik kalitesi"), "quality", [["auto", tr("Otomatik")], ["high", tr("Yüksek")], ["low", tr("Düşük (mobil)")]])
	_choice(v, tr("Dokunmatik kontroller"), "touch_controls", [["auto", tr("Otomatik")], ["on", tr("Açık")], ["off", tr("Kapalı")]])
	var note := UITheme.label(tr("Kalite ve dokunmatik ayarı yeni yüklenen oyunda geçerli olur."), 13, UITheme.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	var full := CheckBox.new()
	full.text = tr("Tam ekran")
	full.button_pressed = bool(GameState.settings.get("fullscreen", false))
	full.toggled.connect(func(on: bool) -> void:
		GameState.settings.fullscreen = on
		GameState.apply_settings())
	v.add_child(full)
	var back := Button.new()
	back.text = tr("Geri")
	back.custom_minimum_size = Vector2(160, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_close)
	v.add_child(back)


func _close() -> void:
	Sfx.play("ui_click", -10.0)
	GameState.save_settings()
	closed.emit()


func _slider(parent: Control, title: String, key: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := UITheme.label(title, 18)
	l.custom_minimum_size.x = 250
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(GameState.settings[key])
	s.custom_minimum_size.x = 220
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val := UITheme.label(_fmt(key, s.value), 16, UITheme.TEXT_DIM)
	val.custom_minimum_size.x = 50
	row.add_child(val)
	s.value_changed.connect(func(x: float) -> void:
		GameState.settings[key] = x
		val.text = _fmt(key, x)
		GameState.apply_settings())
	parent.add_child(row)


func _choice(parent: Control, title: String, key: String, options: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := UITheme.label(title, 18)
	l.custom_minimum_size.x = 250
	row.add_child(l)
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(220, 40)
	for i in options.size():
		ob.add_item(options[i][1], i)
		if str(GameState.settings.get(key, "auto")) == options[i][0]:
			ob.select(i)
	ob.item_selected.connect(func(i: int) -> void:
		GameState.settings[key] = options[i][0])
	row.add_child(ob)
	parent.add_child(row)


static func _fmt(key: String, x: float) -> String:
	if key == "fov":
		return "%d°" % int(x)
	if key == "master_volume":
		return "%%%d" % int(x * 100.0)
	return "%.2f" % x
