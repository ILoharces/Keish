extends Control
class_name ControlsSettingsPanel

# Modo de control por jugador y tabla de referencia (solo lectura).

const COL_CONTROL: float = 132.0
const COL_PLAYER: float = 168.0

@onready var _scroll: ScrollContainer = $VBox/Scroll
@onready var _rows_vbox: VBoxContainer = %RowsVBox
@onready var _status_label: Label = %StatusLabel

var _p1_mode_option: OptionButton = null
var _p2_mode_option: OptionButton = null
var _p2_mode_row: Control = null
var _first_focus_control: Control = null
var _reference_rows: Array[HBoxContainer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scroll.follow_focus = true
	InputBindings.control_modes_changed.connect(_on_control_modes_changed)
	GameSettings.setting_changed.connect(_on_game_setting_changed)
	_build_ui()


func refresh() -> void:
	_sync_mode_options()
	_refresh_reference_table()
	_update_status()


func is_listening() -> bool:
	return false


func cancel_listen() -> void:
	pass


func cancel_listen_silent() -> void:
	pass


func grab_initial_focus() -> void:
	if _first_focus_control != null:
		_first_focus_control.grab_focus()


func wire_external_focus_down(external: Control) -> void:
	if external == null or _first_focus_control == null:
		return
	var last_row: Node = _rows_vbox.get_child(_rows_vbox.get_child_count() - 1)
	if last_row is Control:
		var last_control: Control = last_row as Control
		if last_control.focus_mode != Control.FOCUS_NONE:
			last_control.focus_neighbor_bottom = last_control.get_path_to(external)
			external.focus_neighbor_top = external.get_path_to(last_control)


func _build_ui() -> void:
	for child: Node in _rows_vbox.get_children():
		child.queue_free()
	_reference_rows.clear()
	_first_focus_control = null
	_add_section_title("Modo de control")
	_add_mode_row(
		"Jugador 1 (blanco)",
		0,
		[
			InputBindings.PlayerControlMode.KEYBOARD_MOUSE,
			InputBindings.PlayerControlMode.GAMEPAD,
		],
		true,
	)
	_add_mode_row(
		"Jugador 2 (negro)",
		1,
		[
			InputBindings.PlayerControlMode.GAMEPAD,
			InputBindings.PlayerControlMode.KEYBOARD,
		],
		false,
	)
	_add_section_title("Referencia de controles")
	var header_row: HBoxContainer = _make_row()
	_add_header_label(header_row, "Control", COL_CONTROL)
	_add_header_label(header_row, "Jugador 1", COL_PLAYER)
	_add_header_label(header_row, "Jugador 2", COL_PLAYER)
	_rows_vbox.add_child(header_row)
	for row: Dictionary in InputBindings.get_binding_table():
		_add_reference_row(row)
	_sync_mode_options()
	_update_status()


func _add_mode_row(
	label_text: String,
	player_index: int,
	modes: Array,
	is_p1: bool,
) -> void:
	var row: HBoxContainer = _make_row()
	var label: Label = Label.new()
	label.text = label_text
	label.focus_mode = Control.FOCUS_NONE
	label.custom_minimum_size = Vector2(COL_CONTROL, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var option: OptionButton = OptionButton.new()
	option.custom_minimum_size = Vector2(COL_PLAYER * 2.0 + 8.0, 36)
	option.focus_mode = Control.FOCUS_ALL
	for mode: int in modes:
		option.add_item(InputBindings.get_control_mode_label(mode as InputBindings.PlayerControlMode, player_index), mode)
		var item_index: int = option.get_item_count() - 1
		if mode == InputBindings.PlayerControlMode.KEYBOARD and player_index == 1:
			option.set_item_disabled(item_index, true)
	option.item_selected.connect(_on_mode_selected.bind(player_index, option))
	row.add_child(option)
	_rows_vbox.add_child(row)
	if is_p1:
		_p1_mode_option = option
		if _first_focus_control == null:
			_first_focus_control = option
	else:
		_p2_mode_option = option
		_p2_mode_row = row
	_update_p2_row_visibility()


func _add_reference_row(row_data: Dictionary) -> void:
	var label_text: String = String(row_data.get("label", ""))
	var p1_action: String = String(row_data.get("p1", ""))
	var p2_action: String = String(row_data.get("p2", ""))
	var row: HBoxContainer = _make_row()
	var control_label: Label = Label.new()
	control_label.text = label_text
	control_label.focus_mode = Control.FOCUS_NONE
	control_label.custom_minimum_size = Vector2(COL_CONTROL, 0)
	control_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(control_label)
	var p1_label: Label = _make_reference_cell(p1_action, 0)
	var p2_label: Label = _make_reference_cell(p2_action, 1)
	row.add_child(p1_label)
	row.add_child(p2_label)
	_rows_vbox.add_child(row)
	_reference_rows.append(row)


func _make_reference_cell(action: String, player_index: int) -> Label:
	var cell: Label = Label.new()
	cell.focus_mode = Control.FOCUS_NONE
	cell.custom_minimum_size = Vector2(COL_PLAYER, 36)
	cell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.text = InputBindings.get_binding_label_for_player(player_index, action)
	return cell


func _refresh_reference_table() -> void:
	var table: Array[Dictionary] = InputBindings.get_binding_table()
	for i: int in range(_reference_rows.size()):
		if i >= table.size():
			break
		var row: HBoxContainer = _reference_rows[i]
		var row_data: Dictionary = table[i]
		var p1_label: Label = row.get_child(1) as Label
		var p2_label: Label = row.get_child(2) as Label
		if p1_label != null:
			p1_label.text = InputBindings.get_binding_label_for_player(
				0, String(row_data.get("p1", ""))
			)
		if p2_label != null:
			p2_label.text = InputBindings.get_binding_label_for_player(
				1, String(row_data.get("p2", ""))
			)


func _sync_mode_options() -> void:
	_set_option_to_mode(_p1_mode_option, InputBindings.get_control_mode(0))
	_set_option_to_mode(_p2_mode_option, InputBindings.get_control_mode(1))
	_update_p2_row_visibility()


func _set_option_to_mode(option: OptionButton, mode: int) -> void:
	if option == null:
		return
	for i: int in range(option.item_count):
		if option.get_item_id(i) == mode as int:
			option.select(i)
			return


func _update_p2_row_visibility() -> void:
	if _p2_mode_row != null:
		_p2_mode_row.visible = not GameSettings.use_ai_default


func _on_mode_selected(player_index: int, option: OptionButton, index: int) -> void:
	var mode: int = option.get_item_id(index)
	if not InputBindings.can_set_control_mode(player_index, mode):
		_sync_mode_options()
		_update_status()
		return
	InputBindings.set_control_mode(player_index, mode as InputBindings.PlayerControlMode)
	_refresh_reference_table()
	_update_status()


func _on_control_modes_changed() -> void:
	_sync_mode_options()
	_refresh_reference_table()
	_update_status()


func _on_game_setting_changed(option_id: String, _value: Variant) -> void:
	if option_id == "use_ai_default":
		_update_p2_row_visibility()
		_update_status()


func _update_status() -> void:
	var lines: PackedStringArray = PackedStringArray()
	if GameSettings.use_ai_default:
		lines.append(
			"Contra IA: en partida el control se adapta (teclado+raton o mando). "
			+ "El modo de J1 aqui es solo valor inicial."
		)
	lines.append(InputBindings.get_control_scheme_summary(0))
	if not GameSettings.use_ai_default:
		lines.append(InputBindings.get_control_scheme_summary(1))
	if InputBindings.needs_two_gamepads_for_local_play():
		if InputBindings.has_enough_gamepads_for_local_play():
			lines.append("Conectados %d mandos." % InputBindings.get_connected_gamepad_count())
		else:
			lines.append("Se necesitan 2 mandos para esta configuracion.")
	_status_label.text = "\n".join(lines)


func _make_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row


func _add_section_title(text: String) -> void:
	var title: Label = Label.new()
	title.text = text
	title.focus_mode = Control.FOCUS_NONE
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT)
	_rows_vbox.add_child(title)


func _add_header_label(row: HBoxContainer, text: String, min_width: float) -> void:
	var label: Label = Label.new()
	label.text = text
	label.focus_mode = Control.FOCUS_NONE
	label.custom_minimum_size = Vector2(min_width, 0)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT)
	row.add_child(label)
