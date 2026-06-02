extends RefCounted
class_name RoomPerspective

# Geometria oblicua de habitacion. Indices del suelo (trapecio):
#   0 front_l  ----  1 front_r   (borde SUR / camara, has_door_s)
#        |              |
#   3 back_l  -------  2 back_r    (borde NORTE / pared fondo, has_door_n)
# Borde 0-1 = S, 1-2 = E, 2-3 = N, 3-0 = W

const EDGE_S: int = 0
const EDGE_E: int = 1
const EDGE_N: int = 2
const EDGE_W: int = 3

static func back_top_y(room_h: float) -> float:
	return room_h * 0.039


static func back_bottom_y(room_h: float) -> float:
	return room_h * 0.239


static func floor_back_inset(room_w: float) -> float:
	return room_w * 0.15


static func floor_side_margin(room_w: float) -> float:
	return room_w * 0.04


static func floor_front_y_offset(room_h: float) -> float:
	return room_h * 0.061


static func floor_polygon(room_w: float, room_h: float) -> PackedVector2Array:
	var front_y: float = room_h - floor_front_y_offset(room_h)
	var back_y: float = back_bottom_y(room_h)
	var inset: float = floor_back_inset(room_w)
	var margin: float = floor_side_margin(room_w)
	var front_l: Vector2 = Vector2(margin, front_y)
	var front_r: Vector2 = Vector2(room_w - margin, front_y)
	var back_r: Vector2 = Vector2(room_w - inset, back_y)
	var back_l: Vector2 = Vector2(inset, back_y)
	return PackedVector2Array([front_l, front_r, back_r, back_l])


static func floor_centroid(room_w: float, room_h: float) -> Vector2:
	var poly: PackedVector2Array = floor_polygon(room_w, room_h)
	var sum: Vector2 = Vector2.ZERO
	for p: Vector2 in poly:
		sum += p
	return sum / float(poly.size())


static func visible_content_rect(room_w: float, room_h: float) -> Rect2:
	var bounds: Rect2 = Rect2()
	var polys: Array[PackedVector2Array] = [
		floor_polygon(room_w, room_h),
		back_wall_polygon(room_w, room_h),
		left_wall_polygon(room_w, room_h),
		right_wall_polygon(room_w, room_h),
	]
	for poly: PackedVector2Array in polys:
		for p: Vector2 in poly:
			if bounds.size == Vector2.ZERO:
				bounds = Rect2(p, Vector2.ZERO)
			else:
				bounds = bounds.expand(p)
	if bounds.size == Vector2.ZERO:
		return Rect2(0.0, 0.0, room_w, room_h)
	return bounds


static func visible_content_center(room_w: float, room_h: float) -> Vector2:
	return visible_content_rect(room_w, room_h).get_center()


static func back_wall_polygon(room_w: float, room_h: float) -> PackedVector2Array:
	var back_y: float = back_bottom_y(room_h)
	var inset: float = floor_back_inset(room_w)
	return PackedVector2Array([
		Vector2(inset, back_top_y(room_h)),
		Vector2(room_w - inset, back_top_y(room_h)),
		Vector2(room_w - inset, back_y),
		Vector2(inset, back_y),
	])


static func left_wall_polygon(room_w: float, room_h: float) -> PackedVector2Array:
	var floor_pts: PackedVector2Array = floor_polygon(room_w, room_h)
	var margin: float = floor_side_margin(room_w)
	var inset: float = floor_back_inset(room_w)
	return PackedVector2Array([
		floor_pts[0],
		floor_pts[3],
		Vector2(inset, back_top_y(room_h)),
		Vector2(margin, back_top_y(room_h) + room_h * 0.017),
	])


static func right_wall_polygon(room_w: float, room_h: float) -> PackedVector2Array:
	var floor_pts: PackedVector2Array = floor_polygon(room_w, room_h)
	var margin: float = floor_side_margin(room_w)
	var inset: float = floor_back_inset(room_w)
	return PackedVector2Array([
		floor_pts[1],
		floor_pts[2],
		Vector2(room_w - inset, back_top_y(room_h)),
		Vector2(room_w - margin, back_top_y(room_h) + room_h * 0.017),
	])


