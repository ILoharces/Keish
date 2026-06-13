class_name AimResolver
extends RefCounted

const WEAPON_AIM_DEAD_ZONE_RADIUS: float = 28.0
const WEAPON_AIM_DEAD_ZONE_RADIUS_SQ: float = WEAPON_AIM_DEAD_ZONE_RADIUS * WEAPON_AIM_DEAD_ZONE_RADIUS

var _views: GameViewsPanel = null


func _init(views: GameViewsPanel) -> void:
	_views = views


func clamp_reticle_pos(screen_pos: Vector2) -> Vector2:
	if _views == null:
		return screen_pos
	return _views.clamp_to_aim_views(screen_pos)


func resolve_aim_direction(screen_pos: Vector2, attacker: SpyBase) -> Vector2:
	if _views == null or attacker == null:
		return Vector2.ZERO
	var reticle_pos: Vector2 = clamp_reticle_pos(screen_pos)
	if is_reticle_over_weapon(reticle_pos, attacker):
		return Vector2.ZERO
	var grip_world: Vector2 = attacker.get_grip_world_position()
	var world_at_reticle: Vector2 = _screen_to_world_for_attacker(reticle_pos, attacker)
	var to_aim: Vector2 = world_at_reticle - grip_world
	if to_aim.length_squared() <= 0.0001:
		return Vector2.ZERO
	return to_aim.normalized()


func is_reticle_over_weapon(screen_pos: Vector2, attacker: SpyBase) -> bool:
	if attacker.held == null or not attacker.held.is_holding_weapon():
		return false
	var reticle_pos: Vector2 = clamp_reticle_pos(screen_pos)
	var grip_screen: Vector2 = world_to_screen(attacker.get_grip_world_position(), attacker)
	var muzzle_screen: Vector2 = world_to_screen(attacker.get_muzzle_world_position(), attacker)
	if grip_screen == Vector2.ZERO or muzzle_screen == Vector2.ZERO:
		return false
	return (
		_point_segment_distance_sq(reticle_pos, grip_screen, muzzle_screen)
		<= WEAPON_AIM_DEAD_ZONE_RADIUS_SQ
	)


