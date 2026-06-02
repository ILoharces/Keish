extends Control
class_name Main

# Orquestador: layout NES + flujo de menús/partida.

@onready var game_root: Control = $GameRoot
@onready var game_views: GameViewsPanel = $GameRoot/GameViewsPanel
@onready var hud: Hud = $GameRoot/Hud
@onready var trapulator: Trapulator = $GameRoot/Trapulator
@onready var game_over: GameOverPanel = $GameOver
@onready var main_menu: MainMenu = $MainMenu
@onready var play_menu: PlayMenu = $PlayMenu
@onready var map_editor: MapEditor = $MapEditor
@onready var escape_menu: EscapeMenu = $EscapeMenu
@onready var settings_menu: SettingsMenu = $SettingsMenu
@onready var tutorial_overlay: TutorialOverlay = $TutorialOverlay

var _game_started: bool = false
var _was_running_before_pause: bool = false
var _side_divider: ColorRect = null
var _stats_divider: ColorRect = null
var _map_overlay: Control = null
var _map_panel: Minimap = null
var _map_open: bool = false

var _layout_helper: MainLayout = null
var _screens: MainScreens = null
var _aim_controllers: Dictionary = {}
var _aim_cursor: AimCursor = null
var _aim_resolver: AimResolver = null
var _weapon_executor: WeaponExecutor = null
var _aim_snap_connections: Array[Dictionary] = []
var _orbital_laser: OrbitalLaserOverlay = null

const _AIM_CURSOR_SCENE: PackedScene = preload("res://Scenes/ui/aim_cursor.tscn")
const AIM_SNAP_WORLD_OFFSET: float = 48.0


func _ready() -> void:
	_layout_helper = MainLayout.new(self)
	_screens = MainScreens.new(self)
	DisplayConfig.sync_to_window()
	get_viewport().size_changed.connect(_on_viewport_resized)
	game_views.views_resized.connect(_on_views_resized)
	if not game_views.shared_room_layout_changed.is_connected(_on_shared_room_layout_changed):
		game_views.shared_room_layout_changed.connect(_on_shared_room_layout_changed)
	_layout_helper.setup()
	GameState.running = false
	_screens.set_game_ui_visible(false)
	_screens.connect_menus()
	if not InputBindings.control_modes_changed.is_connected(_on_control_modes_changed):
		InputBindings.control_modes_changed.connect(_on_control_modes_changed)
	if not GameSettings.has_completed_tutorial():
		main_menu.visible = false
		if not tutorial_overlay.finished.is_connected(_on_tutorial_finished):
			tutorial_overlay.finished.connect(_on_tutorial_finished, CONNECT_ONE_SHOT)
		tutorial_overlay.show_tutorial()
	else:
		main_menu.show_menu()


func _on_tutorial_finished() -> void:
	main_menu.show_menu()


func _on_viewport_resized() -> void:
	_layout_helper.apply_layout()


func _refresh_viewport_layout() -> void:
	_layout_helper.update_camera_zooms()
	game_views.snap_cameras()


func _on_views_resized() -> void:
	_layout_helper.update_camera_zooms()


func close_map_overlay() -> void:
	if not _map_open:
		return
	_map_open = false
	GameState.map_overlay_open = false
	if _map_overlay != null:
		_map_overlay.visible = false
	_screens.update_player_input_block()


func _process(_delta: float) -> void:
	_layout_helper.follow_cameras()
	_update_os_mouse_visibility()


func _unhandled_input(event: InputEvent) -> void:
	_screens.handle_unhandled_input(event)


# Atajos hacia GameViewsPanel (evita rutas largas en el resto del proyecto).
var mansion: Mansion:
	get:
		return game_views.mansion


var player_viewport: SubViewport:
	get:
		return game_views.player_viewport


var ai_viewport: SubViewport:
	get:
		return game_views.ai_viewport


