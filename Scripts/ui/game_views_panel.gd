class_name GameViewsPanel
extends Control

# Columna izquierda: dos vistas de cámara (jugador / oponente) en VBox 50/50.

const VIEW_BORDER_PX: float = 2.0
const VIEW_BORDER_COLOR: Color = Color("#000000")
const DEATH_OVERLAY_COLOR: Color = Color("#707070", 0.95)
const DEATH_OVERLAY_Z: int = 70

signal views_resized
signal shared_room_layout_changed(active: bool)

@onready var _vbox: VBoxContainer = $VBox
@onready var player_view: SubViewportContainer = $VBox/PlayerView
@onready var ai_view: SubViewportContainer = $VBox/AiView
@onready var player_viewport: SubViewport = $VBox/PlayerView/PlayerViewport
@onready var ai_viewport: SubViewport = $VBox/AiView/AiViewport
@onready var mansion: Mansion = $VBox/PlayerView/PlayerViewport/Mansion
@onready var _player_label: Label = $PlayerLabel
@onready var _ai_label: Label = $AiLabel

var player_camera: Camera2D = null
var ai_camera: Camera2D = null
var _spies_share_room: bool = false
var _top_view_blackout: ColorRect = null
var _death_overlays: Dictionary = {}


func _ready() -> void:
	_prepare_viewport(player_viewport)
	_prepare_viewport(ai_viewport)
	_vbox.add_theme_constant_override("separation", 0)
	for view: SubViewportContainer in [player_view, ai_view]:
		view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		view.custom_minimum_size = Vector2.ZERO
		view.stretch = true
		view.resized.connect(_on_any_view_resized)
	NesUiTheme.style_spy_label(_player_label)
	NesUiTheme.style_spy_label(_ai_label)
	_player_label.text = "BLANCO"
	_ai_label.text = "NEGRO"
	_player_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ai_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_on_panel_resized)
	GameState.respawn_started.connect(_on_respawn_started)
	GameState.respawn_tick.connect(_on_respawn_tick)
	GameState.respawn_finished.connect(_on_respawn_finished)
	call_deferred("_on_panel_resized")


func _draw() -> void:
	for view: Control in [player_view, ai_view]:
		if view == null:
			continue
		var rect: Rect2 = _local_rect_for(view)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		draw_rect(rect, VIEW_BORDER_COLOR, false, VIEW_BORDER_PX)


func _on_panel_resized() -> void:
	_sync_all_viewports()
	_update_label_positions()
	queue_redraw()
	views_resized.emit()


func _on_any_view_resized() -> void:
	_sync_all_viewports()
	_update_label_positions()
	queue_redraw()
	views_resized.emit()


func apply_outer_rect(rect: Rect2) -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	offset_left = rect.position.x
	offset_top = rect.position.y
	offset_right = rect.end.x
	offset_bottom = rect.end.y
	queue_redraw()
	call_deferred("_on_panel_resized")


func _update_label_positions() -> void:
	var pad: float = 8.0
	if player_view != null:
		var player_rect: Rect2 = _local_rect_for(player_view)
		_player_label.position = player_rect.position + Vector2(VIEW_BORDER_PX + pad, VIEW_BORDER_PX + 6.0)
	if ai_view != null:
		var ai_rect: Rect2 = _local_rect_for(ai_view)
		_ai_label.position = ai_rect.position + Vector2(VIEW_BORDER_PX + pad, VIEW_BORDER_PX + 6.0)


func _local_rect_for(control: Control) -> Rect2:
	var top_left: Vector2 = control.global_position
	var local_top: Vector2 = get_global_transform().affine_inverse() * top_left
	return Rect2(local_top, control.size)


func get_player_view_global_rect() -> Rect2:
	if player_view == null:
		return Rect2()
	return player_view.get_global_rect()


func get_ai_view_global_rect() -> Rect2:
	if ai_view == null:
		return Rect2()
	return ai_view.get_global_rect()


func get_game_column_global_rect() -> Rect2:
	return get_global_rect()


func get_aim_views_global_rect() -> Rect2:
	var player_rect: Rect2 = get_player_view_global_rect()
	var ai_rect: Rect2 = get_ai_view_global_rect()
	if player_rect.size == Vector2.ZERO and ai_rect.size == Vector2.ZERO:
		return get_global_rect()
	if player_rect.size == Vector2.ZERO:
		return ai_rect
	if ai_rect.size == Vector2.ZERO:
		return player_rect
	var top_left: Vector2 = Vector2(
		minf(player_rect.position.x, ai_rect.position.x),
		minf(player_rect.position.y, ai_rect.position.y),
	)
	var bottom_right: Vector2 = Vector2(
		maxf(player_rect.end.x, ai_rect.end.x),
		maxf(player_rect.end.y, ai_rect.end.y),
	)
	return Rect2(top_left, bottom_right - top_left)


