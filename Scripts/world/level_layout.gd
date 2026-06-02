extends RefCounted
class_name LevelLayout

# Datos de nivel construidos por el editor de mapas (rejilla + puertas).

var grid_width: int = 0
var grid_height: int = 0
var room_cells: Dictionary = {}
var exit_door_cell: Vector2i = Vector2i(-1, -1)
var exit_door_dir: String = ""
var player_spawn_cell: Vector2i = Vector2i(-1, -1)
var ai_spawn_cell: Vector2i = Vector2i(-1, -1)
var source_name: String = "editor"

var _door_specs: Array[Dictionary] = []


static func from_editor(
	rooms: Dictionary,
	door_specs: Array[Dictionary],
	exit_door: Dictionary,
	player_gp: Vector2i = Vector2i(-1, -1),
	ai_gp: Vector2i = Vector2i(-1, -1),
	label: String = "editor"
) -> LevelLayout:
	var layout: LevelLayout = LevelLayout.new()
	layout.apply_editor_data(rooms, door_specs, exit_door, player_gp, ai_gp, label)
	return layout


func apply_editor_data(
	rooms: Dictionary,
	door_specs: Array[Dictionary],
	exit_door: Dictionary,
	player_gp: Vector2i = Vector2i(-1, -1),
	ai_gp: Vector2i = Vector2i(-1, -1),
	label: String = "editor"
) -> void:
	_reset_state()
	source_name = label
	for key: Variant in rooms.keys():
		room_cells[key as Vector2i] = true
	_door_specs = _duplicate_door_specs(door_specs)
	_apply_exit_door(exit_door)
	if player_gp.x >= 0 and room_cells.has(player_gp):
		player_spawn_cell = player_gp
	if ai_gp.x >= 0 and room_cells.has(ai_gp):
		ai_spawn_cell = ai_gp
	if room_cells.is_empty():
		push_error("[LevelLayout] Sin habitaciones.")
		return
	_finalize_metadata(source_name)
	_validate_doors(source_name)
	_recompute_grid_bounds()


func build_passages() -> Dictionary:
	var passages: Dictionary = {}
	for spec: Dictionary in _door_specs:
		var cell: Vector2i = spec["cell"] as Vector2i
		var dir_str: String = String(spec["dir"])
		_link_passage(passages, cell, dir_str)
	return passages


func has_room(gp: Vector2i) -> bool:
	return room_cells.has(gp)


func get_exit_door_spec() -> Dictionary:
	if exit_door_cell.x < 0 or exit_door_dir.is_empty():
		return {}
	return {"cell": exit_door_cell, "dir": exit_door_dir}


func get_exit_door_room_cell() -> Vector2i:
	return exit_door_cell


func get_player_spawn_cell() -> Vector2i:
	if player_spawn_cell.x >= 0:
		return player_spawn_cell
	if exit_door_cell.x >= 0:
		return exit_door_cell
	return Vector2i(-1, -1)


func get_ai_spawn_cell() -> Vector2i:
	return ai_spawn_cell


func get_connectivity_start_cell() -> Vector2i:
	if player_spawn_cell.x >= 0 and room_cells.has(player_spawn_cell):
		return player_spawn_cell
	if exit_door_cell.x >= 0 and room_cells.has(exit_door_cell):
		return exit_door_cell
	for key: Variant in room_cells.keys():
		return key as Vector2i
	return Vector2i(-1, -1)


func find_unreachable_room_cells(from_cell: Vector2i = Vector2i(-1, -1)) -> Array[Vector2i]:
	if room_cells.is_empty():
		return []
	var start: Vector2i = from_cell
	if start.x < 0 or not room_cells.has(start):
		start = get_connectivity_start_cell()
	if start.x < 0:
		return []
	var adjacency: Dictionary = _build_room_adjacency()
	var reachable: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	reachable[start] = true
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front() as Vector2i
		if not adjacency.has(current):
			continue
		for nbr: Variant in adjacency[current] as Array:
			var neighbor: Vector2i = nbr as Vector2i
			if reachable.has(neighbor):
				continue
			reachable[neighbor] = true
			queue.append(neighbor)
	var unreachable: Array[Vector2i] = []
	for key: Variant in room_cells.keys():
		var gp: Vector2i = key as Vector2i
		if not reachable.has(gp):
			unreachable.append(gp)
	unreachable.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			if a.y != b.y:
				return a.y < b.y
			return a.x < b.x
	)
	return unreachable


func _reset_state() -> void:
	room_cells.clear()
	_door_specs.clear()
	exit_door_cell = Vector2i(-1, -1)
	exit_door_dir = ""
	player_spawn_cell = Vector2i(-1, -1)
	ai_spawn_cell = Vector2i(-1, -1)
	grid_width = 0
	grid_height = 0


