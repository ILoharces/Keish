extends CharacterBody2D
class_name SpyBase

# Logica comun entre el jugador y la IA. Subclases implementan input;
# movimiento, combate, interaccion y dibujo viven en componentes.

@warning_ignore("unused_signal")
signal search_started(furniture: Furniture)
signal search_finished(furniture: Furniture)
signal stunned_changed(is_stunned: bool)
signal health_changed(current: float, maximum: float)
signal held_changed(kind: int, held_id: int)
signal weapon_changed(weapon_id: StringName)

const PROBE_RADIUS_BASE: float = 25.6
const MAX_HEALTH: float = 100.0
const COLLIDER_SCALE: float = 1.95
const PHYSICS_FOOT_HEIGHT: float = 12.0
const PHYSICS_FOOT_WIDTH_RATIO: float = 0.72
const PROBE_RADIUS: float = PROBE_RADIUS_BASE * COLLIDER_SCALE
const KNOCKBACK_DURATION: float = 0.18
const WALK_WIGGLE_SPEED: float = 13.0

@export var spy_id: int = 0

var current_room: Room = null
var nearby_furniture: Furniture = null
var nearby_door: Door = null
var stun_timer: float = 0.0
var knockback_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var aim_direction: Vector2 = Vector2.RIGHT
var health: float = MAX_HEALTH
var is_alive: bool = true
var alive_modulate: Color = Color.WHITE
var search_timer: float = 0.0
var searching_furniture: Furniture = null
var search_progress: ColorRect = null
var search_progress_bg: ColorRect = null
var open_furniture: Furniture = null
var nearby_pickup: Node = null
var held: HeldInventory = null
var orbital_targeting: bool = false
var walk_phase: float = 0.0

var visual: SpyVisual
var movement: SpyMovement
var combat: SpyCombat
var interaction: SpyInteraction

var _body_collider: CollisionShape2D = null
var _body_shape: RectangleShape2D = null


func _ready() -> void:
	add_to_group("spy")
	collision_layer = 2
	collision_mask = 3
	motion_mode = MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	floor_max_angle = deg_to_rad(89.0)
	safe_margin = 1.0
	visual = SpyVisual.new(self)
	movement = SpyMovement.new(self)
	combat = SpyCombat.new(self)
	interaction = SpyInteraction.new(self)
	_build_collider()
	_build_probe()
	_build_search_indicator()
	held = HeldInventory.new()
	held.sync_carried_from_inventory(spy_id)
	if not GameState.inventory_changed.is_connected(_on_inventory_changed):
		GameState.inventory_changed.connect(_on_inventory_changed)
	if not GameState.weapons_changed.is_connected(_on_weapons_changed):
		GameState.weapons_changed.connect(_on_weapons_changed)
	alive_modulate = Color.WHITE
	health = MAX_HEALTH
	queue_redraw()


func _draw() -> void:
	visual.draw()


func _physics_process(delta: float) -> void:
	if combat != null:
		combat.tick_cooldown(delta)
	movement.physics_process(delta)


func _compute_input_vector() -> Vector2:
	return Vector2.ZERO


func is_stunned() -> bool:
	return stun_timer > 0.0


func is_operational() -> bool:
	return is_alive and not is_stunned() and not is_searching()


func is_searching() -> bool:
	return search_timer > 0.0


func set_orbital_targeting(active: bool) -> void:
	if orbital_targeting == active:
		return
	orbital_targeting = active
	if active:
		velocity = Vector2.ZERO
	elif is_inside_tree():
		var main: Main = get_tree().current_scene as Main
		if main != null:
			main.restore_orbital_aim_mode_for_spy(self)
	queue_redraw()


func reset_health() -> void:
	combat.reset_health()


func interact_with_nearby() -> bool:
	return interaction.interact_with_nearby()


func try_place_trap(trap_id: int) -> bool:
	return interaction.try_place_trap(trap_id)


func refresh_hands_from_inventory() -> void:
	interaction.refresh_hands_from_inventory()


func prepare_hands_for_trap(trap_id: int) -> bool:
	return interaction.prepare_hands_for_trap(trap_id)


func respawn_in_room(room: Room) -> void:
	if room == null:
		return
	if current_room != null:
		current_room.spies_inside.erase(self)
	is_alive = true
	collision_layer = 2
	collision_mask = 3
	alive_modulate = ItemDB.SPY_COLORS.get(spy_id, Color.WHITE) as Color
	modulate = alive_modulate
	velocity = Vector2.ZERO
	stun_timer = 0.0
	knockback_timer = 0.0
	knockback_velocity = Vector2.ZERO
	set_orbital_targeting(false)
	interaction.close_open_furniture()
	reset_held_for_match()
	global_position = room.get_center_world_pos()
	set_current_room(room)
	if not room.spies_inside.has(self):
		room.spies_inside.append(self)
	update_body_collider()
	queue_redraw()


