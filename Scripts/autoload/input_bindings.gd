extends Node

# Bindings fijos de partida; cada jugador elige modo (teclado+raton / mando) en ajustes.

signal control_modes_changed

enum PlayerControlMode {
	KEYBOARD_MOUSE = 0,
	KEYBOARD = 1,
	GAMEPAD = 2,
}

const SLOT_KEYBOARD: String = "keyboard"
const SLOT_GAMEPAD: String = "gamepad"

const MENU_ACTIONS: Array[String] = [
	"ui_cancel", "ui_accept", "ui_up", "ui_down", "ui_left", "ui_right", "restart",
]

const GAMEPLAY_ACTIONS: Array[String] = [
	"move_up", "move_down", "move_left", "move_right",
	"interact", "place_trap", "next_trap", "trapulator", "toggle_map",
	"pause_menu",
	"p2_move_up", "p2_move_down", "p2_move_left", "p2_move_right",
	"p2_interact", "p2_place_trap", "p2_next_trap",
	"p2_trapulator", "p2_toggle_map", "p2_pause_menu",
	"fire_weapon",
	"aim_left", "aim_right", "aim_up", "aim_down",
	"aim_mode_toggle",
	"p2_fire_weapon",
	"p2_aim_left", "p2_aim_right", "p2_aim_up", "p2_aim_down",
	"p2_aim_mode_toggle",
]

const BINDING_TABLE: Array[Dictionary] = [
	{"label": "Mover arriba", "p1": "move_up", "p2": "p2_move_up"},
	{"label": "Mover abajo", "p1": "move_down", "p2": "p2_move_down"},
	{"label": "Mover izquierda", "p1": "move_left", "p2": "p2_move_left"},
	{"label": "Mover derecha", "p1": "move_right", "p2": "p2_move_right"},
	{"label": "Interactuar", "p1": "interact", "p2": "p2_interact"},
	{"label": "Colocar trampa", "p1": "place_trap", "p2": "p2_place_trap"},
	{"label": "Cambiar trampa", "p1": "next_trap", "p2": "p2_next_trap"},
	{"label": "Trapulator", "p1": "trapulator", "p2": "p2_trapulator"},
	{"label": "Mapa", "p1": "toggle_map", "p2": "p2_toggle_map"},
	{"label": "Menu ingame", "p1": "pause_menu", "p2": "p2_pause_menu"},
	{"label": "Disparar", "p1": "fire_weapon", "p2": "p2_fire_weapon"},
	{"label": "Apuntar (combate)", "p1": "aim_left", "p2": "p2_aim_left", "aim_only": true},
	{"label": "Modo apuntado (mando)", "p1": "aim_mode_toggle", "p2": "p2_aim_mode_toggle", "aim_only": true},
]

var _bindings: Dictionary = {}
var _ai_adaptive_active: bool = false
var _ai_adaptive_p1_mode: PlayerControlMode = PlayerControlMode.KEYBOARD_MOUSE

const AI_GAMEPAD_AXIS_THRESHOLD: float = 0.45
const AI_MOUSE_MOTION_THRESHOLD_SQ: float = 64.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_actions_exist()
	_bindings = _build_default_bindings()
	_sync_gamepad_devices()
	apply_all()
	set_process_input(true)
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if not GameSettings.control_modes_changed.is_connected(_on_control_modes_changed):
		GameSettings.control_modes_changed.connect(_on_control_modes_changed)


func get_binding_table() -> Array[Dictionary]:
	return BINDING_TABLE.duplicate(true)


func get_control_mode(player_index: int) -> PlayerControlMode:
	if player_index <= 0 and _ai_adaptive_active and GameState.use_ai:
		return _ai_adaptive_p1_mode
	if player_index <= 0:
		return clampi(GameSettings.p1_control_mode, 0, 2) as PlayerControlMode
	return clampi(GameSettings.p2_control_mode, 0, 2) as PlayerControlMode


func set_ai_adaptive_controls(enabled: bool) -> void:
	if _ai_adaptive_active == enabled:
		return
	_ai_adaptive_active = enabled
	if enabled:
		_reset_ai_adaptive_p1_mode()
	apply_all()
	control_modes_changed.emit()


