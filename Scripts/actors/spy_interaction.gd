class_name SpyInteraction
extends RefCounted

# Muebles, pickups, maletín y colocación de trampas.

var host: SpyBase = null


func _init(p_host: SpyBase) -> void:
	host = p_host


func interact_with_nearby() -> bool:
	if not host.is_alive or host.is_stunned() or host.is_searching() or host.orbital_targeting:
		return false
	if host.nearby_door != null and is_instance_valid(host.nearby_door):
		host.nearby_door.try_toggle_for_spy(host.spy_id)
		return true
	var pickup: Node = _find_ground_pickup_target()
	if pickup != null:
		host.nearby_pickup = pickup
		if _try_pickup_nearby_ground():
			return true
	return false


func try_place_trap(trap_id: int) -> bool:
	if not host.is_alive or host.is_stunned() or host.is_searching():
		return false
	if not prepare_hands_for_trap(trap_id):
		return false
	if host.nearby_furniture == null:
		return false
	if not host.nearby_furniture.is_raised_open() or not host.nearby_furniture.is_empty():
		return false
	var success: bool = host.nearby_furniture.set_trap(trap_id, host.spy_id)
	if success:
		host.open_furniture = null
		GameState.consume_trap(host.spy_id, trap_id)
		if host.held != null:
			host.held.release_trap()
			_refresh_hands_from_inventory()
	return success


func drop_item_in_room(item_id: int) -> void:
	if host.current_room == null:
		return
	GameState.spawn_dropped_item(host.current_room, host.global_position, item_id)
	_refresh_hands_from_inventory()


func close_furniture(furn: Furniture) -> void:
	if furn == null or not is_instance_valid(furn):
		return
	furn.lower_close()
	if host.open_furniture == furn:
		host.open_furniture = null


func close_open_furniture() -> void:
	if host.open_furniture != null:
		close_furniture(host.open_furniture)


func cancel_search() -> void:
	host.search_timer = 0.0
	host.searching_furniture = null
	host.search_progress_bg.visible = false
	host.search_progress.visible = false


func refresh_hands_from_inventory() -> void:
	_refresh_hands_from_inventory()


func _find_ground_pickup_target() -> Node:
	var best: Node = null
	var best_dist: float = SpyBase.PROBE_RADIUS
	if host.nearby_pickup != null and is_instance_valid(host.nearby_pickup):
		var cached_dist: float = host.global_position.distance_to(host.nearby_pickup.global_position)
		if cached_dist <= SpyBase.PROBE_RADIUS:
			best = host.nearby_pickup
			best_dist = cached_dist
	if host.current_room == null:
		return best
	for child: Node in host.current_room.get_children():
		if not child.is_in_group("ground_pickup"):
			continue
		var dist: float = host.global_position.distance_to(child.global_position)
		if dist > SpyBase.PROBE_RADIUS:
			continue
		if best == null or dist < best_dist:
			best = child
			best_dist = dist
	return best


func _try_pickup_nearby_ground() -> bool:
	if host.nearby_pickup == null or not is_instance_valid(host.nearby_pickup):
		return false
	if GameState.try_pickup_ground(host, host.nearby_pickup):
		_refresh_hands_from_inventory()
		return true
	return false


func _resolve_furniture_interaction(furn: Furniture) -> void:
	if furn == null or not is_instance_valid(furn):
		return
	var result: Dictionary = furn.interact(host)
	if int(result["item_found"]) != -1:
		var item_id: int = int(result["item_found"])
		var added: bool = GameState.add_item(host.spy_id, item_id)
		if added:
			_on_item_added_to_inventory()
		elif item_id != ItemDB.ItemId.SUITCASE:
			drop_item_in_room(item_id)
	var weapon_found: StringName = result.get("weapon_found", &"") as StringName
	if not weapon_found.is_empty():
		GameState.try_pickup_weapon_in_hands(host, weapon_found)
	if int(result["trap_triggered"]) != -1:
		host.combat.apply_trap_effect(int(result["trap_triggered"]), furn.global_position)
	if bool(result.get("should_close", false)):
		close_furniture(furn)


func prepare_hands_for_trap(trap_id: int) -> bool:
	if host.held == null:
		return false
	if host.held.is_holding_trap():
		if host.held.get_trap_id() == trap_id:
			return true
		host.held.set_trap(trap_id)
		host.emit_held_changed()
		return true
	if host.held.is_holding_weapon():
		if not GameState.drop_weapon_from_hands(host):
			return false
	if host.held.is_holding_carried():
		if host.current_room == null:
			return false
		if not GameState.drop_carried_to_ground(host.spy_id, host.current_room, host.global_position, host.held):
			return false
	host.held.set_trap(trap_id)
	host.emit_held_changed()
	return true


func _on_item_added_to_inventory() -> void:
	if host.held != null and host.held.is_holding_weapon():
		GameState.drop_weapon_from_hands(host)
	_refresh_hands_from_inventory()


func _refresh_hands_from_inventory() -> void:
	if host.held == null or host.held.is_holding_trap() or host.held.is_holding_weapon():
		return
	if host.held.sync_carried_from_inventory(host.spy_id):
		host.emit_held_changed()
	else:
		host.queue_redraw()
