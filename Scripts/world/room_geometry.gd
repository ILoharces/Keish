class_name RoomGeometry
extends RefCounted

# Colisiones y geometría de paredes de una habitación.


static func build_wall_collision(room: Room) -> void:
	var walls: StaticBody2D = StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 0
	room.add_child(walls)
	var rw: float = room.get_room_w()
	var rh: float = room.get_room_h()
	var floor_pts: PackedVector2Array = RoomPerspective.floor_polygon(rw, rh)
	var centroid: Vector2 = RoomPerspective.floor_centroid(rw, rh)
	var door_flags: Array[bool] = [room.has_door_s, room.has_door_e, room.has_door_n, room.has_door_w]
	for edge_idx: int in floor_pts.size():
		if edge_idx == RoomPerspective.EDGE_S:
			continue
		# El borde N del suelo queda dentro de la zona jugable; colisionarlo bloquea
		# la hitbox del espía antes de llegar a muebles en la pared norte (cuadros).
		if edge_idx == RoomPerspective.EDGE_N:
			continue
		var seg_a: Vector2 = floor_pts[edge_idx]
		var seg_b: Vector2 = floor_pts[(edge_idx + 1) % floor_pts.size()]
		var dir_str: String = RoomPerspective.direction_for_edge_index(edge_idx)
		var is_side_edge: bool = edge_idx == RoomPerspective.EDGE_W or edge_idx == RoomPerspective.EDGE_E
		if door_flags[edge_idx]:
			var door_center: Vector2 = RoomPerspective.get_door_visual_center(dir_str, rw, rh)
			var gap_half: float = RoomPerspective.get_door_gap_half_tight(dir_str, rw, rh)
			if is_side_edge:
				_add_capsule_wall_edge_with_door_gap(walls, seg_a, seg_b, door_center, gap_half, centroid)
			else:
				_add_wall_edge_with_door_gap(walls, seg_a, seg_b, door_center, gap_half, centroid)
		elif is_side_edge:
			_add_capsule_wall_on_edge(walls, seg_a, seg_b, centroid, Room.WALL_THICKNESS)
		else:
			_add_wall_strip_on_edge(walls, seg_a, seg_b, centroid, Room.WALL_THICKNESS, 0.0)
	_add_south_bar_collision(room, walls, rw, rh, room.has_door_s)


static func _add_south_bar_collision(
	room: Room,
	parent: StaticBody2D,
	rw: float,
	rh: float,
	with_door_gap: bool
) -> void:
	var bar: PackedVector2Array = RoomPerspective.south_wall_bar_polygon(rw, rh)
	if not with_door_gap:
		_add_collision_polygon(parent, bar)
		return
	var door_poly: PackedVector2Array = RoomPerspective.get_door_polygon("S", rw, rh)
	if door_poly.size() < 4:
		_add_collision_polygon(parent, bar)
		return
	var min_x: float = minf(door_poly[0].x, door_poly[3].x)
	var max_x: float = maxf(door_poly[1].x, door_poly[2].x)
	var top_l: Vector2 = bar[0]
	var top_r: Vector2 = bar[1]
	var front_l: Vector2 = bar[3]
	var front_r: Vector2 = bar[2]
	var bar_top_y: float = top_l.y
	if min_x > top_l.x + 4.0:
		_add_collision_polygon(
			parent,
			PackedVector2Array([
				top_l,
				Vector2(min_x, bar_top_y),
				Vector2(min_x, front_l.y),
				front_l,
			])
		)
	if max_x < top_r.x - 4.0:
		_add_collision_polygon(
			parent,
			PackedVector2Array([
				Vector2(max_x, bar_top_y),
				top_r,
				front_r,
				Vector2(max_x, front_r.y),
			])
		)


static func _add_collision_polygon(parent: StaticBody2D, poly: PackedVector2Array) -> void:
	if poly.size() < 3:
		return
	var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	shape.points = poly
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	parent.add_child(col)


