class_name MainLayout
extends RefCounted

# Orquesta layout de pantalla: métricas → paneles → HUD → minimapa.

const MAP_OVERLAY_PAD: float = 28.0

var main: Main = null


func _init(p_main: Main) -> void:
	main = p_main


func setup() -> void:
	setup_screen_bg()
	setup_map_overlay()
	apply_layout()


func setup_screen_bg() -> void:
	var bg: ColorRect = main.get_node("Background") as ColorRect
	if bg != null:
		bg.color = NesUiTheme.COLOR_BG


func setup_map_overlay() -> void:
	main._map_overlay = Control.new()
	main._map_overlay.name = "MapOverlay"
	main._map_overlay.visible = false
	main._map_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	main._map_overlay.add_to_group("map_overlay_root")
	main.game_root.add_child(main._map_overlay)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color("#000000")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main._map_overlay.add_child(backdrop)
	main._map_panel = Minimap.new()
	main._map_panel.name = "Minimap"
	main._map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main._map_overlay.add_child(main._map_panel)


func apply_layout() -> void:
	var screen: Vector2 = main.get_viewport().get_visible_rect().size
	var metrics: LayoutMetrics = DisplayConfig.compute_layout(screen) as LayoutMetrics
	main.game_views.apply_outer_rect(metrics.views_outer_rect())
	_layout_side_dividers(metrics)
	if main.hud != null:
		main.hud.relayout_for_display()
	apply_map_overlay_layout(metrics)
	main.call_deferred("_refresh_viewport_layout")


func _layout_side_dividers(metrics: LayoutMetrics) -> void:
	if main._side_divider == null:
		main._side_divider = ColorRect.new()
		main._side_divider.name = "SideDivider"
		main._side_divider.color = NesUiTheme.COLOR_BORDER
		main._side_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main.game_root.add_child(main._side_divider)
	if main._stats_divider == null:
		main._stats_divider = ColorRect.new()
		main._stats_divider.name = "StatsDivider"
		main._stats_divider.color = NesUiTheme.COLOR_BORDER
		main._stats_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main.game_root.add_child(main._stats_divider)
	var side_x: float = metrics.central_panel_left() - metrics.border
	main._side_divider.position = Vector2(side_x, 0.0)
	main._side_divider.size = Vector2(metrics.border, metrics.screen_size.y)
	var stats_x: float = metrics.stats_panel_left() - metrics.border
	main._stats_divider.position = Vector2(stats_x, 0.0)
	main._stats_divider.size = Vector2(metrics.border, metrics.screen_size.y)


func apply_map_overlay_layout(metrics: LayoutMetrics = null) -> void:
	if main._map_overlay == null:
		return
	if metrics == null:
		metrics = DisplayConfig.get_metrics() as LayoutMetrics
	main._map_overlay.position = Vector2(metrics.margin_left, 0.0)
	main._map_overlay.size = Vector2(metrics.views_outer_width, metrics.screen_size.y)
	if main._map_panel != null:
		var inset: float = MAP_OVERLAY_PAD
		var available: Vector2 = main._map_overlay.size - Vector2(inset * 2.0, inset * 2.0)
		var square_side: float = minf(available.x, available.y)
		var map_pos: Vector2 = Vector2(inset, inset) + (available - Vector2(square_side, square_side)) * 0.5
		main._map_panel.position = map_pos
		main._map_panel.size = Vector2(square_side, square_side)
		main._map_panel.custom_minimum_size = main._map_panel.size
	main.game_root.move_child(main._map_overlay, main.game_root.get_child_count() - 1)


func setup_cameras() -> void:
	main.game_views.ensure_cameras()
	main.game_views.update_camera_zooms()
	main.game_views.snap_cameras()


func update_camera_zooms() -> void:
	main.game_views.update_camera_zooms()


func snap_cameras() -> void:
	main.game_views.snap_cameras()


func follow_cameras() -> void:
	main.game_views.follow_cameras(main._game_started)
