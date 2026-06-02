class_name MapEditorGridDraw
extends RefCounted

# Dibujo de la rejilla del editor de mapas.


static func draw_all(grid: MapEditorGrid) -> void:
	var canvas: Control = grid as Control
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), MapEditorGrid.COLOR_BG, true)
	for r: int in grid.grid_rows:
		for c: int in grid.grid_cols:
			var rect: Rect2 = Rect2(
				Vector2(float(c * MapEditorGrid.CELL_SIZE) + 1.0, float(r * MapEditorGrid.CELL_SIZE) + 1.0),
				Vector2(float(MapEditorGrid.CELL_SIZE - 2), float(MapEditorGrid.CELL_SIZE - 2))
			)
			var gp: Vector2i = Vector2i(c, r)
			if grid.has_room(gp):
				var room_color: Color = MapEditorGrid.COLOR_ROOM
				if grid.is_door_count_overlay_enabled():
					var door_count: int = grid.get_inter_room_door_count(gp)
					room_color = MapEditorGrid.door_count_room_color(door_count)
				canvas.draw_rect(rect, room_color, true)
				if grid.is_unreachable_highlighted(gp):
					canvas.draw_rect(rect, MapEditorGrid.COLOR_ROOM_UNREACHABLE, true)
			else:
				canvas.draw_rect(rect, MapEditorGrid.COLOR_EMPTY, true)
			canvas.draw_rect(rect, MapEditorGrid.COLOR_GRID, false, 1.0)
	_draw_passages(grid, canvas)
	_draw_external_exit_door(grid, canvas)
	_draw_spawn_markers(grid, canvas)
	_draw_door_counts(grid, canvas)
	_draw_cursor(grid, canvas)


static func _draw_cursor(grid: MapEditorGrid, canvas: Control) -> void:
	if not grid.is_cursor_visible():
		return
	var gp: Vector2i = grid.get_cursor_cell()
	if gp.x < 0 or gp.y < 0 or gp.x >= grid.grid_cols or gp.y >= grid.grid_rows:
		return
	var rect: Rect2 = Rect2(
		Vector2(float(gp.x * MapEditorGrid.CELL_SIZE) + 2.0, float(gp.y * MapEditorGrid.CELL_SIZE) + 2.0),
		Vector2(float(MapEditorGrid.CELL_SIZE - 4), float(MapEditorGrid.CELL_SIZE - 4))
	)
	canvas.draw_rect(rect, Color(1.0, 0.92, 0.35, 0.95), false, 3.0)
	if grid.place_mode != MapEditorGrid.PlaceMode.BUILD and grid.place_mode != MapEditorGrid.PlaceMode.EXIT:
		return
	var edge_dir: Vector2i = grid.get_edge_dir()
	if edge_dir != Vector2i.ZERO:
		_draw_edge_hint(canvas, gp, edge_dir)


static func _draw_edge_hint(canvas: Control, gp: Vector2i, nav_dir: Vector2i) -> void:
	var center: Vector2 = Vector2(
		float(gp.x * MapEditorGrid.CELL_SIZE) + float(MapEditorGrid.CELL_SIZE) * 0.5,
		float(gp.y * MapEditorGrid.CELL_SIZE) + float(MapEditorGrid.CELL_SIZE) * 0.5
	)
	var offset: Vector2 = Vector2(float(nav_dir.x), float(nav_dir.y)) * float(MapEditorGrid.CELL_SIZE) * 0.34
	var tip: Vector2 = center + offset
	canvas.draw_line(center, tip, Color(0.95, 0.78, 0.2, 0.95), 3.0)
	canvas.draw_circle(tip, 4.0, Color(0.95, 0.78, 0.2, 0.95))


static func _draw_spawn_markers(grid: MapEditorGrid, canvas: Control) -> void:
	if grid.get_player_spawn_cell().x >= 0 and grid.has_room(grid.get_player_spawn_cell()):
		_draw_marker(grid, canvas, grid.get_player_spawn_cell(), "1", MapEditorGrid.COLOR_PLAYER)
	if grid.get_ai_spawn_cell().x >= 0 and grid.has_room(grid.get_ai_spawn_cell()):
		_draw_marker(grid, canvas, grid.get_ai_spawn_cell(), "2", MapEditorGrid.COLOR_AI)