func is_ai_adaptive_active() -> bool:
	return _ai_adaptive_active


func set_control_mode(player_index: int, mode: PlayerControlMode) -> void:
	if not can_set_control_mode(player_index, mode):
		return
	if player_index <= 0:
		GameSettings.set_p1_control_mode(mode as int)
	else:
		GameSettings.set_p2_control_mode(mode as int)


func can_set_control_mode(player_index: int, mode: PlayerControlMode) -> bool:
	if player_index == 1 and mode == PlayerControlMode.KEYBOARD:
		return false
	if not _mode_uses_keyboard(mode):
		return true
	var other_index: int = 1 if player_index <= 0 else 0
	return not _mode_uses_keyboard(get_control_mode(other_index))


func uses_keyboard(player_index: int) -> bool:
	return _mode_uses_keyboard(get_control_mode(player_index))


func uses_gamepad(player_index: int) -> bool:
	return get_control_mode(player_index) == PlayerControlMode.GAMEPAD


func needs_two_gamepads_for_local_play() -> bool:
	if GameState.use_ai:
		return false
	return uses_gamepad(0) and uses_gamepad(1)


func has_enough_gamepads_for_local_play() -> bool:
	if not needs_two_gamepads_for_local_play():
		return true
	return get_connected_gamepad_count() >= 2


func get_control_mode_label(mode: PlayerControlMode, _player_index: int) -> String:
	match mode:
		PlayerControlMode.KEYBOARD_MOUSE:
			return "Teclado y raton"
		PlayerControlMode.KEYBOARD:
			return "Teclado"
		PlayerControlMode.GAMEPAD:
			return "Mando"
		_:
			return "?"


func get_control_scheme_summary(player_index: int) -> String:
	match get_control_mode(player_index):
		PlayerControlMode.KEYBOARD_MOUSE:
			return "WASD mover | Ratón apuntar | Clic izq. disparar | E/Q/R/Tab/M/Esc"
		PlayerControlMode.KEYBOARD:
			return "Flechas mover | I/K/L/O/P/U/Home (apuntado combate pendiente)"
		PlayerControlMode.GAMEPAD:
			return "Stick izq. mover | Stick der. apuntar | RT disparar | R3 cambiar modo apuntado | A/Y/X/LB/Start/Select"
		_:
			return ""


func get_binding_label_for_player(player_index: int, action: String) -> String:
	if action.is_empty() or is_menu_action(action):
		return "—"
	if (_is_aim_action(action) or _is_aim_mode_toggle_action(action)) and get_control_mode(player_index) != PlayerControlMode.GAMEPAD:
		if get_control_mode(player_index) == PlayerControlMode.KEYBOARD_MOUSE and player_index == 0 and _is_aim_action(action):
			return "Ratón"
		return "—"
	var slot: String = _active_slot_for_player(player_index)
	var event: InputEvent = _get_action_slots(action).get(slot) as InputEvent
	if event == null:
		return "—"
	return format_event(event)


func is_menu_action(action: String) -> bool:
	return MENU_ACTIONS.has(action)


func is_gamepad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


