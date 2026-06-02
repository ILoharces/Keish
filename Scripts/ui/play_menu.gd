extends CanvasLayer
class_name PlayMenu

# Lista de mapas guardados para jugar.

signal back_pressed
signal map_selected(layout: LevelLayout)

@onready var _map_list: ItemList = %MapList
@onready var _back_button: Button = %BackButton
@onready var _play_button: Button = %PlayButton
@onready var _hint_label: Label = %HintLabel
@onready var _ai_checkbox: CheckBox = %AiCheckbox

var _entries: Array[Dictionary] = []


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var center: Control = $Center as Control
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back_button.pressed.connect(func() -> void: back_pressed.emit())
	_play_button.pressed.connect(_on_play_pressed)
	_map_list.item_activated.connect(_on_item_activated)
	_map_list.item_selected.connect(_on_item_selected)
	_map_list.focus_entered.connect(_on_map_list_focus_entered)
	_ai_checkbox.toggled.connect(_on_ai_checkbox_toggled)
	_wire_menu_focus()
	set_process_unhandled_input(true)
	_refresh_list()


func show_menu() -> void:
	_refresh_list()
	_ai_checkbox.button_pressed = GameSettings.use_ai_default
	_on_ai_checkbox_toggled(_ai_checkbox.button_pressed)
	visible = true
	if _entries.is_empty():
		_back_button.grab_focus()
	else:
		_ensure_map_list_selection()
		_map_list.grab_focus()


func hide_menu() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		back_pressed.emit()
		get_viewport().set_input_as_handled()


func _refresh_list() -> void:
	_map_list.clear()
	_entries = MapStorage.list_map_entries()
	if _entries.is_empty():
		_map_list.add_item("(Sin mapas guardados)")
		_map_list.set_item_disabled(0, true)
		_play_button.disabled = true
		_hint_label.text = "Crea y guarda mapas en el editor (Crear mapa > Guardar)."
		return
	_play_button.disabled = false
	_hint_label.text = "Selecciona un mapa y pulsa Jugar o haz doble clic."
	for entry: Dictionary in _entries:
		_map_list.add_item(String(entry.get("label", entry.get("id", "Mapa"))))
	if visible and _map_list.has_focus():
		_ensure_map_list_selection()


func _ensure_map_list_selection() -> void:
	if _entries.is_empty():
		return
	var selected: PackedInt32Array = _map_list.get_selected_items()
	var index: int = 0 if selected.is_empty() else int(selected[0])
	index = clampi(index, 0, _entries.size() - 1)
	_map_list.select(index)
	_map_list.ensure_current_is_visible()


func _on_map_list_focus_entered() -> void:
	_ensure_map_list_selection()


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	var label: String = String(_entries[index].get("label", "mapa"))
	_hint_label.text = "Mapa: %s  |  A: jugar  |  B: volver" % label


func _wire_menu_focus() -> void:
	_ai_checkbox.focus_neighbor_bottom = _ai_checkbox.get_path_to(_map_list)
	_map_list.focus_neighbor_top = _map_list.get_path_to(_ai_checkbox)
	_map_list.focus_neighbor_bottom = _map_list.get_path_to(_back_button)
	_map_list.focus_neighbor_left = _map_list.get_path_to(_map_list)
	_map_list.focus_neighbor_right = _map_list.get_path_to(_map_list)
	_back_button.focus_neighbor_top = _back_button.get_path_to(_map_list)
	_back_button.focus_neighbor_bottom = _back_button.get_path_to(_ai_checkbox)
	_back_button.focus_neighbor_right = _back_button.get_path_to(_play_button)
	_play_button.focus_neighbor_top = _play_button.get_path_to(_map_list)
	_play_button.focus_neighbor_bottom = _play_button.get_path_to(_ai_checkbox)
	_play_button.focus_neighbor_left = _play_button.get_path_to(_back_button)
	_ai_checkbox.focus_neighbor_top = _ai_checkbox.get_path_to(_play_button)


func _on_play_pressed() -> void:
	var selected: PackedInt32Array = _map_list.get_selected_items()
	if selected.is_empty():
		_hint_label.text = "Selecciona un mapa de la lista."
		return
	_start_map(int(selected[0]))


func _on_item_activated(index: int) -> void:
	_start_map(index)


func _on_ai_checkbox_toggled(pressed: bool) -> void:
	GameState.use_ai = pressed
	if pressed:
		_ai_checkbox.text = "Jugar contra IA (teclado+raton o mando, se adapta al usar)"
	else:
		_ai_checkbox.text = "Dos jugadores local (modos en Ajustes > Controles)"


func _start_map(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	GameState.use_ai = _ai_checkbox.button_pressed
	if not GameState.use_ai and InputBindings.needs_two_gamepads_for_local_play():
		if not InputBindings.has_enough_gamepads_for_local_play():
			_hint_label.text = "Conecta 2 mandos (Ajustes > Controles: ambos en modo Mando)."
			return
	var entry: Dictionary = _entries[index]
	var data: Dictionary = entry.get("data", {}) as Dictionary
	if data.is_empty():
		return
	var label: String = String(entry.get("label", "mapa"))
	var layout: LevelLayout = MapStorage.data_to_layout(data, label)
	hide_menu()
	map_selected.emit(layout)
