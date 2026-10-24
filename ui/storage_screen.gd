extends CanvasLayer
## Sandık ekranı: solda oyuncu envanteri, sağda sandık. Bir slota tıklamak o
## yığını diğer tarafa taşır.

var player: Player
var box: Node
var is_open := false

var _root: Control
var _player_slots: Array[ItemSlotView] = []
var _box_slots: Array[ItemSlotView] = []
var _player_grid: GridContainer
var _box_grid: GridContainer


func _ready() -> void:
	layer = 10
	player = get_parent().get_node("Player")
	_build()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func open(p_box: Node) -> void:
	if player.input_locked:
		return
	box = p_box
	is_open = true
	visible = true
	player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fill_grid(_box_grid, _box_slots, box.inventory, _on_box_clicked)
	_refresh()


func close() -> void:
	is_open = false
	visible = false
	box = null
	player.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh() -> void:
	for i in _player_slots.size():
		_player_slots[i].set_data(player.inventory.get_slot(i))
	if box:
		for i in _box_slots.size():
			_box_slots[i].set_data(box.inventory.get_slot(i))


func _on_player_clicked(index: int, _button: int) -> void:
	_transfer(player.inventory, box.inventory, index)


func _on_box_clicked(index: int, _button: int) -> void:
	_transfer(box.inventory, player.inventory, index)


static func _transfer(from: Inventory, to: Inventory, index: int) -> void:
	var s := from.get_slot(index)
	if s.is_empty():
		return
	var left := to.add(s.id, int(s.count), float(s.get("dur", -1.0)))
	var moved := int(s.count) - left
	if moved > 0:
		from.take_from(index, moved)


func _fill_grid(grid: GridContainer, list: Array[ItemSlotView], inv: Inventory, handler: Callable) -> void:
	for c in grid.get_children():
		c.queue_free()
	list.clear()
	for i in inv.size():
		var slot := ItemSlotView.new(i, 64)
		slot.clicked.connect(handler)
		grid.add_child(slot)
		list.append(slot)
	if not inv.changed.is_connected(_refresh):
		inv.changed.connect(_refresh)


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
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	v.add_child(cols)
	for side in [[tr("ENVANTER"), 5], [tr("SANDIK"), 4]]:
		var col := VBoxContainer.new()
		col.add_child(UITheme.label(side[0], 24, UITheme.ACCENT))
		var grid := GridContainer.new()
		grid.columns = side[1]
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		col.add_child(grid)
		cols.add_child(col)
		if _player_grid == null:
			_player_grid = grid
		else:
			_box_grid = grid
	v.add_child(UITheme.label(tr("Tıkla: yığını diğer tarafa taşı · E / Esc: kapat"), 14, UITheme.TEXT_DIM))
	_fill_grid(_player_grid, _player_slots, player.inventory, _on_player_clicked)
