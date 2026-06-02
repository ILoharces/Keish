class_name SpyVisual
extends RefCounted

# Dibujo placeholder del espía y objeto en mano.

const SPY_SCALE: float = SpyBase.COLLIDER_SCALE
const BODY_H_NEAR: float = 20.8
const BODY_H_FAR: float = 27.2
const BODY_W_NEAR: float = 11.2
const BODY_W_FAR: float = 14.4
const HEAD_R_NEAR: float = 5.6
const HEAD_R_FAR: float = 7.2
const HELD_W_NEAR: float = 22.0
const HELD_W_FAR: float = 28.0
const HELD_H_NEAR: float = 14.0
const HELD_H_FAR: float = 18.0
const HELD_LABEL_FONT_MAX: int = 9
const HELD_LABEL_FONT_MIN: int = 6
const PISTOL_GRIP_X: float = 0.55
const PISTOL_GRIP_Y: float = -0.05
const PISTOL_BODY_W_RATIO: float = 0.7
const PISTOL_BODY_H_RATIO: float = 0.7
const PISTOL_BARREL_W_RATIO: float = 0.55
const PISTOL_BARREL_H_RATIO: float = 0.4
const PISTOL_BARREL_X: float = 0.0
const PISTOL_BARREL_Y: float = -0.2
const WALK_TILT: float = 0.055
const WALK_BOB: float = 0.04

var host: SpyBase = null


func _init(p_host: SpyBase) -> void:
	host = p_host


func compute_metrics() -> Dictionary:
	var depth: float = _get_depth()
	var body_h: float = lerpf(BODY_H_NEAR, BODY_H_FAR, depth) * SPY_SCALE
	var body_w: float = lerpf(BODY_W_NEAR, BODY_W_FAR, depth) * SPY_SCALE
	var head_r: float = lerpf(HEAD_R_NEAR, HEAD_R_FAR, depth) * SPY_SCALE
	var foot_y: float = body_h * 0.45
	var body_top_y: float = -body_h * 0.45
	var head_top_y: float = body_top_y - head_r * 2.0
	var hit_h: float = foot_y - head_top_y
	var hit_w: float = body_w * 2.0
	var hit_center: Vector2 = Vector2(0.0, (foot_y + head_top_y) * 0.5)
	return {
		"depth": depth,
		"body_h": body_h,
		"body_w": body_w,
		"head_r": head_r,
		"foot_y": foot_y,
		"body_top_y": body_top_y,
		"head_top_y": head_top_y,
		"hitbox_size": Vector2(hit_w, hit_h),
		"hitbox_center": hit_center,
		"hit_radius": maxf(hit_w, hit_h) * 0.5,
	}


func draw() -> void:
	if host == null:
		return
	var metrics: Dictionary = compute_metrics()
	var depth: float = metrics["depth"] as float
	var body_h: float = metrics["body_h"] as float
	var body_w: float = metrics["body_w"] as float
	var head_r: float = metrics["head_r"] as float
	var col: Color = ItemDB.SPY_COLORS.get(host.spy_id, Color.WHITE)
	var outline: Color = ItemDB.COLOR_OUTLINE
	var walk_xf: Transform2D = _get_walk_transform(body_h)
	host.draw_set_transform_matrix(walk_xf)
	var body_pts: PackedVector2Array = PackedVector2Array([
		Vector2(-body_w, body_h * 0.45),
		Vector2(body_w, body_h * 0.45),
		Vector2(body_w, -body_h * 0.45),
		Vector2(-body_w, -body_h * 0.45),
	])
	host.draw_colored_polygon(body_pts, col)
	host.draw_polyline(body_pts + PackedVector2Array([body_pts[0]]), outline, 2.0, true)
	var head_c: Vector2 = Vector2(0.0, -body_h * 0.45 - head_r)
	host.draw_circle(head_c, head_r, col)
	host.draw_arc(head_c, head_r, 0.0, TAU, 16, outline, 2.0, false)
	_draw_held_item(depth, body_h, body_w, outline, walk_xf)
	host.draw_set_transform_matrix(Transform2D.IDENTITY)