func format_event(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT:
				return "Clic izquierdo"
			MOUSE_BUTTON_RIGHT:
				return "Clic derecho"
			MOUSE_BUTTON_MIDDLE:
				return "Clic central"
			_:
				return "Raton boton %d" % int(mouse_event.button_index)
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		var keycode: Key = key_event.physical_keycode
		if keycode == KEY_NONE:
			keycode = key_event.keycode
		return OS.get_keycode_string(keycode)
	if event is InputEventJoypadButton:
		var button_event: InputEventJoypadButton = event as InputEventJoypadButton
		return _joy_button_label(button_event.button_index)
	if event is InputEventJoypadMotion:
		var motion_event: InputEventJoypadMotion = event as InputEventJoypadMotion
		return _format_joy_motion(motion_event.axis, motion_event.axis_value)
	return "?"


func get_connected_gamepad_count() -> int:
	return Input.get_connected_joypads().size()


func get_gamepad_device_for_player(player_index: int) -> int:
	if not uses_gamepad(player_index):
		return -1
	var pads: Array = Input.get_connected_joypads()
	if pads.is_empty():
		return -1
	var p1_pad: bool = uses_gamepad(0)
	var p2_pad: bool = uses_gamepad(1)
	if player_index <= 0:
		return int(pads[0])
	if not p2_pad:
		return -1
	if p1_pad and pads.size() > 1:
		return int(pads[1])
	return int(pads[0])


func apply_all() -> void:
	_sync_gamepad_devices()
	for action: String in GAMEPLAY_ACTIONS:
		apply_action(action)
	for action: String in MENU_ACTIONS:
		apply_action(action)


func apply_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	if is_menu_action(action):
		_apply_fixed_menu_bindings(action)
		return
	var player_index: int = _player_index_for_action(action)
	if player_index < 0:
		return
	if (_is_aim_action(action) or _is_aim_mode_toggle_action(action)) and get_control_mode(player_index) != PlayerControlMode.GAMEPAD:
		return
	var slot: String = _active_slot_for_player(player_index)
	var slots: Dictionary = _get_action_slots(action)
	var event: InputEvent = slots.get(slot) as InputEvent
	if event != null:
		InputMap.action_add_event(action, event.duplicate())


func _on_control_modes_changed() -> void:
	_sync_gamepad_devices()
	apply_all()
	control_modes_changed.emit()


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	if _ai_adaptive_active and GameState.use_ai:
		if (
			_ai_adaptive_p1_mode == PlayerControlMode.GAMEPAD
			and get_connected_gamepad_count() == 0
		):
			_set_ai_adaptive_p1_mode(PlayerControlMode.KEYBOARD_MOUSE)
	_sync_gamepad_devices()
	apply_all()
	control_modes_changed.emit()


func _input(event: InputEvent) -> void:
	if not _ai_adaptive_active or not GameState.use_ai:
		return
	var target_mode: int = _detect_ai_p1_mode_from_event(event)
	if target_mode < 0:
		return
	_set_ai_adaptive_p1_mode(target_mode as PlayerControlMode)


func _reset_ai_adaptive_p1_mode() -> void:
	var saved: PlayerControlMode = clampi(GameSettings.p1_control_mode, 0, 2) as PlayerControlMode
	if saved == PlayerControlMode.KEYBOARD:
		saved = PlayerControlMode.KEYBOARD_MOUSE
	if saved == PlayerControlMode.GAMEPAD and get_connected_gamepad_count() == 0:
		saved = PlayerControlMode.KEYBOARD_MOUSE
	_ai_adaptive_p1_mode = saved


func _set_ai_adaptive_p1_mode(mode: PlayerControlMode) -> void:
	if mode != PlayerControlMode.KEYBOARD_MOUSE and mode != PlayerControlMode.GAMEPAD:
		return
	if mode == PlayerControlMode.GAMEPAD and get_connected_gamepad_count() == 0:
		mode = PlayerControlMode.KEYBOARD_MOUSE
	if _ai_adaptive_p1_mode == mode:
		return
	_ai_adaptive_p1_mode = mode
	_sync_gamepad_devices()
	apply_all()
	control_modes_changed.emit()


func _detect_ai_p1_mode_from_event(event: InputEvent) -> int:
	if event is InputEventJoypadButton:
		var button_event: InputEventJoypadButton = event as InputEventJoypadButton
		if button_event.pressed:
			return PlayerControlMode.GAMEPAD
	if event is InputEventJoypadMotion:
		var motion_event: InputEventJoypadMotion = event as InputEventJoypadMotion
		if absf(motion_event.axis_value) >= AI_GAMEPAD_AXIS_THRESHOLD:
			return PlayerControlMode.GAMEPAD
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.pressed:
			return PlayerControlMode.KEYBOARD_MOUSE
	if event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		if mouse_motion.relative.length_squared() >= AI_MOUSE_MOTION_THRESHOLD_SQ:
			return PlayerControlMode.KEYBOARD_MOUSE
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			return PlayerControlMode.KEYBOARD_MOUSE
	return -1


func _sync_gamepad_devices() -> void:
	var pads: Array = Input.get_connected_joypads()
	if pads.is_empty():
		return
	for action: String in GAMEPLAY_ACTIONS:
		var slots: Dictionary = _get_action_slots(action)
		var event: InputEvent = slots.get(SLOT_GAMEPAD) as InputEvent
		if event == null or not is_gamepad_event(event):
			continue
		var player_index: int = _player_index_for_action(action)
		if player_index < 0 or not uses_gamepad(player_index):
			continue
		var preferred: int = get_gamepad_device_for_player(player_index)
		if preferred < 0:
			continue
		var current: int = _event_device(event)
		if current != preferred or not pads.has(current):
			_set_event_device(event, preferred)


func _player_index_for_action(action: String) -> int:
	if action.begins_with("p2_"):
		return 1
	if action.begins_with("aim_") or GAMEPLAY_ACTIONS.has(action):
		return 0
	return -1


func _active_slot_for_player(player_index: int) -> String:
	if uses_gamepad(player_index):
		return SLOT_GAMEPAD
	return SLOT_KEYBOARD


func _is_aim_action(action: String) -> bool:
	return action.begins_with("aim_") or action.begins_with("p2_aim_")


func _is_aim_mode_toggle_action(action: String) -> bool:
	return action == "aim_mode_toggle" or action == "p2_aim_mode_toggle"


func _mode_uses_keyboard(mode: PlayerControlMode) -> bool:
	return mode == PlayerControlMode.KEYBOARD_MOUSE or mode == PlayerControlMode.KEYBOARD


func _ensure_actions_exist() -> void:
	for action: String in GAMEPLAY_ACTIONS + MENU_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)


