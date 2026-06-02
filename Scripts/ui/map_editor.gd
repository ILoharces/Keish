extends CanvasLayer
class_name MapEditor

# Editor de mapas: habitaciones, puertas, puerta de salida y spawns de jugadores.

signal map_confirmed(layout: LevelLayout)
signal editor_closed

enum InputMode { GRID, MENU }

enum DeviceMode { GAMEPAD, MOUSE }

enum PendingAction { NONE, PLAY, SAVE }

const MODES: Array[MapEditorGrid.PlaceMode] = [
	MapEditorGrid.PlaceMode.BUILD,
	MapEditorGrid.PlaceMode.EXIT,
	MapEditorGrid.PlaceMode.PLAYER,
	MapEditorGrid.PlaceMode.AI,
]

const MODE_LABELS: Array[String] = ["Habitaciones", "Salida", "Jugador 1", "Jugador 2"]

const MODE_HINTS: Array[String] = [
	"Crea habitaciones con A. Puertas: apunta el borde con stick R y pulsa A.",
	"Coloca la salida en un borde exterior o puerta existente (stick R + A).",
	"Pulsa A en una habitacion para el spawn del jugador 1 (1).",
	"Pulsa A en una habitacion para el spawn del jugador 2 (2).",
]

const MODE_HINTS_MOUSE: Array[String] = [
	"Click en celdas para habitaciones. Click en bordes entre habitaciones para puertas.",
	"Click en un borde exterior o en una puerta para colocar la salida.",
	"Click en una habitacion para el spawn del jugador 1 (1).",
	"Click en una habitacion para el spawn del jugador 2 (2).",
]

const NAV_REPEAT_DELAY: float = 0.32
const NAV_REPEAT_RATE: float = 0.07
const EDGE_STICK_DEADZONE: float = 0.45
const GAMEPAD_AXIS_DEADZONE: float = 0.35

@onready var _panel: PanelContainer = %Panel
@onready var _grid_frame: PanelContainer = $Center/Panel/Margin/RootVBox/MainSplit/Content/GridFrame
@onready var _grid: MapEditorGrid = %EditorGrid
@onready var _back_button: Button = %BackButton
@onready var _load_button: Button = %LoadButton
@onready var _save_button: Button = %SaveButton
@onready var _build_button: Button = %BuildModeButton
@onready var _exit_button: Button = %ExitModeButton
@onready var _player_button: Button = %PlayerModeButton
@onready var _ai_button: Button = %AiModeButton
@onready var _play_button: Button = %PlayButton
@onready var _connect_button: Button = %ConnectAllButton
@onready var _door_count_button: Button = %DoorCountButton
@onready var _clear_button: Button = %ClearButton
@onready var _mode_hint: Label = %ModeHint
@onready var _stats_label: Label = %StatsLabel
@onready var _status_label: Label = %StatusLabel
@onready var _hint_label: Label = %Hint
@onready var _mode_label: Label = %ModeLabel
@onready var _ai_play_button: Button = %AiPlayButton
@onready var _local_play_button: Button = %LocalPlayButton

