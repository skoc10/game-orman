extends CanvasLayer
## Takas ekranı: şefin bugünkü teklifleri. Her satırda ne verip ne alacağın,
## elinde ne kadar olduğu ve bugün kaç kez yapılabileceği yazar.

var player: Player
var trader: Villager
var is_open := false

var _root: Control
var _title: Label
var _list: VBoxContainer


func _ready() -> void:
	layer = 10
	player = get_parent().get_node("Player")
	_build()
	visible = false
	player.inventory.changed.connect(func() -> void:
		if is_open:
			_fill())


func _unhandled_input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory")):
		close()
		get_viewport().set_input_as_handled()


func open(p_trader: Villager) -> void:
	if player.input_locked:
		return
	trader = p_trader
	is_open = true
	visible = true
	player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_title.text = tr("Şef %s ile takas") % trader.display_name
	_fill()


func close() -> void:
	is_open = false
	visible = false
	trader = null
	player.input_locked = false
	GameState.capture_mouse()


func _village() -> Village:
	return trader.village as Village if trader else null


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	var village := _village()
	if village == null:
		return
	var t := village.trading
	for i in t.offers.size():
		var o: Dictionary = t.offers[i]
		var ok := t.can_trade(player.inventory, i)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UITheme.panel_box(UITheme.BG_LIGHT, 6, 10))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		for id in o.get:
			var icon := ItemSlotView.new(0, 52, false)
			icon.set_data({"id": id, "count": int(o.get[id]), "dur": 0.0})
			h.add_child(icon)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UITheme.label(tr("Al: %s") % Trading.describe(o.get), 18))
		var have := PackedStringArray()
		for id in o.give:
			have.append("%s %d/%d" % [ItemDB.display_name(id), mini(player.inventory.count_of(id), int(o.give[id])), int(o.give[id])])
		var enough := player.inventory.has_all(o.give)
		v.add_child(UITheme.label(tr("Ver: %s") % ", ".join(have), 15, UITheme.ACCENT if enough else Color(0.95, 0.55, 0.45)))
		v.add_child(UITheme.label(tr("Bugün %d kez") % int(o.stock) if int(o.stock) > 0 else tr("Bugünlük bitti"), 13, UITheme.TEXT_DIM))
		h.add_child(v)
		var btn := Button.new()
		btn.text = tr("Takas et")
		btn.disabled = not ok
		btn.custom_minimum_size = Vector2(120, 44)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(_trade.bind(i))
		h.add_child(btn)
		_list.add_child(row)


func _trade(i: int) -> void:
	var village := _village()
	if village == null:
		return
	var o: Dictionary = village.trading.offers[i]
	if village.trading.trade(player.inventory, i):
		Sfx.play("trade", -6.0)
		player.notify(tr("Takas: %s aldın.") % Trading.describe(o.get))
	else:
		player.notify(tr("Takas olmadı: eşya eksik ya da envanter dolu."))
	_fill()


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
	panel.add_theme_stylebox_override("panel", UITheme.panel_box(UITheme.BG, 10, 18))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	_title = UITheme.label("", 24, UITheme.ACCENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close_btn := Button.new()
	close_btn.text = tr("Kapat")
	close_btn.custom_minimum_size = Vector2(110, 40)
	close_btn.pressed.connect(close)
	head.add_child(close_btn)
	v.add_child(head)
	v.add_child(UITheme.label(tr("Teklifler her gün değişir."), 14, UITheme.TEXT_DIM))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(640, 440) if GameState.touch_controls_enabled() else Vector2(660, 520)
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