func _point_segment_distance_sq(point: Vector2, seg_a: Vector2, seg_b: Vector2) -> float:
	var ab: Vector2 = seg_b - seg_a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq <= 0.0001:
		return point.distance_squared_to(seg_a)
	var t: float = clampf((point - seg_a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var closest: Vector2 = seg_a + ab * t
	return point.distance_squared_to(closest)


func resolve(screen_pos: Vector2, attacker: SpyBase) -> AimResult:
	var result: AimResult = AimResult.new()
	if _views == null or attacker == null:
		return result
	if _views.spies_share_room():
		return _resolve_shared_room(screen_pos, attacker)
	var player_rect: Rect2 = _views.get_player_view_global_rect()
	var bottom_rect: Rect2 = _views.get_ai_view_global_rect()
	var in_player: bool = player_rect.has_point(screen_pos)
	var in_bottom: bool = bottom_rect.has_point(screen_pos)
	if not in_player and not in_bottom:
		return result
	var is_player_attacker: bool = attacker.spy_id == ItemDB.SpyId.PLAYER1
	var own_rect: Rect2 = player_rect if is_player_attacker else bottom_rect
	var opp_rect: Rect2 = bottom_rect if is_player_attacker else player_rect
	var own_view: SubViewportContainer = _views.player_view if is_player_attacker else _views.ai_view
	var opp_view: SubViewportContainer = _views.ai_view if is_player_attacker else _views.player_view
	var own_viewport: SubViewport = _views.player_viewport if is_player_attacker else _views.ai_viewport
	var opp_viewport: SubViewport = _views.ai_viewport if is_player_attacker else _views.player_viewport
	var own_camera: Camera2D = _views.player_camera if is_player_attacker else _views.ai_camera
	var opp_camera: Camera2D = _views.ai_camera if is_player_attacker else _views.player_camera
	var target_container: SubViewportContainer = null
	var target_viewport: SubViewport = null
	var target_camera: Camera2D = null
	if in_player and not in_bottom:
		target_container = _views.player_view
		target_viewport = _views.player_viewport
		target_camera = _views.player_camera
		result.target_view = AimResult.TargetView.OWN if is_player_attacker else AimResult.TargetView.OPPONENT
	elif in_bottom and not in_player:
		target_container = _views.ai_view
		target_viewport = _views.ai_viewport
		target_camera = _views.ai_camera
		result.target_view = AimResult.TargetView.OWN if not is_player_attacker else AimResult.TargetView.OPPONENT
	elif in_player:
		target_container = own_view if player_rect.has_point(screen_pos) else opp_view
		target_viewport = own_viewport if target_container == own_view else opp_viewport
		target_camera = own_camera if target_container == own_view else opp_camera
		result.target_view = AimResult.TargetView.OWN if target_container == own_view else AimResult.TargetView.OPPONENT
	else:
		target_container = own_view if bottom_rect.has_point(screen_pos) else opp_view
		target_viewport = own_viewport if target_container == own_view else opp_viewport
		target_camera = own_camera if target_container == own_view else opp_camera
		result.target_view = AimResult.TargetView.OWN if target_container == own_view else AimResult.TargetView.OPPONENT
	if target_container == null or target_viewport == null or target_camera == null:
		return result
	result.viewport = target_viewport
	result.camera = target_camera
	result.world_pos = _screen_to_world(screen_pos, target_container, target_viewport, target_camera)
	result.target_room = _room_for_view(result.target_view, is_player_attacker)
	result.is_remote_shot = result.target_view == AimResult.TargetView.OPPONENT
	result.target_spy = _find_spy_at_world_pos(result.world_pos, result.target_room, attacker)
	result.is_valid = result.target_room != null
	return result


func _resolve_shared_room(screen_pos: Vector2, attacker: SpyBase) -> AimResult:
	var result: AimResult = AimResult.new()
	var player_rect: Rect2 = _views.get_player_view_global_rect()
	var bottom_rect: Rect2 = _views.get_ai_view_global_rect()
	var in_player: bool = player_rect.has_point(screen_pos)
	var in_bottom: bool = bottom_rect.has_point(screen_pos)
	if not in_player and not in_bottom:
		return result
	var container: SubViewportContainer = _views.ai_view
	var viewport: SubViewport = _views.ai_viewport
	var camera: Camera2D = _views.ai_camera
	if in_player and not in_bottom:
		container = _views.player_view
		viewport = _views.player_viewport
		camera = _views.player_camera
	if container == null or viewport == null or camera == null:
		return result
	result.target_view = AimResult.TargetView.OWN
	result.viewport = viewport
	result.camera = camera
	result.world_pos = _screen_to_world(screen_pos, container, viewport, camera)
	result.target_room = _views.get_shared_room()
	result.is_remote_shot = false
	result.target_spy = _find_spy_at_world_pos(result.world_pos, result.target_room, attacker)
	result.is_valid = result.target_room != null
	return result


func validate_for_weapon(weapon: WeaponData, aim: AimResult, attacker: SpyBase, opponent: SpyBase) -> bool:
	if weapon == null or not aim.is_valid:
		return false
	match weapon.aim_profile:
		WeaponData.AimProfile.NONE, WeaponData.AimProfile.DIRECTIONAL:
			return false
		WeaponData.AimProfile.LOCAL_VIEW:
			if aim.target_view != AimResult.TargetView.OWN:
				return false
		WeaponData.AimProfile.REMOTE_VIEW:
			if aim.target_view != AimResult.TargetView.OPPONENT:
				return false
		WeaponData.AimProfile.ANY_VIEW:
			pass
	if weapon.blocks_when_same_room and _same_room(attacker, opponent):
		return false
	if weapon.requires_same_room and not _same_room(attacker, opponent):
		return false
	if weapon.max_range > 0.0 and attacker.global_position.distance_to(aim.world_pos) > weapon.max_range:
		return false
	return true


func _screen_to_world(
	screen_pos: Vector2,
	container: SubViewportContainer,
	viewport: SubViewport,
	camera: Camera2D
) -> Vector2:
	var local: Vector2 = screen_pos - container.global_position
	var size: Vector2 = container.size
	if size.x <= 0.0 or size.y <= 0.0:
		return camera.global_position
	var vp_size: Vector2 = Vector2(viewport.size)
	var vp_pos: Vector2 = Vector2(
		local.x / size.x * vp_size.x,
		local.y / size.y * vp_size.y
	)
	return camera.get_canvas_transform().affine_inverse() * vp_pos


func world_to_screen(world_pos: Vector2, attacker: SpyBase) -> Vector2:
	var refs: Dictionary = _attacker_view_refs(attacker)
	var container: SubViewportContainer = refs.get("container") as SubViewportContainer
	var viewport: SubViewport = refs.get("viewport") as SubViewport
	var camera: Camera2D = refs.get("camera") as Camera2D
	if container == null or viewport == null or camera == null:
		return Vector2.ZERO
	var size: Vector2 = container.size
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	var vp_size: Vector2 = Vector2(viewport.size)
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return Vector2.ZERO
	var vp_pos: Vector2 = camera.get_canvas_transform() * world_pos
	var local: Vector2 = Vector2(
		vp_pos.x / vp_size.x * size.x,
		vp_pos.y / vp_size.y * size.y,
	)
	return container.global_position + local


func _screen_to_world_for_attacker(screen_pos: Vector2, attacker: SpyBase) -> Vector2:
	var refs: Dictionary = _attacker_view_refs(attacker)
	var container: SubViewportContainer = refs.get("container") as SubViewportContainer
	var viewport: SubViewport = refs.get("viewport") as SubViewport
	var camera: Camera2D = refs.get("camera") as Camera2D
	if container == null or viewport == null or camera == null:
		return attacker.global_position if attacker != null else Vector2.ZERO
	return _screen_to_world(screen_pos, container, viewport, camera)


func _attacker_view_refs(attacker: SpyBase) -> Dictionary:
	var refs: Dictionary = {
		"container": null,
		"viewport": null,
		"camera": null,
	}
	if _views == null or attacker == null or _views.mansion == null:
		return refs
	var is_player_attacker: bool = attacker == _views.mansion.player
	refs["container"] = _views.player_view if is_player_attacker else _views.ai_view
	refs["viewport"] = _views.player_viewport if is_player_attacker else _views.ai_viewport
	refs["camera"] = _views.player_camera if is_player_attacker else _views.ai_camera
	if _views.spies_share_room():
		refs["container"] = _views.ai_view
		refs["viewport"] = _views.ai_viewport
		refs["camera"] = _views.ai_camera
	return refs


func _room_for_view(target_view: int, is_player_attacker: bool) -> Room:
	if _views == null or _views.mansion == null:
		return null
	if target_view == AimResult.TargetView.OWN:
		if is_player_attacker:
			return _views.mansion.player.current_room if _views.mansion.player != null else null
		var bottom: SpyBase = _views.mansion.get_bottom_spy()
		return bottom.current_room if bottom != null else null
	if is_player_attacker:
		var bottom_spy: SpyBase = _views.mansion.get_bottom_spy()
		return bottom_spy.current_room if bottom_spy != null else null
	return _views.mansion.player.current_room if _views.mansion.player != null else null


func _find_spy_at_world_pos(world_pos: Vector2, room: Room, attacker: SpyBase) -> SpyBase:
	if room == null or _views == null or _views.mansion == null:
		return null
	var candidates: Array[SpyBase] = []
	if _views.mansion.player != null and _views.mansion.player.is_alive:
		candidates.append(_views.mansion.player)
	var bottom: SpyBase = _views.mansion.get_bottom_spy()
	if bottom != null and bottom.is_alive and bottom != _views.mansion.player:
		candidates.append(bottom)
	for spy: SpyBase in candidates:
		if spy == attacker or spy.current_room != room:
			continue
		if spy.contains_hit_point(world_pos):
			return spy
	return null


func _same_room(a: SpyBase, b: SpyBase) -> bool:
	if a == null or b == null:
		return false
	if a.current_room == null or b.current_room == null:
		return false
	return a.current_room == b.current_room
