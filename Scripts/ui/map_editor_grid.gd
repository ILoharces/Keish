extends Control
class_name MapEditorGrid

# Rejilla del editor: habitaciones, puertas compartidas, puerta de salida y marcadores de spawn.

enum PlaceMode { BUILD, EXIT, PLAYER1, PLAYER2 }

signal room_toggled(cell: Vector2i, has_room: bool)
signal door_toggled(cell: Vector2i, direction: String, has_door: bool)
signal marker_changed()
signal pointer_used()
signal cursor_moved()

const CELL_SIZE: int = 48
const EDGE_BAND_RATIO: float = 0.28

const COLOR_BG: Color = Color(0.1, 0.1, 0.12, 1.0)
const COLOR_GRID: Color = Color(0.22, 0.22, 0.26, 1.0)
const COLOR_EMPTY: Color = Color(0.14, 0.14, 0.17, 1.0)
const COLOR_ROOM: Color = Color(0.55, 0.58, 0.65, 1.0)
const COLOR_ROOM_UNREACHABLE: Color = Color(0.62, 0.36, 0.38, 0.72)
const COLOR_EXIT: Color = Color(0.28, 0.62, 0.38, 1.0)
const COLOR_DOOR: Color = Color(0.72, 0.45, 0.18, 1.0)
const COLOR_PLAYER: Color = Color(0.25, 0.55, 0.95, 1.0)
const COLOR_AI: Color = Color(0.92, 0.32, 0.28, 1.0)
const COLOR_MARKER_OUTLINE: Color = Color(0.05, 0.05, 0.08, 1.0)
const COLOR_DOOR_COUNT_MIN: Color = Color(0.46, 0.14, 0.14, 1.0)
const COLOR_DOOR_COUNT_MAX: Color = Color(0.52, 0.84, 0.56, 1.0)

var grid_cols: int = 11
var grid_rows: int = 9
var place_mode: PlaceMode = PlaceMode.BUILD

var _rooms: Dictionary = {}
var _passages: Dictionary = {}
var _exit_door_cell: Vector2i = Vector2i(-1, -1)
var _exit_door_dir: String = ""
var _player_spawn_cell: Vector2i = Vector2i(-1, -1)
var _ai_spawn_cell: Vector2i = Vector2i(-1, -1)
var _cursor_cell: Vector2i = Vector2i.ZERO
var _edge_dir: Vector2i = Vector2i(0, -1)
var _cursor_visible: bool = false
var _unreachable_highlight: Dictionary = {}
var _show_door_counts: bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(grid_cols * CELL_SIZE, grid_rows * CELL_SIZE)
	size = custom_minimum_size
	reset_cursor()
	queue_redraw()


func set_cursor_visible(visible_flag: bool) -> void:
	_cursor_visible = visible_flag
	queue_redraw()


func is_cursor_visible() -> bool:
	return _cursor_visible


func reset_cursor() -> void:
	_cursor_cell = Vector2i((grid_cols - 1) / 2, (grid_rows - 1) / 2)
	_edge_dir = Vector2i(0, -1)
	queue_redraw()


func get_cursor_cell() -> Vector2i:
	return _cursor_cell


func get_edge_dir() -> Vector2i:
	return _edge_dir