func reset_held_for_match() -> void:
	if held == null:
		return
	held.clear()
	if combat != null:
		combat.clear_equipped_weapon()
	else:
		emit_weapon_changed()
	reset_health()
	refresh_hands_from_inventory()
	emit_held_changed()


func equip_trap_from_trapulator(trap_id: int) -> bool:
	if held == null:
		return false
	return prepare_hands_for_trap(trap_id)


func release_trap_selection() -> void:
	if held == null or not held.is_holding_trap():
		return
	held.release_trap()
	refresh_hands_from_inventory()
	emit_held_changed()


func cycle_held_trap() -> void:
	if held == null:
		return
	var available: Array[int] = held.get_available_traps(spy_id)
	if available.is_empty():
		release_trap_selection()
		return
	if not held.is_holding_trap():
		prepare_hands_for_trap(available[0])
		return
	var current_idx: int = available.find(held.get_trap_id())
	if current_idx < 0:
		_swap_held_trap(available[0])
		return
	var next_idx: int = current_idx + 1
	if next_idx >= available.size():
		release_trap_selection()
		return
	_swap_held_trap(available[next_idx])


func _swap_held_trap(trap_id: int) -> void:
	if held == null:
		return
	held.set_trap(trap_id)
	emit_held_changed()


func apply_trap_effect(trap_id: int, effect_origin: Vector2 = Vector2.ZERO) -> void:
	combat.apply_trap_effect(trap_id, effect_origin)


func try_fire_weapon(screen_pos: Vector2, _game_views: GameViewsPanel = null) -> bool:
	if combat == null:
		return false
	return combat.try_fire_weapon(screen_pos)


func get_aim_controller_spy_id() -> int:
	return spy_id


func get_muzzle_world_position() -> Vector2:
	if visual == null:
		return global_position
	return global_position + visual.get_muzzle_local_offset()


func get_grip_world_position() -> Vector2:
	if visual == null:
		return global_position
	return global_position + visual.get_grip_local_offset()


func contains_hit_point(world_pos: Vector2) -> bool:
	return get_damage_hitbox_local_rect().has_point(to_local(world_pos))


func get_damage_hitbox_local_rect() -> Rect2:
	if visual == null:
		return Rect2()
	var metrics: Dictionary = visual.compute_metrics()
	var center: Vector2 = metrics["hitbox_center"] as Vector2
	var size: Vector2 = metrics["hitbox_size"] as Vector2
	return Rect2(center - size * 0.5, size)


func intersects_damage_segment(from_world: Vector2, to_world: Vector2) -> bool:
	if visual == null:
		return false
	var rect: Rect2 = get_damage_hitbox_local_rect()
	var a: Vector2 = to_local(from_world)
	var b: Vector2 = to_local(to_world)
	if rect.has_point(a) or rect.has_point(b):
		return true
	var p0: Vector2 = rect.position
	var p1: Vector2 = rect.position + Vector2(rect.size.x, 0.0)
	var p2: Vector2 = rect.end
	var p3: Vector2 = rect.position + Vector2(0.0, rect.size.y)
	var edges: Array[Vector2] = [p0, p1, p2, p3]
	for i: int in edges.size():
		var c: Vector2 = edges[i]
		var d: Vector2 = edges[(i + 1) % edges.size()]
		if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
			return true
	return false


func update_body_collider() -> void:
	# Collider físico (pies): paredes y muebles. No se usa para recibir disparos.
	if _body_shape == null or visual == null:
		return
	var metrics: Dictionary = visual.compute_metrics()
	var body_w: float = metrics["body_w"] as float
	var foot_y: float = metrics["foot_y"] as float
	var foot_h: float = PHYSICS_FOOT_HEIGHT * COLLIDER_SCALE
	var foot_w: float = body_w * 2.0 * PHYSICS_FOOT_WIDTH_RATIO
	_body_shape.size = Vector2(foot_w, foot_h)
	_body_collider.position = Vector2(0.0, foot_y - foot_h * 0.5)
	_update_search_indicator(metrics)


