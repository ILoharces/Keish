extends Node

# Singleton con el estado global de la partida.
# - Reloj individual por espia (no se congela en menus ni muertes).
# - El maletin es prerequisito: sin el no se pueden recoger los otros 4 items.

signal time_changed(spy_id: int, value: float)
signal inventory_changed(spy_id: int)
signal traps_changed(spy_id: int)
signal game_over(winner_id: int)
signal exit_reached(spy_id: int)
signal suitcase_dropped(spy_id: int)
signal suitcase_recovered(spy_id: int)
signal suitcase_stolen(thief_id: int, victim_id: int)
signal weapons_changed(spy_id: int)
signal spy_died(victim_id: int, killer_id: int, trap_id: int)
signal respawn_started(spy_id: int, duration: float)
signal respawn_tick(spy_id: int, remaining: float)
signal respawn_finished(spy_id: int)

const WINNER_NONE: int = -1
const PLACEHOLDER_PISTOL_ID: StringName = &"placeholder_pistol"
const MACHINE_GUN_ID: StringName = &"machine_gun"
const ORBITAL_CANNON_ID: StringName = &"orbital_cannon"
const DEFAULT_MATCH_CONFIG: MatchConfig = preload("res://resources/match_config.tres")
const WINNER_TIMEOUT: int = -2

enum MatchEndReason {
	NONE,
	ESCAPE,
	TRAP,
	WEAPON,
	TIMEOUT,
}
const _DROPPED_SUITCASE_SCRIPT: GDScript = preload("res://Scripts/world/dropped_suitcase.gd")

var time_left_by_spy: Dictionary = {}
var winner: int = WINNER_NONE
var running: bool = false
var map_overlay_open: bool = false

var items_by_spy: Dictionary = {}
var weapons_by_spy: Dictionary = {}
var traps_by_spy: Dictionary = {}
var counters_by_spy: Dictionary = {}
var elimination_trap_id: int = -1
var elimination_killer_id: int = WINNER_NONE
var elimination_weapon_id: StringName = &""
var match_end_reason: MatchEndReason = MatchEndReason.NONE
var _dropped_suitcases: Dictionary = {}
var match_config: MatchConfig = DEFAULT_MATCH_CONFIG
## Si es false, el espia negro lo controla un segundo jugador local.
var use_ai: bool = true

var consecutive_deaths_without_kill: Dictionary = {}
var _respawn_remaining: Dictionary = {}
var _respawn_spy_refs: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_match()


func reset_match() -> void:
	winner = WINNER_NONE
	elimination_trap_id = -1
	elimination_killer_id = WINNER_NONE
	elimination_weapon_id = &""
	match_end_reason = MatchEndReason.NONE
	# use_ai se conserva entre reset_match y lo fijan los menus antes de iniciar.
	_clear_all_dropped_suitcases()
	_cancel_all_respawns()
	running = true
	map_overlay_open = false
	var spy_ids: Array[int] = [ItemDB.SpyId.PLAYER1, ItemDB.SpyId.PLAYER2]
	var duration: float = match_config.match_duration
	for spy_id: int in spy_ids:
		time_left_by_spy[spy_id] = duration
		consecutive_deaths_without_kill[spy_id] = 0
		var inv: Array[int] = []
		items_by_spy[spy_id] = inv
		weapons_by_spy[spy_id] = {}
		var traps: Dictionary = {}
		var counters: Dictionary = {}
		for trap_id: int in ItemDB.get_all_traps():
			traps[trap_id] = match_config.starting_traps_per_kind
		for counter_id: int in ItemDB.get_all_counters():
			counters[counter_id] = match_config.starting_counters_per_kind
		traps_by_spy[spy_id] = traps
		counters_by_spy[spy_id] = counters
		inventory_changed.emit(spy_id)
		weapons_changed.emit(spy_id)
		traps_changed.emit(spy_id)
		time_changed.emit(spy_id, duration)


func _process(delta: float) -> void:
	if not running:
		return
	_tick_respawns(delta)


func _tick_match_timers(delta: float) -> void:
	for spy_id: int in time_left_by_spy.keys():
		var current: float = float(time_left_by_spy[spy_id])
		if current <= 0.0:
			continue
		current = maxf(0.0, current - delta)
		time_left_by_spy[spy_id] = current
		time_changed.emit(spy_id, current)
		if current <= 0.0:
			_on_spy_timeout(spy_id)


