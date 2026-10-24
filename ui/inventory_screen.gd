extends CanvasLayer
## Envanter ve üretim ekranı (Tab). Sol tık slot seçer ya da seçili eşyayı
## taşır; sağ tık eşyayı kullanır. Sağ tarafta üretilebilir tarifler listelenir.

const COLUMNS := 5

var player: Player
var is_open := false

var _root: Control
var _slots: Array[ItemSlotView] = []
var _selected := -1
var _name: Label
var _desc: Label
var _effects: Label
var _use_btn: Button
var _drop_btn: Button
var _recipe_box: VBoxContainer


func _ready() -> void:
	layer = 10
	player = get_parent().get_node("Player")
	_build()
	player.inventory.changed.connect(_refresh)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if is_open:
			close()
		elif not player.input_locked and not player.stats.dead:
			open()
		get_viewport().set_input_as_handled()
	elif is_open and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	is_open = true
	visible = true
	player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_selected = -1
	_refresh()


func close() -> void:
	is_open = false
	visible = false
	player.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh() -> void:
	if not is_open:
		return
	var inv := player.inventory
	for i in _slots.size():
		_slots[i].set_data(inv.get_slot(i), i == _selected, i == player.equipment.selected)
	_show_details()
	_build_recipes()


func _on_slot_clicked(index: int, button: int) -> void:
	var inv := player.inventory
	if button == MOUSE_BUTTON_RIGHT:
		_use(index)
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	if _selected == -1:
		if not inv.get_slot(index).is_empty():
			_selected = index
	elif _selected == index:
		_selected = -1
	else:
		inv.move(_selected, index)
		_selected = -1
	_refresh()


func _use(index: int) -> void:
	var item := player.inventory.slot_item(index)
	if item == null:
		return
	if item.is_consumable():
		var sick := player.stats.consume(item, player.rng)
		player.inventory.take_from(index, 1)
		player.notify("%s %s" % [item.display_name, tr("içtin") if item.category == ItemData.Category.DRINK else tr("yedin")])
		if sick:
			player.notify(tr("Midem bulanıyor..."))
	elif index < Inventory.HOTBAR:
		player.equipment.select(index)
	_refresh()


func _drop(index: int) -> void:
	var stack := player.inventory.take_from(index, 999)
	if stack.is_empty():
		return
	var fwd := -player.global_transform.basis.z
	var p := player.global_position + fwd * 1.2
	var gen: WorldGen = GameState.world.gen
	p.y = maxf(gen.height_at(p.x, p.z), WorldGen.WATER_LEVEL - 3.0)
	GameState.world.spawn_pickup(stack.id, stack.count, p, stack.dur, randf() * TAU)
	_selected = -1
	_refresh()


func _show_details() -> void:
	var item := player.inventory.slot_item(_selected) if _selected >= 0 else null
	_use_btn.visible = item != null
	_drop_btn.visible = item != null
	if item == null:
		_name.text = tr("Bir eşya seç")
		_desc.text = tr("Sol tık: seç ve taşı · Sağ tık: kullan / ele al")
		_effects.text = ""
		return
	_name.text = item.display_name
	_desc.text = item.description
	_effects.text = _effects_text(item, player.inventory.get_slot(_selected))
	_use_btn.text = tr("Kullan") if item.is_consumable() else tr("Ele al")
	_use_btn.disabled = not item.is_consumable() and _selected >= Inventory.HOTBAR


static func _effects_text(item: ItemData, slot: Dictionary) -> String:
	var parts := PackedStringArray()
	for pair in [["Tokluk", item.hunger], ["Su", item.thirst], ["Can", item.health]]:
		if pair[1] != 0.0:
			parts.append("%s %+d" % [pair[0], int(pair[1])])
	if item.nausea_chance > 0.0:
		parts.append("Mide bulantısı riski %%%d" % int(item.nausea_chance * 100.0))
	if item.damage > 0.0:
		parts.append("Hasar %d" % int(item.damage))
	if item.chop_power > 0.0:
		parts.append("Ağaç kesme %d" % int(item.chop_power))
	if item.has_durability():
		var unit := " sn" if item.category == ItemData.Category.LIGHT else ""
		parts.append("Dayanıklılık %d/%d%s" % [int(float(slot.get("dur", 0.0))), int(item.durability), unit])
	if item.fuel > 0.0:
		parts.append("Yakıt %d sn" % int(item.fuel))
	if item.cold_resist < 1.0:
		parts.append("Soğuk direnci %%%d" % int((1.0 - item.cold_resist) * 100.0))
	return "  ·  ".join(parts)