func setup_combat_aim() -> void:
	teardown_combat_aim()
	if mansion == null:
		return
	_aim_cursor = _AIM_CURSOR_SCENE.instantiate() as AimCursor
	if _aim_cursor == null:
		return
	game_root.add_child(_aim_cursor)
	_aim_resolver = AimResolver.new(game_views)
	_weapon_executor = WeaponExecutor.new(_aim_resolver)
	if mansion.player != null and mansion.player.combat != null:
		mansion.player.combat.set_weapon_executor(_weapon_executor)
	var bottom_spy: SpyBase = mansion.get_bottom_spy()
	if bottom_spy != null and bottom_spy.combat != null:
		bottom_spy.combat.set_weapon_executor(_weapon_executor)
	var p1_uses_mouse: bool = (
		InputBindings.get_control_mode(0) == InputBindings.PlayerControlMode.KEYBOARD_MOUSE
	)
	var p1_controller: AimController = AimController.new(ItemDB.SpyId.PLAYER, p1_uses_mouse)
	p1_controller.initialize_at(game_views.get_player_view_global_rect().get_center())
	_aim_controllers[ItemDB.SpyId.PLAYER] = p1_controller
	if bottom_spy != null and bottom_spy != mansion.player:
		var p2_controller: AimController = AimController.new(ItemDB.SpyId.AI, false)
		p2_controller.initialize_at(game_views.get_ai_view_global_rect().get_center())
		_aim_controllers[ItemDB.SpyId.AI] = p2_controller
	_aim_cursor.setup(_aim_controllers, _aim_resolver)
	_orbital_laser = OrbitalLaserOverlay.new()
	game_root.add_child(_orbital_laser)
	_connect_aim_snap_signals(mansion.player)
	if bottom_spy != null:
		_connect_aim_snap_signals(bottom_spy)


func teardown_combat_aim() -> void:
	_disconnect_aim_snap_signals()
	_set_os_mouse_visible(true)
	_aim_controllers.clear()
	_aim_resolver = null
	_weapon_executor = null
	if mansion != null:
		if mansion.player != null and mansion.player.combat != null:
			mansion.player.combat.set_weapon_executor(null)
		var bottom_spy: SpyBase = mansion.get_bottom_spy()
		if bottom_spy != null and bottom_spy.combat != null:
			bottom_spy.combat.set_weapon_executor(null)
	if _aim_cursor != null and is_instance_valid(_aim_cursor):
		_aim_cursor.queue_free()
	_aim_cursor = null
	if _orbital_laser != null and is_instance_valid(_orbital_laser):
		_orbital_laser.queue_free()
	_orbital_laser = null


func play_orbital_laser(attacker_spy_id: int, target_screen_pos: Vector2, on_impact: Callable = Callable()) -> void:
	if _orbital_laser == null or hud == null:
		if on_impact.is_valid():
			on_impact.call()
		return
	_orbital_laser.play_strike(attacker_spy_id, target_screen_pos, hud, on_impact)


func restore_orbital_aim_mode_for_spy(spy: SpyBase) -> void:
	if spy == null:
		return
	var controller_key: int = _aim_controller_key_for_spy(spy)
	var controller: AimController = get_aim_controller(controller_key)
	if controller == null:
		return
	var player_index: int = 0 if spy.spy_id == ItemDB.SpyId.PLAYER else 1
	controller.sync_aim_mode_from_settings(player_index)


func get_aim_controller(spy_id: int) -> AimController:
	return _aim_controllers.get(spy_id) as AimController


func get_aim_resolver() -> AimResolver:
	return _aim_resolver


func _connect_aim_snap_signals(spy: SpyBase) -> void:
	if spy == null:
		return
	var controller_key: int = _aim_controller_key_for_spy(spy)
	var weapon_callback: Callable = _on_spy_weapon_changed.bind(spy, controller_key)
	var held_callback: Callable = _on_spy_held_changed.bind(spy, controller_key)
	spy.weapon_changed.connect(weapon_callback)
	spy.held_changed.connect(held_callback)
	_aim_snap_connections.append({
		"spy": spy,
		"weapon_callback": weapon_callback,
		"held_callback": held_callback,
	})


func _disconnect_aim_snap_signals() -> void:
	for entry: Dictionary in _aim_snap_connections:
		var spy: SpyBase = entry.get("spy") as SpyBase
		if spy == null or not is_instance_valid(spy):
			continue
		var weapon_callback: Callable = entry.get("weapon_callback") as Callable
		if spy.weapon_changed.is_connected(weapon_callback):
			spy.weapon_changed.disconnect(weapon_callback)
		var held_callback: Callable = entry.get("held_callback") as Callable
		if spy.held_changed.is_connected(held_callback):
			spy.held_changed.disconnect(held_callback)
	_aim_snap_connections.clear()


func _aim_controller_key_for_spy(spy: SpyBase) -> int:
	if mansion != null and spy == mansion.player:
		return ItemDB.SpyId.PLAYER
	return ItemDB.SpyId.AI


func _on_spy_weapon_changed(weapon_id: StringName, spy: SpyBase, controller_key: int) -> void:
	if weapon_id.is_empty() or spy.orbital_targeting:
		return
	_snap_aim_to_room_center(spy, controller_key)


func snap_orbital_aim(controller_key: int) -> void:
	var controller: AimController = _aim_controllers.get(controller_key) as AimController
	if controller != null:
		var player_index: int = 0 if controller_key == ItemDB.SpyId.PLAYER else 1
		if InputBindings.get_control_mode(player_index) == InputBindings.PlayerControlMode.GAMEPAD:
			controller.enter_orbital_virtual_cursor()


