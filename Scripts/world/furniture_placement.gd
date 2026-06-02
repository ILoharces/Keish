extends RefCounted
class_name FurniturePlacement

# Reglas de colocacion de muebles por habitacion.

const MIN_PER_ROOM: int = 0
const MAX_PER_ROOM: int = 3
const DOOR_CLEARANCE: float = 78.0
const DOOR_CLEARANCE_MIN_RATIO: float = 0.08
const WE_CORRIDOR_HALF_WIDTH: float = 52.0
const WE_CORRIDOR_V_HALF: float = 0.11
const WE_CORRIDOR_U_MIN: float = 0.06
const WE_CORRIDOR_U_MAX: float = 0.94
const MIN_FURNITURE_SEPARATION: float = 56.0
const N_DOOR_WALL_CLEARANCE: float = 95.0
const DOOR_UV_U_MARGIN: float = 0.08
const DOOR_UV_V_MARGIN: float = 0.2

const _NORTH_FLOOR_V: Array[float] = [0.08, 0.12, 0.16, 0.2]
const _NORTH_FLOOR_U: Array[float] = [0.22, 0.38, 0.5, 0.62, 0.78]
const _FREE_FLOOR_U: Array[float] = [0.2, 0.35, 0.5, 0.65, 0.8]
const _FREE_FLOOR_V: Array[float] = [0.28, 0.42, 0.55, 0.68, 0.8]
const _PAINTING_U: Array[float] = [0.18, 0.32, 0.5, 0.68, 0.82]


static func spawn_for_room(room: Room) -> Array[Dictionary]:
	var count: int = randi_range(MIN_PER_ROOM, MAX_PER_ROOM)
	if count <= 0:
		return []
	var kinds: Array[int] = ItemDB.get_decor_furniture_kinds()
	kinds.shuffle()
	var placements: Array[Dictionary] = []
	var used_positions: Array[Vector2] = []
	for kind: int in kinds:
		if placements.size() >= count:
			break
		var pos: Vector2 = pick_position(room, kind, used_positions)
		if pos == Vector2.INF:
			continue
		placements.append({"kind": kind, "position": pos})
		used_positions.append(pos)
	return placements


static func pick_position(room: Room, kind: int, used_positions: Array[Vector2]) -> Vector2:
	var candidates: Array[Vector2] = _candidates_for_kind(room, kind)
	candidates.shuffle()
	for pos: Vector2 in candidates:
		if _is_valid_position(room, pos, kind, used_positions):
			return pos
	return Vector2.INF


static func _candidates_for_kind(room: Room, kind: int) -> Array[Vector2]:
	var rw: float = room.get_room_w()
	var rh: float = room.get_room_h()
	var out: Array[Vector2] = []
	match kind:
		ItemDB.FurnitureKind.PAINTING:
			for u: float in _PAINTING_U:
				out.append(_north_wall_position(u, rw, rh))
		ItemDB.FurnitureKind.BOOKSHELF, ItemDB.FurnitureKind.DRAWERS, ItemDB.FurnitureKind.WEAPON_BOX:
			for v: float in _NORTH_FLOOR_V:
				for u: float in _NORTH_FLOOR_U:
					out.append(RoomPerspective.floor_uv_to_pos(u, v, rw, rh))
		_:
			for v: float in _FREE_FLOOR_V:
				for u: float in _FREE_FLOOR_U:
					out.append(RoomPerspective.floor_uv_to_pos(u, v, rw, rh))
	return out


static func _north_wall_position(u: float, room_w: float, room_h: float) -> Vector2:
	var back: PackedVector2Array = RoomPerspective.back_wall_polygon(room_w, room_h)
	var top_l: Vector2 = back[0]
	var top_r: Vector2 = back[1]
	var bot_l: Vector2 = back[3]
	var top: Vector2 = top_l.lerp(top_r, u)
	var bottom: Vector2 = bot_l.lerp(back[2], u)
	return top.lerp(bottom, 0.82)


static func _is_valid_position(
	room: Room,
	pos: Vector2,
	kind: int,
	used_positions: Array[Vector2]
) -> bool:
	if _is_near_any_door(room, pos, kind):
		return false
	if _is_on_we_corridor(room, pos):
		return false
	if kind == ItemDB.FurnitureKind.PAINTING and _is_near_north_door_on_wall(room, pos):
		return false
	for other: Vector2 in used_positions:
		if pos.distance_to(other) < MIN_FURNITURE_SEPARATION:
			return false
	if kind != ItemDB.FurnitureKind.PAINTING:
		var rw: float = room.get_room_w()
		var rh: float = room.get_room_h()
		if not Geometry2D.is_point_in_polygon(pos, RoomPerspective.floor_polygon(rw, rh)):
			return false
	return true


