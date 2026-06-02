extends Node2D
class_name SouthWallBar

# Barra de pared sur; mismo z_index que la puerta sur para ordenarse con el jugador.

const OUTLINE_W: float = 2.5

var owning_room: Room = null
var _local_bar: PackedVector2Array = PackedVector2Array()
var _local_gap: PackedVector2Array = PackedVector2Array()


func setup(room: Room) -> void:
	owning_room = room
	_rebuild_polygons()
	queue_redraw()


func _process(_delta: float) -> void:
	if owning_room == null:
		return
	var south_door: Door = owning_room.get_door_for_direction("S")
	if south_door != null and is_instance_valid(south_door):
		z_index = south_door.z_index
	else:
		var rw: float = owning_room.get_room_w()
		var rh: float = owning_room.get_room_h()
		var bar: PackedVector2Array = RoomPerspective.south_wall_bar_polygon(rw, rh)
		var center: Vector2 = _polygon_centroid(bar)
		z_index = int(center.y) + 2


func _rebuild_polygons() -> void:
	if owning_room == null:
		return
	var rw: float = owning_room.get_room_w()
	var rh: float = owning_room.get_room_h()
	var bar: PackedVector2Array = RoomPerspective.south_wall_bar_polygon(rw, rh)
	var center: Vector2 = _polygon_centroid(bar)
	position = center
	_local_bar.clear()
	for p: Vector2 in bar:
		_local_bar.append(p - center)
	_local_gap.clear()
	if owning_room.has_door_s:
		var gap: PackedVector2Array = RoomPerspective.get_door_polygon("S", rw, rh)
		for p: Vector2 in gap:
			_local_gap.append(p - center)


func _draw() -> void:
	if _local_bar.size() < 3:
		return
	var wall_col: Color = ItemDB.COLOR_WALL
	var outline: Color = ItemDB.COLOR_OUTLINE
	draw_colored_polygon(_local_bar, wall_col)
	draw_polyline(_local_bar + PackedVector2Array([_local_bar[0]]), outline, OUTLINE_W, true)
	if _local_gap.size() >= 3:
		draw_colored_polygon(_local_gap, ItemDB.COLOR_DOOR_GAP)
		draw_polyline(_local_gap + PackedVector2Array([_local_gap[0]]), outline, OUTLINE_W, true)


static func _polygon_centroid(poly: PackedVector2Array) -> Vector2:
	if poly.is_empty():
		return Vector2.ZERO
	var sum: Vector2 = Vector2.ZERO
	for p: Vector2 in poly:
		sum += p
	return sum / float(poly.size())