static func floor_uv_to_pos(u: float, v: float, room_w: float, room_h: float) -> Vector2:
	var poly: PackedVector2Array = floor_polygon(room_w, room_h)
	var back_l: Vector2 = poly[3]
	var back_r: Vector2 = poly[2]
	var front_r: Vector2 = poly[1]
	var front_l: Vector2 = poly[0]
	var left_edge: Vector2 = back_l.lerp(front_l, v)
	var right_edge: Vector2 = back_r.lerp(front_r, v)
	return left_edge.lerp(right_edge, u)


static func depth_from_y(local_y: float, room_h: float) -> float:
	var front_y: float = room_h - floor_front_y_offset(room_h)
	var back_y: float = back_bottom_y(room_h)
	return clampf((local_y - back_y) / (front_y - back_y), 0.0, 1.0)


static func position_to_floor_uv(local_pos: Vector2, room_w: float, room_h: float) -> Vector2:
	var v: float = depth_from_y(local_pos.y, room_h)
	var left: Vector2 = floor_uv_to_pos(0.0, v, room_w, room_h)
	var right: Vector2 = floor_uv_to_pos(1.0, v, room_w, room_h)
	var edge: Vector2 = right - left
	var len_sq: float = edge.length_squared()
	var u: float = 0.5
	if len_sq > 0.0001:
		u = clampf((local_pos - left).dot(edge) / len_sq, 0.0, 1.0)
	return Vector2(u, v)


static func we_floor_corridor_v(_room_w: float, _room_h: float) -> float:
	return DOOR_SIDE_WALL_T


static func get_we_floor_corridor_segment(room_w: float, room_h: float) -> PackedVector2Array:
	var v: float = we_floor_corridor_v(room_w, room_h)
	const edge_inset: float = 0.05
	return PackedVector2Array([
		floor_uv_to_pos(edge_inset, v, room_w, room_h),
		floor_uv_to_pos(1.0 - edge_inset, v, room_w, room_h),
	])


static func get_door_floor_uv(direction: String) -> Vector2:
	match direction:
		"S":
			return Vector2(0.5, 1.0)
		"N":
			return Vector2(0.5, 0.0)
		"W":
			return Vector2(0.0, DOOR_SIDE_WALL_T)
		"E":
			return Vector2(1.0, DOOR_SIDE_WALL_T)
	return Vector2(0.5, 0.5)


static func min_distance_to_door(local_pos: Vector2, direction: String, room_w: float, room_h: float) -> float:
	var poly: PackedVector2Array = get_door_polygon(direction, room_w, room_h)
	if poly.is_empty():
		return INF
	var best: float = local_pos.distance_to(get_door_polygon_centroid(poly))
	for i: int in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(local_pos, a, b)
		best = minf(best, local_pos.distance_to(closest))
	var entry: Vector2 = get_door_entry_position(direction, room_w, room_h)
	best = minf(best, local_pos.distance_to(entry))
	return best


static func adjust_passage_entry_position(
	from_local: Vector2,
	from_room_w: float,
	from_room_h: float,
	entry_dir: String,
	entry_spawn: Vector2,
	to_room_w: float,
	to_room_h: float
) -> Vector2:
	var from_uv: Vector2 = position_to_floor_uv(from_local, from_room_w, from_room_h)
	var spawn_uv: Vector2 = position_to_floor_uv(entry_spawn, to_room_w, to_room_h)
	match entry_dir:
		"E", "W":
			spawn_uv.y = from_uv.y
		"N", "S":
			spawn_uv.x = from_uv.x
	return floor_uv_to_pos(spawn_uv.x, spawn_uv.y, to_room_w, to_room_h)


static func door_entry_inward_offset(direction: String, room_w: float, room_h: float) -> Vector2:
	var entry: Vector2 = get_door_entry_position(direction, room_w, room_h)
	var center: Vector2 = get_door_visual_center(direction, room_w, room_h)
	var inward: Vector2 = entry - center
	if inward.length_squared() < 1.0:
		inward = floor_centroid(room_w, room_h) - center
	if inward.length_squared() < 0.001:
		return Vector2.ZERO
	var depth: float = room_h * 0.018
	match direction:
		"S":
			# Entrada por sur (p. ej. cruce de puerta norte): alejar mas del hueco sur.
			depth = room_h * 0.042
	return inward.normalized() * depth


