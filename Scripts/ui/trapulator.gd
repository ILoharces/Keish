extends CanvasLayer
class_name Trapulator

# Trapulator: elegir trampa (suelta el maletin si lo llevas) y consultar inventario.

const ROW_HEIGHT: float = 40.0

signal toggled(open: bool)

var player: Player = null
var player2: Player = null
var _active_player: Player = null
var trap_ids: Array[int] = []
var counter_ids: Array[int] = []
var is_open: bool = false
var selected_trap_index: int = 0

var panel: PanelContainer
var trap_rows: Array[Control] = []
var trap_count_labels: Array[Label] = []
var counter_count_labels: Array[Label] = []
var hint_label: Label = null


func _ready() -> void:
	layer = 20
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	trap_ids = ItemDB.get_all_traps()
	counter_ids = ItemDB.get_all_counters()
	_build_ui()
	GameState.traps_changed.connect(_on_traps_changed)
	GameState.game_over.connect(_on_game_over)


func bind_player(p: Player) -> void:
	player = p
	_connect_held(player)


func bind_player2(p: Player) -> void:
	player2 = p
	if p == null:
		return
	_connect_held(p)


func _connect_held(p: Player) -> void:
	if p == null:
		return
	if p.held_changed.is_connected(_on_held_external_change):
		p.held_changed.disconnect(_on_held_external_change)
	p.held_changed.connect(_on_held_external_change)
	_refresh_highlight()


func _owner_player() -> Player:
	if _active_player != null:
		return _active_player
	return player


func _build_ui() -> void:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 420)
	center.add_child(panel)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	var title: Label = Label.new()
	title.text = "TRAPULATOR (el reloj sigue corriendo)"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	root.add_child(columns)

	var trap_col: VBoxContainer = VBoxContainer.new()
	trap_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(trap_col)
	var trap_title: Label = Label.new()
	trap_title.text = "Trampas (clic o Enter)"
	trap_title.add_theme_font_size_override("font_size", 18)
	trap_col.add_child(trap_title)
	for trap_index: int in trap_ids.size():
		var trap_id: int = trap_ids[trap_index]
		var row: PanelContainer = PanelContainer.new()
		row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.gui_input.connect(_on_trap_row_gui_input.bind(trap_index))
		var row_margin: MarginContainer = MarginContainer.new()
		row_margin.add_theme_constant_override("margin_left", 4)
		row_margin.add_theme_constant_override("margin_right", 4)
		row_margin.add_theme_constant_override("margin_top", 2)
		row_margin.add_theme_constant_override("margin_bottom", 2)
		row.add_child(row_margin)
		var inner: HBoxContainer = HBoxContainer.new()
		row_margin.add_child(inner)
		var swatch: ColorRect = ColorRect.new()
		swatch.custom_minimum_size = Vector2(24, 24)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.color = ItemDB.TRAP_COLORS.get(trap_id, Color.WHITE)
		inner.add_child(swatch)
		var name_label: Label = Label.new()
		name_label.text = " " + String(ItemDB.TRAP_NAMES.get(trap_id, "?"))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(name_label)
		var count_label: Label = Label.new()
		count_label.text = "x0"
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(count_label)
		trap_col.add_child(row)
		trap_rows.append(row)
		trap_count_labels.append(count_label)

	var sep: VSeparator = VSeparator.new()
	columns.add_child(sep)

	var counter_col: VBoxContainer = VBoxContainer.new()
	counter_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(counter_col)
	var counter_title: Label = Label.new()
	counter_title.text = "Contramedidas"
	counter_title.add_theme_font_size_override("font_size", 18)
	counter_col.add_child(counter_title)
	for counter_id: int in counter_ids:
		var row: HBoxContainer = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		var name_label: Label = Label.new()
		name_label.text = String(ItemDB.COUNTER_NAMES.get(counter_id, "?"))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var count_label: Label = Label.new()
		count_label.text = "x0"
		row.add_child(count_label)
		counter_col.add_child(row)
		counter_count_labels.append(count_label)

	hint_label = Label.new()
	hint_label.text = "Tab: cerrar  |  Arriba/Abajo: elegir  |  Enter: equipar  |  Q: colocar"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 14)
	root.add_child(hint_label)


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	is_open = true
	visible = true
	_sync_selected_index_to_held()
	_refresh_counts()
	_refresh_highlight()
	toggled.emit(true)


