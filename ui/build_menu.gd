extends CanvasLayer
## İnşa menüsü (B): yapılabilecek yapıları ve malzemelerini listeler.
## Seçilen yapı için inşa moduna geçilir.

var player: Player
var is_open := false

var _root: Control
var _list: VBoxContainer


func _ready() -> void:
	layer = 10
	player = get_parent().get_node("Player")
	_build()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build"):
		if is_open:
			close()
			get_viewport().set_input_as_handled()
		elif not player.input_locked and not player.stats.dead and not player.build.is_placing():
			open()
			get_viewport().set_input_as_handled()
	elif is_open and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory")):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	is_open = true
	visible = true
	player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fill()


func close() -> void:
	is_open = false
	visible = false
	player.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _choose(recipe: RecipeData) -> void:
	close()
	player.build.start(recipe)


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	for recipe in ItemDB.build_recipes():
		var ok := Crafting.has_ingredients(player.inventory, recipe)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UITheme.panel_box(UITheme.BG_LIGHT, 6, 12))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		row.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UITheme.label(recipe.display_name, 20))
		var desc := UITheme.label(recipe.description, 14, UITheme.TEXT_DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x = 380
		v.add_child(desc)
		v.add_child(UITheme.label(Crafting.ingredients_text(player.inventory, recipe), 15, UITheme.ACCENT if ok else Color(0.95, 0.55, 0.45)))
		h.add_child(v)
		var btn := Button.new()
		btn.text = tr("Yerleştir")
		btn.custom_minimum_size = Vector2(120, 44)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(_choose.bind(recipe))
		h.add_child(btn)
		_list.add_child(row)


func _build() -> void:
	_root = Control.new()
	_root.theme = UITheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_box(UITheme.BG, 10, 22))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(UITheme.label(tr("İNŞA"), 26, UITheme.ACCENT))
	v.add_child(UITheme.label(tr("Malzemeler eksikse de yerleştirmeyi deneyebilirsin; önizleme neyin eksik olduğunu söyler."), 14, UITheme.TEXT_DIM))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	_list.custom_minimum_size = Vector2(620, 0)
	v.add_child(_list)
	v.add_child(UITheme.label(tr("B / Esc: kapat"), 14, UITheme.TEXT_DIM))
