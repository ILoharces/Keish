class_name AimCursorDot
extends Control

const DOT_SIZE: float = 14.0

var base_color: Color = Color.WHITE
var detail_color: Color = Color("#c03030")


func _ready() -> void:
	custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
	size = Vector2(DOT_SIZE, DOT_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = DOT_SIZE * 0.35
	draw_circle(center, radius, base_color)
	draw_arc(center, radius, 0.0, TAU, 12, detail_color, 1.5, false)
	var arm: Vector2 = Vector2(DOT_SIZE * 0.5, 0.0)
	draw_line(center - arm, center + arm, detail_color, 1.5)
	draw_line(center - Vector2(0.0, DOT_SIZE * 0.5), center + Vector2(0.0, DOT_SIZE * 0.5), detail_color, 1.5)
