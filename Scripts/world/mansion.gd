extends Node2D
class_name Mansion

# Mansion generada desde LevelLayout (creador de mapas en el juego).

signal player_room_changed(room: Room)
signal ai_room_changed(room: Room)

const RoomScene: PackedScene = preload("res://Scenes/world/room.tscn")
const FurnitureScene: PackedScene = preload("res://Scenes/world/furniture.tscn")
const PlayerScene: PackedScene = preload("res://Scenes/actors/player.tscn")
const Player2Scene: PackedScene = preload("res://Scenes/actors/player2.tscn")
const AiSpyScene: PackedScene = preload("res://Scenes/actors/ai_spy.tscn")

var grid_width: int = 0
var grid_height: int = 0
var rooms: Array[Room] = []
var room_grid: Dictionary = {}
var exit_door: Door = null
var exit_room: Room = null
var player: Player = null
var player2: Player2 = null
var ai_spy: AiSpy = null
var all_furniture: Array[Furniture] = []

var _layout: LevelLayout = null
var _level_active: bool = false
var _ai_paths: MansionAiPaths = null


func _ready() -> void:
	pass


func shutdown() -> void:
	if _level_active:
		_clear_level()


func rebuild_all_room_geometry() -> void:
	for room: Room in rooms:
		if is_instance_valid(room):
			room.rebuild_geometry()


func begin_with_layout(layout: LevelLayout) -> void:
	if _level_active:
		_clear_level()
	if layout == null:
		push_error("[Mansion] LevelLayout nulo.")
		return
	_layout = layout
	DisplayConfig.sync_to_window()
	randomize()
	grid_width = _layout.grid_width
	grid_height = _layout.grid_height
	var builder: MansionBuilder = MansionBuilder.new(self)
	builder.generate_grid(_layout)
	builder.wire_passages(_layout)
	builder.wire_external_exit_door(_layout)
	builder.mark_exit_door(_layout)
	builder.spawn_world_content()
	builder.spawn_actors(_layout)
	_ai_paths = MansionAiPaths.new(self)
	_level_active = true


func notify_room_size_changed() -> void:
	if not _level_active:
		return
	rebuild_all_room_geometry()
	_reposition_spies_in_rooms()


func _reposition_spies_in_rooms() -> void:
	if player != null and is_instance_valid(player) and player.current_room != null:
		player.global_position = player.current_room.get_center_world_pos()
	var bottom_spy: SpyBase = get_bottom_spy()
	if bottom_spy != null and is_instance_valid(bottom_spy) and bottom_spy.current_room != null:
		bottom_spy.global_position = bottom_spy.current_room.get_center_world_pos()


func _clear_level() -> void:
	for room: Room in rooms:
		if is_instance_valid(room):
			room.queue_free()
	rooms.clear()
	room_grid.clear()
	all_furniture.clear()
	exit_door = null
	exit_room = null
	if player != null and is_instance_valid(player):
		player.queue_free()
	player = null
	if player2 != null and is_instance_valid(player2):
		player2.queue_free()
	player2 = null
	if ai_spy != null and is_instance_valid(ai_spy):
		ai_spy.queue_free()
	ai_spy = null
	_layout = null
	_ai_paths = null
	grid_width = 0
	grid_height = 0
	_level_active = false


func get_room_at(gp: Vector2i) -> Room:
	return room_grid.get(gp) as Room


func _on_room_spy_entered(spy: Node, room: Room) -> void:
	var spy_base: SpyBase = spy as SpyBase
	if spy_base == null:
		return
	spy_base.set_current_room(room)
	if spy_base == player:
		player_room_changed.emit(room)
	elif spy_base == ai_spy or spy_base == player2:
		ai_room_changed.emit(room)


func get_bottom_spy() -> SpyBase:
	if player2 != null:
		return player2
	return ai_spy


func _on_room_spy_exited(_spy: Node, _room: Room) -> void:
	pass


func get_exit_door_spec() -> Dictionary:
	if _layout == null:
		return {}
	return _layout.get_exit_door_spec()


func get_exit_door() -> Door:
	return exit_door


func get_exit_door_direction() -> String:
	if _layout == null:
		return ""
	return String(_layout.get_exit_door_spec().get("dir", ""))


func get_exit_room() -> Room:
	return exit_room


func pick_next_search_room(spy: AiSpy) -> Room:
	if _ai_paths == null:
		return null
	return _ai_paths.pick_next_search_room(spy)


func next_direction(from_room: Room, to_room: Room) -> String:
	if _ai_paths == null:
		return ""
	return _ai_paths.next_direction(from_room, to_room)


func get_opponent_for(spy: SpyBase) -> SpyBase:
	if spy == null:
		return null
	if spy == player:
		return get_bottom_spy()
	if spy == player2 or spy == ai_spy:
		return player
	return null


func pick_random_room_excluding(exclude: Room) -> Room:
	if rooms.is_empty():
		return null
	var pool: Array[Room] = []
	for room: Room in rooms:
		if room != exclude:
			pool.append(room)
	if pool.is_empty():
		return exclude if exclude != null and rooms.has(exclude) else rooms[0]
	return pool[randi() % pool.size()]


func respawn_spy(spy: SpyBase) -> void:
	if spy == null or not is_instance_valid(spy) or not _level_active:
		return
	var opponent: SpyBase = get_opponent_for(spy)
	var exclude_room: Room = opponent.current_room if opponent != null else null
	var room: Room = pick_random_room_excluding(exclude_room)
	if room == null:
		return
	spy.respawn_in_room(room)
	if spy == player:
		player_room_changed.emit(room)
	elif spy == get_bottom_spy():
		ai_room_changed.emit(room)
	var main: Main = get_tree().current_scene as Main
	if main != null and main.game_views != null:
		main.game_views.follow_cameras.call_deferred(GameState.running)