static func ensure_spawn_clear_of_passage(
	local_pos: Vector2,
	entry_dir: String,
	room_w: float,
	room_h: float
) -> Vector2:
	var passage_poly: PackedVector2Array = get_door_polygon(entry_dir, room_w, room_h)
	if passage_poly.size() < 3:
		return local_pos
	if not Geometry2D.is_point_in_polygon(local_pos, passage_poly):
		return local_pos
	var step: Vector2 = door_entry_inward_offset(entry_dir, room_w, room_h)
	if step.length_squared() < 0.001:
		return local_pos
	var cleared: Vector2 = local_pos
	for _i: int in 8:
		cleared += step
		if not Geometry2D.is_point_in_polygon(cleared, passage_poly):
			return cleared
	return cleared


static func clamp_to_floor(local_pos: Vector2, room_w: float, room_h: float) -> Vector2:
	var poly: PackedVector2Array = floor_polygon(room_w, room_h)
	if Geometry2D.is_point_in_polygon(local_pos, poly):
		return local_pos
	var best: Vector2 = poly[0]
	var best_dist: float = local_pos.distance_squared_to(best)
	for i: int in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(local_pos, a, b)
		var d: float = local_pos.distance_squared_to(closest)
		if d < best_dist:
			best_dist = d
			best = closest
	return best


static func direction_for_edge_index(edge_idx: int) -> String:
	match edge_idx:
		EDGE_S:
			return "S"
		EDGE_E:
			return "E"
		EDGE_N:
			return "N"
		EDGE_W:
			return "W"
	return ""


static func opposite_direction(direction: String) -> String:
	return GridDirection.opposite(direction)


# Posicion a lo largo del borde lateral: 0 = frente, 1 = fondo (0.5 = centrado).
const DOOR_SIDE_WALL_T: float = 0.5
const DOOR_N_WIDTH_RATIO: float = 0.09
const DOOR_N_HEIGHT_RATIO: float = 0.70
const DOOR_S_WIDTH_RATIO: float = 0.11
const SOUTH_BAR_HEIGHT_RATIO: float = 0.068
const DOOR_SIDE_WIDTH_RATIO: float = 0.052
const DOOR_SIDE_PANEL_RATIO: float = 0.44
const DOOR_GAP_MARGIN_RATIO: float = 0.012


static func get_door_polygon(direction: String, room_w: float, room_h: float) -> PackedVector2Array:
	match direction:
		"N":
			return _north_door_polygon(room_w, room_h)
		"S":
			return _south_door_polygon(room_w, room_h)
		"W", "E":
			return _side_door_polygon(direction, room_w, room_h)
	return PackedVector2Array()


static func _north_door_polygon(room_w: float, room_h: float) -> PackedVector2Array:
	var back: PackedVector2Array = back_wall_polygon(room_w, room_h)
	var top_l: Vector2 = back[0]
	var top_r: Vector2 = back[1]
	var bot_l: Vector2 = back[3]
	var cx: float = (top_l.x + top_r.x) * 0.5
	var half: float = room_w * DOOR_N_WIDTH_RATIO * 0.5
	var bot: float = bot_l.y
	var top: float = lerpf(top_l.y, bot, 1.0 - DOOR_N_HEIGHT_RATIO)
	return PackedVector2Array([
		Vector2(cx - half, top),
		Vector2(cx + half, top),
		Vector2(cx + half, bot),
		Vector2(cx - half, bot),
	])


static func south_wall_bar_polygon(room_w: float, room_h: float) -> PackedVector2Array:
	var floor_pts: PackedVector2Array = floor_polygon(room_w, room_h)
	var front_l: Vector2 = floor_pts[0]
	var front_r: Vector2 = floor_pts[1]
	var back_l: Vector2 = floor_pts[3]
	var back_r: Vector2 = floor_pts[2]
	var bar_top_y: float = front_l.y - room_h * SOUTH_BAR_HEIGHT_RATIO
	var top_l_x: float = _x_on_segment_at_y(front_l, back_l, bar_top_y)
	var top_r_x: float = _x_on_segment_at_y(front_r, back_r, bar_top_y)
	return PackedVector2Array([
		Vector2(top_l_x, bar_top_y),
		Vector2(top_r_x, bar_top_y),
		front_r,
		front_l,
	])


