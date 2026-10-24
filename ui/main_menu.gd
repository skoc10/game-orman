extends Node3D
## Ana menü: arkada alacakaranlıkta yavaşça dönen bir ada, solda menü,
## sağda kısa oynanış bilgisi.

const BACKDROP_SEED := 7
const ORBIT_RADIUS := 250.0
const ORBIT_HEIGHT := 75.0

var _camera: Camera3D
var _angle := 0.8
var _root: Control
var _menu: VBoxContainer
var _settings: SettingsPanel
var _help: PanelContainer
var _confirm: PanelContainer


func _ready() -> void:
	TimeOfDay.running = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	var debug := get_node_or_null("/root/DebugCapture")
	if debug and debug.wants_world():
		GameState.start_new_game(GameState.new_game_seed)
		return
	_build_backdrop()
	_build_ui()
	if debug:
		debug.on_menu_ready(self)


func _process(delta: float) -> void:
	if _camera == null:
		return
	_angle += delta * 0.025
	_camera.position = Vector3(cos(_angle) * ORBIT_RADIUS, ORBIT_HEIGHT, sin(_angle) * ORBIT_RADIUS)
	_camera.look_at(Vector3(0, 8, 0), Vector3.UP)


func _build_backdrop() -> void:
	TimeOfDay.hour = 18.7
	var gen := WorldGen.new(BACKDROP_SEED)
	var terrain := IslandTerrain.new()
	add_child(terrain)
	terrain.build(gen)
	var trees := TreeField.new()
	add_child(trees)
	trees.build(gen, gen.find_spawn())
	var day_night := DayNight.new()
	add_child(day_night)
	var water_mat := ShaderMaterial.new()
	water_mat.shader = preload("res://world/water.gdshader")
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400, 1400)
	plane.subdivide_width = 120
	plane.subdivide_depth = 120
	var water := MeshInstance3D.new()
	water.mesh = plane
	water.material_override = water_mat
	add_child(water)
	day_night.water_mat = water_mat
	day_night.fog_scale = 0.25
	_camera = Camera3D.new()
	_camera.far = 1200.0
	_camera.fov = 60.0
	add_child(_camera)
	_camera.current = true


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_root = Control.new()
	_root.theme = UITheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_root)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 560
	shade.color = Color(0.02, 0.03, 0.02, 0.55)
	_root.add_child(shade)

	_menu = VBoxContainer.new()
	_menu.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_menu.offset_left = 80
	_menu.offset_right = 520
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu.add_theme_constant_override("separation", 14)
	_root.add_child(_menu)

	_menu.add_child(UITheme.label("ORMAN", 96, Color(0.86, 0.9, 0.78)))
	_menu.add_child(UITheme.label(tr("Issız bir ormanda hayatta kal."), 22, UITheme.TEXT_DIM))
	var gap := Control.new()
	gap.custom_minimum_size.y = 30
	_menu.add_child(gap)

	if GameState.has_save():
		var save := GameState.read_save()
		var day := int(save.get("time", {}).get("day", 1))
		_menu.add_child(_button(tr("Devam et  (%d. gün)") % day, GameState.continue_game))
	_menu.add_child(_button(tr("Yeni oyun"), _on_new_game))
	_menu.add_child(_button(tr("Nasıl oynanır"), func() -> void: _show_panel(_help)))
	_menu.add_child(_button(tr("Ayarlar"), func() -> void: _show_panel(_settings)))
	_menu.add_child(_button(tr("Çıkış"), func() -> void: get_tree().quit()))

	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 24
	_menu.add_child(gap2)
	if GameState.best_days > 0:
		_menu.add_child(UITheme.label(tr("En uzun hayatta kalma: %d gün") % GameState.best_days, 16, UITheme.TEXT_DIM))
	_menu.add_child(UITheme.label("v%s" % ProjectSettings.get_setting("application/config/version", "0.1"), 14, UITheme.TEXT_DIM.darkened(0.3)))

	var right := CenterContainer.new()
	right.set_anchors_preset(Control.PRESET_FULL_RECT)
	right.offset_left = 560
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(right)
	var stack := VBoxContainer.new()
	right.add_child(stack)
	_settings = SettingsPanel.new()
	_settings.closed.connect(func() -> void: _show_panel(null))
	stack.add_child(_settings)
	_help = _build_help()
	stack.add_child(_help)
	_confirm = _build_confirm()
	stack.add_child(_confirm)
	_show_panel(null)


func _show_panel(panel: Control) -> void:
	_settings.visible = panel == _settings
	_help.visible = panel == _help
	_confirm.visible = panel == _confirm


func _on_new_game() -> void:
	if GameState.has_save():
		_show_panel(_confirm)
	else:
		GameState.start_new_game()


func _build_confirm() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_box(UITheme.BG, 10, 24))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(UITheme.label(tr("Yeni oyun başlatılsın mı?"), 24, UITheme.ACCENT))
	v.add_child(UITheme.label(tr("Mevcut kayıt, yeni oyunda ilk kayıt alındığında silinir."), 16, UITheme.TEXT_DIM))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	h.add_child(_button(tr("Başlat"), func() -> void: GameState.start_new_game(), 180))
	h.add_child(_button(tr("Vazgeç"), func() -> void: _show_panel(null), 180))
	return panel


func _build_help() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_box(UITheme.BG, 10, 24))
	panel.custom_minimum_size = Vector2(620, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(UITheme.label(tr("NASIL OYNANIR"), 26, UITheme.ACCENT))
	var tips := [
		"Göl ya da dereye bakıp E'yi basılı tutarak su iç. Deniz suyu tuzludur.",
		"Yerden dal, taş ve uzun otlardan lif topla. Tab ile envanteri açıp ip, bıçak ve balta yap.",
		"Baltayla ağaç kes; düşen kütükler barınak ve uzun yanan ateş içindir.",
		"B ile inşa menüsünü aç. Kamp ateşi ısıtır, yemek pişirir, su kaynatır ve kurtları uzak tutar.",
		"Geyiğe eğilerek (Ctrl) yaklaş, mızrakla vur ya da sağ tıkla fırlat. Bıçakla kesip et al.",
		"Çiğ et ve kaynatılmamış su mideni bozabilir. Metal kabı ateşte kullanarak suyu kaynat.",
		"Gece soğuk ve karanlıktır; kurtlar daha cesurdur. Ateş yak ya da meşale taşı.",
		"Barınakta gece uyuyup sabaha atlayabilir, gündüz dinlenip kaydedebilirsin.",
	]
	for t in tips:
		var l := UITheme.label("•  " + tr(t), 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 570
		v.add_child(l)
	v.add_child(UITheme.label(tr("WASD hareket · Shift koş · Space zıpla · Ctrl eğil · E etkileşim · Sol tık vur/kullan · Sağ tık fırlat · Tab envanter · B inşa · R döndür · 1-5 seçim · F5 kayıt · Esc menü"), 14, UITheme.TEXT_DIM))
	var back := _button(tr("Geri"), func() -> void: _show_panel(null), 160)
	v.add_child(back)
	(v.get_child(v.get_child_count() - 2) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(v.get_child(v.get_child_count() - 2) as Label).custom_minimum_size.x = 570
	return panel


func _button(text: String, action: Callable, width := 300) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 50)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(func() -> void: Sfx.play("ui_click", -10.0))
	b.pressed.connect(action)
	return b