func _on_spy_timeout(loser_id: int) -> void:
	_cancel_all_respawns()
	running = false
	match_end_reason = MatchEndReason.TIMEOUT
	for spy_id: int in time_left_by_spy.keys():
		if spy_id != loser_id:
			winner = spy_id
			game_over.emit(winner)
			return
	winner = WINNER_TIMEOUT
	game_over.emit(winner)


func get_time_left(spy_id: int) -> float:
	return float(time_left_by_spy.get(spy_id, 0.0))


func notify_spy_died(victim_id: int, killer_id: int, trap_id: int, weapon_id: StringName) -> void:
	if not running:
		return
	if killer_id == ItemDB.SpyId.PLAYER1 or killer_id == ItemDB.SpyId.PLAYER2:
		consecutive_deaths_without_kill[killer_id] = 0
	elimination_trap_id = trap_id
	elimination_killer_id = killer_id
	elimination_weapon_id = weapon_id
	if trap_id >= 0:
		match_end_reason = MatchEndReason.TRAP
	elif not weapon_id.is_empty():
		match_end_reason = MatchEndReason.WEAPON
	else:
		match_end_reason = MatchEndReason.NONE
	spy_died.emit(victim_id, killer_id, trap_id)


func start_respawn(spy: SpyBase) -> void:
	if not running or spy == null:
		return
	var spy_id: int = spy.spy_id
	var streak: int = int(consecutive_deaths_without_kill.get(spy_id, 0))
	var duration: float = (
		match_config.respawn_base_duration
		+ float(streak) * match_config.respawn_streak_increment
	)
	consecutive_deaths_without_kill[spy_id] = streak + 1
	_apply_time_penalty(spy_id, duration)
	if not running:
		return
	_respawn_remaining[spy_id] = duration
	_respawn_spy_refs[spy_id] = spy
	respawn_started.emit(spy_id, duration)
	respawn_tick.emit(spy_id, duration)


func _apply_time_penalty(spy_id: int, amount: float) -> void:
	if amount <= 0.0 or not time_left_by_spy.has(spy_id):
		return
	var current: float = float(time_left_by_spy[spy_id])
	current = maxf(0.0, current - amount)
	time_left_by_spy[spy_id] = current
	time_changed.emit(spy_id, current)
	if current <= 0.0:
		_on_spy_timeout(spy_id)


func _tick_respawns(delta: float) -> void:
	if _respawn_remaining.is_empty():
		return
	var finished: Array[int] = []
	for spy_id: int in _respawn_remaining.keys():
		var remaining: float = float(_respawn_remaining[spy_id]) - delta
		if remaining <= 0.0:
			finished.append(spy_id)
			continue
		_respawn_remaining[spy_id] = remaining
		respawn_tick.emit(spy_id, remaining)
	for spy_id: int in finished:
		_finish_respawn(spy_id)


func _finish_respawn(spy_id: int) -> void:
	var spy: SpyBase = _respawn_spy_refs.get(spy_id) as SpyBase
	_respawn_remaining.erase(spy_id)
	_respawn_spy_refs.erase(spy_id)
	respawn_finished.emit(spy_id)
	if not running or spy == null or not is_instance_valid(spy):
		return
	var mansion: Mansion = _get_mansion()
	if mansion != null:
		mansion.respawn_spy(spy)


func _get_mansion() -> Mansion:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var main: Main = tree.current_scene as Main
	if main == null or main.game_views == null:
		return null
	return main.game_views.mansion


func _clear_respawn_state() -> void:
	consecutive_deaths_without_kill.clear()
	_respawn_remaining.clear()
	_respawn_spy_refs.clear()


func _cancel_all_respawns() -> void:
	var pending: Array = _respawn_remaining.keys()
	_clear_respawn_state()
	for spy_id: Variant in pending:
		respawn_finished.emit(int(spy_id))


func drop_all_loot_on_death(spy: SpyBase) -> void:
	if spy == null or spy.current_room == null:
		return
	var room: Room = spy.current_room
	var world_pos: Vector2 = spy.global_position
	var spy_id: int = spy.spy_id
	if spy.held != null:
		if spy.held.is_holding_weapon():
			drop_weapon_from_hands(spy)
		elif spy.held.is_holding_carried():
			drop_carried_to_ground(spy_id, room, world_pos, spy.held)
		elif spy.held.is_holding_trap():
			spy.held.release_trap()
			spy.emit_held_changed()
		else:
			spy.held.clear()
	var inv: Array = items_by_spy.get(spy_id, []) as Array
	if not inv.is_empty():
		if has_suitcase(spy_id):
			_drop_suitcase_bundle(spy_id, room, world_pos)
		else:
			var stored: Array[int] = []
			for item_id: Variant in inv:
				stored.append(int(item_id))
			items_by_spy[spy_id] = []
			inventory_changed.emit(spy_id)
			for item_id: int in stored:
				spawn_dropped_item(room, world_pos, item_id)
	_clear_spy_trap_stock(spy_id)


