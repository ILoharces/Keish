extends Control
class_name Minimap

# Minimapa cuadrado: celdas coloreadas por habitacion o por espia presente.

const BG_COLOR: Color = Color("#000000")
const ROOM_COLOR: Color = Color("#b0b0b0")
const EXIT_COLOR: Color = Color("#4caf50")
const DOOR_COLOR: Color = Color("#c62828")
const VOID_COLOR: Color = Color("#000000")
const GRID_MARGIN: float = 16.0
const CELL_GAP: float = 2.0
const PULSE_SPEED: float = 5.5
const PULSE_DARKEN: float = 0.28
const PULSE_LIGHTEN: float = 0.22

var mansion: Mansion = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("minimap")


func bind_mansion(m: Mansion) -> void:
	mansion = m
	queue_redraw()


func _process(_delta: float) -> void:
	if mansion != null and is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(rect, BG_COLOR, true)
	draw_rect(rect, NesUiTheme.COLOR_BORDER, false, float(NesUiTheme.BORDER_WIDTH))
	if mansion == null or mansion.rooms.is_empty():
		return

	var gw: int = mansion.grid_width
	var gh: int = mansion.grid_height
	var grid_layout: Dictionary = _compute_grid_layout(gw, gh)
	var origin: Vector2 = grid_layout["origin"] as Vector2
	var cell_size: float = grid_layout["cell_size"] as float
	var spy_tints: Dictionary = _spy_cell_colors()

	for r: int in gh:
		for c: int in gw:
			var gp: Vector2i = Vector2i(c, r)
			var cell_rect: Rect2 = _cell_rect(origin, cell_size, c, r)
			var room: Room = mansion.get_room_at(gp)
			if room == null:
				draw_rect(cell_rect, VOID_COLOR, true)
				continue
			var fill: Color = spy_tints.get(gp, ROOM_COLOR)
			draw_rect(cell_rect, fill, true)
			_draw_door_marks(cell_rect, room, gp)


func _compute_grid_layout(gw: int, gh: int) -> Dictionary:
	var inner: Vector2 = size - Vector2(GRID_MARGIN * 2.0, GRID_MARGIN * 2.0)
	var side: float = minf(inner.x, inner.y)
	var cell_size: float = side / float(maxi(gw, gh))
	var grid_w: float = cell_size * float(gw)
	var grid_h: float = cell_size * float(gh)
	var origin: Vector2 = Vector2(GRID_MARGIN, GRID_MARGIN)
	origin.x += (inner.x - grid_w) * 0.5
	origin.y += (inner.y - grid_h) * 0.5
	return {"origin": origin, "cell_size": cell_size}


func _cell_rect(origin: Vector2, cell_size: float, col: int, row: int) -> Rect2:
	var inset: float = CELL_GAP * 0.5
	return Rect2(
		origin + Vector2(float(col) * cell_size + inset, float(row) * cell_size + inset),
		Vector2(cell_size - CELL_GAP, cell_size - CELL_GAP),
	)


func _spy_cell_colors() -> Dictionary:
	var tints: Dictionary = {}
	var bottom_spy: SpyBase = mansion.get_bottom_spy()
	if bottom_spy != null and bottom_spy.current_room != null:
		var ai_gp: Vector2i = bottom_spy.current_room.grid_pos
		var ai_base: Color = ItemDB.SPY_COLORS.get(bottom_spy.spy_id, Color.WHITE)
		tints[ai_gp] = _pulse_color(ai_base, 1.9)
	if mansion.player != null and mansion.player.current_room != null:
		var player_gp: Vector2i = mansion.player.current_room.grid_pos
		var player_base: Color = ItemDB.SPY_COLORS.get(mansion.player.spy_id, Color.WHITE)
		tints[player_gp] = _pulse_color(player_base, 0.0)
	return tints


func _pulse_color(base: Color, phase: float) -> Color:
	var wave: float = (sin(Time.get_ticks_msec() * 0.001 * PULSE_SPEED + phase) + 1.0) * 0.5
	var dim: Color = base.darkened(PULSE_DARKEN)
	var bright: Color = base.lightened(PULSE_LIGHTEN)
	return dim.lerp(bright, wave)


func _draw_door_marks(cell_rect: Rect2, room: Room, gp: Vector2i) -> void:
	var exit_spec: Dictionary = mansion.get_exit_door_spec() if mansion != null else {}
	if room.has_door_n:
		draw_rect(
			Rect2(cell_rect.position + Vector2(cell_rect.size.x * 0.42, 0.0), Vector2(cell_rect.size.x * 0.16, 2.0)),
			_door_mark_color(exit_spec, gp, "N"),
			true,
		)
	if room.has_door_s:
		draw_rect(
			Rect2(cell_rect.position + Vector2(cell_rect.size.x * 0.42, cell_rect.size.y - 2.0), Vector2(cell_rect.size.x * 0.16, 2.0)),
			_door_mark_color(exit_spec, gp, "S"),
			true,
		)
	if room.has_door_w:
		draw_rect(
			Rect2(cell_rect.position + Vector2(0.0, cell_rect.size.y * 0.42), Vector2(2.0, cell_rect.size.y * 0.16)),
			_door_mark_color(exit_spec, gp, "W"),
			true,
		)
	if room.has_door_e:
		draw_rect(
			Rect2(cell_rect.position + Vector2(cell_rect.size.x - 2.0, cell_rect.size.y * 0.42), Vector2(2.0, cell_rect.size.y * 0.16)),
			_door_mark_color(exit_spec, gp, "E"),
			true,
		)


func _door_mark_color(exit_spec: Dictionary, gp: Vector2i, dir_str: String) -> Color:
	if exit_spec.is_empty():
		return DOOR_COLOR
	var exit_cell: Vector2i = exit_spec.get("cell", Vector2i(-1, -1)) as Vector2i
	if exit_cell == gp and String(exit_spec.get("dir", "")) == dir_str:
		return EXIT_COLOR
	return DOOR_COLOR
