class_name LayoutMetrics
extends RefCounted

# Rectángulos calculados una vez por frame de layout (pantalla → UI de partida).

var screen_size: Vector2 = Vector2.ZERO
var mid_y: float = 0.0
var margin_left: float = 0.0
var border: float = 0.0
var views_inner_width: float = 0.0
var views_outer_width: float = 0.0
var views_inner_height: float = 0.0
var central_panel_width: float = 0.0
var stats_panel_width: float = 0.0
var view_half_height: int = 0
var view_width: int = 0


func views_outer_rect() -> Rect2:
	return Rect2(margin_left, 0.0, views_outer_width, screen_size.y)


func views_inner_rect() -> Rect2:
	return Rect2(
		margin_left + border,
		border,
		views_inner_width,
		views_inner_height,
	)


func side_panels_left() -> float:
	return margin_left + views_outer_width


func central_panel_left() -> float:
	return side_panels_left()


func stats_panel_left() -> float:
	return central_panel_left() + central_panel_width


func central_panel_rect() -> Rect2:
	return Rect2(
		central_panel_left(),
		0.0,
		central_panel_width,
		screen_size.y,
	)


func stats_panel_rect() -> Rect2:
	return Rect2(
		stats_panel_left(),
		0.0,
		stats_panel_width,
		screen_size.y,
	)


func game_column_rect() -> Rect2:
	return Rect2(margin_left, 0.0, views_outer_width, screen_size.y)
