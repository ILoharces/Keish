extends Area2D
class_name DroppedItem

# Objeto en el suelo. Se recoge con la accion interactuar (E), no al pasar encima.

var item_id: int = -1


func _ready() -> void:
	add_to_group("dropped_item")
	add_to_group("ground_pickup")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	z_index = int(position.y)
	var col: CollisionShape2D = CollisionShape2D.new()
	var sh: CircleShape2D = CircleShape2D.new()
	sh.radius = 18.0
	col.shape = sh
	add_child(col)
	queue_redraw()


func _draw() -> void:
	if item_id < 0:
		return
	var col: Color = ItemDB.ITEM_COLORS.get(item_id, Color.WHITE)
	draw_circle(Vector2.ZERO, 10.0, col)
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 12, ItemDB.COLOR_OUTLINE, 2.0, false)
	var label: String = ItemDB.get_item_name(item_id)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 11
	var text_w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(
		font,
		Vector2(-text_w * 0.5, -22.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		ItemDB.COLOR_OUTLINE
	)


func get_pickup_label() -> String:
	return ItemDB.get_item_name(item_id)
