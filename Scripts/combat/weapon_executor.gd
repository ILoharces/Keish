class_name WeaponExecutor
extends RefCounted

var _resolver: AimResolver = null


func _init(resolver: AimResolver) -> void:
	_resolver = resolver


func try_fire(attacker: SpyBase, screen_pos: Vector2) -> bool:
	if attacker == null or attacker.combat == null:
		return false
	if not attacker.combat.can_fire_weapon():
		return false
	var weapon: WeaponData = attacker.combat.get_equipped_weapon_data()
	if weapon == null:
		return false
	if _resolver != null:
		screen_pos = _resolver.clamp_reticle_pos(screen_pos)
	var opponent: SpyBase = _get_opponent(attacker)
	var aim: AimResult = _resolver.resolve(screen_pos, attacker)
	if not _resolver.validate_for_weapon(weapon, aim, attacker, opponent):
		return false
	if weapon.custom_effect != null:
		var effect_obj: Variant = weapon.custom_effect.new()
		if effect_obj is WeaponEffect:
			var custom: WeaponEffect = effect_obj as WeaponEffect
			var ctx: WeaponContext = WeaponContext.new(attacker, weapon, screen_pos, aim)
			if not custom.can_fire(ctx):
				return false
			if weapon.telegraph_time > 0.0:
				custom.on_telegraph_start(ctx)
	if weapon.uses_ammo:
		if not GameState.has_weapon(attacker, weapon.weapon_id):
			return false
		if not GameState.consume_weapon_ammo(attacker, weapon.weapon_id):
			return false
	attacker.combat.start_cooldown(weapon.cooldown)
	if weapon.telegraph_time > 0.0:
		_schedule_delayed_fire(attacker, weapon, screen_pos, aim, weapon.telegraph_time)
		return true
	if weapon.uses_ammo:
		_clear_weapon_if_empty(attacker, weapon.weapon_id)
	return _execute_delivery(attacker, weapon, screen_pos, aim)


func _execute_delivery(attacker: SpyBase, weapon: WeaponData, screen_pos: Vector2, aim: AimResult) -> bool:
	var ctx: WeaponContext = WeaponContext.new(attacker, weapon, screen_pos, aim)
	if weapon.custom_effect != null:
		var effect_obj: Variant = weapon.custom_effect.new()
		if effect_obj is WeaponEffect:
			var custom: WeaponEffect = effect_obj as WeaponEffect
			custom.execute(ctx)
			return true
	match weapon.delivery:
		WeaponData.Delivery.HITSCAN:
			return _execute_hitscan(ctx)
		WeaponData.Delivery.PROJECTILE:
			return _execute_projectile(ctx)
		WeaponData.Delivery.DELAYED_STRIKE, WeaponData.Delivery.MELEE_ARC, WeaponData.Delivery.AREA:
			push_warning("[WeaponExecutor] Delivery %d no implementado en v1." % weapon.delivery)
			return false
	return false


func _execute_projectile(ctx: WeaponContext) -> bool:
	if ctx.attacker == null or ctx.attacker.current_room == null or ctx.aim_result == null:
		return false
	var muzzle: Vector2 = ctx.attacker.get_muzzle_world_position()
	var dir: Vector2 = Vector2.ZERO
	if _resolver != null:
		dir = _resolver.resolve_aim_direction(ctx.screen_pos, ctx.attacker)
	if dir == Vector2.ZERO:
		dir = ctx.attacker.aim_direction
	if dir.length_squared() <= 0.0001:
		dir = Vector2.RIGHT
	var max_travel: float = ctx.weapon_data.max_range
	if max_travel <= 0.0:
		max_travel = WeaponProjectile.DEFAULT_MAX_TRAVEL
	WeaponProjectile.spawn(
		ctx.attacker.current_room,
		ctx.attacker.spy_id,
		ctx.weapon_data.weapon_id,
		ctx.weapon_data.damage,
		ctx.weapon_data.knockback_force,
		dir,
		ctx.weapon_data.projectile_speed,
		max_travel,
		muzzle
	)
	return true


func _execute_hitscan(ctx: WeaponContext) -> bool:
	var target: SpyBase = ctx.target_spy
	if target == null and ctx.aim_result != null:
		target = ctx.aim_result.target_spy
	if target == null or not target.is_alive:
		return false
	if ctx.weapon_data.damage > 0.0:
		target.combat.apply_damage(ctx.weapon_data.damage, ctx.attacker.spy_id, ctx.weapon_data.weapon_id)
	if ctx.weapon_data.stun_duration > 0.0:
		target.combat.apply_weapon_stun(ctx.weapon_data.stun_duration)
	return true


func _schedule_delayed_fire(
	attacker: SpyBase,
	weapon: WeaponData,
	screen_pos: Vector2,
	aim: AimResult,
	delay: float
) -> void:
	var tree: SceneTree = attacker.get_tree()
	if tree == null:
		return
	var timer: SceneTreeTimer = tree.create_timer(delay)
	timer.timeout.connect(_on_delayed_fire.bind(attacker, weapon, screen_pos, aim))


func _on_delayed_fire(attacker: SpyBase, weapon: WeaponData, screen_pos: Vector2, aim: AimResult) -> void:
	if not is_instance_valid(attacker) or not attacker.is_alive:
		return
	_execute_delivery(attacker, weapon, screen_pos, aim)
	if weapon.uses_ammo:
		_clear_weapon_if_empty(attacker, weapon.weapon_id)


func _get_opponent(attacker: SpyBase) -> SpyBase:
	if attacker.current_room == null:
		return null
	var mansion: Mansion = null
	var node: Node = attacker.get_parent()
	while node != null:
		if node is Mansion:
			mansion = node as Mansion
			break
		node = node.get_parent()
	if mansion == null:
		return null
	if attacker.spy_id == ItemDB.SpyId.PLAYER:
		return mansion.get_bottom_spy()
	return mansion.player


func _clear_weapon_if_empty(attacker: SpyBase, weapon_id: StringName) -> void:
	if GameState.has_weapon(attacker, weapon_id):
		return
	if attacker.combat != null:
		attacker.combat.clear_equipped_weapon()
	if attacker.held != null and attacker.held.is_holding_weapon():
		if attacker.held.get_weapon_id() == weapon_id:
			attacker.held.clear()
			attacker.emit_held_changed()
