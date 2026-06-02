extends CanvasLayer
class_name Hud

# HUD estilo Spy vs Spy (NES): panel derecho con TIME, vida e inventario; centro reservado.

const STATS_PAD: float = 8.0

var player_panel: SpyHudPanel
var ai_panel: SpyHudPanel
var message_label: Label
var bound_player: Player = null
var bound_opponent: SpyBase = null


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud_root")
	_build_ui()
	GameState.time_changed.connect(_on_time_changed)
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.weapons_changed.connect(_on_weapons_changed)
	GameState.game_over.connect(_on_game_over)
	GameState.exit_reached.connect(_on_exit_reached)
	GameState.item_blocked_no_suitcase.connect(_on_item_blocked)
	GameState.suitcase_dropped.connect(_on_suitcase_state_changed)
	GameState.suitcase_recovered.connect(_on_suitcase_recovered)
	GameState.suitcase_stolen.connect(_on_suitcase_stolen)
	_on_time_changed(ItemDB.SpyId.PLAYER, GameState.get_time_left(ItemDB.SpyId.PLAYER))
	_on_time_changed(ItemDB.SpyId.AI, GameState.get_time_left(ItemDB.SpyId.AI))
	player_panel.update_inventory()
	ai_panel.update_inventory()
	relayout_for_display()
	DebugFlags.apply_ui_visibility()


func relayout_for_display() -> void:
	var metrics: LayoutMetrics = DisplayConfig.get_metrics() as LayoutMetrics
	var stats_rect: Rect2 = metrics.stats_panel_rect()
	var stats_left: float = stats_rect.position.x + STATS_PAD
	var stats_w: float = stats_rect.size.x - STATS_PAD * 2.0
	var mid_y: float = metrics.mid_y
	player_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	player_panel.position = Vector2(stats_left, 0.0)
	player_panel.size = Vector2(stats_w, mid_y)
	ai_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ai_panel.position = Vector2(stats_left, mid_y)
	ai_panel.size = Vector2(stats_w, metrics.screen_size.y - mid_y)
	if message_label != null:
		var game: Rect2 = metrics.game_column_rect()
		message_label.position = Vector2(game.position.x, mid_y - 16.0)
		message_label.size = Vector2(game.size.x, 32.0)


func bind_player(player: Player) -> void:
	if bound_player != null and is_instance_valid(bound_player):
		if bound_player.weapon_changed.is_connected(_on_player_weapon_changed):
			bound_player.weapon_changed.disconnect(_on_player_weapon_changed)
	bound_player = player
	_connect_health_bar(player, _on_player_health_changed)
	player.weapon_changed.connect(_on_player_weapon_changed)
	player.reset_held_for_match()
	player_panel.update_inventory()
	player_panel.update_ammo(null, &"")
	_refresh_ammo_displays()


func bind_world(mansion: Mansion) -> void:
	if mansion == null:
		return
	var bottom_spy: SpyBase = mansion.get_bottom_spy()
	if bottom_spy == null:
		return
	if bound_opponent != null and is_instance_valid(bound_opponent):
		if bound_opponent.weapon_changed.is_connected(_on_opponent_weapon_changed):
			bound_opponent.weapon_changed.disconnect(_on_opponent_weapon_changed)
	bound_opponent = bottom_spy
	_connect_health_bar(bottom_spy, _on_ai_health_changed)
	if not bottom_spy.weapon_changed.is_connected(_on_opponent_weapon_changed):
		bottom_spy.weapon_changed.connect(_on_opponent_weapon_changed)
	ai_panel.update_health(bottom_spy.health, SpyBase.MAX_HEALTH)
	ai_panel.update_inventory()
	ai_panel.update_ammo(null, &"")
	_refresh_ammo_displays()


func _build_ui() -> void:
	player_panel = SpyHudPanel.new()
	player_panel.name = "PlayerStats"
	player_panel.setup(ItemDB.SpyId.PLAYER, true)
	player_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player_panel)
	ai_panel = SpyHudPanel.new()
	ai_panel.name = "AiStats"
	ai_panel.setup(ItemDB.SpyId.AI, false)
	ai_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ai_panel)
	message_label = Label.new()
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label.modulate = Color(1, 1, 1, 0)
	message_label.text = ""
	add_child(message_label)


func _connect_health_bar(spy: SpyBase, callback: Callable) -> void:
	if spy.health_changed.is_connected(callback):
		spy.health_changed.disconnect(callback)
	spy.health_changed.connect(callback)
	callback.call(spy.health, SpyBase.MAX_HEALTH)


func _on_player_health_changed(current: float, maximum: float) -> void:
	player_panel.update_health(current, maximum)


func _on_ai_health_changed(current: float, maximum: float) -> void:
	ai_panel.update_health(current, maximum)


