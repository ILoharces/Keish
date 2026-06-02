extends Node

# Métricas de pantalla, tamaño de habitación y zoom de cámara.

const _LayoutMetrics := preload("res://Scripts/core/layout_metrics.gd")

const STATS_PANEL_RATIO: float = 0.28
const STATS_PANEL_MIN_WIDTH: int = 280
const CENTRAL_PANEL_MIN_WIDTH: int = 200
const GAME_MARGIN_LEFT: int = 16
const ROOM_GRID_SPACING: int = 4000
const ROOM_SCALE: float = 1.0
const ROOM_ASPECT: float = 1.55
const CAMERA_FILL_BIAS: float = 1.12

var room_width: int = 960
var room_height: int = 540
var _metrics: RefCounted = _LayoutMetrics.new()


func compute_layout(screen: Vector2) -> RefCounted:
	var sz: Vector2 = screen
	if sz.x < 64.0 or sz.y < 64.0:
		sz = Vector2(1280.0, 720.0)
	var border: float = float(NesUiTheme.BORDER_WIDTH)
	var inner_h: float = maxf(sz.y - border * 2.0, 128.0)
	var half_h: int = maxi(int(inner_h * 0.5), 64)
	var inner_w: int = maxi(int(round(float(half_h) * ROOM_ASPECT)), 64)
	var game_right: float = float(GAME_MARGIN_LEFT) + float(inner_w) + border * 2.0
	var right_total: float = maxf(sz.x - game_right, float(STATS_PANEL_MIN_WIDTH + CENTRAL_PANEL_MIN_WIDTH))
	var stats_w: float = float(maxi(int(sz.x * STATS_PANEL_RATIO), STATS_PANEL_MIN_WIDTH))
	stats_w = minf(stats_w, right_total - float(CENTRAL_PANEL_MIN_WIDTH))
	var central_w: float = right_total - stats_w
	_metrics.screen_size = sz
	_metrics.margin_left = float(GAME_MARGIN_LEFT)
	_metrics.border = border
	_metrics.mid_y = sz.y * 0.5
	_metrics.views_inner_width = float(inner_w)
	_metrics.views_outer_width = float(inner_w) + border * 2.0
	_metrics.views_inner_height = inner_h
	_metrics.central_panel_width = central_w
	_metrics.stats_panel_width = stats_w
	_metrics.view_half_height = half_h
	_metrics.view_width = inner_w
	update_room_size_for_view(inner_w, half_h)
	return _metrics


func sync_to_window() -> void:
	compute_layout(Vector2(DisplayServer.window_get_size()))


func get_metrics() -> RefCounted:
	return _metrics


func update_room_size_for_view(vp_w: int, vp_h: int) -> void:
	room_height = vp_h
	room_width = vp_w


func get_camera_zoom_for_size(vp_w: int, vp_h: int) -> Vector2:
	var bounds: Rect2 = RoomPerspective.visible_content_rect(float(room_width), float(room_height))
	if bounds.size.x <= 1.0 or bounds.size.y <= 1.0:
		var z_fallback: float = maxf(float(vp_w) / float(room_width), float(vp_h) / float(room_height))
		z_fallback *= CAMERA_FILL_BIAS
		return Vector2(z_fallback, z_fallback)
	var zx: float = float(vp_w) / bounds.size.x
	var zy: float = float(vp_h) / bounds.size.y
	var z: float = maxf(zx, zy) * CAMERA_FILL_BIAS
	return Vector2(z, z)


func get_stats_panel_left() -> float:
	return _metrics.stats_panel_left()


func get_game_column_rect(_screen_size: Vector2) -> Rect2:
	return _metrics.game_column_rect()


func get_mid_y() -> float:
	return _metrics.mid_y