var _save_dialog: AcceptDialog = null
var _load_dialog: AcceptDialog = null
var _connectivity_dialog: ConfirmationDialog = null
var _save_name_edit: LineEdit = null
var _load_list: ItemList = null
var _load_entries: Array[Dictionary] = []
var _current_map_id: String = ""
var _current_map_name: String = ""
var _input_mode: InputMode = InputMode.GRID
var _device_mode: DeviceMode = DeviceMode.MOUSE
var _mode_index: int = 0
var _menu_controls: Array[Control] = []
var _held_nav: Vector2i = Vector2i.ZERO
var _nav_repeat_timer: float = 0.0
var _pending_action: PendingAction = PendingAction.NONE
var _pending_layout: LevelLayout = null
var _pending_save_name: String = ""


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_process_input(true)
	set_process_unhandled_input(true)
	set_process(true)
	var center: Control = $Center as Control
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_ui_theme()
	_menu_controls = [
		_back_button,
		_load_button,
		_save_button,
		_build_button,
		_exit_button,
		_player_button,
		_ai_button,
		_connect_button,
		_door_count_button,
		_clear_button,
		_ai_play_button,
		_local_play_button,
		_play_button,
	]
	_wire_menu_focus()
	_back_button.pressed.connect(_on_back_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_build_button.toggled.connect(_on_build_mode_toggled)
	_exit_button.toggled.connect(_on_exit_mode_toggled)
	_player_button.toggled.connect(_on_player_mode_toggled)
	_ai_button.toggled.connect(_on_ai_mode_toggled)
	_play_button.pressed.connect(_on_play_pressed)
	_connect_button.pressed.connect(_on_connect_all_pressed)
	_door_count_button.toggled.connect(_on_door_count_toggled)
	_clear_button.pressed.connect(_on_clear_pressed)
	_ai_play_button.toggled.connect(_on_ai_play_toggled)
	_local_play_button.toggled.connect(_on_local_play_toggled)
	_grid.room_toggled.connect(_on_grid_changed)
	_grid.door_toggled.connect(_on_grid_changed)
	_grid.marker_changed.connect(_on_grid_changed)
	_grid.pointer_used.connect(_on_grid_pointer_used)
	_grid.cursor_moved.connect(_on_grid_cursor_moved)
	_build_save_dialog()
	_build_load_dialog()
	_build_connectivity_dialog()
	_set_input_mode(InputMode.GRID)
	_update_status()


func show_editor() -> void:
	_set_play_against_ai(GameSettings.use_ai_default)
	visible = true
	_grid.reset_cursor()
	_set_device_mode(DeviceMode.MOUSE)
	_set_input_mode(InputMode.GRID)


func hide_editor() -> void:
	visible = false
	_grid.set_cursor_visible(false)


func _set_input_mode(mode: InputMode) -> void:
	_input_mode = mode
	_held_nav = Vector2i.ZERO
	_nav_repeat_timer = 0.0
	var menu_focus: bool = mode == InputMode.MENU and _device_mode == DeviceMode.GAMEPAD
	for control: Control in _menu_controls:
		control.focus_mode = Control.FOCUS_ALL if menu_focus else Control.FOCUS_NONE
	_sync_cursor_visibility()
	if mode == InputMode.MENU and _device_mode == DeviceMode.GAMEPAD:
		_back_button.grab_focus()
	_update_status()


func _set_device_mode(mode: DeviceMode) -> void:
	if _device_mode == mode:
		return
	_device_mode = mode
	if mode == DeviceMode.MOUSE and _input_mode == InputMode.MENU:
		_input_mode = InputMode.GRID
		for control: Control in _menu_controls:
			control.focus_mode = Control.FOCUS_NONE
	_sync_cursor_visibility()
	_update_status()


func _sync_cursor_visibility() -> void:
	var show_cursor: bool = _device_mode == DeviceMode.GAMEPAD and _input_mode == InputMode.GRID
	_grid.set_cursor_visible(show_cursor)


func _process(delta: float) -> void:
	if not visible or _device_mode != DeviceMode.GAMEPAD or _input_mode != InputMode.GRID:
		_held_nav = Vector2i.ZERO
		_nav_repeat_timer = 0.0
		return
	if _dialog_open():
		return
	_update_edge_dir_from_stick()
	var nav_dir: Vector2i = _read_nav_dir()
	if nav_dir == Vector2i.ZERO:
		_held_nav = Vector2i.ZERO
		_nav_repeat_timer = 0.0
		return
	if nav_dir != _held_nav:
		_held_nav = nav_dir
		_nav_repeat_timer = NAV_REPEAT_DELAY
		_grid.move_cursor(nav_dir)
		return
	_nav_repeat_timer -= delta
	if _nav_repeat_timer <= 0.0:
		_nav_repeat_timer = NAV_REPEAT_RATE
		_grid.move_cursor(nav_dir)


func _read_nav_dir() -> Vector2i:
	if Input.is_action_pressed("ui_up"):
		return Vector2i(0, -1)
	if Input.is_action_pressed("ui_down"):
		return Vector2i(0, 1)
	if Input.is_action_pressed("ui_left"):
		return Vector2i(-1, 0)
	if Input.is_action_pressed("ui_right"):
		return Vector2i(1, 0)
	return Vector2i.ZERO


func _update_edge_dir_from_stick() -> void:
	var edge_dir: Vector2i = _read_right_stick_dir()
	if edge_dir != Vector2i.ZERO:
		_grid.set_edge_dir(edge_dir)


func _read_right_stick_dir() -> Vector2i:
	var pads: Array = Input.get_connected_joypads()
	if pads.is_empty():
		return Vector2i.ZERO
	var device: int = int(pads[0])
	var axis_x: float = Input.get_joy_axis(device, JOY_AXIS_RIGHT_X)
	var axis_y: float = Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
	if absf(axis_x) < EDGE_STICK_DEADZONE and absf(axis_y) < EDGE_STICK_DEADZONE:
		return Vector2i.ZERO
	if absf(axis_x) >= absf(axis_y):
		return Vector2i(1, 0) if axis_x > 0.0 else Vector2i(-1, 0)
	return Vector2i(0, 1) if axis_y > 0.0 else Vector2i(0, -1)


func _dialog_open() -> bool:
	if _save_dialog != null and _save_dialog.visible:
		return true
	if _load_dialog != null and _load_dialog.visible:
		return true
	if _connectivity_dialog != null and _connectivity_dialog.visible:
		return true
	return false


func _build_save_dialog() -> void:
	_save_dialog = AcceptDialog.new()
	_save_dialog.title = "Guardar mapa"
	_save_dialog.ok_button_text = "Guardar"
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var label: Label = Label.new()
	label.text = "Nombre del mapa:"
	box.add_child(label)
	_save_name_edit = LineEdit.new()
	_save_name_edit.custom_minimum_size = Vector2(280, 32)
	_save_name_edit.placeholder_text = "mi_mapa"
	box.add_child(_save_name_edit)
	_save_dialog.add_child(box)
	_save_dialog.confirmed.connect(_on_save_confirmed)
	add_child(_save_dialog)


func _build_load_dialog() -> void:
	_load_dialog = AcceptDialog.new()
	_load_dialog.title = "Cargar mapa"
	_load_dialog.ok_button_text = "Cargar"
	_load_list = ItemList.new()
	_load_list.custom_minimum_size = Vector2(320, 220)
	_load_list.item_activated.connect(_on_load_item_activated)
	_load_dialog.add_child(_load_list)
	_load_dialog.confirmed.connect(_on_load_confirmed)
	add_child(_load_dialog)


func _build_connectivity_dialog() -> void:
	_connectivity_dialog = ConfirmationDialog.new()
	_connectivity_dialog.title = "Habitaciones inaccesibles"
	_connectivity_dialog.ok_button_text = "Continuar"
	_connectivity_dialog.cancel_button_text = "Corregir"
	_connectivity_dialog.confirmed.connect(_on_connectivity_confirmed)
	_connectivity_dialog.canceled.connect(_on_connectivity_canceled)
	add_child(_connectivity_dialog)


func _on_back_pressed() -> void:
	hide_editor()
	editor_closed.emit()


func _on_save_pressed() -> void:
	if _grid.get_room_cells().is_empty():
		_status_label.text = "Anade habitaciones antes de guardar."
		return
	if not _current_map_name.is_empty():
		_save_name_edit.text = _current_map_name
	else:
		_save_name_edit.text = ""
	_save_dialog.popup_centered()


func _on_save_confirmed() -> void:
	var map_name: String = _save_name_edit.text.strip_edges()
	if map_name.is_empty():
		_status_label.text = "Escribe un nombre para guardar."
		return
	var layout: LevelLayout = _build_layout_from_grid()
	if _maybe_warn_unreachable(layout, PendingAction.SAVE, map_name):
		return
	_finish_save(map_name)


func _finish_save(map_name: String) -> void:
	var map_id: String = MapStorage.save_map(map_name, _grid.export_state())
	if map_id.is_empty():
		_status_label.text = "No se pudo guardar el mapa."
		return
	_current_map_id = map_id
	_current_map_name = map_name
	_status_label.text = "Mapa guardado: %s" % map_name


func _on_load_pressed() -> void:
	_refresh_load_list()
	if _load_entries.is_empty():
		_status_label.text = "No hay mapas guardados."
		return
	_load_dialog.popup_centered()


func _refresh_load_list() -> void:
	_load_list.clear()
	_load_entries = MapStorage.list_map_entries()
	for entry: Dictionary in _load_entries:
		_load_list.add_item(String(entry.get("label", entry.get("id", ""))))


func _on_load_confirmed() -> void:
	var selected: PackedInt32Array = _load_list.get_selected_items()
	var index: int = 0 if selected.is_empty() else int(selected[0])
	_apply_load_index(index)


func _on_load_item_activated(index: int) -> void:
	_apply_load_index(index)
	_load_dialog.hide()


func _apply_load_index(index: int) -> void:
	if index < 0 or index >= _load_entries.size():
		return
	var entry: Dictionary = _load_entries[index]
	var data: Dictionary = entry.get("data", {}) as Dictionary
	if data.is_empty():
		return
	_grid.import_state(data)
	_set_mode_index(0)
	_current_map_id = String(entry.get("id", ""))
	_current_map_name = String(entry.get("label", _current_map_id))
	_status_label.text = "Mapa cargado: %s" % _current_map_name


func _set_mode_index(index: int) -> void:
	_mode_index = posmod(index, MODES.size())
	_sync_mode_buttons()
	_grid.set_place_mode(MODES[_mode_index])
	_update_status()


func _cycle_mode(step: int) -> void:
	_set_mode_index(_mode_index + step)


func _sync_mode_buttons() -> void:
	var mode: MapEditorGrid.PlaceMode = MODES[_mode_index]
	_build_button.set_pressed_no_signal(mode == MapEditorGrid.PlaceMode.BUILD)
	_exit_button.set_pressed_no_signal(mode == MapEditorGrid.PlaceMode.EXIT)
	_player_button.set_pressed_no_signal(mode == MapEditorGrid.PlaceMode.PLAYER)
	_ai_button.set_pressed_no_signal(mode == MapEditorGrid.PlaceMode.AI)
	for button: Button in [_build_button, _exit_button, _player_button, _ai_button]:
		NesUiTheme.refresh_toggle_button(button)


func _clear_mode_buttons() -> void:
	_set_mode_index(0)


func _on_build_mode_toggled(pressed: bool) -> void:
	if pressed:
		_set_mode_index(0)
	elif _mode_index == 0:
		_build_button.set_pressed_no_signal(true)


func _on_exit_mode_toggled(pressed: bool) -> void:
	if pressed:
		_set_mode_index(MODES.find(MapEditorGrid.PlaceMode.EXIT))
	else:
		_set_mode_index(0)


func _on_player_mode_toggled(pressed: bool) -> void:
	if pressed:
		_set_mode_index(MODES.find(MapEditorGrid.PlaceMode.PLAYER))
	else:
		_set_mode_index(0)


func _on_ai_mode_toggled(pressed: bool) -> void:
	if pressed:
		_set_mode_index(MODES.find(MapEditorGrid.PlaceMode.AI))
	else:
		_set_mode_index(0)


func _on_connect_all_pressed() -> void:
	if _grid.get_room_cells().is_empty():
		_status_label.text = "Anade habitaciones antes de conectar."
		return
	var added: int = _grid.connect_all_adjacent()
	if added == 0:
		_status_label.text = "Todas las habitaciones vecinas ya estan conectadas."
	else:
		_update_status()


func _on_door_count_toggled(pressed: bool) -> void:
	_grid.set_door_count_overlay_enabled(pressed)
	NesUiTheme.refresh_toggle_button(_door_count_button)
	if pressed:
		_status_label.text = (
			"Oscuro (0 puertas) → verde claro (4). La salida no cuenta."
		)
	else:
		_update_status()


func _on_clear_pressed() -> void:
	_grid.clear_all()
	_clear_mode_buttons()
	_current_map_id = ""
	_current_map_name = ""
	_update_status()


func _on_grid_changed(_arg1: Variant = null, _arg2: Variant = null, _arg3: Variant = null) -> void:
	_grid.clear_unreachable_highlight()
	_update_status()


func _on_grid_pointer_used() -> void:
	_set_device_mode(DeviceMode.MOUSE)
	if _input_mode == InputMode.MENU:
		_set_input_mode(InputMode.GRID)


func _on_grid_cursor_moved() -> void:
	if _device_mode == DeviceMode.MOUSE:
		_update_status()


func _cell_text(gp: Vector2i) -> String:
	if gp.x < 0:
		return "-"
	return "%d,%d" % [gp.x, gp.y]


func _exit_door_text() -> String:
	var exit_door: Dictionary = _grid.get_exit_door()
	if exit_door.is_empty():
		return "-"
	var cell: Vector2i = exit_door["cell"] as Vector2i
	return "%d,%d %s" % [cell.x, cell.y, String(exit_door["dir"])]


func _update_status() -> void:
	var room_count: int = _grid.get_room_cells().size()
	var door_count: int = _grid.get_door_specs().size()
	var exit_text: String = _exit_door_text()
	var player_gp: Vector2i = _grid.get_player_spawn_cell()
	var ai_gp: Vector2i = _grid.get_ai_spawn_cell()
	var cursor_gp: Vector2i = _grid.get_cursor_cell()
	var saved_hint: String = ""
	if not _current_map_id.is_empty():
		saved_hint = "  |  Guardado: %s" % _current_map_id
	_mode_label.text = MODE_LABELS[_mode_index]
	var mode_hints: Array[String] = MODE_HINTS_MOUSE if _device_mode == DeviceMode.MOUSE else MODE_HINTS
	_mode_hint.text = mode_hints[_mode_index]
	_stats_label.text = (
		"Habitaciones: %d  Puertas: %d  Salida: %s  J1: %s  J2: %s%s"
		% [room_count, door_count, exit_text, _cell_text(player_gp), _cell_text(ai_gp), saved_hint]
	)
	_status_label.text = "Cursor: %s" % _cell_text(cursor_gp)
	match _input_mode:
		InputMode.GRID:
			if _device_mode == DeviceMode.MOUSE:
				_hint_label.text = "Ratón: click en celdas y bordes  |  Botones laterales: modos y acciones"
			else:
				_hint_label.text = (
					"Stick L: mover  |  Stick R: borde  |  A: editar  |  B: menu  |  LB/RB: modo  |  Start: jugar"
				)
		InputMode.MENU:
			_hint_label.text = (
				"Arriba/abajo: sidebar  |  Der: Cargar / Izq: Guardar  |  Abajo desde Cargar/Guardar: sidebar  |  B: rejilla"
			)


func _build_layout_from_grid() -> LevelLayout:
	return LevelLayout.from_editor(
		_grid.get_room_cells(),
		_grid.get_door_specs(),
		_grid.get_exit_door(),
		_grid.get_player_spawn_cell(),
		_grid.get_ai_spawn_cell(),
		_current_map_id if not _current_map_id.is_empty() else "editor"
	)


func _format_unreachable_message(
	unreachable: Array[Vector2i],
	layout: LevelLayout,
	action_label: String
) -> String:
	var start: Vector2i = layout.get_connectivity_start_cell()
	var origin_text: String = "(%d,%d)" % [start.x, start.y]
	if layout.player_spawn_cell == start:
		origin_text = "spawn del jugador 1 %s" % origin_text
	elif layout.exit_door_cell == start:
		origin_text = "habitacion de la salida %s" % origin_text
	var lines: PackedStringArray = PackedStringArray()
	lines.append(
		"%d habitacion(es) no se pueden alcanzar desde %s:"
		% [unreachable.size(), origin_text]
	)
	for gp: Vector2i in unreachable:
		lines.append("  • (%d,%d)" % [gp.x, gp.y])
	var ai_gp: Vector2i = layout.get_ai_spawn_cell()
	if ai_gp.x >= 0 and _gp_in_list(ai_gp, unreachable):
		lines.append("El spawn del jugador 2 esta en una habitacion inaccesible.")
	lines.append("Puedes %s el mapa igualmente, pero esas habitaciones quedaran aisladas." % action_label)
	return "\n".join(lines)


func _gp_in_list(gp: Vector2i, cells: Array[Vector2i]) -> bool:
	for entry: Vector2i in cells:
		if entry == gp:
			return true
	return false


func _maybe_warn_unreachable(layout: LevelLayout, action: PendingAction, save_name: String = "") -> bool:
	var unreachable: Array[Vector2i] = layout.find_unreachable_room_cells()
	if unreachable.is_empty():
		return false
	_pending_action = action
	_pending_layout = layout
	_pending_save_name = save_name
	var action_label: String = "jugar" if action == PendingAction.PLAY else "guardar"
	_connectivity_dialog.dialog_text = _format_unreachable_message(unreachable, layout, action_label)
	_grid.set_unreachable_highlight(unreachable)
	_connectivity_dialog.popup_centered()
	return true


func _clear_connectivity_pending(clear_highlight: bool = true) -> void:
	_pending_action = PendingAction.NONE
	_pending_layout = null
	_pending_save_name = ""
	if clear_highlight:
		_grid.clear_unreachable_highlight()


func _on_connectivity_confirmed() -> void:
	match _pending_action:
		PendingAction.PLAY:
			if _pending_layout != null:
				_finish_play(_pending_layout)
		PendingAction.SAVE:
			if not _pending_save_name.is_empty():
				_finish_save(_pending_save_name)
	_clear_connectivity_pending()


func _on_connectivity_canceled() -> void:
	_pending_action = PendingAction.NONE
	_pending_layout = null
	_pending_save_name = ""
	_status_label.text = "Corrige las habitaciones marcadas en rojo."


func _set_play_against_ai(use_ai: bool) -> void:
	GameState.use_ai = use_ai
	_ai_play_button.set_pressed_no_signal(use_ai)
	_local_play_button.set_pressed_no_signal(not use_ai)
	NesUiTheme.refresh_toggle_button(_ai_play_button)
	NesUiTheme.refresh_toggle_button(_local_play_button)


func _on_ai_play_toggled(pressed: bool) -> void:
	if pressed:
		_set_play_against_ai(true)
	elif not _local_play_button.button_pressed:
		_ai_play_button.set_pressed_no_signal(true)


func _on_local_play_toggled(pressed: bool) -> void:
	if pressed:
		_set_play_against_ai(false)
	elif not _ai_play_button.button_pressed:
		_local_play_button.set_pressed_no_signal(true)


func _on_play_pressed() -> void:
	if _grid.get_room_cells().is_empty():
		_status_label.text = "Anade al menos una habitacion."
		return
	if _grid.get_exit_door().is_empty():
		_status_label.text = "Coloca una salida en modo Salida antes de jugar."
		return
	GameState.use_ai = _ai_play_button.button_pressed
	var layout: LevelLayout = _build_layout_from_grid()
	if _maybe_warn_unreachable(layout, PendingAction.PLAY):
		return
	_finish_play(layout)


func _finish_play(layout: LevelLayout) -> void:
	hide_editor()
	map_confirmed.emit(layout)


func _handle_cancel() -> void:
	if _device_mode == DeviceMode.MOUSE:
		return
	if _input_mode == InputMode.GRID:
		_set_input_mode(InputMode.MENU)
		return
	if _back_button.has_focus():
		_on_back_pressed()
		return
	_set_input_mode(InputMode.GRID)


func _detect_device_from_event(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_set_device_mode(DeviceMode.MOUSE)
		return
	if event is InputEventJoypadButton:
		_set_device_mode(DeviceMode.GAMEPAD)
		return
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		if absf(motion.axis_value) >= GAMEPAD_AXIS_DEADZONE:
			_set_device_mode(DeviceMode.GAMEPAD)
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if (
			event.is_action("ui_up")
			or event.is_action("ui_down")
			or event.is_action("ui_left")
			or event.is_action("ui_right")
			or event.is_action("ui_accept")
			or event.is_action("ui_cancel")
		):
			_set_device_mode(DeviceMode.GAMEPAD)


func _input(event: InputEvent) -> void:
	if not visible or _dialog_open():
		return
	_detect_device_from_event(event)


func _handle_grid_button(event: InputEvent) -> bool:
	if not event is InputEventJoypadButton:
		return false
	var button_event: InputEventJoypadButton = event as InputEventJoypadButton
	if not button_event.pressed:
		return false
	match button_event.button_index:
		JOY_BUTTON_LEFT_SHOULDER:
			_cycle_mode(-1)
			return true
		JOY_BUTTON_RIGHT_SHOULDER:
			_cycle_mode(1)
			return true
		JOY_BUTTON_START:
			_on_play_pressed()
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _dialog_open():
		return
	if _device_mode == DeviceMode.MOUSE:
		return
	if _input_mode == InputMode.GRID:
		if _handle_grid_button(event):
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_accept"):
			_grid.apply_cursor_action()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"):
			_handle_cancel()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		_handle_cancel()
		get_viewport().set_input_as_handled()


func _apply_ui_theme() -> void:
	_panel.add_theme_stylebox_override(
		"panel",
		NesUiTheme.panel_style(Color(0.05, 0.05, 0.07, 1.0), NesUiTheme.COLOR_BORDER)
	)
	_grid_frame.add_theme_stylebox_override(
		"panel",
		NesUiTheme.panel_style(MapEditorGrid.COLOR_BG, NesUiTheme.COLOR_BORDER_DARK, 4)
	)
	_play_button.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65, 1.0))
	NesUiTheme.style_toggle_buttons([
		_build_button,
		_exit_button,
		_player_button,
		_ai_button,
		_door_count_button,
		_ai_play_button,
		_local_play_button,
	])