func _snap_aim_to_views_center(controller_key: int) -> void:
	var controller: AimController = _aim_controllers.get(controller_key) as AimController
	if controller == null or game_views == null:
		return
	var center: Vector2 = game_views.get_aim_views_global_rect().get_center()
	controller.initialize_at(center)


func _on_spy_held_changed(kind: int, _held_id: int, spy: SpyBase, controller_key: int) -> void:
	if kind != HeldInventory.Kind.WEAPON:
		return
	_snap_aim_to_room_center(spy, controller_key)


func _on_shared_room_layout_changed(active: bool) -> void:
	if not active:
		return
	_snap_aim_cursors_to_spy_centers(true)


func _snap_aim_cursors_to_spy_centers(move_os_cursor: bool = false) -> void:
	if _aim_resolver == null or mansion == null:
		return
	if mansion.player != null:
		_snap_aim_to_spy_center(mansion.player, ItemDB.SpyId.PLAYER, move_os_cursor)
	var bottom_spy: SpyBase = mansion.get_bottom_spy()
	if bottom_spy != null and bottom_spy != mansion.player:
		_snap_aim_to_spy_center(bottom_spy, ItemDB.SpyId.AI, move_os_cursor)


func _snap_aim_to_room_center(spy: SpyBase, controller_key: int) -> void:
	if game_views != null and game_views.spies_share_room():
		_snap_aim_to_spy_center(spy, controller_key, false)
		return
	if _aim_resolver == null or spy == null:
		return
	var controller: AimController = _aim_controllers.get(controller_key) as AimController
	if controller == null:
		return
	var room: Room = spy.current_room
	if room == null:
		return
	var screen_pos: Vector2 = _aim_resolver.world_to_screen(room.get_center_world_pos(), spy)
	if screen_pos == Vector2.ZERO:
		var view_rect: Rect2 = (
			game_views.get_player_view_global_rect()
			if controller_key == ItemDB.SpyId.PLAYER
			else game_views.get_ai_view_global_rect()
		)
		if view_rect.size == Vector2.ZERO:
			return
		screen_pos = view_rect.get_center()
	screen_pos = game_views.clamp_to_aim_views(screen_pos)
	controller.initialize_at(screen_pos)
	_sync_spy_aim_direction(spy, screen_pos)


func _snap_aim_to_spy_center(spy: SpyBase, controller_key: int, move_os_cursor: bool) -> void:
	if _aim_resolver == null or spy == null or not spy.is_alive:
		return
	var controller: AimController = _aim_controllers.get(controller_key) as AimController
	if controller == null:
		return
	var screen_pos: Vector2 = _aim_resolver.world_to_screen(_aim_snap_world_pos(spy), spy)
	if screen_pos == Vector2.ZERO:
		_snap_aim_to_room_center(spy, controller_key)
		return
	screen_pos = game_views.clamp_to_aim_views(screen_pos)
	controller.initialize_at(screen_pos)
	_sync_spy_aim_direction(spy, screen_pos)
	if move_os_cursor and controller.uses_mouse:
		get_viewport().warp_mouse(screen_pos)


func _aim_snap_world_pos(spy: SpyBase) -> Vector2:
	var dir: Vector2 = spy.aim_direction
	if dir.length_squared() <= 0.0001:
		dir = Vector2.RIGHT
	return spy.get_muzzle_world_position() + dir.normalized() * AIM_SNAP_WORLD_OFFSET


func _sync_spy_aim_direction(spy: SpyBase, screen_pos: Vector2) -> void:
	if _aim_resolver == null or spy == null:
		return
	var aim_dir: Vector2 = _aim_resolver.resolve_aim_direction(screen_pos, spy)
	if aim_dir == Vector2.ZERO:
		return
	if aim_dir == spy.aim_direction:
		return
	spy.aim_direction = aim_dir
	spy.queue_redraw()


func _on_control_modes_changed() -> void:
	if not GameState.running or mansion == null:
		return
	setup_combat_aim()


func _update_os_mouse_visibility() -> void:
	var hide_mouse: bool = (
		GameState.running
		and _game_started
		and InputBindings.get_control_mode(0) == InputBindings.PlayerControlMode.KEYBOARD_MOUSE
		and not escape_menu.visible
		and not settings_menu.visible
		and (game_over == null or not game_over.visible)
	)
	if hide_mouse:
		_set_os_mouse_visible(false)
	else:
		_set_os_mouse_visible(true)


func _set_os_mouse_visible(show_cursor: bool) -> void:
	if show_cursor:
		if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if Input.mouse_mode != Input.MOUSE_MODE_HIDDEN:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