func close(release_trap: bool = true) -> void:
	var owner: Player = _owner_player()
	if release_trap and is_open and owner != null:
		owner.release_trap_selection()
	is_open = false
	visible = false
	_active_player = null
	toggled.emit(false)


func _unhandled_input(event: InputEvent) -> void:
	if GameState.map_overlay_open:
		return
	if event.is_action_pressed("trapulator") and player != null:
		_toggle_for(player)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("p2_trapulator") and player2 != null:
		_toggle_for(player2)
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		_confirm_trap_selection()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_up"):
		_move_trap_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_trap_selection(1)
		get_viewport().set_input_as_handled()


func _on_trap_row_gui_input(event: InputEvent, trap_index: int) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			selected_trap_index = trap_index
			_refresh_highlight()
			_confirm_trap_selection()
			get_viewport().set_input_as_handled()


func _move_trap_selection(delta: int) -> void:
	if trap_ids.is_empty():
		return
	selected_trap_index = (selected_trap_index + delta) % trap_ids.size()
	if selected_trap_index < 0:
		selected_trap_index = trap_ids.size() - 1
	_refresh_highlight()


func _toggle_for(p: Player) -> void:
	if is_open and _active_player != p:
		close()
	_active_player = p
	toggle()


func _confirm_trap_selection() -> void:
	var owner: Player = _owner_player()
	if owner == null or trap_ids.is_empty():
		return
	var trap_id: int = trap_ids[selected_trap_index]
	if owner.equip_trap_from_trapulator(trap_id):
		close(false)


func _sync_selected_index_to_held() -> void:
	selected_trap_index = 0
	var owner: Player = _owner_player()
	if owner == null or owner.held == null:
		return
	var held_trap_id: int = owner.held.get_trap_id()
	if held_trap_id < 0:
		return
	var idx: int = trap_ids.find(held_trap_id)
	if idx >= 0:
		selected_trap_index = idx


func _refresh_highlight() -> void:
	var owner: Player = _owner_player()
	var held_trap_id: int = -1
	if owner != null and owner.held != null and owner.held.is_holding_trap():
		held_trap_id = owner.held.get_trap_id()
	for i: int in trap_rows.size():
		var row: Control = trap_rows[i]
		if trap_ids[i] == held_trap_id:
			row.modulate = Color(1.0, 1.0, 0.55)
		elif i == selected_trap_index:
			row.modulate = Color(0.85, 1.0, 0.85)
		else:
			row.modulate = Color.WHITE
	_refresh_hint()


func _refresh_hint() -> void:
	if hint_label == null:
		return
	var owner: Player = _owner_player()
	if owner == null:
		return
	if owner.held != null and owner.held.is_holding_carried():
		hint_label.text = (
			"Equipar trampa suelta lo que llevas en las manos (recoge con E). "
			+ "Tab: cerrar  |  Enter: equipar"
		)
	else:
		hint_label.text = "Tab: cerrar  |  Arriba/Abajo: elegir  |  Enter: equipar  |  Q: colocar"


func _refresh_counts() -> void:
	var owner: Player = _owner_player()
	if owner == null:
		return
	var spy_id: int = owner.spy_id
	for i: int in trap_ids.size():
		if GameState.match_config.traps_infinite:
			trap_count_labels[i].text = "inf"
		else:
			trap_count_labels[i].text = "x%d" % GameState.get_trap_count(spy_id, trap_ids[i])
	for i: int in counter_ids.size():
		counter_count_labels[i].text = "x%d" % GameState.get_counter_count(spy_id, counter_ids[i])


func _on_traps_changed(_spy_id: int) -> void:
	if is_open:
		_refresh_counts()


func _on_held_external_change(_kind: int, _held_id: int) -> void:
	if is_open:
		_refresh_highlight()


func _on_game_over(_winner_id: int) -> void:
	if is_open:
		close()
	GameState.map_overlay_close_requested.emit()