func _clear_spy_trap_stock(spy_id: int) -> void:
	var traps: Dictionary = traps_by_spy.get(spy_id, {}) as Dictionary
	for trap_id: int in ItemDB.get_all_traps():
		traps[trap_id] = 0
	traps_by_spy[spy_id] = traps
	var counters: Dictionary = counters_by_spy.get(spy_id, {}) as Dictionary
	for counter_id: int in ItemDB.get_all_counters():
		counters[counter_id] = 0
	counters_by_spy[spy_id] = counters
	traps_changed.emit(spy_id)


func has_suitcase(spy_id: int) -> bool:
	var inv: Array = items_by_spy.get(spy_id, []) as Array
	return inv.has(ItemDB.ItemId.SUITCASE)


func drop_carried_to_ground(spy_id: int, room: Room, world_pos: Vector2, held: HeldInventory) -> bool:
	if room == null or held == null or not held.is_holding_carried():
		return false
	if held.is_holding_suitcase():
		var dropped: bool = _drop_suitcase_bundle(spy_id, room, world_pos)
		if dropped:
			held.clear()
		return dropped
	var item_id: int = held.held_id
	if not remove_item(spy_id, item_id):
		return false
	spawn_dropped_item(room, world_pos, item_id)
	held.clear()
	inventory_changed.emit(spy_id)
	return true


func _drop_suitcase_bundle(spy_id: int, room: Room, world_pos: Vector2) -> bool:
	var inv: Array = items_by_spy.get(spy_id, []) as Array
	if inv.is_empty():
		return false
	var stored: Array[int] = []
	for item_id: Variant in inv:
		stored.append(int(item_id))
	items_by_spy[spy_id] = []
	inventory_changed.emit(spy_id)
	var dropped: Area2D = _DROPPED_SUITCASE_SCRIPT.new() as Area2D
	dropped.call("setup", spy_id, stored)
	var local_offset: Vector2 = Vector2(randf_range(-16.0, 16.0), randf_range(-8.0, 16.0))
	dropped.position = world_pos - room.global_position + local_offset
	room.add_child(dropped)
	_dropped_suitcases[spy_id] = dropped
	suitcase_dropped.emit(spy_id)
	return true


func spawn_dropped_item(room: Room, world_pos: Vector2, item_id: int) -> void:
	var dropped: DroppedItem = DroppedItem.new()
	dropped.item_id = item_id
	var local_offset: Vector2 = Vector2(randf_range(-16.0, 16.0), randf_range(-8.0, 16.0))
	dropped.position = world_pos - room.global_position + local_offset
	room.add_child(dropped)


func get_equipped_ammo_label(spy: SpyBase, weapon_id: StringName) -> String:
	if spy == null or weapon_id.is_empty() or spy.held == null:
		return ""
	if not spy.held.is_holding_weapon() or spy.held.get_weapon_id() != weapon_id:
		return ""
	var weapon: WeaponData = WeaponDB.get_weapon(weapon_id)
	if weapon == null:
		return ""
	if not weapon.uses_ammo:
		return "BAL: inf"
	return "BAL: %d" % spy.held.get_weapon_ammo()


func has_weapon(spy: SpyBase, weapon_id: StringName) -> bool:
	if spy == null or spy.held == null or weapon_id.is_empty():
		return false
	if not spy.held.is_holding_weapon() or spy.held.get_weapon_id() != weapon_id:
		return false
	return spy.held.has_weapon_ammo()


func consume_weapon_ammo(spy: SpyBase, weapon_id: StringName) -> bool:
	if spy == null or spy.held == null:
		return false
	if not spy.held.is_holding_weapon() or spy.held.get_weapon_id() != weapon_id:
		return false
	if not spy.held.consume_weapon_ammo():
		return false
	weapons_changed.emit(spy.spy_id)
	return true


