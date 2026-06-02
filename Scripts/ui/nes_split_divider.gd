extends Control
class_name NesSplitDivider

# Divisor horizontal con muescas laterales (estilo NES Spy vs Spy).

const LINE_COLOR: Color = Color("#000000")
const NOTCH_COLOR: Color = Color("#d4d4d4")


func _draw() -> void:
	var h: float = size.y
	var w: float = size.x
	var mid: float = h * 0.5
	draw_line(Vector2(0.0, mid), Vector2(w, mid), LINE_COLOR, maxf(2.0, h))

	var notch_w: float = 10.0
	var notch_h: float = h * 2.5
	# Muesca izquierda
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, mid - notch_h * 0.5),
			Vector2(notch_w, mid),
			Vector2(0.0, mid + notch_h * 0.5),
		]),
		NOTCH_COLOR,
	)
	# Muesca derecha
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(w, mid - notch_h * 0.5),
			Vector2(w - notch_w, mid),
			Vector2(w, mid + notch_h * 0.5),
		]),
		NOTCH_COLOR,
	)