func _build_default_bindings() -> Dictionary:
	var bindings: Dictionary = {}
	_set_keyboard(bindings, "move_up", KEY_W)
	_set_keyboard(bindings, "move_down", KEY_S)
	_set_keyboard(bindings, "move_left", KEY_A)
	_set_keyboard(bindings, "move_right", KEY_D)
	_set_keyboard(bindings, "interact", KEY_E)
	_set_keyboard(bindings, "place_trap", KEY_Q)
	_set_keyboard(bindings, "next_trap", KEY_R)
	_set_keyboard(bindings, "trapulator", KEY_TAB)
	_set_keyboard(bindings, "toggle_map", KEY_M)
	_set_keyboard(bindings, "pause_menu", KEY_ESCAPE)
	_set_mouse_button(bindings, "fire_weapon", MOUSE_BUTTON_LEFT)
	_set_keyboard(bindings, "p2_fire_weapon", KEY_O)
	_set_keyboard(bindings, "p2_move_up", KEY_UP)
	_set_keyboard(bindings, "p2_move_down", KEY_DOWN)
	_set_keyboard(bindings, "p2_move_left", KEY_LEFT)
	_set_keyboard(bindings, "p2_move_right", KEY_RIGHT)
	_set_keyboard(bindings, "p2_interact", KEY_I)
	_set_keyboard(bindings, "p2_place_trap", KEY_K)
	_set_keyboard(bindings, "p2_next_trap", KEY_L)
	_set_keyboard(bindings, "p2_trapulator", KEY_P)
	_set_keyboard(bindings, "p2_toggle_map", KEY_U)
	_set_keyboard(bindings, "p2_pause_menu", KEY_HOME)
	_apply_default_gamepad_layout(bindings, "", 0)
	_apply_default_gamepad_layout(bindings, "p2_", 1)
	return bindings