func _build_recipes() -> void:
	for c in _recipe_box.get_children():
		c.queue_free()
	var inv := player.inventory
	for recipe in ItemDB.craft_recipes():
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UITheme.panel_box(UITheme.BG_LIGHT, 6, 8))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		var icon := ItemSlotView.new(0, 44, false)
		icon.set_data({"id": recipe.result_id, "count": recipe.result_count, "dur": 0.0})
		h.add_child(icon)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UITheme.label(recipe.display_name, 18))
		var ok := Crafting.has_ingredients(inv, recipe)
		var ing := UITheme.label(Crafting.ingredients_text(inv, recipe), 14, UITheme.TEXT_DIM if ok else Color(0.95, 0.55, 0.45))
		ing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(ing)
		h.add_child(v)
		var btn := Button.new()
		btn.text = tr("Üret")
		btn.disabled = not ok
		btn.custom_minimum_size = Vector2(80, 40)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(_craft.bind(recipe))
		h.add_child(btn)
		_recipe_box.add_child(row)


func _craft(recipe: RecipeData) -> void:
	if Crafting.craft(player.inventory, recipe):
		player.notify(tr("Üretildi: %s") % recipe.display_name)
	else:
		player.notify(tr("Envanterde yer yok."))


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
	panel.add_theme_stylebox_override("panel", UITheme.panel_box(UITheme.BG, 10, 20))
	center.add_child(panel)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	panel.add_child(cols)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	cols.add_child(left)
	left.add_child(UITheme.label(tr("ENVANTER"), 24, UITheme.ACCENT))
	left.add_child(UITheme.label(tr("İlk sıra hızlı erişim çubuğu (1–5)"), 14, UITheme.TEXT_DIM))
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	left.add_child(grid)
	for i in player.inventory.size():
		var slot := ItemSlotView.new(i, 72)
		if i < Inventory.HOTBAR:
			slot.hotkey = str(i + 1)
		slot.clicked.connect(_on_slot_clicked)
		grid.add_child(slot)
		_slots.append(slot)

	var details := PanelContainer.new()
	details.add_theme_stylebox_override("panel", UITheme.panel_box(UITheme.BG_LIGHT, 8, 12))
	details.custom_minimum_size = Vector2(0, 150)
	left.add_child(details)
	var dv := VBoxContainer.new()
	details.add_child(dv)
	_name = UITheme.label("", 22)
	_desc = UITheme.label("", 15, UITheme.TEXT_DIM)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size.x = 380
	_effects = UITheme.label("", 15, UITheme.ACCENT)
	_effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_name)
	dv.add_child(_desc)
	dv.add_child(_effects)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	dv.add_child(buttons)
	_use_btn = Button.new()
	_use_btn.custom_minimum_size = Vector2(110, 38)
	_use_btn.pressed.connect(func() -> void: _use(_selected))
	buttons.add_child(_use_btn)
	_drop_btn = Button.new()
	_drop_btn.text = tr("Yere at")
	_drop_btn.custom_minimum_size = Vector2(110, 38)
	_drop_btn.pressed.connect(func() -> void: _drop(_selected))
	buttons.add_child(_drop_btn)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	cols.add_child(right)
	right.add_child(UITheme.label(tr("ÜRETİM"), 24, UITheme.ACCENT))
	right.add_child(UITheme.label(tr("İnşa için B tuşu"), 14, UITheme.TEXT_DIM))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_recipe_box = VBoxContainer.new()
	_recipe_box.add_theme_constant_override("separation", 8)
	_recipe_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_recipe_box)
