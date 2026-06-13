class_name AimCursor
extends CanvasLayer

const COLOR_DETAIL: Color = Color("#c03030")

var _player_dot: AimCursorDot = null
var _bottom_dot: AimCursorDot = null
var _player_orbital: OrbitalTargetRing = null
var _bottom_orbital: OrbitalTargetRing = null
var _aim_controllers: Dictionary = {}


func _ready() -> void:
	layer = 15
	_player_dot = AimCursorDot.new()
	_player_dot.base_color = ItemDB.SPY_COLORS[ItemDB.SpyId.PLAYER1] as Color
	_player_dot.detail_color = COLOR_DETAIL
	_bottom_dot = AimCursorDot.new()
	_bottom_dot.base_color = ItemDB.SPY_COLORS[ItemDB.SpyId.PLAYER2] as Color
	_bottom_dot.detail_color = COLOR_DETAIL
	_player_orbital = OrbitalTargetRing.new()
	_bottom_orbital = OrbitalTargetRing.new()
	add_child(_player_dot)
	add_child(_bottom_dot)
	add_child(_player_orbital)
	add_child(_bottom_orbital)


func setup(controllers: Dictionary, _resolver: AimResolver) -> void:
	_aim_controllers = controllers


func _process(_delta: float) -> void:
	var main: Main = _find_main()
	if main == null or main.mansion == null:
		return
	_update_cursor(_player_dot, _player_orbital, main.mansion.player, ItemDB.SpyId.PLAYER1, main)
	var bottom_spy: SpyBase = main.mansion.get_bottom_spy()
	if bottom_spy != null:
		_update_cursor(_bottom_dot, _bottom_orbital, bottom_spy, ItemDB.SpyId.PLAYER2, main)


func _update_cursor(
	dot: AimCursorDot,
	orbital_ring: OrbitalTargetRing,
	spy: SpyBase,
	controller_key: int,
	main: Main
) -> void:
	if spy == null or spy.held == null or not spy.held.is_holding_weapon():
		dot.visible = false
		orbital_ring.visible = false
		return
	var weapon: WeaponData = WeaponDB.get_weapon(spy.held.get_weapon_id())
	if weapon == null or weapon.aim_profile == WeaponData.AimProfile.NONE or weapon.aim_profile == WeaponData.AimProfile.DIRECTIONAL:
		dot.visible = false
		orbital_ring.visible = false
		return
	var controller: AimController = _aim_controllers.get(controller_key) as AimController
	if controller == null:
		dot.visible = false
		orbital_ring.visible = false
		return
	var reticle_pos: Vector2 = controller.get_screen_pos()
	if main.game_views != null:
		reticle_pos = main.game_views.clamp_to_aim_views(reticle_pos)
	if weapon.orbital_strike:
		dot.visible = false
		orbital_ring.visible = spy.orbital_targeting
		if spy.orbital_targeting:
			orbital_ring.global_position = reticle_pos - orbital_ring.size * 0.5
		return
	var use_orbital: bool = spy.orbital_targeting
	dot.visible = not use_orbital
	orbital_ring.visible = use_orbital
	if use_orbital:
		orbital_ring.global_position = reticle_pos - orbital_ring.size * 0.5
	else:
		dot.global_position = reticle_pos - dot.size * 0.5


func _find_main() -> Main:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var root: Node = tree.current_scene
	if root is Main:
		return root as Main
	return null