func _on_time_changed(spy_id: int, value: float) -> void:
	var clamped: float = maxf(0.0, value)
	var minutes: int = int(clamped) / 60
	var seconds: int = int(clamped) % 60
	var text: String = "%02d:%02d" % [minutes, seconds]
	if spy_id == ItemDB.SpyId.PLAYER:
		player_panel.set_time_text(text, NesUiTheme.timer_color(clamped))
	elif spy_id == ItemDB.SpyId.AI:
		ai_panel.set_time_text(text, NesUiTheme.timer_color(clamped))


func _on_inventory_changed(spy_id: int) -> void:
	if spy_id == ItemDB.SpyId.PLAYER:
		player_panel.update_inventory()
	else:
		ai_panel.update_inventory()


func _on_weapons_changed(spy_id: int) -> void:
	if spy_id == ItemDB.SpyId.PLAYER:
		player_panel.update_ammo(bound_player, _get_equipped_weapon_id(bound_player))
	else:
		ai_panel.update_ammo(bound_opponent, _get_equipped_weapon_id(bound_opponent))


func _on_player_weapon_changed(weapon_id: StringName) -> void:
	player_panel.update_ammo(bound_player, weapon_id)


func _on_opponent_weapon_changed(weapon_id: StringName) -> void:
	ai_panel.update_ammo(bound_opponent, weapon_id)


func _refresh_ammo_displays() -> void:
	player_panel.update_ammo(bound_player, _get_equipped_weapon_id(bound_player))
	ai_panel.update_ammo(bound_opponent, _get_equipped_weapon_id(bound_opponent))


func _get_equipped_weapon_id(spy: SpyBase) -> StringName:
	if spy == null or spy.held == null or not spy.held.is_holding_weapon():
		return &""
	return spy.held.get_weapon_id()


func _on_game_over(_winner_id: int) -> void:
	var copy: Dictionary = _build_flash_copy(_winner_id)
	flash_message(copy.get("message", "GAME OVER") as String)


func _build_flash_copy(winner_id: int) -> Dictionary:
	if winner_id == GameState.WINNER_TIMEOUT:
		return {"message": "TIME UP"}
	var winner_name: String = _spy_flash_label(winner_id)
	match GameState.match_end_reason:
		GameState.MatchEndReason.ESCAPE:
			return {"message": "%s ESCAPED!" % winner_name}
		GameState.MatchEndReason.TRAP:
			return {"message": "TRAP KILL!"}
		GameState.MatchEndReason.WEAPON:
			return {"message": "ELIMINADO!"}
		GameState.MatchEndReason.TIMEOUT:
			return {"message": "TIME UP!"}
	if winner_id == ItemDB.SpyId.PLAYER:
		return {"message": "YOU WIN!" if GameState.use_ai else "BLANCO WINS!"}
	if winner_id == ItemDB.SpyId.AI:
		return {"message": "YOU LOSE!" if GameState.use_ai else "NEGRO WINS!"}
	return {"message": "GAME OVER"}


func _spy_flash_label(spy_id: int) -> String:
	if spy_id == ItemDB.SpyId.PLAYER:
		return "BLANCO" if not GameState.use_ai else "YOU"
	if spy_id == ItemDB.SpyId.AI:
		return "NEGRO" if not GameState.use_ai else "BLACK SPY"
	return "???"


func _on_exit_reached(spy_id: int) -> void:
	if spy_id == ItemDB.SpyId.PLAYER:
		flash_message("Need all 5 items to escape")


func _on_item_blocked(spy_id: int) -> void:
	if spy_id == ItemDB.SpyId.PLAYER:
		flash_message("Need suitcase first")


func _on_suitcase_state_changed(spy_id: int) -> void:
	_on_inventory_changed(spy_id)
	if spy_id == ItemDB.SpyId.PLAYER:
		flash_message("Suelta lo que llevabas — recoge con E")


func _on_suitcase_recovered(spy_id: int) -> void:
	_on_inventory_changed(spy_id)
	if spy_id == ItemDB.SpyId.PLAYER:
		player_panel.blink_inventory()
		flash_message("Maletin recuperado — todo el botin a salvo")


func _on_suitcase_stolen(thief_id: int, victim_id: int) -> void:
	_on_inventory_changed(thief_id)
	_on_inventory_changed(victim_id)
	if thief_id == ItemDB.SpyId.PLAYER:
		flash_message("Has robado el maletin enemigo")
	elif victim_id == ItemDB.SpyId.PLAYER:
		flash_message("Te han robado el maletin")


func flash_message(text: String) -> void:
	message_label.text = text
	message_label.modulate = Color.WHITE
	var tween: Tween = create_tween()
	tween.tween_property(message_label, "modulate", Color(1, 1, 1, 0), 2.5)


func set_room_label(room: Room) -> void:
	if room == null:
		player_panel.set_room_text("")
		return
	var gp: Vector2i = room.grid_pos
	player_panel.set_room_text("ROOM %d,%d" % [gp.x, gp.y])