static func _draw_door_counts(grid: MapEditorGrid, canvas: Control) -> void:
	if not grid.is_door_count_overlay_enabled():
		return
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 15
	for key: Variant in grid.get_room_cells().keys():
		var gp: Vector2i = key as Vector2i
		var door_count: int = grid.get_inter_room_door_count(gp)
		var label: String = str(door_count)
		var text_pos: Vector2 = Vector2(
			float(gp.x * MapEditorGrid.CELL_SIZE) + 6.0,
			float(gp.y * MapEditorGrid.CELL_SIZE) + float(font_size) + 2.0
		)
		var label_color: Color = MapEditorGrid.door_count_label_color(door_count)
		canvas.draw_string(
			font,
			text_pos + Vector2(1.0, 1.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			MapEditorGrid.COLOR_MARKER_OUTLINE
		)
		canvas.draw_string(
			font,
			text_pos,
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			label_color
		)


static func _draw_marker(
	_grid: MapEditorGrid,
	canvas: Control,
	gp: Vector2i,
	letter: String,
	fill: Color
) -> void:
	var center: Vector2 = Vector2(
		float(gp.x * MapEditorGrid.CELL_SIZE) + float(MapEditorGrid.CELL_SIZE) * 0.5,
		float(gp.y * MapEditorGrid.CELL_SIZE) + float(MapEditorGrid.CELL_SIZE) * 0.5
	)
	var radius: float = float(MapEditorGrid.CELL_SIZE) * 0.18
	canvas.draw_circle(center, radius + 2.0, MapEditorGrid.COLOR_MARKER_OUTLINE)
	canvas.draw_circle(center, radius, fill)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 16
	var text_size: Vector2 = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos: Vector2 = center - text_size * 0.5 + Vector2(0.0, text_size.y * 0.12)
	canvas.draw_string(
		font,
		text_pos,
		letter,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color(1.0, 1.0, 1.0, 1.0)
	)


static func _draw_passages(grid: MapEditorGrid, canvas: Control) -> void:
	for key: Variant in grid.get_passage_keys():
		if not grid.is_passage_active(key):
			continue
		var parts: PackedStringArray = String(key).split(",")
		if parts.size() != 3:
			continue
		_draw_door_marker(
			canvas,
			Vector2i(int(parts[0]), int(parts[1])),
			parts[2],
			key == grid.get_exit_passage_key()
		)


static func _draw_external_exit_door(grid: MapEditorGrid, canvas: Control) -> void:
	var exit: Dictionary = grid.get_exit_door()
	if exit.is_empty():
		return
	var key: String = grid.get_exit_passage_key()
	if not key.is_empty() and grid.has_passage_key(key):
		return
	var cell: Vector2i = exit["cell"] as Vector2i
	_draw_door_marker(canvas, cell, String(exit["dir"]), true)


static func _draw_door_marker(
	canvas: Control,
	from_cell: Vector2i,
	dir_str: String,
	is_exit: bool
) -> void:
	var door_len: float = float(MapEditorGrid.CELL_SIZE) * 0.36
	var thick: float = 6.0
	var door_col: Color = MapEditorGrid.COLOR_EXIT if is_exit else MapEditorGrid.COLOR_DOOR
	match dir_str:
		"E":
			var x_line: float = float((from_cell.x + 1) * MapEditorGrid.CELL_SIZE)
			var y_center: float = float(from_cell.y * MapEditorGrid.CELL_SIZE) + float(MapEditorGrid.CELL_SIZE) * 0.5
			canvas.draw_rect(
				Rect2(
					Vector2(x_line - thick * 0.5, y_center - door_len * 0.5),
					Vector2(thick, door_len)
				),
				door_col,
				true
			)
		"W":
			var x_line_w: float = float(from_cell.x * MapEditorGrid.CELL_SIZE)
			var y_center_w: float = float(from_cell.y * MapEditorGrid.CELL_SIZE) + float(MapEditorGrid.CELL_SIZE) * 0.5
			canvas.draw_rect(
				Rect2(
					Vector2(x_line_w - thick * 0.5, y_center_w - door_len * 0.5),
					Vector2(thick, door_len)
				),
				door_col,
				true
			)
		"S":
			var y_line: float = float((from_cell.y + 1) * MapEditorGrid.CELL_SIZE)
			var x_center: float = float(from_cell.x * MapEditorGrid.CELL_SIZE) + float(MapEditorGrid.CELL_SIZE) * 0.5
			canvas.draw_rect(
				Rect2(
					Vector2(x_center - door_len * 0.5, y_line - thick * 0.5),
					Vector2(door_len, thick)
				),
				door_col,
				true
			)
		"N":
			var y_line_n: float = float(from_cell.y * MapEditorGrid.CELL_SIZE)
			var x_center_n: float = float(from_cell.x * MapEditorGrid.CELL_SIZE) + float(MapEditorGrid.CELL_SIZE) * 0.5
			canvas.draw_rect(
				Rect2(
					Vector2(x_center_n - door_len * 0.5, y_line_n - thick * 0.5),
					Vector2(door_len, thick)
				),
				door_col,
				true
			)
