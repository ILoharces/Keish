extends Node2D
class_name Furniture

# Mueble: vacio / con item / con trampa (oculta). Abierto = desplazado para inspeccionar o poner trampa.

@warning_ignore("unused_signal")
signal item_taken(item_id: int, spy: SpyBase)
@warning_ignore("unused_signal")
signal trap_triggered(trap_id: int, spy: SpyBase)
signal opened_changed(is_open: bool)

const SIZE: Vector2 = Vector2(40, 35)
const INTERACT_PADDING: float = 14.0
const INSPECT_LIFT_PX: float = 14.0
const INSPECT_SLIDE_PX: float = 22.0

enum State { EMPTY, HAS_ITEM, HAS_WEAPON, HAS_TRAP }

@export var kind: int = ItemDB.FurnitureKind.DRAWERS

var state: int = State.EMPTY
var hidden_item: int = -1
var hidden_weapon_id: StringName = &""
var trap_id: int = -1
var trapper_id: int = -1
var owning_room: Room = null
var timed_bomb_timer: Timer = null
var is_open: bool = false
var _inspect_visual_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("furniture")
	_build_collider()
	_build_interact_zone()
	queue_redraw()


func _process(_delta: float) -> void:
	z_index = int(position.y)


func is_raised_open() -> bool:
	return is_open


func raise_open(opener: Node2D = null) -> void:
	if is_open:
		return
	is_open = true
	if kind == ItemDB.FurnitureKind.PAINTING:
		_inspect_visual_offset = _painting_slide_offset(opener)
	else:
		_inspect_visual_offset = Vector2(0.0, -INSPECT_LIFT_PX)
	opened_changed.emit(true)
	queue_redraw()


func lower_close() -> void:
	if not is_open:
		return
	is_open = false
	_inspect_visual_offset = Vector2.ZERO
	opened_changed.emit(false)
	queue_redraw()


func _painting_slide_offset(opener: Node2D) -> Vector2:
	var dir: float = 1.0
	if opener != null and opener.global_position.x >= global_position.x:
		dir = -1.0
	return Vector2(INSPECT_SLIDE_PX * dir, 0.0)


func _draw() -> void:
	var depth: float = 0.55
	if owning_room != null:
		depth = owning_room.get_depth_at_local(position)
	var w: float = lerpf(SIZE.x * 0.62, SIZE.x, depth)
	var h: float = lerpf(SIZE.y * 0.5, SIZE.y, depth)
	var col: Color = ItemDB.FURNITURE_COLORS.get(kind, Color.GRAY)
	var offset: Vector2 = _inspect_visual_offset
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(-w * 0.5, h * 0.5) + offset,
		Vector2(w * 0.5, h * 0.5) + offset,
		Vector2(w * 0.5, -h * 0.5) + offset,
		Vector2(-w * 0.5, -h * 0.5) + offset,
	])
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), ItemDB.COLOR_OUTLINE, 2.0, true)
	_draw_kind_label(w, h, offset)
	if is_open and state == State.HAS_WEAPON and not hidden_weapon_id.is_empty():
		_draw_hidden_weapon(w, h, offset)


func _draw_hidden_weapon(_w: float, h: float, offset: Vector2) -> void:
	var weapon: WeaponData = WeaponDB.get_weapon(hidden_weapon_id)
	var col: Color = weapon.hold_color if weapon != null else Color("#9e9e9e")
	var center: Vector2 = Vector2(0.0, -h * 0.08) + offset
	draw_circle(center, 7.0, col)
	draw_arc(center, 7.0, 0.0, TAU, 12, ItemDB.COLOR_OUTLINE, 1.5, false)


func _draw_kind_label(_w: float, h: float, offset: Vector2) -> void:
	var label: String = ItemDB.get_furniture_name(kind)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 11
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var base: Vector2 = Vector2(-text_size.x * 0.5, h * 0.55 + 2.0) + offset
	var shadow: Color = Color(0.0, 0.0, 0.0, 0.85)
	var text_col: Color = Color(0.98, 0.98, 0.98, 0.95)
	draw_string(font, base + Vector2(1.0, 1.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow)
	draw_string(font, base, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)


func _build_collider() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = SIZE
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _build_interact_zone() -> void:
	var area: Area2D = Area2D.new()
	area.name = "InteractZone"
	area.collision_layer = 4
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = SIZE + Vector2.ONE * INTERACT_PADDING * 2.0
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	area.add_child(col)
	add_child(area)


func hide_item(item_id: int) -> void:
	hidden_item = item_id
	state = State.HAS_ITEM


func hide_weapon(weapon_id: StringName) -> void:
	if weapon_id.is_empty():
		return
	hidden_weapon_id = weapon_id
	state = State.HAS_WEAPON


func set_trap(new_trap_id: int, owner_spy_id: int) -> bool:
	if not is_open or state != State.EMPTY:
		return false
	trap_id = new_trap_id
	trapper_id = owner_spy_id
	state = State.HAS_TRAP
	lower_close()
	return true


func interact(spy: SpyBase) -> Dictionary:
	var result: Dictionary = {
		"item_found": -1,
		"weapon_found": &"",
		"trap_triggered": -1,
		"trap_disarmed": false,
		"should_close": false,
	}
	match state:
		State.EMPTY:
			pass
		State.HAS_ITEM:
			var found: int = hidden_item
			hidden_item = -1
			state = State.EMPTY
			result["item_found"] = found
			item_taken.emit(found, spy)
		State.HAS_WEAPON:
			var found_weapon: StringName = hidden_weapon_id
			hidden_weapon_id = &""
			state = State.EMPTY
			result["weapon_found"] = found_weapon
		State.HAS_TRAP:
			var counter_id: int = ItemDB.get_counter_for_trap(trap_id)
			if GameState.consume_counter(spy.spy_id, counter_id):
				result["trap_disarmed"] = true
			else:
				result["trap_triggered"] = trap_id
				trap_triggered.emit(trap_id, spy)
			trap_id = -1
			trapper_id = -1
			state = State.EMPTY
			_cancel_timed_bomb()
			result["should_close"] = true
	return result


func _cancel_timed_bomb() -> void:
	if timed_bomb_timer != null and is_instance_valid(timed_bomb_timer):
		timed_bomb_timer.queue_free()
		timed_bomb_timer = null


func has_item() -> bool:
	return state == State.HAS_ITEM


func has_weapon() -> bool:
	return state == State.HAS_WEAPON


func is_empty() -> bool:
	return state == State.EMPTY
