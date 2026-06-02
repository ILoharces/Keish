extends Node2D
class_name Door

# Panel de puerta sobre el hueco (negro en la pared). Cerrada = visible; abierta = oculta.
# El pasaje solo funciona mientras la puerta esta abierta.

signal open_state_changed(is_open: bool)

const OUTLINE_W: float = 2.0
const INTERACT_PADDING: float = 10.0

var direction: String = "N"
var owning_room: Room = null
var partner: Door = null
var is_exit_door: bool = false
var is_open: bool = false
var _passage_area: Area2D = null
var _blocker_body: StaticBody2D = null
var _local_poly: PackedVector2Array = PackedVector2Array()
var _syncing_partner: bool = false


func _ready() -> void:
	add_to_group("door")


func _process(_delta: float) -> void:
	if owning_room != null:
		z_index = int(position.y) + 2


func refresh_from_room() -> void:
	if owning_room == null:
		return
	position = RoomPerspective.get_door_visual_center(
		direction, owning_room.get_room_w(), owning_room.get_room_h()
	)
	_rebuild_local_polygon()
	_build_blocker()
	_sync_blocker()
	_build_interact_zone()
	queue_redraw()


func setup(room: Room, dir_str: String, passage: Area2D) -> void:
	owning_room = room
	direction = dir_str
	_passage_area = passage
	position = RoomPerspective.get_door_visual_center(
		direction, room.get_room_w(), room.get_room_h()
	)
	_rebuild_local_polygon()
	_build_blocker()
	_build_interact_zone()
	_sync_passage()
	_sync_blocker()
	_update_visibility()
	queue_redraw()


func link_partner(other: Door) -> void:
	if other == null or other == self:
		return
	partner = other


func set_open(open: bool, propagate: bool = true) -> void:
	if is_open == open:
		return
	is_open = open
	_apply_open_state()
	if propagate and partner != null and is_instance_valid(partner) and not partner._syncing_partner:
		partner._syncing_partner = true
		partner.set_open(open, false)
		partner._syncing_partner = false


func can_spy_open(spy_id: int) -> bool:
	if not is_exit_door:
		return true
	return GameState.has_all_items(spy_id)


func try_toggle_for_spy(spy_id: int) -> bool:
	if is_open:
		set_open(false, true)
		return true
	if not can_spy_open(spy_id):
		GameState.exit_reached.emit(spy_id)
		return false
	set_open(true, true)
	return true


func try_open_for_spy(spy_id: int, propagate: bool = true) -> bool:
	if is_open:
		return true
	if not can_spy_open(spy_id):
		return false
	set_open(true, propagate)
	return true


func toggle() -> void:
	set_open(not is_open, true)


func _apply_open_state() -> void:
	_sync_passage()
	_sync_blocker()
	_update_visibility()
	open_state_changed.emit(is_open)
	queue_redraw()


func is_closed() -> bool:
	return not is_open


func _update_visibility() -> void:
	visible = is_closed()


func _sync_passage() -> void:
	if _passage_area != null and is_instance_valid(_passage_area):
		_passage_area.monitoring = is_open


func _sync_blocker() -> void:
	if _blocker_body == null or not is_instance_valid(_blocker_body):
		return
	_blocker_body.set_collision_layer_value(1, is_closed())


func _rebuild_local_polygon() -> void:
	if owning_room == null:
		return
	var rw: float = owning_room.get_room_w()
	var rh: float = owning_room.get_room_h()
	var poly: PackedVector2Array = RoomPerspective.get_door_polygon(direction, rw, rh)
	var center: Vector2 = RoomPerspective.get_door_visual_center(direction, rw, rh)
	_local_poly.clear()
	for p: Vector2 in poly:
		_local_poly.append(p - center)


func _get_blocker_polygon() -> PackedVector2Array:
	return _local_poly


func _build_blocker() -> void:
	var blocker_pts: PackedVector2Array = _get_blocker_polygon()
	if blocker_pts.size() < 3:
		return
	if _blocker_body != null and is_instance_valid(_blocker_body):
		_blocker_body.queue_free()
	_blocker_body = StaticBody2D.new()
	_blocker_body.name = "DoorBlocker"
	_blocker_body.collision_layer = 1
	_blocker_body.collision_mask = 0
	var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	shape.points = blocker_pts
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	_blocker_body.add_child(col)
	add_child(_blocker_body)


func _build_interact_zone() -> void:
	var existing: Area2D = get_node_or_null("InteractZone") as Area2D
	if existing != null:
		existing.queue_free()
	var area: Area2D = Area2D.new()
	area.name = "InteractZone"
	area.collision_layer = 4
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	if _local_poly.size() >= 3:
		var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
		shape.points = _expand_polygon(_local_poly, INTERACT_PADDING)
		var col: CollisionShape2D = CollisionShape2D.new()
		col.shape = shape
		area.add_child(col)
	add_child(area)


func _expand_polygon(poly: PackedVector2Array, padding: float) -> PackedVector2Array:
	if poly.size() < 3:
		return poly
	var centroid: Vector2 = Vector2.ZERO
	for p: Vector2 in poly:
		centroid += p
	centroid /= float(poly.size())
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in poly:
		var dir: Vector2 = (p - centroid).normalized()
		out.append(p + dir * padding)
	return out


func _draw() -> void:
	if is_open or _local_poly.size() < 3:
		return
	var panel_col: Color = ItemDB.COLOR_DOOR_EXIT if is_exit_door else ItemDB.COLOR_DOOR
	draw_colored_polygon(_local_poly, panel_col)
	draw_polyline(_local_poly + PackedVector2Array([_local_poly[0]]), ItemDB.COLOR_OUTLINE, OUTLINE_W, true)