func _wire_menu_focus() -> void:
	var sidebar: Array[Control] = [
		_build_button,
		_exit_button,
		_player_button,
		_ai_button,
		_connect_button,
		_door_count_button,
		_clear_button,
		_ai_play_button,
		_local_play_button,
		_play_button,
	]
	_back_button.focus_neighbor_bottom = _back_button.get_path_to(_build_button)
	_back_button.focus_neighbor_top = _back_button.get_path_to(_play_button)
	_back_button.focus_neighbor_right = _back_button.get_path_to(_load_button)
	_back_button.focus_neighbor_left = _back_button.get_path_to(_save_button)
	_load_button.focus_neighbor_left = _load_button.get_path_to(_back_button)
	_load_button.focus_neighbor_right = _load_button.get_path_to(_save_button)
	_load_button.focus_neighbor_top = _load_button.get_path_to(_back_button)
	_load_button.focus_neighbor_bottom = _load_button.get_path_to(_build_button)
	_save_button.focus_neighbor_left = _save_button.get_path_to(_load_button)
	_save_button.focus_neighbor_right = _save_button.get_path_to(_back_button)
	_save_button.focus_neighbor_top = _save_button.get_path_to(_back_button)
	_save_button.focus_neighbor_bottom = _save_button.get_path_to(_build_button)
	_build_button.focus_neighbor_top = _build_button.get_path_to(_back_button)
	for i: int in range(sidebar.size()):
		var current: Control = sidebar[i]
		current.focus_neighbor_left = current.get_path_to(_save_button)
		current.focus_neighbor_right = current.get_path_to(_load_button)
		if i > 0:
			current.focus_neighbor_top = current.get_path_to(sidebar[i - 1])
		if i < sidebar.size() - 1:
			current.focus_neighbor_bottom = current.get_path_to(sidebar[i + 1])
	_play_button.focus_neighbor_bottom = _play_button.get_path_to(_back_button)