static func _x_on_segment_at_y(a: Vector2, b: Vector2, y: float) -> float:
	if absf(b.y - a.y) < 0.001:
		return a.x
	var t: float = clampf((y - a.y) / (b.y - a.y), 0.0, 1.0)
	return lerpf(a.x, b.x, t)


static func south_wall_bar_top_y(room_w: float, room_h: float) -> float:
	var floor_pts: PackedVector2Array = floor_polygon(room_w, room_h)
	return floor_pts[0].y - room_h * SOUTH_BAR_HEIGHT_RATIO


static func _south_door_polygon(room_w: float, room_h: float) -> PackedVector2Array:
	var floor_pts: PackedVector2Array = floor_polygon(room_w, room_h)
	var front_l: Vector2 = floor_pts[0]
	var front_r: Vector2 = floor_pts[1]
	var back_l: Vector2 = floor_pts[3]
	var back_r: Vector2 = floor_pts[2]
	var bar_top_y: float = south_wall_bar_top_y(room_w, room_h)
	var top_l_x: float = _x_on_segment_at_y(front_l, back_l, bar_top_y)
	var top_r_x: float = _x_on_segment_at_y(front_r, back_r, bar_top_y)
	var span: float = top_r_x - top_l_x
	var half: float = span * DOOR_S_WIDTH_RATIO * 0.5
	var cx: float = (top_l_x + top_r_x) * 0.5
	var bl: Vector2 = Vector2(cx - half, front_l.y)
	var br: Vector2 = Vector2(cx + half, front_r.y)
	var tl: Vector2 = Vector2(cx - half, bar_top_y)
	var tr: Vector2 = Vector2(cx + half, bar_top_y)
	return PackedVector2Array([tl, tr, br, bl])


static func _side_door_polygon(side: String, room_w: float, room_h: float) -> PackedVector2Array:
	var wall: PackedVector2Array = left_wall_polygon(room_w, room_h) if side == "W" else right_wall_polygon(room_w, room_h)
	var along: Vector2 = (wall[1] - wall[0]).normalized()
	var bottom_mid: Vector2 = wall[0].lerp(wall[1], DOOR_SIDE_WALL_T)
	var ceiling_mid: Vector2 = wall[3].lerp(wall[2], DOOR_SIDE_WALL_T)
	var door_top: Vector2 = bottom_mid.lerp(ceiling_mid, DOOR_SIDE_PANEL_RATIO)
	var depth: float = depth_from_y(bottom_mid.y, room_h)
	var half_w: float = lerpf(
		room_h * DOOR_SIDE_WIDTH_RATIO,
		room_h * DOOR_SIDE_WIDTH_RATIO * 0.72,
		1.0 - depth
	)
	return PackedVector2Array([
		bottom_mid - along * half_w,
		bottom_mid + along * half_w,
		door_top + along * half_w,
		door_top - along * half_w,
	])


static func get_door_polygon_centroid(poly: PackedVector2Array) -> Vector2:
	if poly.is_empty():
		return Vector2.ZERO
	var sum: Vector2 = Vector2.ZERO
	for p: Vector2 in poly:
		sum += p
	return sum / float(poly.size())


static func get_door_visual_center(direction: String, room_w: float, room_h: float) -> Vector2:
	return get_door_polygon_centroid(get_door_polygon(direction, room_w, room_h))


static func get_door_entry_position(direction: String, room_w: float, room_h: float) -> Vector2:
	match direction:
		"S":
			return _spawn_past_south_door(room_w, room_h)
		"N":
			return _spawn_past_north_door(room_w, room_h)
		"W":
			return _spawn_past_side_door("W", room_w, room_h)
		"E":
			return _spawn_past_side_door("E", room_w, room_h)
	return floor_centroid(room_w, room_h)


static func _spawn_past_south_door(room_w: float, room_h: float) -> Vector2:
	var poly: PackedVector2Array = get_door_polygon("S", room_w, room_h)
	var door_center: Vector2 = get_door_polygon_centroid(poly)
	return door_center + Vector2(0.0, -room_h * 0.034)