func spawn_dropped_weapon(
	room: Room,
	world_pos: Vector2,
	weapon_id: StringName,
	ammo: int = -1,
) -> void:
	var dropped: DroppedWeapon = DroppedWeapon.new()
	dropped.weapon_id = weapon_id
	dropped.ammo_count = ammo
	var local_offset: Vector2 = Vector2(randf_range(-16.0, 16.0), randf_range(-8.0, 16.0))
	dropped.position = world_pos - room.global_position + local_offset
	room.add_child(dropped)


func drop_weapon_from_hands(spy: SpyBase) -> bool:
	if spy == null or spy.held == null or spy.current_room == null:
		return false
	if not spy.held.is_holding_weapon():
		return false
	var weapon_id: StringName = spy.held.get_weapon_id()
	var ammo: int = spy.held.get_weapon_ammo()
	spawn_dropped_weapon(spy.current_room, spy.global_position, weapon_id, ammo)
	if spy.combat != null:
		spy.combat.clear_equipped_weapon()
	spy.held.clear()
	spy.emit_held_changed()
	weapons_changed.emit(spy.spy_id)
	return true


func try_pickup_weapon_in_hands(spy: SpyBase, weapon_id: StringName, ammo: int = -1) -> bool:
	if spy == null or spy.held == null or weapon_id.is_empty():
		return false
	if WeaponDB.get_weapon(weapon_id) == null:
		return false
	if spy.current_room == null:
		return false
	if spy.held.is_holding_weapon() and spy.held.get_weapon_id() == weapon_id:
		_sync_orbital_targeting(spy)
		spy.emit_weapon_changed()
		return true
	if not _clear_hands_for_weapon_pickup(spy):
		return false
	spy.held.set_weapon(weapon_id, ammo)
	spy.emit_held_changed()
	spy.emit_weapon_changed()
	_sync_orbital_targeting(spy)
	weapons_changed.emit(spy.spy_id)
	return true


func _clear_hands_for_weapon_pickup(spy: SpyBase) -> bool:
	if spy.held.is_holding_weapon():
		if not drop_weapon_from_hands(spy):
			return false
	if spy.held.is_holding_trap():
		spy.held.release_trap()
		spy.emit_held_changed()
	if spy.held.is_holding_carried():
		if not drop_carried_to_ground(spy.spy_id, spy.current_room, spy.global_position, spy.held):
			return false
	return true