func _update_search_indicator(metrics: Dictionary) -> void:
	if search_progress_bg == null or search_progress == null:
		return
	var head_top_y: float = metrics["head_top_y"] as float
	var body_w: float = metrics["body_w"] as float
	var bar_w: float = body_w * 2.4
	var bar_h: float = 4.0 * COLLIDER_SCALE * lerpf(0.82, 1.0, metrics["depth"] as float)
	var bar_y: float = head_top_y - bar_h * 1.6
	search_progress_bg.size = Vector2(bar_w, bar_h)
	search_progress_bg.position = Vector2(-bar_w * 0.5, bar_y)
	search_progress.size = Vector2(0.0, bar_h)
	search_progress.position = Vector2(-bar_w * 0.5, bar_y)


func emit_weapon_changed() -> void:
	var weapon_id: StringName = &""
	if held != null and held.is_holding_weapon():
		weapon_id = held.get_weapon_id()
	weapon_changed.emit(weapon_id)
	queue_redraw()


func set_current_room(room: Room) -> void:
	movement.set_current_room(room)


func teleport_to_room(room: Room, entry_dir: String, from_room: Room = null) -> void:
	movement.teleport_to_room(room, entry_dir, from_room)


func arm_passage_entry_block(room: Room, entry_dir: String) -> void:
	movement.arm_passage_entry_block(room, entry_dir)


func clear_passage_entry_block(room: Room, exit_dir: String) -> void:
	movement.clear_passage_entry_block(room, exit_dir)


func is_passage_bounce_blocked(room: Room, exit_dir: String) -> bool:
	return movement.is_passage_bounce_blocked(room, exit_dir)


func emit_held_changed() -> void:
	if held == null:
		return
	held_changed.emit(held.kind, held.held_id)
	queue_redraw()


func _build_collider() -> void:
	_body_shape = RectangleShape2D.new()
	_body_collider = CollisionShape2D.new()
	_body_collider.name = "PhysicsFootCollider"
	_body_collider.shape = _body_shape
	add_child(_body_collider)
	update_body_collider()


func _build_probe() -> void:
	var probe: Area2D = Area2D.new()
	probe.name = "InteractProbe"
	probe.collision_layer = 0
	probe.collision_mask = 12
	probe.monitoring = true
	probe.monitorable = false
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = PROBE_RADIUS
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	probe.add_child(col)
	add_child(probe)
	probe.area_entered.connect(_on_probe_area_entered)
	probe.area_exited.connect(_on_probe_area_exited)


func _build_search_indicator() -> void:
	search_progress_bg = ColorRect.new()
	search_progress_bg.size = Vector2(27.2, 4.0) * COLLIDER_SCALE
	search_progress_bg.position = Vector2(-13.6, -19.2) * COLLIDER_SCALE
	search_progress_bg.color = Color(0, 0, 0, 0.6)
	search_progress_bg.visible = false
	search_progress_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	search_progress_bg.z_index = 10
	add_child(search_progress_bg)
	search_progress = ColorRect.new()
	search_progress.size = Vector2(0, 4.0 * COLLIDER_SCALE)
	search_progress.position = Vector2(-13.6, -19.2) * COLLIDER_SCALE
	search_progress.color = Color("#ffeb3b")
	search_progress.visible = false
	search_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	search_progress.z_index = 11
	add_child(search_progress)


func _on_probe_area_entered(area: Area2D) -> void:
	var pickup_node: Node = _area_to_ground_pickup(area)
	if pickup_node != null:
		nearby_pickup = pickup_node
		return
	var parent: Node = area.get_parent()
	if parent.is_in_group("furniture"):
		nearby_furniture = parent as Furniture
	elif parent.is_in_group("door"):
		nearby_door = parent as Door


func _area_to_ground_pickup(area: Area2D) -> Node:
	if area.is_in_group("ground_pickup"):
		return area
	var parent: Node = area.get_parent()
	if parent != null and parent.is_in_group("ground_pickup"):
		return parent
	return null


func _on_probe_area_exited(area: Area2D) -> void:
	var pickup_node: Node = _area_to_ground_pickup(area)
	if pickup_node != null and pickup_node == nearby_pickup:
		nearby_pickup = null
	var parent: Node = area.get_parent()
	if parent is Furniture:
		var furn: Furniture = parent as Furniture
		if furn.is_raised_open():
			interaction.close_furniture(furn)
	if parent == nearby_furniture:
		nearby_furniture = null
	elif parent == nearby_door:
		nearby_door = null


func _on_inventory_changed(changed_spy_id: int) -> void:
	if changed_spy_id != spy_id:
		return
	interaction.refresh_hands_from_inventory()


func _on_weapons_changed(changed_spy_id: int) -> void:
	if changed_spy_id != spy_id:
		return
	# Solo cambia la munición; el HUD escucha weapons_changed. No recentrar mirilla.
