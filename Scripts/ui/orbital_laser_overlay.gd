class_name OrbitalLaserOverlay
extends CanvasLayer

const HOLD_DURATION: float = 0.3
const FADE_DURATION: float = 0.12
const LASER_CORE: Color = Color(0.94, 0.1, 0.1, 0.95)
const LASER_GLOW: Color = Color(1.0, 0.18, 0.18, 0.38)
const IMPACT_CORE: Color = Color(1.0, 0.35, 0.35, 0.92)
const IMPACT_RING: Color = Color(1.0, 0.12, 0.12, 0.45)

var _drawer: Control = null
var _beam_start: Vector2 = Vector2.ZERO
var _beam_end: Vector2 = Vector2.ZERO
var _impact_pos: Vector2 = Vector2.ZERO
var _active: bool = false
var _alpha: float = 1.0
var _fade_tween: Tween = null


func _ready() -> void:
	layer = 30
	_drawer = Control.new()
	_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer.draw.connect(_on_draw)
	add_child(_drawer)
	visible = false


func play_strike(
	_attacker_spy_id: int,
	target_screen_pos: Vector2,
	_hud: Hud,
	on_impact: Callable = Callable()
) -> void:
	if _fade_tween != null and is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_impact_pos = target_screen_pos
	_beam_start = Vector2(target_screen_pos.x, 0.0)
	_beam_end = target_screen_pos
	_alpha = 1.0
	_active = true
	visible = true
	if _drawer != null:
		_drawer.queue_redraw()
	if on_impact.is_valid():
		on_impact.call()
	_fade_tween = create_tween()
	_fade_tween.tween_interval(HOLD_DURATION)
	_fade_tween.tween_method(_set_alpha, 1.0, 0.0, FADE_DURATION)
	_fade_tween.tween_callback(_finish_strike)


func _set_alpha(value: float) -> void:
	_alpha = value
	if _drawer != null:
		_drawer.queue_redraw()


func _finish_strike() -> void:
	_active = false
	_alpha = 1.0
	visible = false
	_fade_tween = null
	if _drawer != null:
		_drawer.queue_redraw()


func _on_draw() -> void:
	if not _active:
		return
	_drawer.draw_line(_beam_start, _beam_end, _fade_color(LASER_GLOW), 12.0, true)
	_drawer.draw_line(_beam_start, _beam_end, _fade_color(LASER_CORE), 4.0, true)
	_drawer.draw_circle(_impact_pos, 22.0, _fade_color(IMPACT_RING))
	_drawer.draw_circle(_impact_pos, 10.0, _fade_color(IMPACT_CORE))


func _fade_color(color: Color) -> Color:
	return Color(color.r, color.g, color.b, color.a * _alpha)