func clamp_to_aim_views(screen_pos: Vector2) -> Vector2:
	var bounds: Rect2 = get_aim_views_global_rect()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return screen_pos
	return Vector2(
		clampf(screen_pos.x, bounds.position.x, bounds.end.x),
		clampf(screen_pos.y, bounds.position.y, bounds.end.y),
	)


func spies_share_room() -> bool:
	return _spies_share_room


func get_shared_room() -> Room:
	if not _spies_share_room or mansion == null or mansion.player == null:
		return null
	return mansion.player.current_room


func get_viewport_for_container(container: SubViewportContainer) -> SubViewport:
	if container == player_view:
		return player_viewport
	if container == ai_view:
		return ai_viewport
	return null


func get_camera_for_container(container: SubViewportContainer) -> Camera2D:
	if container == player_view:
		return player_camera
	if container == ai_view:
		return ai_camera
	return null


func get_room_for_container(container: SubViewportContainer) -> Room:
	if mansion == null:
		return null
	if container == player_view:
		return mansion.player.current_room if mansion.player != null else null
	var bottom_spy: SpyBase = mansion.get_bottom_spy()
	return bottom_spy.current_room if bottom_spy != null else null


func get_player_view_size_i() -> Vector2i:
	return _view_size_i(player_view)


func get_ai_view_size_i() -> Vector2i:
	return _view_size_i(ai_view)


func _view_size_i(view: SubViewportContainer) -> Vector2i:
	if view == null:
		return Vector2i.ZERO
	var measured: Vector2 = view.get_size()
	if measured.x > 1.0 and measured.y > 1.0:
		return Vector2i(measured.floor())
	for child: Node in view.get_children():
		if child is SubViewport:
			var vp: SubViewport = child as SubViewport
			if vp.size.x > 0 and vp.size.y > 0:
				return vp.size
	return Vector2i.ZERO


func ensure_cameras() -> void:
	if player_camera == null:
		player_camera = _make_camera()
		player_viewport.add_child(player_camera)
		player_camera.make_current()
	if ai_camera == null:
		ai_camera = _make_camera()
		ai_viewport.add_child(ai_camera)
		ai_camera.make_current()


func update_camera_zooms() -> void:
	var player_size: Vector2i = get_player_view_size_i()
	var ai_size: Vector2i = get_ai_view_size_i()
	if player_size.x > 0 and player_size.y > 0:
		var prev_w: int = DisplayConfig.room_width
		var prev_h: int = DisplayConfig.room_height
		DisplayConfig.update_room_size_for_view(player_size.x, player_size.y)
		if mansion != null and (prev_w != DisplayConfig.room_width or prev_h != DisplayConfig.room_height):
			mansion.notify_room_size_changed()
	if player_camera != null and player_size.x > 0 and player_size.y > 0:
		player_camera.zoom = DisplayConfig.get_camera_zoom_for_size(player_size.x, player_size.y)
	if ai_camera != null and ai_size.x > 0 and ai_size.y > 0:
		ai_camera.zoom = DisplayConfig.get_camera_zoom_for_size(ai_size.x, ai_size.y)
	snap_cameras()


func snap_cameras() -> void:
	if _spies_share_room and mansion != null and mansion.player != null and mansion.player.current_room != null:
		var center: Vector2 = mansion.player.current_room.get_center_world_pos()
		if player_camera != null:
			player_camera.global_position = center
		if ai_camera != null:
			ai_camera.global_position = center
		return
	if mansion.player != null and mansion.player.current_room != null and player_camera != null:
		player_camera.global_position = mansion.player.current_room.get_center_world_pos()
	var bottom_spy: SpyBase = mansion.get_bottom_spy()
	if bottom_spy != null and bottom_spy.current_room != null and ai_camera != null:
		ai_camera.global_position = bottom_spy.current_room.get_center_world_pos()


func refresh_spy_room_layout() -> void:
	var next_shared: bool = _compute_spies_share_room()
	if next_shared != _spies_share_room:
		_spies_share_room = next_shared
		_apply_shared_room_visuals(_spies_share_room)
	snap_cameras()


func _compute_spies_share_room() -> bool:
	if mansion == null or mansion.player == null:
		return false
	var bottom_spy: SpyBase = mansion.get_bottom_spy()
	if bottom_spy == null or not mansion.player.is_alive or not bottom_spy.is_alive:
		return false
	if mansion.player.current_room == null or bottom_spy.current_room == null:
		return false
	return mansion.player.current_room == bottom_spy.current_room


