class_name StatBar
extends Control
## HUD'daki tek bir istatistik çubuğu: etiket, dolgu ve sayı. Değer kritik
## seviyenin altına inince yanıp söner.

var title := ""
var color := Color.WHITE
var value := 100.0
var critical := 20.0


func _init(p_title: String, p_color: Color) -> void:
	title = p_title
	color = p_color
	custom_minimum_size = Vector2(230, 20) * UITheme.scale()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(v: float) -> void:
	if not is_equal_approx(v, value) or v < critical:
		value = v
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0, 0, 0, 0.5))
	var c := color
	if value < critical:
		c = c.lerp(Color.WHITE, (sin(Time.get_ticks_msec() * 0.012) * 0.5 + 0.5) * 0.5)
	var fill := Rect2(Vector2(2, 2), Vector2((size.x - 4) * clampf(value / 100.0, 0.0, 1.0), size.y - 4))
	draw_rect(fill, c)
	var font := get_theme_default_font()
	var fs := UITheme.fs(14)
	var y := size.y * 0.5 + fs * 0.35
	draw_string(font, Vector2(8, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))
	draw_string(font, Vector2(0, y), str(int(ceil(value))), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, fs, Color(1, 1, 1, 0.95))
