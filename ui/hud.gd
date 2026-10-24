extends CanvasLayer
## Oyun içi arayüz: istatistik çubukları, nişangah, etkileşim ipucu, saat,
## bildirimler, uyarılar ve ekran kenarı efektleri.

const VIGNETTE_SHADER := preload("res://ui/vignette.gdshader")
const DeathScreen := preload("res://ui/death_screen.gd")
const NOTIFY_SECONDS := 3.5

var player: Player

var _bars := {}
var _status: Label
var _prompt: Label
var _hold_bar: ProgressBar
var _clock: Label
var _warning: Label
var _notes: VBoxContainer
var _vignette_mat: ShaderMaterial
var _damage_flash := 0.0
var _root: Control
var _fade: ColorRect
var _hotbar: Array[ItemSlotView] = []
var _held_name: Label


func _ready() -> void:
	layer = 5
	player = get_parent().get_node("Player")
	_root = Control.new()
	_root.theme = UITheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_vignette()
	_build_stats()
	_build_center()
	_build_corner()
	_build_hotbar()
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	Events.notify.connect(show_note)
	Events.interaction_changed.connect(_on_interaction)
	Events.player_damaged.connect(_on_damaged)
	Events.player_died.connect(_on_died)


func _process(delta: float) -> void:
	if player == null:
		return
	var s := player.stats
	_bars.health.set_value(s.health)
	_bars.hunger.set_value(s.hunger)
	_bars.thirst.set_value(s.thirst)
	_bars.warmth.set_value(s.warmth)
	_bars.stamina.set_value(s.stamina)
	_bars.warmth.color = Color(0.45, 0.7, 1.0).lerp(Color(0.95, 0.72, 0.3), s.warmth / 100.0)

	var status := []
	if s.is_nauseous():
		status.append(tr("Mide bulantısı %d sn") % int(ceil(s.nausea_time)))
	var target := player.current_warmth_target()
	if target > TimeOfDay.ambient_warmth() + 1.0 and target > s.warmth + 1.0:
		status.append(tr("Isınıyorsun"))
	elif target < s.warmth - 1.0 and s.warmth < 60.0:
		status.append(tr("Üşüyorsun"))
	_status.text = "  ·  ".join(status)

	_clock.text = tr("%d. Gün  %s") % [TimeOfDay.day, TimeOfDay.clock_text()]
	var sel := player.equipment.selected if player.equipment else 0
	for i in _hotbar.size():
		_hotbar[i].set_data(player.inventory.get_slot(i), i == sel)
	var held := player.inventory.slot_item(sel)
	_held_name.text = held.display_name if held else ""
	_warning.text = _warning_text(s)

	_damage_flash = maxf(0.0, _damage_flash - delta * 1.6)
	var underwater := player.camera.global_position.y < WorldGen.WATER_LEVEL
	_vignette_mat.set_shader_parameter("damage", _damage_flash)
	_vignette_mat.set_shader_parameter("low_health", clampf((35.0 - s.health) / 35.0, 0.0, 1.0))
	_vignette_mat.set_shader_parameter("nausea", 1.0 if s.is_nauseous() else 0.0)
	_vignette_mat.set_shader_parameter("cold", clampf((30.0 - s.warmth) / 30.0, 0.0, 1.0))
	_vignette_mat.set_shader_parameter("underwater", 1.0 if underwater else 0.0)


func show_note(text: String) -> void:
	var l := UITheme.label(text, 18)
	_notes.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(NOTIFY_SECONDS)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
	while _notes.get_child_count() > 6:
		_notes.get_child(0).free()


## Ekranı karartır (1) ya da açar (0). Uyku geçişinde kullanılır.
func fade_to(alpha: float, duration: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, duration)
	return tw


func set_visible_hud(v: bool) -> void:
	_root.visible = v