static func _spawn_past_north_door(room_w: float, room_h: float) -> Vector2:
	var cx: float = room_w * 0.5
	var lip_y: float = back_bottom_y(room_h)
	var inside_y: float = lip_y + room_h * 0.028
	return Vector2(cx, inside_y)


static func _spawn_past_side_door(side: String, room_w: float, room_h: float) -> Vector2:
	var poly: PackedVector2Array = get_door_polygon(side, room_w, room_h)
	var center: Vector2 = get_door_polygon_centroid(poly)
	var margin_x: float = room_w * 0.028
	if side == "W":
		return Vector2(center.x + margin_x, center.y)
	return Vector2(center.x - margin_x, center.y)


static func get_door_nav_position(direction: String, room_w: float, room_h: float) -> Vector2:
	var entry: Vector2 = get_door_entry_position(direction, room_w, room_h)
	var visual: Vector2 = get_door_visual_center(direction, room_w, room_h)
	return visual.lerp(entry, 0.55)


static func edge_index_for_direction(direction: String) -> int:
	match direction:
		"S":
			return EDGE_S
		"E":
			return EDGE_E
		"N":
			return EDGE_N
		"W":
			return EDGE_W
	return EDGE_S


static func get_door_gap_half(direction: String, room_w: float, room_h: float) -> float:
	var poly: PackedVector2Array = get_door_polygon(direction, room_w, room_h)
	var floor_pts: PackedVector2Array = floor_polygon(room_w, room_h)
	var edge_idx: int = edge_index_for_direction(direction)
	var seg_a: Vector2 = floor_pts[edge_idx]
	var seg_b: Vector2 = floor_pts[(edge_idx + 1) % floor_pts.size()]
	var edge: Vector2 = seg_b - seg_a
	var edge_len: float = edge.length()
	if edge_len < 0.001 or poly.is_empty():
		return 40.0
	var along: Vector2 = edge / edge_len
	var min_t: float = INF
	var max_t: float = -INF
	for p: Vector2 in poly:
		var t: float = (p - seg_a).dot(along)
		min_t = minf(min_t, t)
		max_t = maxf(max_t, t)
	return (max_t - min_t) * 0.5 + room_h * DOOR_GAP_MARGIN_RATIO


static func get_door_gap_half_tight(direction: String, room_w: float, room_h: float) -> float:
	var poly: PackedVector2Array = get_door_polygon(direction, room_w, room_h)
	var floor_pts: PackedVector2Array = floor_polygon(room_w, room_h)
	var edge_idx: int = edge_index_for_direction(direction)
	var seg_a: Vector2 = floor_pts[edge_idx]
	var seg_b: Vector2 = floor_pts[(edge_idx + 1) % floor_pts.size()]
	var edge: Vector2 = seg_b - seg_a
	var edge_len: float = edge.length()
	if edge_len < 0.001 or poly.is_empty():
		return 40.0
	var along: Vector2 = edge / edge_len
	var min_t: float = INF
	var max_t: float = -INF
	for p: Vector2 in poly:
		var t: float = (p - seg_a).dot(along)
		min_t = minf(min_t, t)
		max_t = maxf(max_t, t)
	return (max_t - min_t) * 0.5


static func project_point_on_segment(point: Vector2, seg_a: Vector2, seg_b: Vector2) -> Vector2:
	var ab: Vector2 = seg_b - seg_a
	var len_sq: float = ab.length_squared()
	if len_sq < 0.001:
		return seg_a
	var t: float = clampf((point - seg_a).dot(ab) / len_sq, 0.0, 1.0)
	return seg_a + ab * t


static func outward_normal_for_edge(seg_a: Vector2, seg_b: Vector2, centroid: Vector2) -> Vector2:
	var mid: Vector2 = (seg_a + seg_b) * 0.5
	var edge_dir: Vector2 = (seg_b - seg_a).normalized()
	var normal: Vector2 = Vector2(-edge_dir.y, edge_dir.x)
	if normal.dot(centroid - mid) > 0.0:
		normal = -normal
	return normal.normalized()
