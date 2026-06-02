extends Player
class_name Player2

# Jugador local 2 (espia negro): flechas + I/O/K/L.


func _ready() -> void:
	super._ready()
	add_to_group("player2")


func get_aim_controller_spy_id() -> int:
	return ItemDB.SpyId.AI


func _get_fire_action() -> String:
	return "p2_fire_weapon"


func _compute_input_vector() -> Vector2:
	if not is_alive or input_blocked or not GameState.running or GameState.map_overlay_open:
		return Vector2.ZERO
	return Input.get_vector("p2_move_left", "p2_move_right", "p2_move_up", "p2_move_down")


func _unhandled_input(event: InputEvent) -> void:
	if not is_alive or input_blocked or not GameState.running or GameState.map_overlay_open:
		return
	if orbital_targeting:
		return
	if event.is_action_pressed("p2_interact"):
		interact_with_nearby()
	elif event.is_action_pressed("p2_place_trap"):
		var trap_id: int = held.get_trap_id() if held != null else -1
		if trap_id >= 0:
			try_place_trap(trap_id)
	elif event.is_action_pressed("p2_next_trap"):
		_cycle_held_trap()
