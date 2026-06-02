extends CharacterBody2D
class_name WeaponProjectile

const DEFAULT_MAX_TRAVEL: float = 1200.0
const SPAWN_OFFSET: float = 14.0
const BULLET_RADIUS: float = 4.0

var owner_spy_id: int = -1
var weapon_id: StringName = &""
var damage: float = 0.0
var knockback_force: float = 0.0
var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var max_travel: float = DEFAULT_MAX_TRAVEL
var room: Room = null

var _traveled: float = 0.0
var _hit: bool = false


static func spawn(
	p_room: Room,
	p_owner_spy_id: int,
	p_weapon_id: StringName,
	p_damage: float,
	p_knockback_force: float,
	p_direction: Vector2,
	p_speed: float,
	p_max_travel: float,
	p_muzzle_world_pos: Vector2
) -> WeaponProjectile:
	var projectile: WeaponProjectile = WeaponProjectile.new()
	projectile.owner_spy_id = p_owner_spy_id
	projectile.weapon_id = p_weapon_id
	projectile.damage = p_damage
	projectile.knockback_force = p_knockback_force
	projectile.direction = p_direction.normalized() if p_direction.length_squared() > 0.0001 else Vector2.RIGHT
	projectile.speed = p_speed
	projectile.max_travel = p_max_travel if p_max_travel > 0.0 else DEFAULT_MAX_TRAVEL
	projectile.room = p_room
	p_room.add_child(projectile)
	projectile.global_position = p_muzzle_world_pos + projectile.direction * SPAWN_OFFSET
	return projectile


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	motion_mode = MOTION_MODE_FLOATING
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = BULLET_RADIUS
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	z_index = 512
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _hit:
		return
	var step: float = speed * delta
	var motion: Vector2 = direction * step
	var start_pos: Vector2 = global_position
	var end_pos: Vector2 = start_pos + motion
	var hit_spy: SpyBase = _find_spy_hit_on_segment(start_pos, end_pos)
	if hit_spy != null:
		_apply_spy_hit(hit_spy)
		return
	var collision: KinematicCollision2D = move_and_collide(motion)
	_traveled += step
	if collision != null:
		_handle_collision(collision.get_collider())
		return
	if _traveled >= max_travel:
		queue_free()
		return
	if room == null or not _is_inside_room():
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, BULLET_RADIUS, Color(1.0, 0.88, 0.2, 0.95))
	draw_circle(Vector2.ZERO, BULLET_RADIUS * 0.55, Color(1.0, 0.98, 0.75, 1.0))


func _handle_collision(collider: Object) -> void:
	if _hit:
		return
	if collider is StaticBody2D:
		_hit = true
		queue_free()


func _find_spy_hit_on_segment(from_pos: Vector2, to_pos: Vector2) -> SpyBase:
	if room == null:
		return null
	for node: Node in room.spies_inside:
		var spy: SpyBase = node as SpyBase
		if spy == null or spy.spy_id == owner_spy_id or not spy.is_alive:
			continue
		if spy.intersects_damage_segment(from_pos, to_pos):
			return spy
	return null


func _apply_spy_hit(spy: SpyBase) -> void:
	if _hit or spy == null:
		return
	_hit = true
	if damage > 0.0:
		spy.combat.apply_damage(damage, owner_spy_id, weapon_id)
	if knockback_force > 0.0:
		spy.combat.apply_weapon_knockback(direction, knockback_force)
	queue_free()


func _is_inside_room() -> bool:
	if room == null:
		return false
	var local_pos: Vector2 = global_position - room.global_position
	var clamped: Vector2 = room.clamp_local_position(local_pos)
	return local_pos.distance_to(clamped) < 2.0
