class_name MainScreens
extends RefCounted

# Menús, flujo de partida, pausa y entrada global.


var main: Main = null


func _init(p_main: Main) -> void:
	main = p_main


func connect_menus() -> void:
	main.main_menu.play_pressed.connect(on_main_play)
	main.main_menu.create_map_pressed.connect(on_main_create_map)
	main.main_menu.settings_pressed.connect(on_main_settings)
	main.main_menu.quit_pressed.connect(on_main_quit)
	main.settings_menu.back_pressed.connect(on_settings_back)
	main.play_menu.back_pressed.connect(on_play_back)
	main.play_menu.map_selected.connect(on_map_confirmed)
	main.map_editor.map_confirmed.connect(on_map_confirmed)
	main.map_editor.editor_closed.connect(on_editor_closed)
	main.escape_menu.resume_pressed.connect(on_escape_resume)
	main.escape_menu.exit_pressed.connect(on_escape_exit)
	GameState.map_overlay_close_requested.connect(main.close_map_overlay)


func on_main_play() -> void:
	main.main_menu.hide_menu()
	main.play_menu.show_menu()


func on_main_create_map() -> void:
	main.main_menu.hide_menu()
	main.map_editor.show_editor()


func on_main_settings() -> void:
	main.main_menu.hide_menu()
	main.settings_menu.show_menu()


func on_settings_back() -> void:
	main.settings_menu.hide_menu()
	main.main_menu.show_menu()


func on_main_quit() -> void:
	main.get_tree().quit()


func on_play_back() -> void:
	main.play_menu.hide_menu()
	main.main_menu.show_menu()


func on_editor_closed() -> void:
	main.map_editor.hide_editor()
	main.main_menu.show_menu()


func set_game_ui_visible(visible_flag: bool) -> void:
	main.game_root.visible = visible_flag
	if main.hud != null:
		main.hud.visible = visible_flag and DebugFlags.hud_enabled
	if main.trapulator != null:
		if not visible_flag:
			main.trapulator.close()
		else:
			main.trapulator.visible = main.trapulator.is_open


func on_map_confirmed(layout: LevelLayout) -> void:
	main._game_started = true
	main.escape_menu.hide_menu()
	main.main_menu.hide_menu()
	main.settings_menu.hide_menu()
	main.play_menu.hide_menu()
	main.map_editor.hide_editor()
	GameState.reset_match()
	InputBindings.set_ai_adaptive_controls(GameState.use_ai)
	InputBindings.apply_all()
	main.close_map_overlay()
	if main.trapulator.is_open:
		main.trapulator.close()
	set_game_ui_visible(true)
	main._layout_helper.apply_layout()
	main.mansion.begin_with_layout(layout)
	main.ai_viewport.world_2d = main.player_viewport.world_2d
	main._layout_helper.setup_cameras()
	bind_ui()
	main.setup_combat_aim()
	main._layout_helper.snap_cameras()
	main.call_deferred("_refresh_viewport_layout")
	DebugFlags.apply_ui_visibility()


func bind_ui() -> void:
	if main.mansion.player != null:
		main.hud.bind_player(main.mansion.player)
		main.trapulator.bind_player(main.mansion.player)
	if main.mansion.player2 != null:
		main.mansion.player2.reset_held_for_match()
		main.trapulator.bind_player2(main.mansion.player2)
	elif main.mansion.ai_spy != null:
		main.mansion.ai_spy.reset_held_for_match()
		main.trapulator.bind_player2(null)
	else:
		main.trapulator.bind_player2(null)
	main.hud.bind_world(main.mansion)
	if main._map_panel != null:
		main._map_panel.bind_mansion(main.mansion)
	main.mansion.player_room_changed.connect(main.hud.set_room_label)
	main.trapulator.toggled.connect(on_trapulator_toggled)
	if main.mansion.player != null and main.mansion.player.current_room != null:
		main.hud.set_room_label(main.mansion.player.current_room)


func on_trapulator_toggled(open: bool) -> void:
	if open and main._map_open:
		main.trapulator.close()
		return
	update_player_input_block()


func update_player_input_block() -> void:
	if main.mansion == null:
		return
	var blocked: bool = (
		main._map_open or main.trapulator.is_open or main.escape_menu.is_visible_menu()
	)
	if main.mansion.player != null:
		main.mansion.player.set_input_blocked(blocked)
	if main.mansion.player2 != null:
		main.mansion.player2.set_input_blocked(blocked)


func toggle_map_overlay() -> void:
	if not DebugFlags.minimap_enabled:
		return
	main._map_open = not main._map_open
	GameState.map_overlay_open = main._map_open
	if main._map_overlay != null:
		main._map_overlay.visible = main._map_open
	if main._map_open:
		if main.trapulator.is_open:
			main.trapulator.close()
		if main._map_panel != null:
			main._map_panel.bind_mansion(main.mansion)
	update_player_input_block()


func handle_unhandled_input(event: InputEvent) -> void:
	if not main._game_started or not GameState.running:
		if main.escape_menu.is_visible_menu() and (
			event.is_action_pressed("ui_cancel")
			or event.is_action_pressed("pause_menu")
			or event.is_action_pressed("p2_pause_menu")
		):
			on_escape_resume()
			main.get_viewport().set_input_as_handled()
		return
	if main.game_over.visible:
		return
	if main._map_open:
		if event.is_action_pressed("toggle_map") or event.is_action_pressed("p2_toggle_map"):
			toggle_map_overlay()
			main.get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_map") or event.is_action_pressed("p2_toggle_map"):
		toggle_map_overlay()
		main.get_viewport().set_input_as_handled()
		return
	if main.trapulator.is_open:
		return
	if event.is_action_pressed("pause_menu") or event.is_action_pressed("p2_pause_menu"):
		open_escape_menu()
		main.get_viewport().set_input_as_handled()


func open_escape_menu() -> void:
	if main.escape_menu.is_visible_menu():
		return
	main._was_running_before_pause = GameState.running
	GameState.running = false
	if main.trapulator.is_open:
		main.trapulator.close()
	if main._map_open:
		toggle_map_overlay()
	update_player_input_block()
	main.escape_menu.show_menu()


func on_escape_resume() -> void:
	main.escape_menu.hide_menu()
	if not main._game_started:
		return
	if main._was_running_before_pause:
		GameState.running = true
	update_player_input_block()


func on_escape_exit() -> void:
	main.escape_menu.hide_menu()
	return_to_main_menu()


func return_to_main_menu() -> void:
	main._game_started = false
	GameState.running = false
	InputBindings.set_ai_adaptive_controls(false)
	GameSettings.apply_to_match_defaults()
	GameState.map_overlay_open = false
	main._map_open = false
	if main._map_overlay != null:
		main._map_overlay.visible = false
	if main.trapulator.is_open:
		main.trapulator.close()
	main.mansion.shutdown()
	set_game_ui_visible(false)
	update_player_input_block()
	main.main_menu.show_menu()