func get_muzzle_local_offset() -> Vector2:
	return _weapon_point_local(_muzzle_weapon_local(), true)


func get_grip_local_offset() -> Vector2:
	return _weapon_point_local(Vector2.ZERO, true)


func _muzzle_weapon_local() -> Vector2:
	var depth: float = compute_metrics()["depth"] as float
	var held_w: float = lerpf(HELD_W_NEAR, HELD_W_FAR, depth) * SPY_SCALE
	var held_h: float = lerpf(HELD_H_NEAR, HELD_H_FAR, depth) * SPY_SCALE
	return Vector2(
		held_w * (PISTOL_BARREL_X + PISTOL_BARREL_W_RATIO),
		held_h * (PISTOL_BARREL_Y + PISTOL_BARREL_H_RATIO * 0.5)
	)


func _weapon_point_local(point_in_weapon_space: Vector2, apply_walk: bool) -> Vector2:
	var metrics: Dictionary = compute_metrics()
	var body_h: float = metrics["body_h"] as float
	var body_w: float = metrics["body_w"] as float
	var grip: Vector2 = Vector2(body_w * PISTOL_GRIP_X, body_h * PISTOL_GRIP_Y)
	var angle: float = host.aim_direction.angle() if host.aim_direction.length_squared() > 0.0001 else 0.0
	var weapon_xf: Transform2D = Transform2D(angle, grip)
	var local_pos: Vector2 = weapon_xf * point_in_weapon_space
	if apply_walk:
		local_pos = _get_walk_transform(body_h) * local_pos
	return local_pos


func _get_walk_transform(body_h: float) -> Transform2D:
	if host == null or host.velocity.length_squared() <= 64.0:
		return Transform2D.IDENTITY
	var anim: Dictionary = _get_walk_anim()
	var pivot: Vector2 = Vector2(0.0, body_h * 0.45)
	var bob: float = (anim["bob"] as float) * body_h * WALK_BOB
	var tilt: float = (anim["sway"] as float) * WALK_TILT
	return Transform2D.IDENTITY.translated(pivot + Vector2(0.0, bob)).rotated(tilt).translated(-pivot)


func _get_depth() -> float:
	if host.current_room == null:
		return 0.65
	var local_pos: Vector2 = host.global_position - host.current_room.global_position
	return host.current_room.get_depth_at_local(local_pos)


func _get_walk_anim() -> Dictionary:
	if host == null or host.velocity.length_squared() <= 64.0:
		return {"sway": 0.0, "bob": 0.0}
	var phase: float = host.walk_phase
	return {"sway": sin(phase), "bob": sin(phase * 2.0)}


func _draw_held_item(depth: float, body_h: float, body_w: float, outline: Color, walk_xf: Transform2D) -> void:
	if host.held == null or not host.held.is_holding():
		return
	if host.held.is_holding_weapon():
		_draw_held_weapon(depth, body_h, body_w, outline, walk_xf)
		return
	var held_w: float = lerpf(HELD_W_NEAR, HELD_W_FAR, depth) * SPY_SCALE
	var held_h: float = lerpf(HELD_H_NEAR, HELD_H_FAR, depth) * SPY_SCALE
	var center: Vector2 = Vector2(body_w * 0.72, -body_h * 0.05)
	var rect: Rect2 = Rect2(center - Vector2(held_w * 0.5, held_h * 0.5), Vector2(held_w, held_h))
	host.draw_rect(rect, host.held.get_display_color())
	host.draw_rect(rect, outline, false, 2.0)
	_draw_held_item_label(rect)


