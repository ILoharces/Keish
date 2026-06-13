class_name MapEditorGridInput
extends RefCounted

# Entrada de ratón, mando y teclado en el editor de mapas.


static func handle_gamepad_action(grid: MapEditorGrid, gp: Vector2i, edge_dir: Vector2i) -> void:
	if gp.x < 0 or gp.y < 0 or gp.x >= grid.grid_cols or gp.y >= grid.grid_rows:
		return
	match grid.place_mode:
		MapEditorGrid.PlaceMode.EXIT:
			_handle_exit_action(grid, gp, edge_dir)
		MapEditorGrid.PlaceMode.BUILD:
			_handle_build_action(grid, gp, edge_dir)
		MapEditorGrid.PlaceMode.PLAYER1:
			if grid.has_room(gp):
				grid.set_player_spawn(gp)
		MapEditorGrid.PlaceMode.PLAYER2:
			if grid.has_room(gp):
				grid.set_ai_spawn(gp)


static func handle_click(grid: MapEditorGrid, local_pos: Vector2) -> void:
	if local_pos.x < 0.0 or local_pos.y < 0.0:
		return
	if grid.place_mode == MapEditorGrid.PlaceMode.EXIT:
		var edge: Dictionary = pick_exit_edge(grid, local_pos)
		if edge.is_empty():
			edge = pick_shared_edge(grid, local_pos)
		if edge.size() > 0:
			grid.toggle_exit_door(edge["cell"] as Vector2i, String(edge["dir"]))
		return
	if grid.place_mode == MapEditorGrid.PlaceMode.BUILD:
		var passage: Dictionary = pick_shared_edge(grid, local_pos)
		if passage.size() > 0:
			grid.toggle_passage(passage["cell"] as Vector2i, String(passage["dir"]))
			return
	var col: int = int(local_pos.x / float(MapEditorGrid.CELL_SIZE))
	var row: int = int(local_pos.y / float(MapEditorGrid.CELL_SIZE))
	if col < 0 or row < 0 or col >= grid.grid_cols or row >= grid.grid_rows:
		return
	var gp: Vector2i = Vector2i(col, row)
	match grid.place_mode:
		MapEditorGrid.PlaceMode.PLAYER1:
			if grid.has_room(gp):
				grid.set_player_spawn(gp)
		MapEditorGrid.PlaceMode.PLAYER2:
			if grid.has_room(gp):
				grid.set_ai_spawn(gp)
		_:
			grid.toggle_room(gp)


static func pick_shared_edge(grid: MapEditorGrid, local_pos: Vector2) -> Dictionary:
	var col: int = int(local_pos.x / float(MapEditorGrid.CELL_SIZE))
	var row: int = int(local_pos.y / float(MapEditorGrid.CELL_SIZE))
	if col < 0 or row < 0 or col >= grid.grid_cols or row >= grid.grid_rows:
		return {}
	var in_cell: Vector2 = local_pos - Vector2(float(col * MapEditorGrid.CELL_SIZE), float(row * MapEditorGrid.CELL_SIZE))
	var band: float = float(MapEditorGrid.CELL_SIZE) * MapEditorGrid.EDGE_BAND_RATIO
	var best_dist: float = INF
	var best: Dictionary = {}
	var checks: Array[Dictionary] = [
		{
			"dist": in_cell.x,
			"valid": col > 0 and in_cell.x < band,
			"left": Vector2i(col - 1, row),
			"right": Vector2i(col, row),
			"dir": "E",
		},
		{
			"dist": float(MapEditorGrid.CELL_SIZE) - in_cell.x,
			"valid": col < grid.grid_cols - 1 and in_cell.x > float(MapEditorGrid.CELL_SIZE) - band,
			"left": Vector2i(col, row),
			"right": Vector2i(col + 1, row),
			"dir": "E",
		},
		{
			"dist": in_cell.y,
			"valid": row > 0 and in_cell.y < band,
			"left": Vector2i(col, row - 1),
			"right": Vector2i(col, row),
			"dir": "S",
		},
		{
			"dist": float(MapEditorGrid.CELL_SIZE) - in_cell.y,
			"valid": row < grid.grid_rows - 1 and in_cell.y > float(MapEditorGrid.CELL_SIZE) - band,
			"left": Vector2i(col, row),
			"right": Vector2i(col, row + 1),
			"dir": "S",
		},
	]
	for check: Dictionary in checks:
		if not bool(check["valid"]):
			continue
		var left: Vector2i = check["left"] as Vector2i
		var right: Vector2i = check["right"] as Vector2i
		if not grid.has_room(left) or not grid.has_room(right):
			continue
		var dist: float = float(check["dist"])
		if dist < best_dist:
			best_dist = dist
			best = grid.canonical_passage(left, String(check["dir"]))
	return best


