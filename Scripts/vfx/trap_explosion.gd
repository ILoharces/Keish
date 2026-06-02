extends Node2D
class_name TrapExplosion

# Efecto breve de explosion para trampas letales (p. ej. bomba).

const DURATION: float = 0.45

var _elapsed: float = 0.0


func _ready() -> void:
	z_index = 2048
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = _elapsed / DURATION
	var alpha: float = 1.0 - t
	var outer_r: float = lerpf(10.0, 40.0, t)
	var inner_r: float = lerpf(5.0, 22.0, t)
	draw_circle(Vector2.ZERO, outer_r, Color(1.0, 0.35, 0.05, alpha * 0.65))
	draw_circle(Vector2.ZERO, inner_r, Color(1.0, 0.92, 0.45, alpha * 0.9))
	draw_circle(Vector2.ZERO, inner_r * 0.45, Color(1.0, 1.0, 0.95, alpha))
