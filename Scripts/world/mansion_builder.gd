class_name MansionBuilder
extends RefCounted

# Generación de rejilla, pasajes, contenido y actores de la mansión.

var mansion: Mansion = null


func _init(p_mansion: Mansion) -> void:
	mansion = p_mansion


func generate_grid(layout: LevelLayout) -> void:
	var spacing: int = DisplayConfig.ROOM_GRID_SPACING
	var passages: Dictionary = layout.build_passages()
	for r: int in mansion.grid_height:
		for c: int in mansion.grid_width:
			var gp: Vector2i = Vector2i(c, r)
			if not layout.has_room(gp):
				continue
			var room: Room = Mansion.RoomScene.instantiate() as Room
			room.grid_pos = gp
			_apply_passages_to_room(room, passages, layout)
			room.position = Vector2(c * spacing, r * spacing)
			mansion.add_child(room)
			mansion.rooms.append(room)
			mansion.room_grid[gp] = room
			room.spy_entered.connect(mansion._on_room_spy_entered.bind(room))
			room.spy_exited.connect(mansion._on_room_spy_exited.bind(room))


func wire_passages(layout: LevelLayout) -> void:
	for room: Room in mansion.rooms:
		var gp: Vector2i = room.grid_pos
		if room.has_door_n:
			var north: Room = mansion.room_grid.get(gp + Vector2i(0, -1)) as Room
			if north != null:
				room.register_passage("N", north, "S")
		if room.has_door_s:
			var south: Room = mansion.room_grid.get(gp + Vector2i(0, 1)) as Room
			if south != null:
				room.register_passage("S", south, "N")
		if room.has_door_w:
			var west: Room = mansion.room_grid.get(gp + Vector2i(-1, 0)) as Room
			if west != null:
				room.register_passage("W", west, "E")
		if room.has_door_e:
			var east: Room = mansion.room_grid.get(gp + Vector2i(1, 0)) as Room
			if east != null:
				room.register_passage("E", east, "W")
	_link_door_pairs()


func wire_external_exit_door(layout: LevelLayout) -> void:
	var spec: Dictionary = layout.get_exit_door_spec()
	if spec.is_empty() or not layout.is_external_exit_door():
		return
	var cell: Vector2i = spec["cell"] as Vector2i
	var dir_str: String = String(spec["dir"])
	var room: Room = mansion.get_room_at(cell)
	if room == null:
		return
	room.register_exit_passage(dir_str)


func mark_exit_door(layout: LevelLayout) -> void:
	mansion.exit_door = null
	mansion.exit_room = null
	var spec: Dictionary = layout.get_exit_door_spec()
	if spec.is_empty():
		return
	var cell: Vector2i = spec["cell"] as Vector2i
	var dir_str: String = String(spec["dir"])
	var room: Room = mansion.get_room_at(cell)
	if room == null:
		return
	var door: Door = room.get_door_for_direction(dir_str)
	if door == null:
		return
	door.is_exit_door = true
	if door.partner != null and is_instance_valid(door.partner):
		door.partner.is_exit_door = true
		door.partner.queue_redraw()
	mansion.exit_door = door
	mansion.exit_room = room
	door.queue_redraw()


func spawn_world_content() -> void:
	if DebugFlags.is_furniture_enabled():
		_spawn_furniture_and_items()
	elif DebugFlags.scatter_items_when_no_furniture:
		_scatter_items_on_floor()


func spawn_actors(layout: LevelLayout) -> void:
	var player_room: Room = _room_at_cell(layout.get_player_spawn_cell())
	if player_room == null:
		player_room = mansion.exit_room
	if player_room == null and not mansion.rooms.is_empty():
		player_room = mansion.rooms[0]
	mansion.player = Mansion.PlayerScene.instantiate() as Player
	mansion.player.position = player_room.get_center_world_pos()
	mansion.add_child(mansion.player)
	mansion.player.set_current_room(player_room)
	var ai_room: Room = _room_at_cell(layout.get_ai_spawn_cell())
	if ai_room == null:
		ai_room = MansionAiPaths.new(mansion).find_farthest_room(player_room)
	if ai_room == null:
		ai_room = mansion.rooms.back()
	if GameState.use_ai:
		mansion.ai_spy = Mansion.AiSpyScene.instantiate() as AiSpy
		mansion.ai_spy.position = ai_room.get_center_world_pos()
		mansion.add_child(mansion.ai_spy)
		mansion.ai_spy.set_current_room(ai_room)
		mansion.ai_spy.set_mansion(mansion)
		if not DebugFlags.is_ai_active():
			mansion.ai_spy.set_physics_process(false)
			mansion.ai_spy.visible = false
	else:
		mansion.player2 = Mansion.Player2Scene.instantiate() as Player2
		mansion.player2.position = ai_room.get_center_world_pos()
		mansion.add_child(mansion.player2)
		mansion.player2.set_current_room(ai_room)


