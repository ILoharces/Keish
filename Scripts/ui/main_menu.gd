extends CanvasLayer
class_name MainMenu

signal play_pressed
signal create_map_pressed
signal settings_pressed
signal quit_pressed

@onready var _play_button: Button = %PlayButton
@onready var _create_button: Button = %CreateMapButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var center: Control = $Center as Control
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_play_button.pressed.connect(func() -> void: play_pressed.emit())
	_create_button.pressed.connect(func() -> void: create_map_pressed.emit())
	_settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	_quit_button.pressed.connect(func() -> void: quit_pressed.emit())
	_wire_menu_focus()


func show_menu() -> void:
	visible = true
	call_deferred("_grab_initial_focus")


func _grab_initial_focus() -> void:
	if not visible:
		return
	_play_button.grab_focus()


func _wire_menu_focus() -> void:
	var buttons: Array[Button] = [_play_button, _create_button, _settings_button, _quit_button]
	for i: int in range(buttons.size()):
		var current: Button = buttons[i]
		if i > 0:
			current.focus_neighbor_top = current.get_path_to(buttons[i - 1])
		if i < buttons.size() - 1:
			current.focus_neighbor_bottom = current.get_path_to(buttons[i + 1])


func hide_menu() -> void:
	visible = false
