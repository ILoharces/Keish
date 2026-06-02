extends SpyBase
class_name Player

# R: ciclar trampa | Q: colocar | Tab: Trapulator | E: inspeccionar / recoger del suelo

var input_blocked: bool = false


func _ready() -> void:
	if spy_id != ItemDB.SpyId.AI:
		spy_id = ItemDB.SpyId.PLAYER
	super._ready()
	add_to_group("player")


func _compute_input_vector() -> Vector2:
	if not is_alive or input_blocked or not GameState.running or GameState.map_overlay_open:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _process(delta: float) -> void:
	_update_aim_controller(delta)
	_poll_combat_input()


func _poll_combat_input() -> void:
	if not is_alive or input_blocked or not GameState.running or GameState.map_overlay_open:
		return
	var weapon: WeaponData = combat.get_equipped_weapon_data() if combat != null else null
	if weapon != null and weapon.orbital_strike:
		if Input.is_action_just_pressed(_get_fire_action()):
			if orbital_targeting:
				_try_fire_weapon()
			else:
				_arm_orbital_cannon()
		return
	if weapon != null and weapon.auto_fire:
		if Input.is_action_pressed(_get_fire_action()):
			_try_fire_weapon()
	elif Input.is_action_just_pressed(_get_fire_action()):
		_try_fire_weapon()


func _get_fire_action() -> String:
	return "fire_weapon"


func _update_aim_controller(delta: float) -> void:
	var main_node: Main = _get_main_node()
	if main_node == null:
		return
	var controller: AimController = main_node.get_aim_controller(get_aim_controller_spy_id())
	if controller == null:
		return
	var bounds: Rect2 = main_node.game_views.get_aim_views_global_rect()
	var viewport: Viewport = main_node.get_viewport()
	controller.update(delta, bounds, viewport, self, main_node.get_aim_resolver())
	_update_aim_direction(main_node, controller)


func _update_aim_direction(main_node: Main, controller: AimController) -> void:
	if combat == null:
		return
	var weapon: WeaponData = combat.get_equipped_weapon_data()
	if weapon == null:
		return
	if weapon.aim_profile == WeaponData.AimProfile.NONE or weapon.aim_profile == WeaponData.AimProfile.DIRECTIONAL:
		return
	var resolver: AimResolver = main_node.get_aim_resolver()
	if resolver == null:
		return
	var next_dir: Vector2 = resolver.resolve_aim_direction(controller.get_screen_pos(), self)
	if next_dir == Vector2.ZERO:
		return
	if next_dir == aim_direction:
		return
	aim_direction = next_dir
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_alive or input_blocked or not GameState.running or GameState.map_overlay_open:
		return
	if orbital_targeting:
		return
	if event.is_action_pressed("interact"):
		interact_with_nearby()
	elif event.is_action_pressed("place_trap"):
		var trap_id: int = held.get_trap_id() if held != null else -1
		if trap_id >= 0:
			try_place_trap(trap_id)
	elif event.is_action_pressed("next_trap"):
		_cycle_held_trap()


func set_input_blocked(value: bool) -> void:
	input_blocked = value


func get_held_trap_id() -> int:
	if held == null:
		return -1
	return held.get_trap_id()


func _try_fire_weapon() -> void:
	var main_node: Main = _get_main_node()
	if main_node == null:
		return
	var controller: AimController = main_node.get_aim_controller(get_aim_controller_spy_id())
	if controller == null:
		return
	var screen_pos: Vector2 = main_node.game_views.clamp_to_aim_views(controller.get_screen_pos())
	try_fire_weapon(screen_pos, main_node.game_views)


func _arm_orbital_cannon() -> void:
	if combat == null:
		return
	var weapon: WeaponData = combat.get_equipped_weapon_data()
	if weapon == null or not weapon.orbital_strike or orbital_targeting:
		return
	set_orbital_targeting(true)
	var main_node: Main = _get_main_node()
	if main_node != null:
		main_node.snap_orbital_aim(get_aim_controller_spy_id())


func _get_main_node() -> Main:
	return get_tree().current_scene as Main


func _cycle_held_trap() -> void:
	cycle_held_trap()
