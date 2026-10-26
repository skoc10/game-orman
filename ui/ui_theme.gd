class_name UITheme
extends RefCounted
## Tüm arayüzün ortak görünümü: koyu, yarı saydam paneller ve sade düğmeler.

const BG := Color(0.06, 0.08, 0.06, 0.82)
const BG_LIGHT := Color(0.14, 0.18, 0.13, 0.9)
const ACCENT := Color(0.55, 0.75, 0.38)
const TEXT := Color(0.93, 0.92, 0.86)
const TEXT_DIM := Color(0.66, 0.68, 0.6)
const DANGER := Color(0.86, 0.32, 0.28)

static var _theme: Theme
static var _scale := -1.0


## Önbelleği temizler; ölçek değişince yeni sahnede tema yeniden kurulur.
static func reset() -> void:
	_theme = null
	_scale = -1.0


## Dokunmatik ekranda yazılar biraz daha büyük.
static func scale() -> float:
	if _scale < 0.0:
		_scale = 1.2 if GameState.touch_controls_enabled() else 1.0
	return _scale


static func fs(size: int) -> int:
	return int(round(size * scale()))


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = fs(18)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)

	t.set_stylebox("panel", "PanelContainer", panel_box(BG))
	t.set_stylebox("panel", "Panel", panel_box(BG))

	t.set_stylebox("normal", "Button", panel_box(BG_LIGHT, 6, 10))
	t.set_stylebox("hover", "Button", panel_box(BG_LIGHT.lightened(0.15), 6, 10, ACCENT))
	t.set_stylebox("pressed", "Button", panel_box(ACCENT.darkened(0.4), 6, 10, ACCENT))
	t.set_stylebox("focus", "Button", panel_box(Color(0, 0, 0, 0), 6, 10, ACCENT))
	t.set_stylebox("disabled", "Button", panel_box(Color(0.1, 0.1, 0.1, 0.6), 6, 10))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", TEXT_DIM.darkened(0.3))
	t.set_font_size("font_size", "Button", fs(20))
	t.set_font_size("font_size", "OptionButton", fs(18))
	t.set_font_size("font_size", "CheckBox", fs(18))
	t.set_font_size("font_size", "PopupMenu", fs(18))
	_theme = t
	return t


static func panel_box(color: Color, radius := 8, padding := 12, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(padding)
	if border.a > 0.0:
		sb.set_border_width_all(2)
		sb.border_color = border
	return sb


static func label(text: String, size := 18, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