func _apply_default_gamepad_layout(bindings: Dictionary, prefix: String, device: int) -> void:
	_set_gamepad_motion(bindings, prefix + "move_up", JOY_AXIS_LEFT_Y, -1.0, device)
	_set_gamepad_motion(bindings, prefix + "move_down", JOY_AXIS_LEFT_Y, 1.0, device)
	_set_gamepad_motion(bindings, prefix + "move_left", JOY_AXIS_LEFT_X, -1.0, device)
	_set_gamepad_motion(bindings, prefix + "move_right", JOY_AXIS_LEFT_X, 1.0, device)
	_set_gamepad_button(bindings, prefix + "interact", JOY_BUTTON_A, device)
	_set_gamepad_button(bindings, prefix + "place_trap", JOY_BUTTON_Y, device)
	_set_gamepad_button(bindings, prefix + "next_trap", JOY_BUTTON_X, device)
	_set_gamepad_button(bindings, prefix + "trapulator", JOY_BUTTON_BACK, device)
	_set_gamepad_button(bindings, prefix + "toggle_map", JOY_BUTTON_LEFT_SHOULDER, device)
	_set_gamepad_button(bindings, prefix + "pause_menu", JOY_BUTTON_START, device)
	_set_gamepad_button(bindings, prefix + "fire_weapon", JOY_BUTTON_RIGHT_SHOULDER, device)
	_set_gamepad_button(bindings, prefix + "aim_mode_toggle", JOY_BUTTON_RIGHT_STICK, device)
	var aim_prefix: String = prefix if not prefix.is_empty() else ""
	if aim_prefix.is_empty():
		_set_gamepad_motion(bindings, "aim_left", JOY_AXIS_RIGHT_X, -1.0, device)
		_set_gamepad_motion(bindings, "aim_right", JOY_AXIS_RIGHT_X, 1.0, device)
		_set_gamepad_motion(bindings, "aim_up", JOY_AXIS_RIGHT_Y, -1.0, device)
		_set_gamepad_motion(bindings, "aim_down", JOY_AXIS_RIGHT_Y, 1.0, device)
	else:
		_set_gamepad_motion(bindings, prefix + "aim_left", JOY_AXIS_RIGHT_X, -1.0, device)
		_set_gamepad_motion(bindings, prefix + "aim_right", JOY_AXIS_RIGHT_X, 1.0, device)
		_set_gamepad_motion(bindings, prefix + "aim_up", JOY_AXIS_RIGHT_Y, -1.0, device)
		_set_gamepad_motion(bindings, prefix + "aim_down", JOY_AXIS_RIGHT_Y, 1.0, device)


func _set_mouse_button(bindings: Dictionary, action: String, button_index: MouseButton) -> void:
	var slots: Dictionary = _ensure_binding_slots(bindings, action)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button_index
	event.device = -1
	slots[SLOT_KEYBOARD] = event


func _set_keyboard(bindings: Dictionary, action: String, keycode: Key) -> void:
	var slots: Dictionary = _ensure_binding_slots(bindings, action)
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.device = -1
	slots[SLOT_KEYBOARD] = event


func _set_gamepad_button(bindings: Dictionary, action: String, button_index: JoyButton, device: int) -> void:
	var slots: Dictionary = _ensure_binding_slots(bindings, action)
	slots[SLOT_GAMEPAD] = _make_joy_button_event(button_index, device)


func _set_gamepad_motion(bindings: Dictionary, action: String, axis: JoyAxis, axis_value: float, device: int) -> void:
	var slots: Dictionary = _ensure_binding_slots(bindings, action)
	slots[SLOT_GAMEPAD] = _make_joy_motion_event(axis, axis_value, device)


func _ensure_binding_slots(bindings: Dictionary, action: String) -> Dictionary:
	if not bindings.has(action) or not bindings[action] is Dictionary:
		bindings[action] = _empty_slots()
	return bindings[action] as Dictionary


func _empty_slots() -> Dictionary:
	return {SLOT_KEYBOARD: null, SLOT_GAMEPAD: null}


func _get_action_slots(action: String) -> Dictionary:
	if not _bindings.has(action):
		_bindings[action] = _empty_slots()
	return _bindings[action] as Dictionary


func _menu_gamepad_device() -> int:
	var pads: Array = Input.get_connected_joypads()
	if pads.is_empty():
		return 0
	return int(pads[0])


