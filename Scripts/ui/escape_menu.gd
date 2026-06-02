extends CanvasLayer
class_name EscapeMenu

# Menu modal de pausa (Escape): reanudar o volver al menu principal.

signal resume_pressed
signal exit_pressed

const OVERLAY_COLOR: Color = Color(0.0, 0.0, 0.0, 0.55)

@onready var _overlay: ColorRect = %Overlay
@onready var _resume_button: Button = %ResumeButton
@onready var _exit_button: Button = %ExitButton


func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_overlay.color = OVERLAY_COLOR
	var center: Control = %Center as Control
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_resume_button.pressed.connect(func() -> void: resume_pressed.emit())
	_exit_button.pressed.connect(func() -> void: exit_pressed.emit())


func show_menu() -> void:
	visible = true
	_resume_button.grab_focus()


func hide_menu() -> void:
	visible = false


func is_visible_menu() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu") or event.is_action_pressed("p2_pause_menu"):
		resume_pressed.emit()
		get_viewport().set_input_as_handled()
