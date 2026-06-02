class_name OrbitalTargetRing
extends Control

const RING_RADIUS: float = 26.0
const RING_COLOR: Color = Color(0.92, 0.12, 0.12, 0.42)
const RING_OUTLINE: Color = Color(1.0, 0.2, 0.2, 0.72)


func _ready() -> void:
	var diameter: float = RING_RADIUS * 2.0
	custom_minimum_size = Vector2(diameter, diameter)
	size = Vector2(diameter, diameter)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_circle(center, RING_RADIUS, RING_COLOR)
	draw_arc(center, RING_RADIUS, 0.0, TAU, 32, RING_OUTLINE, 2.0, true)
	draw_circle(center, 4.0, RING_OUTLINE)
