extends Area2D
class_name DroppedSuitcase

# Maletin en el suelo con todo el botin dentro. Se recoge con interactuar (E).

const PICKUP_RADIUS: float = 20.0

var owner_spy_id: int = -1
var stored_items: Array[int] = []


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("dropped_suitcase")
	add_to_group("ground_pickup")
	z_index = int(position.y)
	var col: CollisionShape2D = CollisionShape2D.new()
	var sh: CircleShape2D = CircleShape2D.new()
	sh.radius = PICKUP_RADIUS
	col.shape = sh
	add_child(col)
	queue_redraw()


func setup(owner_id: int, items: Array[int]) -> void:
	owner_spy_id = owner_id
	stored_items = items.duplicate()
	queue_redraw()


func _draw() -> void:
	var case_col: Color = ItemDB.ITEM_COLORS.get(ItemDB.ItemId.SUITCASE, Color.CYAN)
	draw_rect(Rect2(-14.0, -10.0, 28.0, 20.0), case_col)
	draw_rect(Rect2(-14.0, -10.0, 28.0, 20.0), ItemDB.COLOR_OUTLINE, false, 2.0)
	var handle_pts: PackedVector2Array = PackedVector2Array([
		Vector2(-6.0, -10.0),
		Vector2(6.0, -10.0),
		Vector2(6.0, -14.0),
		Vector2(-6.0, -14.0),
	])
	draw_colored_polygon(handle_pts, case_col.darkened(0.15))
	draw_polyline(handle_pts + PackedVector2Array([handle_pts[0]]), ItemDB.COLOR_OUTLINE, 2.0, true)
	var label: String = "Maletin"
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 10
	var text_w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(
		font,
		Vector2(-text_w * 0.5, 18.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		ItemDB.COLOR_OUTLINE
	)
	if stored_items.size() > 1:
		var loot_count: int = stored_items.size() - 1
		var count_text: String = "x%d" % loot_count
		var count_w: float = font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(
			font,
			Vector2(-count_w * 0.5, 30.0),
			count_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color(0.95, 0.95, 0.95, 0.95)
		)


func get_pickup_label() -> String:
	return "Maletin"
