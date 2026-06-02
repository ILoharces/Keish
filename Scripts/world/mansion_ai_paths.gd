class_name MansionAiPaths
extends RefCounted

# Pathfinding y selección de habitaciones para la IA.


var mansion: Mansion = null


func _init(p_mansion: Mansion) -> void:
	mansion = p_mansion


func pick_next_search_room(spy: AiSpy) -> Room:
	if mansion.rooms.is_empty():
		return null
	var visited: Dictionary = spy.rooms_visited
	var candidates: Array[Room] = []
	for room: Room in mansion.rooms:
		if room == spy.current_room:
			continue
		if not visited.has(room.get_instance_id()):
			candidates.append(room)
	if candidates.is_empty():
		spy.rooms_visited.clear()
		candidates.assign(mansion.rooms)
		candidates.erase(spy.current_room)
		if candidates.is_empty():
			return mansion.rooms[0]
	return candidates[randi() % candidates.size()]


func next_direction(from_room: Room, to_room: Room) -> String:
	if from_room == null or to_room == null or from_room == to_room:
		return ""
	var queue: Array[Room] = []
	queue.append(from_room)
	var came_from: Dictionary = {from_room: null}
	var first_dir: Dictionary = {from_room: ""}
	var directions: Array[String] = ["N", "E", "S", "W"]
	while not queue.is_empty():
		var current: Room = queue.pop_front() as Room
		if current == to_room:
			return String(first_dir[current])
		for dir_str: String in directions:
			var nbr: Room = _neighbor(current, dir_str)
			if nbr == null:
				continue
			if came_from.has(nbr):
				continue
			came_from[nbr] = current
			if current == from_room:
				first_dir[nbr] = dir_str
			else:
				first_dir[nbr] = first_dir[current]
			queue.append(nbr)
	return ""


func find_farthest_room(start: Room) -> Room:
	if start == null:
		return null
	var best: Room = start
	var best_dist: int = 0
	var queue: Array[Room] = [start]
	var dist: Dictionary = {start: 0}
	while not queue.is_empty():
		var current: Room = queue.pop_front() as Room
		for dir_str: String in ["N", "E", "S", "W"]:
			var nbr: Room = _neighbor(current, dir_str)
			if nbr == null or dist.has(nbr):
				continue
			var steps: int = int(dist[current]) + 1
			dist[nbr] = steps
			queue.append(nbr)
			if steps > best_dist:
				best_dist = steps
				best = nbr
	return best


func _neighbor(room: Room, dir_str: String) -> Room:
	if not _room_has_passage(room, dir_str):
		return null
	var nbr: Room = mansion.room_grid.get(room.grid_pos + GridDirection.delta(dir_str)) as Room
	if nbr == null:
		return null
	var opp: String = GridDirection.opposite(dir_str)
	return nbr if _room_has_passage(nbr, opp) else null


func _room_has_passage(room: Room, dir_str: String) -> bool:
	match dir_str:
		"N":
			return room.has_door_n
		"S":
			return room.has_door_s
		"W":
			return room.has_door_w
		"E":
			return room.has_door_e
	return false
