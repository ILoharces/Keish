class_name AimController
extends RefCounted

signal aim_changed(screen_pos: Vector2)
signal aim_mode_changed(mode: AimMode)

enum AimMode {
	VIRTUAL_CURSOR,
	ORBIT,
}

const VIRTUAL_CURSOR_SPEED: float = 900.0
const STICK_DEADZONE: float = 0.35
const ORBIT_SCREEN_RADIUS: float = 128.0

var spy_id: int = 0
var uses_mouse: bool = false
var aim_mode: AimMode = AimMode.VIRTUAL_CURSOR
var screen_pos: Vector2 = Vector2.ZERO
var _initialized: bool = false
var _orbit_dir: Vector2 = Vector2.RIGHT
var _aim_left_action: String = ""
var _aim_right_action: String = ""
var _aim_up_action: String = ""
var _aim_down_action: String = ""
var _aim_mode_toggle_action: String = ""
var _gamepad_device: int = 0


func _init(p_spy_id: int, p_uses_mouse: bool) -> void:
	spy_id = p_spy_id
	uses_mouse = p_uses_mouse
	var player_index: int = 0 if spy_id == ItemDB.SpyId.PLAYER else 1
	aim_mode = GameSettings.get_gamepad_aim_mode(player_index) as AimMode
	if spy_id == ItemDB.SpyId.PLAYER:
		_aim_left_action = "aim_left"
		_aim_right_action = "aim_right"
		_aim_up_action = "aim_up"
		_aim_down_action = "aim_down"
		_aim_mode_toggle_action = "aim_mode_toggle"
		_gamepad_device = InputBindings.get_gamepad_device_for_player(0)
	else:
		_aim_left_action = "p2_aim_left"
		_aim_right_action = "p2_aim_right"
		_aim_up_action = "p2_aim_up"
		_aim_down_action = "p2_aim_down"
		_aim_mode_toggle_action = "p2_aim_mode_toggle"
		_gamepad_device = InputBindings.get_gamepad_device_for_player(1)


func initialize_at(center: Vector2) -> void:
	screen_pos = center
	_initialized = true
	aim_changed.emit(screen_pos)


func get_screen_pos() -> Vector2:
	return screen_pos


func get_aim_mode_label() -> String:
	match aim_mode:
		AimMode.ORBIT:
			return "Orbita"
		_:
			return "Cursor"


func enter_orbital_virtual_cursor() -> void:
	if uses_mouse:
		return
	if aim_mode == AimMode.VIRTUAL_CURSOR:
		return
	aim_mode = AimMode.VIRTUAL_CURSOR
	aim_mode_changed.emit(aim_mode)


func sync_aim_mode_from_settings(player_index: int) -> void:
	if uses_mouse:
		return
	aim_mode = GameSettings.get_gamepad_aim_mode(player_index) as AimMode
	aim_mode_changed.emit(aim_mode)


func update(
	delta: float,
	bounds: Rect2,
	viewport: Viewport,
	spy: SpyBase = null,
	resolver: AimResolver = null
) -> void:
	if not _initialized:
		initialize_at(bounds.get_center())
	var clamped_pos: Vector2 = _clamp_to_bounds(screen_pos, bounds)
	if clamped_pos != screen_pos:
		screen_pos = clamped_pos
		aim_changed.emit(screen_pos)
	var player_index: int = 0 if spy_id == ItemDB.SpyId.PLAYER else 1
	_gamepad_device = InputBindings.get_gamepad_device_for_player(player_index)
	if uses_mouse and viewport != null:
		var next_pos: Vector2 = _clamp_to_bounds(viewport.get_mouse_position(), bounds)
		if next_pos != screen_pos:
			screen_pos = next_pos
			aim_changed.emit(screen_pos)
		return
	_try_toggle_aim_mode(spy, resolver)
	var aim_vec: Vector2 = Input.get_vector(
		_aim_left_action, _aim_right_action, _aim_up_action, _aim_down_action
	)
	match aim_mode:
		AimMode.ORBIT:
			_update_orbit(bounds, spy, resolver, aim_vec)
		_:
			_update_virtual_cursor(delta, bounds, aim_vec)


func _try_toggle_aim_mode(spy: SpyBase, resolver: AimResolver) -> void:
	if _aim_mode_toggle_action.is_empty():
		return
	if not Input.is_action_just_pressed(_aim_mode_toggle_action):
		return
	var player_index: int = 0 if spy_id == ItemDB.SpyId.PLAYER else 1
	if aim_mode == AimMode.VIRTUAL_CURSOR:
		aim_mode = AimMode.ORBIT
		_sync_orbit_dir_from_screen(spy, resolver)
	else:
		aim_mode = AimMode.VIRTUAL_CURSOR
	GameSettings.set_gamepad_aim_mode(player_index, aim_mode as int)
	aim_mode_changed.emit(aim_mode)


func _update_virtual_cursor(delta: float, bounds: Rect2, aim_vec: Vector2) -> void:
	if aim_vec.length_squared() < STICK_DEADZONE * STICK_DEADZONE:
		return
	var next_virtual: Vector2 = _clamp_to_bounds(
		screen_pos + aim_vec.normalized() * VIRTUAL_CURSOR_SPEED * delta,
		bounds
	)
	if next_virtual != screen_pos:
		screen_pos = next_virtual
		aim_changed.emit(screen_pos)


func _clamp_to_bounds(pos: Vector2, bounds: Rect2) -> Vector2:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return pos
	return Vector2(
		clampf(pos.x, bounds.position.x, bounds.end.x),
		clampf(pos.y, bounds.position.y, bounds.end.y)
	)


func _update_orbit(
	bounds: Rect2,
	spy: SpyBase,
	resolver: AimResolver,
	aim_vec: Vector2
) -> void:
	if aim_vec.length_squared() >= STICK_DEADZONE * STICK_DEADZONE:
		_orbit_dir = aim_vec.normalized()
	if spy == null or resolver == null:
		return
	var pivot_screen: Vector2 = resolver.world_to_screen(spy.get_muzzle_world_position(), spy)
	if pivot_screen == Vector2.ZERO:
		return
	var next_pos: Vector2 = _clamp_to_bounds(pivot_screen + _orbit_dir * ORBIT_SCREEN_RADIUS, bounds)
	if next_pos != screen_pos:
		screen_pos = next_pos
		aim_changed.emit(screen_pos)


func _sync_orbit_dir_from_screen(spy: SpyBase, resolver: AimResolver) -> void:
	if spy == null or resolver == null:
		return
	var pivot_screen: Vector2 = resolver.world_to_screen(spy.get_muzzle_world_position(), spy)
	if pivot_screen == Vector2.ZERO:
		return
	var offset: Vector2 = screen_pos - pivot_screen
	if offset.length_squared() > 0.0001:
		_orbit_dir = offset.normalized()
