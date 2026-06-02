class_name SpyCombat
extends RefCounted

# Trampas ambientales y combate PvP entre espias.

const STUN_DURATION: float = 1.8
const _TRAP_EXPLOSION_SCRIPT: GDScript = preload("res://Scripts/vfx/trap_explosion.gd")

var host: SpyBase = null
var cooldown_timer: float = 0.0
var _weapon_executor: WeaponExecutor = null


func _init(p_host: SpyBase) -> void:
	host = p_host


func set_weapon_executor(executor: WeaponExecutor) -> void:
	_weapon_executor = executor


func reset_health() -> void:
	host.health = SpyBase.MAX_HEALTH
	host.health_changed.emit(host.health, SpyBase.MAX_HEALTH)
	cooldown_timer = 0.0
	host.knockback_timer = 0.0
	host.knockback_velocity = Vector2.ZERO


func get_equipped_weapon_data() -> WeaponData:
	if host.held == null or not host.held.is_holding_weapon():
		return null
	return WeaponDB.get_weapon(host.held.get_weapon_id())


func can_fire_weapon() -> bool:
	if not host.is_alive or host.is_stunned() or host.held == null or not host.held.is_holding_weapon():
		return false
	if not host.orbital_targeting and not host.is_operational():
		return false
	if cooldown_timer > 0.0:
		return false
	var weapon: WeaponData = get_equipped_weapon_data()
	if weapon == null:
		return false
	if weapon.uses_ammo and not GameState.has_weapon(host, weapon.weapon_id):
		return false
	return true


func start_cooldown(duration: float) -> void:
	cooldown_timer = maxf(duration, 0.0)


func process_cooldown(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer = maxf(0.0, cooldown_timer - delta)


func tick_cooldown(delta: float) -> void:
	process_cooldown(delta)


var equipped_weapon_id: StringName:
	get:
		if host == null or host.held == null or not host.held.is_holding_weapon():
			return &""
		return host.held.get_weapon_id()


func set_equipped_weapon(weapon_id: StringName) -> void:
	if host == null or host.held == null:
		return
	if weapon_id.is_empty():
		if host.held.is_holding_weapon():
			host.held.clear()
		host.emit_weapon_changed()
		return
	if host.held.is_holding_weapon() and host.held.get_weapon_id() == weapon_id:
		host.emit_weapon_changed()
		return
	host.held.set_weapon(weapon_id)
	host.emit_weapon_changed()


func clear_equipped_weapon() -> void:
	host.set_orbital_targeting(false)
	set_equipped_weapon(&"")


func try_fire_weapon(screen_pos: Vector2) -> bool:
	if _weapon_executor == null:
		return false
	return _weapon_executor.try_fire(host, screen_pos)


func apply_damage(amount: float, source_spy_id: int, weapon_id: StringName) -> void:
	if not host.is_alive or amount <= 0.0:
		return
	host.health = maxf(0.0, host.health - amount)
	host.health_changed.emit(host.health, SpyBase.MAX_HEALTH)
	if host.health <= 0.0:
		_die_from_weapon(source_spy_id, weapon_id)


func apply_weapon_stun(duration: float) -> void:
	if not host.is_alive or duration <= 0.0:
		return
	host.stun_timer = maxf(host.stun_timer, duration)
	host.stunned_changed.emit(true)


func apply_weapon_knockback(direction: Vector2, force: float) -> void:
	if not host.is_alive or force <= 0.0:
		return
	var dir: Vector2 = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	host.knockback_velocity = dir * force
	host.knockback_timer = SpyBase.KNOCKBACK_DURATION


func apply_trap_effect(trap_id: int, effect_origin: Vector2 = Vector2.ZERO) -> void:
	if not host.is_alive:
		return
	if trap_id == ItemDB.TrapId.BOMB:
		_trigger_bomb_trap(effect_origin)
		return
	host.stun_timer = STUN_DURATION
	host.stunned_changed.emit(true)
	if trap_id == ItemDB.TrapId.TIMED_BOMB:
		var lost: int = GameState.remove_random_item(host.spy_id)
		if lost != -1:
			host.interaction.drop_item_in_room(lost)


func _trigger_bomb_trap(effect_origin: Vector2) -> void:
	var origin: Vector2 = effect_origin
	if origin == Vector2.ZERO:
		origin = host.global_position
	_spawn_trap_explosion(origin)
	_die_from_trap(ItemDB.TrapId.BOMB)


func _spawn_trap_explosion(origin: Vector2) -> void:
	var parent: Node = host.current_room if host.current_room != null else host.get_parent()
	if parent == null:
		return
	var fx: Node2D = _TRAP_EXPLOSION_SCRIPT.new() as Node2D
	fx.global_position = origin
	parent.add_child(fx)


func _enter_death_state() -> void:
	host.is_alive = false
	host.health = 0.0
	host.health_changed.emit(0.0, SpyBase.MAX_HEALTH)
	host.velocity = Vector2.ZERO
	host.stun_timer = 0.0
	host.set_orbital_targeting(false)
	host.interaction.close_open_furniture()
	host.collision_layer = 0
	host.collision_mask = 0
	host.alive_modulate = Color(0.35, 0.35, 0.35, 0.55)
	host.modulate = host.alive_modulate
	host.queue_redraw()


func _die_from_trap(trap_id: int) -> void:
	if not host.is_alive:
		return
	GameState.drop_all_loot_on_death(host)
	_enter_death_state()
	GameState.notify_spy_died(host.spy_id, GameState.WINNER_NONE, trap_id, &"")
	host.emit_held_changed()
	host.emit_weapon_changed()
	_request_respawn()


func _die_from_weapon(source_spy_id: int, _weapon_id: StringName) -> void:
	if not host.is_alive:
		return
	GameState.drop_all_loot_on_death(host)
	_enter_death_state()
	GameState.notify_spy_died(host.spy_id, source_spy_id, -1, _weapon_id)
	host.emit_held_changed()
	host.emit_weapon_changed()
	_request_respawn()


func _request_respawn() -> void:
	GameState.start_respawn(host)