func _apply_fixed_menu_bindings(action: String) -> void:
	var device: int = _menu_gamepad_device()
	match action:
		"ui_cancel":
			InputMap.action_add_event(action, _make_key_event(KEY_BACKSPACE))
			InputMap.action_add_event(action, _make_joy_button_event(JOY_BUTTON_B, device))
		"ui_accept":
			InputMap.action_add_event(action, _make_key_event(KEY_ENTER))
			InputMap.action_add_event(action, _make_joy_button_event(JOY_BUTTON_A, device))
		"ui_up":
			InputMap.action_add_event(action, _make_key_event(KEY_UP))
			InputMap.action_add_event(action, _make_joy_button_event(JOY_BUTTON_DPAD_UP, device))
			InputMap.action_add_event(action, _make_joy_motion_event(JOY_AXIS_LEFT_Y, -1.0, device))
		"ui_down":
			InputMap.action_add_event(action, _make_key_event(KEY_DOWN))
			InputMap.action_add_event(action, _make_joy_button_event(JOY_BUTTON_DPAD_DOWN, device))
			InputMap.action_add_event(action, _make_joy_motion_event(JOY_AXIS_LEFT_Y, 1.0, device))
		"ui_left":
			InputMap.action_add_event(action, _make_key_event(KEY_LEFT))
			InputMap.action_add_event(action, _make_joy_button_event(JOY_BUTTON_DPAD_LEFT, device))
			InputMap.action_add_event(action, _make_joy_motion_event(JOY_AXIS_LEFT_X, -1.0, device))
		"ui_right":
			InputMap.action_add_event(action, _make_key_event(KEY_RIGHT))
			InputMap.action_add_event(action, _make_joy_button_event(JOY_BUTTON_DPAD_RIGHT, device))
			InputMap.action_add_event(action, _make_joy_motion_event(JOY_AXIS_LEFT_X, 1.0, device))
		"restart":
			InputMap.action_add_event(action, _make_key_event(KEY_R))
			InputMap.action_add_event(action, _make_joy_button_event(JOY_BUTTON_START, device))


func _make_key_event(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.device = -1
	return event


func _make_joy_button_event(button_index: JoyButton, device: int) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button_index
	event.device = device
	return event


func _make_joy_motion_event(axis: JoyAxis, axis_value: float, device: int) -> InputEventJoypadMotion:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	event.device = device
	return event


func _event_device(event: InputEvent) -> int:
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).device
	if event is InputEventJoypadMotion:
		return (event as InputEventJoypadMotion).device
	return -1


func _set_event_device(event: InputEvent, device: int) -> void:
	if event is InputEventJoypadButton:
		(event as InputEventJoypadButton).device = device
	elif event is InputEventJoypadMotion:
		(event as InputEventJoypadMotion).device = device


func _joy_button_label(button_index: JoyButton) -> String:
	match button_index:
		JOY_BUTTON_A:
			return "A / Cross"
		JOY_BUTTON_B:
			return "B / Circle"
		JOY_BUTTON_X:
			return "X / Square"
		JOY_BUTTON_Y:
			return "Y / Triangle"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB / L1"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB / R1"
		JOY_BUTTON_LEFT_STICK:
			return "Stick L (click)"
		JOY_BUTTON_RIGHT_STICK:
			return "Stick R (click)"
		JOY_BUTTON_BACK:
			return "Select / Share"
		JOY_BUTTON_START:
			return "Start / Options"
		JOY_BUTTON_DPAD_UP:
			return "D-Pad arriba"
		JOY_BUTTON_DPAD_DOWN:
			return "D-Pad abajo"
		JOY_BUTTON_DPAD_LEFT:
			return "D-Pad izquierda"
		JOY_BUTTON_DPAD_RIGHT:
			return "D-Pad derecha"
		_:
			return "Boton %d" % int(button_index)


func _format_joy_motion(axis: JoyAxis, axis_value: float) -> String:
	var direction: String = ""
	match axis:
		JOY_AXIS_LEFT_X, JOY_AXIS_RIGHT_X:
			direction = "derecha" if axis_value > 0.0 else "izquierda"
		JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_Y:
			direction = "abajo" if axis_value > 0.0 else "arriba"
		_:
			direction = "eje %d" % int(axis)
	if axis == JOY_AXIS_LEFT_X or axis == JOY_AXIS_LEFT_Y:
		return "Stick L %s" % direction
	if axis == JOY_AXIS_RIGHT_X or axis == JOY_AXIS_RIGHT_Y:
		return "Stick R %s" % direction
	return direction