func _draw_held_weapon(depth: float, body_h: float, body_w: float, outline: Color, walk_xf: Transform2D) -> void:
	var weapon: WeaponData = WeaponDB.get_weapon(host.held.get_weapon_id())
	if weapon != null and weapon.orbital_strike:
		_draw_held_orbital_computer(depth, body_h, body_w, outline)
		return
	var held_w: float = lerpf(HELD_W_NEAR, HELD_W_FAR, depth) * SPY_SCALE
	var held_h: float = lerpf(HELD_H_NEAR, HELD_H_FAR, depth) * SPY_SCALE
	var grip: Vector2 = Vector2(body_w * PISTOL_GRIP_X, body_h * PISTOL_GRIP_Y)
	var angle: float = host.aim_direction.angle() if host.aim_direction.length_squared() > 0.0001 else 0.0
	var item_color: Color = host.held.get_display_color()
	var body_rect: Rect2 = Rect2(
		Vector2(-held_w * PISTOL_BODY_W_RATIO * 0.5, -held_h * PISTOL_BODY_H_RATIO * 0.5),
		Vector2(held_w * PISTOL_BODY_W_RATIO, held_h * PISTOL_BODY_H_RATIO)
	)
	var barrel_rect: Rect2 = Rect2(
		Vector2(held_w * PISTOL_BARREL_X, held_h * PISTOL_BARREL_Y),
		Vector2(held_w * PISTOL_BARREL_W_RATIO, held_h * PISTOL_BARREL_H_RATIO)
	)
	host.draw_set_transform_matrix(walk_xf * Transform2D(angle, grip))
	host.draw_rect(body_rect, item_color)
	host.draw_rect(body_rect, outline, false, 2.0)
	host.draw_rect(barrel_rect, item_color.darkened(0.08))
	host.draw_rect(barrel_rect, outline, false, 2.0)
	host.draw_set_transform_matrix(walk_xf)
	var label_rect: Rect2 = Rect2(
		grip - Vector2(held_w * 0.5, held_h * 0.5),
		Vector2(held_w, held_h)
	)
	_draw_held_item_label(label_rect)


func _draw_held_orbital_computer(depth: float, body_h: float, body_w: float, outline: Color) -> void:
	var held_w: float = lerpf(HELD_W_NEAR, HELD_W_FAR, depth) * SPY_SCALE
	var held_h: float = lerpf(HELD_H_NEAR, HELD_H_FAR, depth) * SPY_SCALE
	var grip: Vector2 = Vector2(body_w * 0.58, -body_h * 0.02)
	var item_color: Color = host.held.get_display_color()
	var base_rect: Rect2 = Rect2(
		grip - Vector2(held_w * 0.42, held_h * 0.34),
		Vector2(held_w * 0.84, held_h * 0.68)
	)
	var screen_rect: Rect2 = Rect2(
		base_rect.position + Vector2(held_w * 0.08, held_h * 0.08),
		Vector2(held_w * 0.68, held_h * 0.36)
	)
	host.draw_rect(base_rect, item_color.darkened(0.12))
	host.draw_rect(base_rect, outline, false, 2.0)
	host.draw_rect(screen_rect, Color(0.08, 0.12, 0.16, 0.95))
	host.draw_rect(screen_rect, Color("#c03030"), false, 1.5)
	_draw_held_item_label(base_rect)


func _draw_held_item_label(rect: Rect2) -> void:
	var label: String = host.held.get_display_name()
	if label.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var font_size: int = _pick_held_label_font_size(font, label, rect.size)
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var base: Vector2 = rect.position + (rect.size - text_size) * 0.5
	var shadow: Color = Color(0.0, 0.0, 0.0, 0.9)
	var text_col: Color = Color(0.98, 0.98, 0.98, 0.95)
	host.draw_string(font, base + Vector2(1.0, 1.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow)
	host.draw_string(font, base, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)


func _pick_held_label_font_size(font: Font, text: String, max_size: Vector2) -> int:
	for size: int in range(HELD_LABEL_FONT_MAX, HELD_LABEL_FONT_MIN - 1, -1):
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		if text_size.x <= max_size.x - 2.0 and text_size.y <= max_size.y - 1.0:
			return size
	return HELD_LABEL_FONT_MIN