func _warning_text(s: SurvivalStats) -> String:
	if s.dead:
		return ""
	if player.is_swimming and s.stamina < 20.0:
		return tr("Boğuluyorsun! Kıyıya çık!")
	if s.thirst < 12.0:
		return tr("Çok susadın!")
	if s.hunger < 12.0:
		return tr("Açlıktan bayılmak üzeresin!")
	if s.warmth < 12.0:
		return tr("Donuyorsun! Ateş yak ya da sığınak bul.")
	return ""


func _on_interaction(text: String, progress: float) -> void:
	_prompt.text = text
	_hold_bar.visible = progress >= 0.0
	if progress >= 0.0:
		_hold_bar.value = progress


func _on_damaged(amount: float) -> void:
	_damage_flash = minf(1.0, _damage_flash + amount / 25.0 + 0.2)


func _on_died(cause: String) -> void:
	_root.visible = false
	var screen := DeathScreen.new()
	screen.cause = cause
	add_sibling(screen)


func _build_vignette() -> void:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = VIGNETTE_SHADER
	rect.material = _vignette_mat
	_root.add_child(rect)


func _build_stats() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_place(box, 24, -24, 24, -24)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)

	_notes = VBoxContainer.new()
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notes.alignment = BoxContainer.ALIGNMENT_END
	_notes.custom_minimum_size = Vector2(400, 0)
	box.add_child(_notes)

	_status = UITheme.label("", 15, UITheme.TEXT_DIM)
	box.add_child(_status)
	for entry in [
		["health", tr("Can"), Color(0.84, 0.27, 0.27)],
		["hunger", tr("Tokluk"), Color(0.89, 0.6, 0.23)],
		["thirst", tr("Su"), Color(0.29, 0.64, 0.87)],
		["warmth", tr("Isı"), Color(0.95, 0.72, 0.3)],
		["stamina", tr("Enerji"), Color(0.48, 0.79, 0.44)],
	]:
		var bar := StatBar.new(entry[1], entry[2])
		_bars[entry[0]] = bar
		box.add_child(bar)
	_bars.stamina.custom_minimum_size.y = 12
	_bars.stamina.critical = 0.0


func _build_center() -> void:
	var cross := Label.new()
	cross.text = "·"
	cross.add_theme_font_size_override("font_size", 32)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cross.grow_vertical = Control.GROW_DIRECTION_BOTH
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(cross)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	_place(box, -300, 40, 300, 40)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	_prompt = UITheme.label("", 20)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_prompt)
	_hold_bar = ProgressBar.new()
	_hold_bar.max_value = 1.0
	_hold_bar.show_percentage = false
	_hold_bar.custom_minimum_size = Vector2(160, 6)
	_hold_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hold_bar.add_theme_stylebox_override("background", UITheme.panel_box(Color(0, 0, 0, 0.5), 3, 0))
	_hold_bar.add_theme_stylebox_override("fill", UITheme.panel_box(UITheme.ACCENT, 3, 0))
	_hold_bar.visible = false
	_hold_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_hold_bar)

	_warning = UITheme.label("", 26, Color(1.0, 0.78, 0.6))
	_warning.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_warning, -500, 80, 500, 80)
	_root.add_child(_warning)


func _build_corner() -> void:
	_clock = UITheme.label("", 22)
	_clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_clock.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_clock, -24, 20, -24, 20)
	_root.add_child(_clock)


func _build_hotbar() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_place(box, -200, -20, 200, -20)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	_held_name = UITheme.label("", 16, UITheme.TEXT)
	_held_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_held_name)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	for i in Inventory.HOTBAR:
		var slot := ItemSlotView.new(i, 58, false)
		slot.hotkey = str(i + 1)
		row.add_child(slot)
		_hotbar.append(slot)


static func _place(c: Control, left: float, top: float, right: float, bottom: float) -> void:
	c.offset_left = left
	c.offset_top = top
	c.offset_right = right
	c.offset_bottom = bottom
