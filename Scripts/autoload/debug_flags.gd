extends Node

# =============================================================================
# DEBUG FLAGS — interruptores rapidos para desarrollo
# Edita los valores debajo o usa las teclas F1–F8 en ejecucion (si hotkeys_enabled).
# =============================================================================

# --- Mundo / interaccion ---
var furniture_enabled: bool = true
## Si furniture_enabled es false, reparte los 5 objetos en el suelo de salas distintas.
var scatter_items_when_no_furniture: bool = true

# --- IA ---
var ai_enabled: bool = true
var ai_places_traps: bool = true

# --- Reglas de partida ---
var require_suitcase_first: bool = true
var match_timer_enabled: bool = true

# --- UI ---
var hud_enabled: bool = true
var minimap_enabled: bool = true

# --- Atajos en juego (F1–F8) ---
var hotkeys_enabled: bool = true


func _ready() -> void:
	_log_state()
	if hotkeys_enabled:
		set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if not hotkeys_enabled or not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_F1:
			furniture_enabled = not furniture_enabled
			print("[DebugFlags] furniture_enabled = %s" % furniture_enabled)
		KEY_F2:
			scatter_items_when_no_furniture = not scatter_items_when_no_furniture
			print("[DebugFlags] scatter_items_when_no_furniture = %s" % scatter_items_when_no_furniture)
		KEY_F3:
			ai_enabled = not ai_enabled
			print("[DebugFlags] ai_enabled = %s" % ai_enabled)
		KEY_F4:
			ai_places_traps = not ai_places_traps
			print("[DebugFlags] ai_places_traps = %s" % ai_places_traps)
		KEY_F5:
			require_suitcase_first = not require_suitcase_first
			print("[DebugFlags] require_suitcase_first = %s" % require_suitcase_first)
		KEY_F6:
			match_timer_enabled = not match_timer_enabled
			print("[DebugFlags] match_timer_enabled = %s" % match_timer_enabled)
		KEY_F7:
			hud_enabled = not hud_enabled
			_apply_hud_visibility()
			print("[DebugFlags] hud_enabled = %s" % hud_enabled)
		KEY_F8:
			minimap_enabled = not minimap_enabled
			_apply_minimap_visibility()
			print("[DebugFlags] minimap_enabled = %s" % minimap_enabled)
		KEY_F9:
			_log_state()
		_:
			return
	get_viewport().set_input_as_handled()


func is_furniture_enabled() -> bool:
	return furniture_enabled


func is_ai_active() -> bool:
	return ai_enabled


func _log_state() -> void:
	print(
		"[DebugFlags] furniture=%s scatter=%s | ai=%s traps=%s | suitcase_first=%s timer=%s | hud=%s minimap=%s | hotkeys=%s"
		% [
			furniture_enabled,
			scatter_items_when_no_furniture,
			ai_enabled,
			ai_places_traps,
			require_suitcase_first,
			match_timer_enabled,
			hud_enabled,
			minimap_enabled,
			hotkeys_enabled,
		]
	)
	print("[DebugFlags] F1 muebles | F2 items suelo | F3 IA | F4 trampas IA | F5 maletin | F6 reloj | F7 HUD | F8 minimapa | F9 resumen")


func _apply_hud_visibility() -> void:
	var hud_nodes: Array[Node] = get_tree().get_nodes_in_group("hud_root")
	for node: Node in hud_nodes:
		if node is CanvasItem:
			(node as CanvasItem).visible = hud_enabled


func _apply_minimap_visibility() -> void:
	if not minimap_enabled:
		GameState.map_overlay_close_requested.emit()
	for node: Node in get_tree().get_nodes_in_group("map_overlay_root"):
		if node is CanvasItem and not minimap_enabled:
			(node as CanvasItem).visible = false


func apply_ui_visibility() -> void:
	_apply_hud_visibility()
	_apply_minimap_visibility()
