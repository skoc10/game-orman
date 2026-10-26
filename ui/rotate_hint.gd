class_name RotateHint
extends Control
## Dokunmatik cihaz dikey tutulduğunda tam ekran "Telefonu yan çevir" uyarısı.
## Oyun ve menüler yatay ekrana göre tasarlanmıştır.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	var size := get_viewport_rect().size
	var portrait := size.y > size.x
	if portrait != visible:
		visible = portrait
	if portrait:
		queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.03, 0.94))
	var c := size * 0.5 - Vector2(0, 80)
	# Yan dönen telefon simgesi.
	draw_rect(Rect2(c - Vector2(45, 80), Vector2(90, 160)), Color(1, 1, 1, 0.8), false, 5.0)
	draw_arc(c, 130.0, -0.6, 0.6, 16, UITheme.ACCENT, 6.0, true)
	draw_string(font, Vector2(0, size.y * 0.5 + 120), tr("Telefonu yan çevir"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 56, Color.WHITE)
	draw_string(font, Vector2(0, size.y * 0.5 + 190), tr("Oyun yatay ekranda oynanır."), HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, Color(1, 1, 1, 0.7))