func _apply_passages_to_room(room: Room, passages: Dictionary, layout: LevelLayout) -> void:
	var dirs: Array[String] = _passage_dirs(passages, room.grid_pos)
	var exit_spec: Dictionary = layout.get_exit_door_spec()
	if not exit_spec.is_empty() and (exit_spec["cell"] as Vector2i) == room.grid_pos:
		var exit_dir: String = String(exit_spec["dir"])
		if not dirs.has(exit_dir):
			dirs.append(exit_dir)
	room.has_door_n = dirs.has("N")
	room.has_door_s = dirs.has("S")
	room.has_door_w = dirs.has("W")
	room.has_door_e = dirs.has("E")


func _passage_dirs(passages: Dictionary, gp: Vector2i) -> Array[String]:
	var dirs: Array[String] = []
	if not passages.has(gp):
		return dirs
	var raw: Array = passages[gp] as Array
	for entry: Variant in raw:
		dirs.append(String(entry))
	return dirs


func _link_door_pairs() -> void:
	for room: Room in mansion.rooms:
		var gp: Vector2i = room.grid_pos
		_link_door_pair(room, "N", gp + Vector2i(0, -1), "S")
		_link_door_pair(room, "S", gp + Vector2i(0, 1), "N")
		_link_door_pair(room, "W", gp + Vector2i(-1, 0), "E")
		_link_door_pair(room, "E", gp + Vector2i(1, 0), "W")


func _link_door_pair(room: Room, dir: String, neighbor_gp: Vector2i, neighbor_dir: String) -> void:
	var neighbor: Room = mansion.room_grid.get(neighbor_gp) as Room
	if neighbor == null:
		return
	var door_a: Door = room.get_door_for_direction(dir)
	var door_b: Door = neighbor.get_door_for_direction(neighbor_dir)
	if door_a == null or door_b == null:
		return
	door_a.link_partner(door_b)
	door_b.link_partner(door_a)


func _spawn_furniture_and_items() -> void:
	for room: Room in mansion.rooms:
		var placements: Array[Dictionary] = FurniturePlacement.spawn_for_room(room)
		for entry: Dictionary in placements:
			var furn: Furniture = Mansion.FurnitureScene.instantiate() as Furniture
			furn.kind = int(entry["kind"])
			furn.position = entry["position"] as Vector2
			room.register_furniture(furn)
			mansion.all_furniture.append(furn)
	var items: Array[int] = ItemDB.get_all_items()
	var pool: Array[Furniture] = []
	pool.assign(mansion.all_furniture)
	pool.shuffle()
	for i: int in items.size():
		if i < pool.size():
			pool[i].hide_item(items[i])
	_spawn_weapon_boxes(mansion.rooms)


func _scatter_items_on_floor() -> void:
	var items: Array[int] = ItemDB.get_all_items()
	var pool_rooms: Array[Room] = []
	pool_rooms.assign(mansion.rooms)
	pool_rooms.shuffle()
	for i: int in items.size():
		if i >= pool_rooms.size():
			break
		var room: Room = pool_rooms[i]
		var dropped: DroppedItem = DroppedItem.new()
		dropped.item_id = items[i]
		dropped.position = RoomPerspective.floor_uv_to_pos(
			0.5, 0.55, room.get_room_w(), room.get_room_h()
		)
		room.add_child(dropped)
	_spawn_weapon_boxes(pool_rooms)


func _spawn_weapon_boxes(pool_rooms: Array[Room]) -> void:
	if pool_rooms.is_empty():
		return
	var shuffled: Array[Room] = []
	shuffled.assign(pool_rooms)
	shuffled.shuffle()
	var weapon_ids: Array[StringName] = [
		GameState.PLACEHOLDER_PISTOL_ID,
		GameState.MACHINE_GUN_ID,
		GameState.ORBITAL_CANNON_ID,
	]
	var weapon_rooms: Array[Room] = []
	for i: int in mini(shuffled.size(), weapon_ids.size()):
		weapon_rooms.append(shuffled[i])
	for i: int in weapon_rooms.size():
		var room: Room = weapon_rooms[i]
		var weapon_id: StringName = weapon_ids[i] if i < weapon_ids.size() else GameState.PLACEHOLDER_PISTOL_ID
		var used_positions: Array[Vector2] = []
		for furn_node: Node in room.furniture_list:
			if furn_node is Node2D:
				used_positions.append((furn_node as Node2D).position)
		var pos: Vector2 = FurniturePlacement.pick_position(
			room, ItemDB.FurnitureKind.WEAPON_BOX, used_positions
		)
		if pos == Vector2.INF:
			pos = RoomPerspective.floor_uv_to_pos(
				0.5, 0.55, room.get_room_w(), room.get_room_h()
			)
		var box: Furniture = Mansion.FurnitureScene.instantiate() as Furniture
		box.kind = ItemDB.FurnitureKind.WEAPON_BOX
		box.position = pos
		room.register_furniture(box)
		mansion.all_furniture.append(box)
		box.hide_weapon(weapon_id)


func _room_at_cell(gp: Vector2i) -> Room:
	if gp.x < 0:
		return null
	return mansion.room_grid.get(gp) as Room
