extends CanvasLayer
## Ölüm ekranı: sebep, hayatta kalınan süre, rekor ve yeniden başlama seçenekleri.

const CAUSE_TEXT := {
	"açlık": "Açlıktan öldün.",
	"susuzluk": "Susuzluktan öldün.",
	"soğuk": "Donarak öldün.",
	"boğulma": "Boğuldun.",
	"düşme": "Yüksekten düştün.",
	"zehirlenme": "Zehirlendin.",
	"kurt": "Kurtlar seni parçaladı.",
	"ayı": "Bir ayı seni parçaladı.",
	"yılan": "Yılan zehri seni öldürdü.",
}

var cause := ""


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var hours := (TimeOfDay.day - 1) * 24.0 + TimeOfDay.hour - Balance.d.start_hour
	hours = maxf(hours, 0.0)
	var days := int(hours / 24.0)
	GameState.record_days(days)

	var root := Control.new()
	root.theme = UITheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.0, 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.modulate.a = 0.0
	root.add_child(box)

	for line in [
		[tr("ÖLDÜN"), 64, UITheme.DANGER],
		[tr(CAUSE_TEXT.get(cause, "Hayatını kaybettin.")), 24, UITheme.TEXT],
		[tr("%d gün %d saat hayatta kaldın") % [days, int(hours) % 24], 22, UITheme.TEXT],
		[tr("Rekor: %d gün") % GameState.best_days, 18, UITheme.TEXT_DIM],
	]:
		var l := UITheme.label(line[0], line[1], line[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	box.add_child(spacer)

	if GameState.has_save():
		box.add_child(_button(tr("Kayıttan devam"), GameState.continue_game))
	box.add_child(_button(tr("Yeni oyun"), func() -> void: GameState.start_new_game()))
	if ResourceLoader.exists(GameState.MENU_SCENE):
		box.add_child(_button(tr("Ana menü"), GameState.go_to_menu))

	var tw := create_tween()
	tw.tween_property(shade, "color:a", 0.78, 2.0)
	tw.parallel().tween_property(box, "modulate:a", 1.0, 1.5).set_delay(0.8)


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 46)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(action)
	return b
