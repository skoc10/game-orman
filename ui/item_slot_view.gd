class_name ItemSlotView
extends Control
## Tek bir envanter slotunun çizimi: renkli kare, kısaltma, adet ve dayanıklılık.
## Envanter ekranında tıklanabilir, HUD'da yalnızca gösterim içindir.

signal clicked(index: int, button: int)

var index := 0
var data: Dictionary = {}
var selected := false
var highlighted := false
var hotkey := ""


func _init(p_index := 0, p_size := 64.0, interactive := true) -> void:
	index = p_index
	custom_minimum_size = Vector2(p_size, p_size)
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE


func set_data(d: Dictionary, p_selected := false, p_highlighted := false) -> void:
	if d == data and p_selected == selected and p_highlighted == highlighted:
		return
	data = d.duplicate()
	selected = p_selected
	highlighted = p_highlighted
	var item := ItemDB.get_item(d.id) if not d.is_empty() else null
	tooltip_text = "%s\n%s" % [item.display_name, item.description] if item else ""
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		clicked.emit(index, event.button_index)
		accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var border := UITheme.ACCENT if selected else (Color(1, 1, 1, 0.5) if highlighted else Color(1, 1, 1, 0.12))
	draw_style_box(UITheme.panel_box(Color(0, 0, 0, 0.45), 6, 0, border), r)
	var font := get_theme_default_font()
	if hotkey != "":
		draw_string(font, Vector2(5, 14), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.55))
	if data.is_empty():
		return
	var item := ItemDB.get_item(data.id)
	if item == null:
		return
	var inner := r.grow(-size.x * 0.16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = item.color
	sb.set_corner_radius_all(int(size.x * 0.12))
	draw_style_box(sb, inner)
	var fs := int(size.x * 0.28)
	var text_col := Color.WHITE if item.color.get_luminance() < 0.55 else Color(0.1, 0.1, 0.1)
	draw_string(font, Vector2(0, size.y * 0.5 + fs * 0.35), item.abbr, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, text_col)
	var count := int(data.get("count", 1))
	if count > 1:
		draw_string_outline(font, Vector2(0, size.y - 5), str(count), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 5, int(size.x * 0.24), 4, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(0, size.y - 5), str(count), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 5, int(size.x * 0.24), Color.WHITE)
	if item.has_durability():
		var t := clampf(float(data.get("dur", 0.0)) / item.durability, 0.0, 1.0)
		var bar := Rect2(Vector2(6, size.y - 7), Vector2((size.x - 12) * t, 3))
		draw_rect(Rect2(Vector2(6, size.y - 7), Vector2(size.x - 12, 3)), Color(0, 0, 0, 0.6))
		draw_rect(bar, Color(0.9, 0.3, 0.2).lerp(Color(0.5, 0.85, 0.35), t))