static func _add_wall_strip_on_edge(
	parent: StaticBody2D,
	seg_a: Vector2,
	seg_b: Vector2,
	centroid: Vector2,
	thickness_outward: float,
	thickness_inward: float
) -> void:
	var normal_out: Vector2 = RoomPerspective.outward_normal_for_edge(seg_a, seg_b, centroid)
	var poly: PackedVector2Array = PackedVector2Array([
		seg_a - normal_out * thickness_inward,
		seg_b - normal_out * thickness_inward,
		seg_b + normal_out * thickness_outward,
		seg_a + normal_out * thickness_outward,
	])
	var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	shape.points = poly
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	parent.add_child(col)


static func _add_wall_edge_with_door_gap(
	parent: StaticBody2D,
	seg_a: Vector2,
	seg_b: Vector2,
	door_center: Vector2,
	gap_half: float,
	centroid: Vector2
) -> void:
	var door_on_seg: Vector2 = RoomPerspective.project_point_on_segment(door_center, seg_a, seg_b)
	var edge: Vector2 = seg_b - seg_a
	var gap_vec: Vector2 = edge.normalized() * gap_half
	if door_on_seg.distance_to(seg_a) > gap_half + 4.0:
		_add_wall_strip_on_edge(parent, seg_a, door_on_seg - gap_vec, centroid, Room.WALL_THICKNESS, 0.0)
	if door_on_seg.distance_to(seg_b) > gap_half + 4.0:
		_add_wall_strip_on_edge(parent, door_on_seg + gap_vec, seg_b, centroid, Room.WALL_THICKNESS, 0.0)


static func _add_capsule_wall_on_edge(
	parent: StaticBody2D,
	seg_a: Vector2,
	seg_b: Vector2,
	centroid: Vector2,
	thickness: float,
	extend_a: float = Room.WALL_CAPSULE_OVERLAP,
	extend_b: float = Room.WALL_CAPSULE_OVERLAP
) -> void:
	var edge: Vector2 = seg_b - seg_a
	var length: float = edge.length()
	if length < 1.0:
		return
	var dir: Vector2 = edge / length
	var start: Vector2 = seg_a - dir * extend_a
	var end: Vector2 = seg_b + dir * extend_b
	var span: Vector2 = end - start
	var span_len: float = span.length()
	if span_len < 1.0:
		return
	var radius: float = thickness * 0.5
	var normal_out: Vector2 = RoomPerspective.outward_normal_for_edge(seg_a, seg_b, centroid)
	var mid: Vector2 = (start + end) * 0.5 + normal_out * radius
	var capsule: CapsuleShape2D = CapsuleShape2D.new()
	capsule.radius = radius
	capsule.height = maxf(span_len - thickness, 0.01)
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = capsule
	col.position = mid
	col.rotation = span.angle() + PI * 0.5
	parent.add_child(col)


static func _add_capsule_wall_edge_with_door_gap(
	parent: StaticBody2D,
	seg_a: Vector2,
	seg_b: Vector2,
	door_center: Vector2,
	gap_half: float,
	centroid: Vector2
) -> void:
	var door_on_seg: Vector2 = RoomPerspective.project_point_on_segment(door_center, seg_a, seg_b)
	var edge: Vector2 = seg_b - seg_a
	var gap_vec: Vector2 = edge.normalized() * gap_half
	if door_on_seg.distance_to(seg_a) > gap_half + 4.0:
		_add_capsule_wall_on_edge(
			parent,
			seg_a,
			door_on_seg - gap_vec,
			centroid,
			Room.WALL_THICKNESS,
			Room.WALL_CAPSULE_OVERLAP,
			0.0
		)
	if door_on_seg.distance_to(seg_b) > gap_half + 4.0:
		_add_capsule_wall_on_edge(
			parent,
			door_on_seg + gap_vec,
			seg_b,
			centroid,
			Room.WALL_THICKNESS,
			0.0,
			Room.WALL_CAPSULE_OVERLAP
		)