static func pick_exit_edge(grid: MapEditorGrid, local_pos: Vector2) -> Dictionary:
	var col: int = int(local_pos.x / float(MapEditorGrid.CELL_SIZE))
	var row: int = int(local_pos.y / float(MapEditorGrid.CELL_SIZE))
	if col < 0 or row < 0 or col >= grid.grid_cols or row >= grid.grid_rows:
		return {}
	var in_cell: Vector2 = local_pos - Vector2(float(col * MapEditorGrid.CELL_SIZE), float(row * MapEditorGrid.CELL_SIZE))
	var band: float = float(MapEditorGrid.CELL_SIZE) * MapEditorGrid.EDGE_BAND_RATIO
	var best_dist: float = INF
	var best: Dictionary = {}
	var gp: Vector2i = Vector2i(col, row)
	var checks: Array[Dictionary] = [
		{"dist": in_cell.x, "valid": in_cell.x < band, "cell": gp, "dir": "W", "nbr": gp + Vector2i(-1, 0)},
		{
			"dist": float(MapEditorGrid.CELL_SIZE) - in_cell.x,
			"valid": in_cell.x > float(MapEditorGrid.CELL_SIZE) - band,
			"cell": gp,
			"dir": "E",
			"nbr": gp + Vector2i(1, 0),
		},
		{"dist": in_cell.y, "valid": in_cell.y < band, "cell": gp, "dir": "N", "nbr": gp + Vector2i(0, -1)},
		{
			"dist": float(MapEditorGrid.CELL_SIZE) - in_cell.y,
			"valid": in_cell.y > float(MapEditorGrid.CELL_SIZE) - band,
			"cell": gp,
			"dir": "S",
			"nbr": gp + Vector2i(0, 1),
		},
	]
	for check: Dictionary in checks:
		if not bool(check["valid"]):
			continue
		var cell: Vector2i = check["cell"] as Vector2i
		if not grid.has_room(cell):
			continue
		var nbr: Vector2i = check["nbr"] as Vector2i
		if grid.has_room(nbr):
			continue
		var dist: float = float(check["dist"])
		if dist < best_dist:
			best_dist = dist
			best = {"cell": cell, "dir": String(check["dir"])}
	return best


static func _handle_build_action(grid: MapEditorGrid, gp: Vector2i, edge_dir: Vector2i) -> void:
	if edge_dir != Vector2i.ZERO:
		var dir_str: String = _delta_to_dir(edge_dir)
		if not dir_str.is_empty():
			var neighbor: Vector2i = gp + GridDirection.delta(dir_str)
			if grid.has_room(gp) and grid.has_room(neighbor):
				grid.toggle_passage(gp, dir_str)
				return
	grid.toggle_room(gp)


static func _handle_exit_action(grid: MapEditorGrid, gp: Vector2i, edge_dir: Vector2i) -> void:
	if edge_dir != Vector2i.ZERO:
		var dir_str: String = _delta_to_dir(edge_dir)
		if not dir_str.is_empty() and _try_toggle_exit(grid, gp, dir_str):
			return
	for fallback_dir: String in ["N", "E", "S", "W"]:
		if _try_toggle_exit(grid, gp, fallback_dir):
			return


static func _try_toggle_exit(grid: MapEditorGrid, gp: Vector2i, dir_str: String) -> bool:
	if dir_str.is_empty() or not grid.has_room(gp):
		return false
	var neighbor: Vector2i = gp + GridDirection.delta(dir_str)
	if grid.has_room(neighbor):
		var passage: Dictionary = grid.canonical_passage(gp, dir_str)
		grid.toggle_exit_door(passage["cell"] as Vector2i, String(passage["dir"]))
		return true
	if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= grid.grid_cols or neighbor.y >= grid.grid_rows:
		return false
	grid.toggle_exit_door(gp, dir_str)
	return true


static func _delta_to_dir(edge_dir: Vector2i) -> String:
	if edge_dir == Vector2i(0, -1):
		return "N"
	if edge_dir == Vector2i(0, 1):
		return "S"
	if edge_dir == Vector2i(-1, 0):
		return "W"
	if edge_dir == Vector2i(1, 0):
		return "E"
	return ""