func try_pickup_ground(spy: SpyBase, node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node.is_in_group("dropped_weapon"):
		var dropped_weapon: DroppedWeapon = node as DroppedWeapon
		if dropped_weapon == null or dropped_weapon.weapon_id.is_empty():
			return false
		var ammo: int = dropped_weapon.ammo_count
		if not try_pickup_weapon_in_hands(spy, dropped_weapon.weapon_id, ammo):
			return false
		dropped_weapon.queue_free()
		return true
	if node.is_in_group("dropped_item"):
		var dropped_item: DroppedItem = node as DroppedItem
		if dropped_item == null or dropped_item.item_id < 0:
			return false
		if not add_item(spy.spy_id, dropped_item.item_id):
			return false
		dropped_item.queue_free()
		if spy.held != null and spy.held.is_holding_weapon():
			drop_weapon_from_hands(spy)
		inventory_changed.emit(spy.spy_id)
		return true
	if node.is_in_group("dropped_suitcase"):
		return try_pickup_dropped_suitcase(spy, node as Area2D)
	return false


func try_pickup_dropped_suitcase(spy: SpyBase, dropped: Area2D) -> bool:
	if dropped == null or not is_instance_valid(dropped):
		return false
	var owner_id: int = int(dropped.get("owner_spy_id"))
	if not _dropped_suitcases.has(owner_id) or _dropped_suitcases[owner_id] != dropped:
		return false
	var picker_id: int = spy.spy_id
	var stored: Array[int] = (dropped.get("stored_items") as Array).duplicate()
	_dropped_suitcases.erase(owner_id)
	if picker_id == owner_id:
		_restore_items_to_spy(picker_id, stored)
		suitcase_recovered.emit(picker_id)
	else:
		_steal_items_from_suitcase(picker_id, stored)
		suitcase_stolen.emit(picker_id, owner_id)
		inventory_changed.emit(owner_id)
	if spy.held != null and spy.held.is_holding_weapon():
		drop_weapon_from_hands(spy)
	dropped.queue_free()
	return true


func _restore_items_to_spy(spy_id: int, stored: Array[int]) -> void:
	var inv: Array = items_by_spy.get(spy_id, []) as Array
	for item_id: int in stored:
		if not inv.has(item_id):
			inv.append(item_id)
	items_by_spy[spy_id] = inv
	inventory_changed.emit(spy_id)


func _steal_items_from_suitcase(thief_id: int, stored: Array[int]) -> void:
	var inv: Array = items_by_spy[thief_id] as Array
	for item_id: int in stored:
		if not inv.has(item_id):
			inv.append(item_id)
	items_by_spy[thief_id] = inv
	inventory_changed.emit(thief_id)


func _clear_all_dropped_suitcases() -> void:
	for spy_id: Variant in _dropped_suitcases.keys():
		var node: Variant = _dropped_suitcases[spy_id]
		if node is Node and is_instance_valid(node):
			(node as Node).queue_free()
	_dropped_suitcases.clear()


func remove_item(spy_id: int, item_id: int) -> bool:
	var inv: Array = items_by_spy.get(spy_id, []) as Array
	var idx: int = inv.find(item_id)
	if idx < 0:
		return false
	inv.remove_at(idx)
	items_by_spy[spy_id] = inv
	inventory_changed.emit(spy_id)
	return true


func add_item(spy_id: int, item_id: int) -> bool:
	var inv: Array = items_by_spy[spy_id] as Array
	if inv.has(item_id):
		return false
	inv.append(item_id)
	inventory_changed.emit(spy_id)
	return true


func remove_random_item(spy_id: int) -> int:
	var inv: Array = items_by_spy[spy_id] as Array
	if inv.is_empty():
		return -1
	var idx: int = randi() % inv.size()
	var item_id: int = int(inv[idx])
	inv.remove_at(idx)
	inventory_changed.emit(spy_id)
	return item_id


func has_all_items(spy_id: int) -> bool:
	var inv: Array = items_by_spy[spy_id] as Array
	return inv.size() >= ItemDB.ITEM_COUNT


func get_items(spy_id: int) -> Array:
	return items_by_spy[spy_id] as Array


func add_trap(spy_id: int, trap_id: int, amount: int = 1) -> void:
	var traps: Dictionary = traps_by_spy[spy_id] as Dictionary
	traps[trap_id] = int(traps.get(trap_id, 0)) + amount
	traps_changed.emit(spy_id)


func consume_trap(spy_id: int, trap_id: int) -> bool:
	if match_config.traps_infinite:
		return true
	var traps: Dictionary = traps_by_spy[spy_id] as Dictionary
	var current: int = int(traps.get(trap_id, 0))
	if current <= 0:
		return false
	traps[trap_id] = current - 1
	traps_changed.emit(spy_id)
	return true


func get_trap_count(spy_id: int, trap_id: int) -> int:
	if match_config.traps_infinite:
		return 99
	var traps: Dictionary = traps_by_spy[spy_id] as Dictionary
	return int(traps.get(trap_id, 0))


func add_counter(spy_id: int, counter_id: int, amount: int = 1) -> void:
	var counters: Dictionary = counters_by_spy[spy_id] as Dictionary
	counters[counter_id] = int(counters.get(counter_id, 0)) + amount
	traps_changed.emit(spy_id)


func consume_counter(spy_id: int, counter_id: int) -> bool:
	var counters: Dictionary = counters_by_spy[spy_id] as Dictionary
	var current: int = int(counters.get(counter_id, 0))
	if current <= 0:
		return false
	counters[counter_id] = current - 1
	traps_changed.emit(spy_id)
	return true


func get_counter_count(spy_id: int, counter_id: int) -> int:
	var counters: Dictionary = counters_by_spy[spy_id] as Dictionary
	return int(counters.get(counter_id, 0))


func equip_weapon_in_hands(spy: SpyBase, weapon_id: StringName) -> bool:
	return try_pickup_weapon_in_hands(spy, weapon_id, -1)


func _sync_orbital_targeting(spy: SpyBase) -> void:
	if spy == null:
		return
	spy.set_orbital_targeting(false)


func notify_exit_reached(spy_id: int) -> void:
	if not running:
		return
	if has_all_items(spy_id):
		_cancel_all_respawns()
		running = false
		match_end_reason = MatchEndReason.ESCAPE
		elimination_trap_id = -1
		elimination_killer_id = WINNER_NONE
		elimination_weapon_id = &""
		winner = spy_id
		game_over.emit(winner)
	else:
		exit_reached.emit(spy_id)