func set_edge_dir(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO or dir == _edge_dir:
		return
	_edge_dir = dir
	queue_redraw()


func move_cursor(delta: Vector2i) -> void:
	var next: Vector2i = _cursor_cell + delta
	next.x = clampi(next.x, 0, grid_cols - 1)
	next.y = clampi(next.y, 0, grid_rows - 1)
	if next == _cursor_cell:
		return
	_cursor_cell = next
	queue_redraw()


func apply_cursor_action() -> void:
	MapEditorGridInput.handle_gamepad_action(self, _cursor_cell, _edge_dir)


func resize_grid(cols: int, rows: int) -> void:
	grid_cols = maxi(cols, 3)
	grid_rows = maxi(rows, 3)
	custom_minimum_size = Vector2(grid_cols * CELL_SIZE, grid_rows * CELL_SIZE)
	size = custom_minimum_size
	_cursor_cell = _cursor_cell.clamp(Vector2i.ZERO, Vector2i(grid_cols - 1, grid_rows - 1))
	queue_redraw()


func set_place_mode(mode: PlaceMode) -> void:
	place_mode = mode
	queue_redraw()


func has_room(gp: Vector2i) -> bool:
	return _rooms.has(gp)


func is_unreachable_highlighted(gp: Vector2i) -> bool:
	return _unreachable_highlight.has(gp)


func set_unreachable_highlight(cells: Array[Vector2i]) -> void:
	_unreachable_highlight.clear()
	for gp: Vector2i in cells:
		_unreachable_highlight[gp] = true
	queue_redraw()


func clear_unreachable_highlight() -> void:
	if _unreachable_highlight.is_empty():
		return
	_unreachable_highlight.clear()
	queue_redraw()


func set_door_count_overlay_enabled(enabled: bool) -> void:
	if _show_door_counts == enabled:
		return
	_show_door_counts = enabled
	queue_redraw()


func is_door_count_overlay_enabled() -> bool:
	return _show_door_counts


static func door_count_room_color(count: int) -> Color:
	var t: float = clampf(float(count) / 4.0, 0.0, 1.0)
	return COLOR_DOOR_COUNT_MIN.lerp(COLOR_DOOR_COUNT_MAX, t)


static func door_count_label_color(count: int) -> Color:
	if count >= 2:
		return Color(0.12, 0.10, 0.08, 1.0)
	return Color(0.96, 0.97, 0.99, 1.0)


func get_inter_room_door_count(gp: Vector2i) -> int:
	if not has_room(gp):
		return 0
	var count: int = 0
	for dir_str: String in ["N", "E", "S", "W"]:
		if not has_door(gp, dir_str):
			continue
		if _passage_is_exit_door(gp, dir_str):
			continue
		var neighbor: Vector2i = gp + GridDirection.delta(dir_str)
		if has_room(neighbor):
			count += 1
	return count


func _passage_is_exit_door(cell: Vector2i, dir_str: String) -> bool:
	var exit_key: String = get_exit_passage_key()
	if exit_key.is_empty():
		return false
	return _canonical_passage_key(cell, dir_str) == exit_key


func has_door(cell: Vector2i, dir_str: String) -> bool:
	return has_passage_key(_canonical_passage_key(cell, dir_str))


func get_passage_keys() -> Array:
	return _passages.keys()


func is_passage_active(key: Variant) -> bool:
	return bool(_passages.get(key, false))


func has_passage_key(key: String) -> bool:
	return _passages.has(key)


func get_exit_passage_key() -> String:
	if _exit_door_cell.x < 0 or _exit_door_dir.is_empty():
		return ""
	return _canonical_passage_key(_exit_door_cell, _exit_door_dir)


func canonical_passage(cell: Vector2i, dir_str: String) -> Dictionary:
	return _canonical_passage(cell, dir_str)


func get_exit_door() -> Dictionary:
	if _exit_door_cell.x < 0 or _exit_door_dir.is_empty():
		return {}
	if not _rooms.has(_exit_door_cell):
		return {}
	return {"cell": _exit_door_cell, "dir": _exit_door_dir}


func get_player_spawn_cell() -> Vector2i:
	return _player_spawn_cell


func get_ai_spawn_cell() -> Vector2i:
	return _ai_spawn_cell


func get_room_cells() -> Dictionary:
	return _rooms.duplicate()


func get_door_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for key: Variant in _passages.keys():
		if not bool(_passages[key]):
			continue
		var parts: PackedStringArray = String(key).split(",")
		if parts.size() != 3:
			continue
		specs.append({
			"cell": Vector2i(int(parts[0]), int(parts[1])),
			"dir": parts[2],
		})
	return specs


func clear_all() -> void:
	_rooms.clear()
	_passages.clear()
	_exit_door_cell = Vector2i(-1, -1)
	_exit_door_dir = ""
	_player_spawn_cell = Vector2i(-1, -1)
	_ai_spawn_cell = Vector2i(-1, -1)
	_unreachable_highlight.clear()
	queue_redraw()


func export_state() -> Dictionary:
	var rooms_arr: Array = []
	for key: Variant in _rooms.keys():
		var gp: Vector2i = key as Vector2i
		rooms_arr.append([gp.x, gp.y])
	var doors_arr: Array = []
	for spec: Dictionary in get_door_specs():
		var cell: Vector2i = spec["cell"] as Vector2i
		doors_arr.append({"x": cell.x, "y": cell.y, "dir": String(spec["dir"])})
	return {
		"grid_cols": grid_cols,
		"grid_rows": grid_rows,
		"rooms": rooms_arr,
		"doors": doors_arr,
		"exit_door": _exit_door_to_json(),
		"player_spawn": _cell_to_json(_player_spawn_cell),
		"ai_spawn": _cell_to_json(_ai_spawn_cell),
	}


func _exit_door_to_json() -> Variant:
	var exit_door: Dictionary = get_exit_door()
	if exit_door.is_empty():
		return null
	var cell: Vector2i = exit_door["cell"] as Vector2i
	return {"x": cell.x, "y": cell.y, "dir": String(exit_door["dir"])}


func import_state(data: Dictionary) -> void:
	clear_all()
	place_mode = PlaceMode.BUILD
	var max_x: int = 0
	var max_y: int = 0
	for entry: Variant in data.get("rooms", []):
		var gp: Vector2i = _parse_cell_array(entry)
		if gp.x < 0:
			continue
		_rooms[gp] = true
		max_x = maxi(max_x, gp.x)
		max_y = maxi(max_y, gp.y)
	var cols: int = int(data.get("grid_cols", max_x + 2))
	var rows: int = int(data.get("grid_rows", max_y + 2))
	grid_cols = maxi(cols, max_x + 1)
	grid_rows = maxi(rows, max_y + 1)
	resize_grid(grid_cols, grid_rows)
	for entry: Variant in data.get("doors", []):
		if entry is Dictionary:
			var dict: Dictionary = entry as Dictionary
			var cell: Vector2i = Vector2i(int(dict.get("x", -1)), int(dict.get("y", -1)))
			var dir_str: String = String(dict.get("dir", "")).to_upper()
			if cell.x >= 0 and dir_str in ["N", "S", "E", "W"]:
				_passages[_canonical_passage_key(cell, dir_str)] = true
	_import_exit_door(data)
	_player_spawn_cell = _parse_cell_array(data.get("player_spawn"))
	_ai_spawn_cell = _parse_cell_array(data.get("ai_spawn"))
	marker_changed.emit()
	queue_redraw()


func _import_exit_door(data: Dictionary) -> void:
	_exit_door_cell = Vector2i(-1, -1)
	_exit_door_dir = ""
	if data.has("exit_door") and data["exit_door"] is Dictionary:
		var spec: Dictionary = _parse_exit_door_dict(data["exit_door"] as Dictionary)
		if not spec.is_empty():
			_apply_exit_door_spec(spec)
			return
	var legacy_cell: Vector2i = _parse_cell_array(data.get("exit"))
	if legacy_cell.x < 0:
		return
	for key: Variant in _passages.keys():
		var parts: PackedStringArray = String(key).split(",")
		if parts.size() != 3:
			continue
		var cell: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
		if cell == legacy_cell:
			_exit_door_cell = cell
			_exit_door_dir = parts[2]
			return


func _apply_exit_door_spec(spec: Dictionary) -> void:
	var cell: Vector2i = spec["cell"] as Vector2i
	var dir_str: String = String(spec["dir"])
	if not _rooms.has(cell):
		return
	_exit_door_cell = cell
	_exit_door_dir = dir_str


func _parse_exit_door_dict(entry: Dictionary) -> Dictionary:
	var cell: Vector2i = Vector2i(int(entry.get("x", -1)), int(entry.get("y", -1)))
	var dir_str: String = String(entry.get("dir", "")).to_upper()
	if cell.x < 0 or dir_str not in ["N", "S", "E", "W"]:
		return {}
	return {"cell": cell, "dir": dir_str}


func _cell_to_json(gp: Vector2i) -> Variant:
	if gp.x < 0:
		return null
	return [gp.x, gp.y]


func _parse_cell_array(value: Variant) -> Vector2i:
	if value == null:
		return Vector2i(-1, -1)
	if value is Array:
		var arr: Array = value as Array
		if arr.size() >= 2:
			return Vector2i(int(arr[0]), int(arr[1]))
	return Vector2i(-1, -1)


func connect_all_adjacent() -> int:
	var added: int = 0
	for key: Variant in _rooms.keys():
		var gp: Vector2i = key as Vector2i
		for dir_str: String in ["E", "S"]:
			var nbr: Vector2i = gp + GridDirection.delta(dir_str)
			if not _rooms.has(nbr):
				continue
			var passage_key: String = _canonical_passage_key(gp, dir_str)
			if _passages.has(passage_key):
				continue
			_passages[passage_key] = true
			added += 1
	if added > 0:
		queue_redraw()
		door_toggled.emit(Vector2i.ZERO, "", true)
	return added


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_update_cursor_from_local_pos(motion.position)
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
			return
		_update_cursor_from_local_pos(mb.position)
		MapEditorGridInput.handle_click(self, mb.position)
		pointer_used.emit()
		accept_event()


func _update_cursor_from_local_pos(local_pos: Vector2) -> void:
	var col: int = clampi(int(local_pos.x / float(CELL_SIZE)), 0, grid_cols - 1)
	var row: int = clampi(int(local_pos.y / float(CELL_SIZE)), 0, grid_rows - 1)
	var next: Vector2i = Vector2i(col, row)
	if next == _cursor_cell:
		return
	_cursor_cell = next
	cursor_moved.emit()
	queue_redraw()


func _cell_less(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


func _canonical_passage_key(cell: Vector2i, dir_str: String) -> String:
	var canon: Dictionary = _canonical_passage(cell, dir_str)
	return String(canon["key"])


func _canonical_passage(cell: Vector2i, dir_str: String) -> Dictionary:
	var from_cell: Vector2i = cell
	var from_dir: String = dir_str
	var nbr: Vector2i = cell + GridDirection.delta(dir_str)
	if _cell_less(nbr, from_cell):
		from_cell = nbr
		from_dir = GridDirection.opposite(dir_str)
	return {
		"key": "%d,%d,%s" % [from_cell.x, from_cell.y, from_dir],
		"cell": from_cell,
		"dir": from_dir,
	}


func toggle_room(gp: Vector2i) -> void:
	if _rooms.has(gp):
		_rooms.erase(gp)
		_remove_passages_for_cell(gp)
		_clear_markers_on_cell(gp)
		room_toggled.emit(gp, false)
	else:
		_rooms[gp] = true
		room_toggled.emit(gp, true)
	queue_redraw()


func _clear_markers_on_cell(gp: Vector2i) -> void:
	if _exit_door_cell == gp:
		_exit_door_cell = Vector2i(-1, -1)
		_exit_door_dir = ""
	if _player_spawn_cell == gp:
		_player_spawn_cell = Vector2i(-1, -1)
	if _ai_spawn_cell == gp:
		_ai_spawn_cell = Vector2i(-1, -1)
	marker_changed.emit()


func toggle_exit_door(cell: Vector2i, dir_str: String) -> void:
	var outward: String = dir_str.to_upper()
	if not _rooms.has(cell) or outward not in ["N", "S", "E", "W"]:
		return
	if _exit_door_cell == cell and _exit_door_dir == outward:
		_exit_door_cell = Vector2i(-1, -1)
		_exit_door_dir = ""
	else:
		_exit_door_cell = cell
		_exit_door_dir = outward
	marker_changed.emit()
	queue_redraw()


func set_player_spawn(gp: Vector2i) -> void:
	_player_spawn_cell = gp
	marker_changed.emit()
	queue_redraw()


func set_ai_spawn(gp: Vector2i) -> void:
	_ai_spawn_cell = gp
	marker_changed.emit()
	queue_redraw()


func toggle_passage(cell: Vector2i, dir_str: String) -> void:
	var canon: Dictionary = _canonical_passage(cell, dir_str)
	var key: String = String(canon["key"])
	var from_cell: Vector2i = canon["cell"] as Vector2i
	var from_dir: String = String(canon["dir"])
	var has: bool = false
	if _passages.has(key):
		_passages.erase(key)
		if _exit_door_cell == from_cell and _exit_door_dir == from_dir:
			_exit_door_cell = Vector2i(-1, -1)
			_exit_door_dir = ""
	else:
		_passages[key] = true
		has = true
	door_toggled.emit(from_cell, from_dir, has)
	queue_redraw()


func _remove_passages_for_cell(gp: Vector2i) -> void:
	var to_remove: Array[String] = []
	for key: Variant in _passages.keys():
		var parts: PackedStringArray = String(key).split(",")
		if parts.size() != 3:
			continue
		var from_cell: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
		var nbr: Vector2i = from_cell + GridDirection.delta(parts[2])
		if from_cell == gp or nbr == gp:
			to_remove.append(String(key))
	for key: String in to_remove:
		_passages.erase(key)


func _draw() -> void:
	MapEditorGridDraw.draw_all(self)