func _apply_exit_door(exit_door: Dictionary) -> void:
	if exit_door.is_empty():
		return
	var cell: Vector2i = exit_door.get("cell", Vector2i(-1, -1)) as Vector2i
	var dir_str: String = String(exit_door.get("dir", "")).to_upper()
	if cell.x >= 0 and dir_str in ["N", "S", "E", "W"]:
		exit_door_cell = cell
		exit_door_dir = dir_str


func _duplicate_door_specs(specs: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for spec: Dictionary in specs:
		out.append({"cell": spec["cell"] as Vector2i, "dir": String(spec["dir"])})
	return out


func _register_door(cell: Vector2i, dir_str: String) -> void:
	for spec: Dictionary in _door_specs:
		if spec["cell"] == cell and String(spec["dir"]) == dir_str:
			return
	_door_specs.append({"cell": cell, "dir": dir_str})


func _validate_doors(name: String) -> void:
	var valid: Array[Dictionary] = []
	for spec: Dictionary in _door_specs:
		var cell: Vector2i = spec["cell"] as Vector2i
		var dir_str: String = String(spec["dir"])
		if not room_cells.has(cell):
			push_warning("[LevelLayout] Puerta en celda sin habitacion %s (%s)" % [cell, name])
			continue
		var nbr: Vector2i = cell + GridDirection.delta(dir_str)
		if not room_cells.has(nbr):
			push_warning("[LevelLayout] Puerta %s desde %s sin vecino (%s)" % [dir_str, cell, name])
			continue
		valid.append(spec)
	_door_specs = valid
	_validate_exit_door(name)


func _validate_exit_door(name: String) -> void:
	if exit_door_cell.x < 0 or exit_door_dir.is_empty():
		return
	if not room_cells.has(exit_door_cell):
		exit_door_cell = Vector2i(-1, -1)
		exit_door_dir = ""
		push_warning("[LevelLayout] Puerta de salida en celda invalida (%s)" % name)


func is_external_exit_door() -> bool:
	if exit_door_cell.x < 0 or exit_door_dir.is_empty():
		return false
	var nbr: Vector2i = exit_door_cell + GridDirection.delta(exit_door_dir)
	return not room_cells.has(nbr)


func _recompute_grid_bounds() -> void:
	var max_x: int = 0
	var max_y: int = 0
	for key: Variant in room_cells.keys():
		var gp: Vector2i = key as Vector2i
		max_x = maxi(max_x, gp.x)
		max_y = maxi(max_y, gp.y)
	grid_width = max_x + 1
	grid_height = max_y + 1


func _finalize_metadata(name: String) -> void:
	if exit_door_cell.x >= 0 and not exit_door_dir.is_empty():
		return
	push_warning("[LevelLayout] Sin puerta de salida en %s" % name)


func _link_passage(passages: Dictionary, from: Vector2i, dir_str: String) -> void:
	var to: Vector2i = from + GridDirection.delta(dir_str)
	if not room_cells.has(to):
		return
	var opp: String = GridDirection.opposite(dir_str)
	var from_dirs: Array[String] = _passage_dirs(passages, from)
	if dir_str not in from_dirs:
		from_dirs.append(dir_str)
		passages[from] = from_dirs
	var to_dirs: Array[String] = _passage_dirs(passages, to)
	if opp not in to_dirs:
		to_dirs.append(opp)
		passages[to] = to_dirs


func _passage_dirs(passages: Dictionary, gp: Vector2i) -> Array[String]:
	var dirs: Array[String] = []
	if not passages.has(gp):
		return dirs
	var raw: Array = passages[gp] as Array
	for entry: Variant in raw:
		dirs.append(String(entry))
	return dirs


func _build_room_adjacency() -> Dictionary:
	var adjacency: Dictionary = {}
	for spec: Dictionary in _door_specs:
		var cell: Vector2i = spec["cell"] as Vector2i
		var dir_str: String = String(spec["dir"])
		if not room_cells.has(cell):
			continue
		var neighbor: Vector2i = cell + GridDirection.delta(dir_str)
		if not room_cells.has(neighbor):
			continue
		_add_room_neighbor(adjacency, cell, neighbor)
		_add_room_neighbor(adjacency, neighbor, cell)
	return adjacency


func _add_room_neighbor(adjacency: Dictionary, from_cell: Vector2i, to_cell: Vector2i) -> void:
	if not adjacency.has(from_cell):
		adjacency[from_cell] = []
	var neighbors: Array = adjacency[from_cell] as Array
	if to_cell not in neighbors:
		neighbors.append(to_cell)
