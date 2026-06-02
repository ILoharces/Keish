extends CanvasLayer
class_name SettingsMenu

# Menu de ajustes: pestanas General y Controles.

signal back_pressed

enum Tab { GENERAL, CONTROLS }

@onready var _general_tab_button: Button = %GeneralTabButton
@onready var _controls_tab_button: Button = %ControlsTabButton
@onready var _general_page: Control = %GeneralPage
@onready var _controls_page: ControlsSettingsPanel = %ControlsPage
@onready var _options_vbox: VBoxContainer = %OptionsVBox
@onready var _back_button: Button = %BackButton
@onready var _hint_label: Label = %HintLabel

var _widgets_by_id: Dictionary = {}
var _current_tab: int = Tab.GENERAL


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var center: Control = $Center as Control
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_general_tab_button.pressed.connect(func() -> void: _show_tab(Tab.GENERAL))
	_controls_tab_button.pressed.connect(func() -> void: _show_tab(Tab.CONTROLS))
	_back_button.pressed.connect(_on_back_requested)
	NesUiTheme.style_toggle_buttons([_general_tab_button, _controls_tab_button])
	_build_options()
	GameSettings.setting_changed.connect(_on_setting_changed)
	set_process_unhandled_input(true)
	_show_tab(Tab.GENERAL)


func show_menu() -> void:
	_sync_widgets_from_settings()
	_controls_page.refresh()
	_show_tab(Tab.GENERAL)
	visible = true
	_back_button.grab_focus()


func hide_menu() -> void:
	_controls_page.cancel_listen_silent()
	visible = false
	get_viewport().gui_release_focus()


func _on_back_requested() -> void:
	if _controls_page.is_listening():
		_controls_page.cancel_listen()
		return
	if _current_tab == Tab.CONTROLS:
		_show_tab(Tab.GENERAL)
		_back_button.grab_focus()
		return
	back_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _handle_tab_bumper(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_requested()
		get_viewport().set_input_as_handled()


func _handle_tab_bumper(event: InputEvent) -> bool:
	if _controls_page.is_listening():
		return false
	if not event is InputEventJoypadButton:
		return false
	var button_event: InputEventJoypadButton = event as InputEventJoypadButton
	if not button_event.pressed:
		return false
	match button_event.button_index:
		JOY_BUTTON_LEFT_SHOULDER:
			_cycle_tab(-1)
			return true
		JOY_BUTTON_RIGHT_SHOULDER:
			_cycle_tab(1)
			return true
	return false


func _cycle_tab(step: int) -> void:
	var tab_index: int = posmod(int(_current_tab) + step, 2)
	_show_tab(tab_index as Tab)


func _show_tab(tab: Tab) -> void:
	_current_tab = tab
	_general_page.visible = tab == Tab.GENERAL
	_controls_page.visible = tab == Tab.CONTROLS
	_general_tab_button.set_pressed_no_signal(tab == Tab.GENERAL)
	_controls_tab_button.set_pressed_no_signal(tab == Tab.CONTROLS)
	NesUiTheme.refresh_toggle_button(_general_tab_button)
	NesUiTheme.refresh_toggle_button(_controls_tab_button)
	_hint_label.visible = true
	match tab:
		Tab.GENERAL:
			_hint_label.text = "LB/RB cambiar pestaña. Las opciones se guardan automaticamente."
		Tab.CONTROLS:
			_hint_label.text = "LB/RB cambiar pestaña. Modo por jugador; controles fijos."
	if tab == Tab.CONTROLS:
		_controls_page.refresh()
		_controls_page.wire_external_focus_down(_back_button)
		_controls_page.grab_initial_focus()


func _build_options() -> void:
	for child: Node in _options_vbox.get_children():
		child.queue_free()
	_widgets_by_id.clear()
	for section: Dictionary in GameSettings.get_sections():
		_add_section(section)


func _add_section(section: Dictionary) -> void:
	var title: Label = Label.new()
	title.text = String(section.get("title", "Ajustes"))
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT)
	_options_vbox.add_child(title)
	var options: Array = section.get("options", []) as Array
	for option: Variant in options:
		_add_option_row(option as Dictionary)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	_options_vbox.add_child(spacer)


func _add_option_row(entry: Dictionary) -> void:
	var option_id: String = String(entry.get("id", ""))
	var option_type: String = String(entry.get("type", ""))
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	match option_type:
		"bool":
			var checkbox: CheckBox = CheckBox.new()
			checkbox.text = String(entry.get("label", option_id))
			checkbox.toggled.connect(_on_bool_toggled.bind(option_id))
			row.add_child(checkbox)
			_widgets_by_id[option_id] = checkbox
		_:
			var fallback: Label = Label.new()
			fallback.text = "%s (tipo no soportado: %s)" % [String(entry.get("label", option_id)), option_type]
			row.add_child(fallback)
	var hint_text: String = String(entry.get("hint", ""))
	if not hint_text.is_empty():
		var hint: Label = Label.new()
		hint.text = hint_text
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 12)
		hint.modulate = Color(0.75, 0.75, 0.75, 1)
		row.add_child(hint)
	_options_vbox.add_child(row)


func _sync_widgets_from_settings() -> void:
	for option_id: Variant in _widgets_by_id.keys():
		var widget: Control = _widgets_by_id[option_id] as Control
		var value: Variant = GameSettings.get_option_value(String(option_id))
		if widget is CheckBox:
			var checkbox: CheckBox = widget as CheckBox
			checkbox.set_block_signals(true)
			checkbox.button_pressed = bool(value)
			checkbox.set_block_signals(false)


func _on_bool_toggled(pressed: bool, option_id: String) -> void:
	GameSettings.set_option_value(option_id, pressed)


func _on_setting_changed(option_id: String, _value: Variant) -> void:
	if not _widgets_by_id.has(option_id):
		return
	var widget: Control = _widgets_by_id[option_id] as Control
	if widget is CheckBox:
		var checkbox: CheckBox = widget as CheckBox
		checkbox.set_block_signals(true)
		checkbox.button_pressed = bool(GameSettings.get_option_value(option_id))
		checkbox.set_block_signals(false)