func _ensure_top_view_blackout() -> void:
	if _top_view_blackout != null or player_view == null:
		return
	_top_view_blackout = ColorRect.new()
	_top_view_blackout.name = "SharedRoomBlackout"
	_top_view_blackout.color = Color.BLACK
	_top_view_blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_view_blackout.visible = false
	_top_view_blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_top_view_blackout.z_index = 60
	player_view.add_child(_top_view_blackout)


func _apply_shared_room_visuals(active: bool) -> void:
	_ensure_top_view_blackout()
	if _top_view_blackout != null:
		_top_view_blackout.visible = active
	if player_viewport != null:
		player_viewport.render_target_update_mode = (
			SubViewport.UPDATE_DISABLED if active else SubViewport.UPDATE_WHEN_VISIBLE
		)
	if ai_viewport != null:
		ai_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	shared_room_layout_changed.emit(active)


func follow_cameras(game_started: bool) -> void:
	if not game_started:
		return
	refresh_spy_room_layout()


func _make_camera() -> Camera2D:
	var cam: Camera2D = Camera2D.new()
	cam.position_smoothing_enabled = false
	return cam


func _prepare_viewport(vp: SubViewport) -> void:
	if vp == null:
		return
	var backdrop: Node = vp.get_node_or_null("Backdrop")
	if backdrop != null:
		backdrop.queue_free()
	vp.transparent_bg = false


func _sync_all_viewports() -> void:
	_sync_viewport_to_container(player_view)
	_sync_viewport_to_container(ai_view)


func _sync_viewport_to_container(container: SubViewportContainer) -> void:
	if container == null:
		return
	var measured: Vector2 = container.get_size().floor()
	if measured.x <= 0.0 or measured.y <= 0.0:
		return
	for child: Node in container.get_children():
		if not child is SubViewport:
			continue
		var vp: SubViewport = child as SubViewport
		var target: Vector2i = Vector2i(measured)
		if vp.size != target:
			vp.size = target


func _on_respawn_started(spy_id: int, duration: float) -> void:
	show_death_overlay(spy_id, duration)


func _on_respawn_tick(spy_id: int, remaining: float) -> void:
	update_death_countdown(spy_id, remaining)


func _on_respawn_finished(spy_id: int) -> void:
	hide_death_overlay(spy_id)


func _view_for_spy(spy_id: int) -> SubViewportContainer:
	if spy_id == ItemDB.SpyId.PLAYER:
		return player_view
	if spy_id == ItemDB.SpyId.AI:
		return ai_view
	return null


func _ensure_death_overlay(spy_id: int) -> Control:
	if _death_overlays.has(spy_id):
		var existing: Control = _death_overlays[spy_id].get("root") as Control
		if existing != null and is_instance_valid(existing):
			return existing
	var view: SubViewportContainer = _view_for_spy(spy_id)
	if view == null:
		return null
	var root: Control = Control.new()
	root.name = "DeathOverlay"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	root.z_index = DEATH_OVERLAY_Z
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = DEATH_OVERLAY_COLOR
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)
	var title: Label = Label.new()
	title.text = "Be right back"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", NesUiTheme.FONT_SPY + 4)
	title.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT)
	title.add_theme_font_override("font", NesUiTheme.mono_font())
	vbox.add_child(title)
	var countdown: Label = Label.new()
	countdown.name = "Countdown"
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown.add_theme_font_size_override("font_size", NesUiTheme.FONT_TIMER)
	countdown.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT)
	countdown.add_theme_font_override("font", NesUiTheme.mono_font())
	vbox.add_child(countdown)
	view.add_child(root)
	_death_overlays[spy_id] = {"root": root, "countdown": countdown}
	return root


func show_death_overlay(spy_id: int, duration: float) -> void:
	var root: Control = _ensure_death_overlay(spy_id)
	if root == null:
		return
	update_death_countdown(spy_id, duration)
	root.visible = true


func update_death_countdown(spy_id: int, remaining: float) -> void:
	if not _death_overlays.has(spy_id):
		return
	var countdown: Label = _death_overlays[spy_id].get("countdown") as Label
	if countdown == null:
		return
	countdown.text = "%.2f" % maxf(0.0, remaining)


func hide_death_overlay(spy_id: int) -> void:
	if not _death_overlays.has(spy_id):
		return
	var root: Control = _death_overlays[spy_id].get("root") as Control
	if root != null and is_instance_valid(root):
		root.visible = false
