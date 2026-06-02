class_name OrbitalStrikeEffect
extends WeaponEffect


func can_fire(ctx: WeaponContext) -> bool:
	return ctx != null and ctx.aim_result != null and ctx.aim_result.is_valid


func execute(ctx: WeaponContext) -> void:
	if ctx.attacker == null or ctx.aim_result == null:
		return
	var on_impact: Callable = _apply_strike.bind(ctx)
	var main: Main = ctx.attacker.get_tree().current_scene as Main
	if main != null:
		main.play_orbital_laser(ctx.attacker.spy_id, ctx.screen_pos, on_impact)
	else:
		on_impact.call()


func _apply_strike(ctx: WeaponContext) -> void:
	var victim: SpyBase = _find_victim_at_strike(ctx)
	if victim != null and victim.is_alive and victim.combat != null:
		victim.combat.apply_damage(SpyBase.MAX_HEALTH, ctx.attacker.spy_id, ctx.weapon_data.weapon_id)
	if ctx.attacker != null:
		ctx.attacker.set_orbital_targeting(false)


func _find_victim_at_strike(ctx: WeaponContext) -> SpyBase:
	var world_pos: Vector2 = ctx.aim_result.world_pos
	var room: Room = ctx.aim_result.target_room
	if room == null:
		return null
	var mansion: Mansion = _find_mansion(ctx.attacker)
	if mansion == null:
		return null
	var candidates: Array[SpyBase] = []
	if mansion.player != null and mansion.player.is_alive:
		candidates.append(mansion.player)
	var bottom: SpyBase = mansion.get_bottom_spy()
	if bottom != null and bottom.is_alive and bottom != mansion.player:
		candidates.append(bottom)
	for spy: SpyBase in candidates:
		if spy == ctx.attacker or spy.current_room != room:
			continue
		if spy.contains_hit_point(world_pos):
			return spy
	return null


func _find_mansion(spy: SpyBase) -> Mansion:
	var node: Node = spy.get_parent()
	while node != null:
		if node is Mansion:
			return node as Mansion
		node = node.get_parent()
	return null