static func _door_clearance(room_w: float) -> float:
	return maxf(DOOR_CLEARANCE, room_w * DOOR_CLEARANCE_MIN_RATIO)


static func _is_near_any_door(room: Room, pos: Vector2, kind: int) -> bool:
	var rw: float = room.get_room_w()
	var rh: float = room.get_room_h()
	var clearance: float = _door_clearance(rw)
	if room.has_door_n and _violates_door_rules(pos, kind, "N", rw, rh, clearance):
		return true
	if room.has_door_s and _violates_door_rules(pos, kind, "S", rw, rh, clearance):
		return true
	if room.has_door_w and _violates_door_rules(pos, kind, "W", rw, rh, clearance):
		return true
	if room.has_door_e and _violates_door_rules(pos, kind, "E", rw, rh, clearance):
		return true
	return false


static func _violates_door_rules(
	pos: Vector2,
	kind: int,
	direction: String,
	room_w: float,
	room_h: float,
	clearance: float
) -> bool:
	if RoomPerspective.min_distance_to_door(pos, direction, room_w, room_h) < clearance:
		return true
	if kind == ItemDB.FurnitureKind.PAINTING:
		return false
	return _is_in_door_uv_zone(pos, direction, room_w, room_h)


static func _is_in_door_uv_zone(
	pos: Vector2,
	direction: String,
	room_w: float,
	room_h: float
) -> bool:
	var uv: Vector2 = RoomPerspective.position_to_floor_uv(pos, room_w, room_h)
	var door_uv: Vector2 = RoomPerspective.get_door_floor_uv(direction)
	match direction:
		"S":
			var u_half: float = RoomPerspective.DOOR_S_WIDTH_RATIO * 0.5 + DOOR_UV_U_MARGIN
			var v_min: float = 1.0 - DOOR_UV_V_MARGIN
			return absf(uv.x - door_uv.x) < u_half and uv.y >= v_min
		"N":
			var n_half: float = RoomPerspective.DOOR_N_WIDTH_RATIO * 0.5 + DOOR_UV_U_MARGIN
			var v_max: float = DOOR_UV_V_MARGIN
			return absf(uv.x - door_uv.x) < n_half and uv.y <= v_max
		"W", "E":
			var u_limit: float = 0.14 + DOOR_UV_U_MARGIN * 0.5
			var v_half: float = 0.14 + DOOR_UV_U_MARGIN
			if direction == "W":
				return uv.x <= u_limit and absf(uv.y - door_uv.y) < v_half
			return uv.x >= 1.0 - u_limit and absf(uv.y - door_uv.y) < v_half
	return false


static func _is_on_we_corridor(room: Room, pos: Vector2) -> bool:
	if not room.has_door_w or not room.has_door_e:
		return false
	var rw: float = room.get_room_w()
	var rh: float = room.get_room_h()
	var seg: PackedVector2Array = RoomPerspective.get_we_floor_corridor_segment(rw, rh)
	var half_w: float = maxf(WE_CORRIDOR_HALF_WIDTH, rw * 0.055)
	if Geometry2D.get_closest_point_to_segment(pos, seg[0], seg[1]).distance_to(pos) < half_w:
		return true
	var uv: Vector2 = RoomPerspective.position_to_floor_uv(pos, rw, rh)
	var corridor_v: float = RoomPerspective.we_floor_corridor_v(rw, rh)
	if absf(uv.y - corridor_v) > WE_CORRIDOR_V_HALF:
		return false
	return uv.x >= WE_CORRIDOR_U_MIN and uv.x <= WE_CORRIDOR_U_MAX


static func _is_near_north_door_on_wall(room: Room, pos: Vector2) -> bool:
	if not room.has_door_n:
		return false
	var rw: float = room.get_room_w()
	var rh: float = room.get_room_h()
	var door_x: float = RoomPerspective.get_door_visual_center("N", rw, rh).x
	return absf(pos.x - door_x) < N_DOOR_WALL_CLEARANCE
