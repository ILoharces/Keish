class_name SpyMovement
extends RefCounted

# Movimiento, pasajes entre habitaciones y orden de dibujo.

const SPEED: float = 200.0
const WALK_PHASE_DECAY: float = 10.0

var host: SpyBase = null
var _passage_entry_blocks: Dictionary = {}


func _init(p_host: SpyBase) -> void:
	host = p_host


func physics_process(delta: float) -> void:
	if not host.is_alive:
		host.velocity = Vector2.ZERO
		host.move_and_slide()
		host.queue_redraw()
		return
	if host.knockback_timer > 0.0:
		host.knockback_timer = maxf(0.0, host.knockback_timer - delta)
		host.velocity = host.knockback_velocity
		host.modulate = host.alive_modulate
		_update_draw_order()
		_update_walk_phase(delta)
		host.update_body_collider()
		host.move_and_slide()
		if host.current_room != null:
			var local_pos: Vector2 = host.global_position - host.current_room.global_position
			var clamped: Vector2 = host.current_room.clamp_local_position(local_pos)
			host.global_position = host.current_room.global_position + clamped
		host.queue_redraw()
		return
	if host.stun_timer > 0.0:
		host.stun_timer = maxf(0.0, host.stun_timer - delta)
		host.modulate = Color(host.alive_modulate.r, host.alive_modulate.g, host.alive_modulate.b, 0.45)
		host.velocity = Vector2.ZERO
		if host.stun_timer <= 0.0:
			host.stunned_changed.emit(false)
	elif host.is_searching() or host.orbital_targeting:
		host.modulate = Color(host.alive_modulate.r, host.alive_modulate.g, host.alive_modulate.b, 0.75)
		host.velocity = Vector2.ZERO
	else:
		host.modulate = host.alive_modulate
		var input_vector: Vector2 = host._compute_input_vector()
		host.velocity = input_vector.normalized() * SPEED if input_vector.length() > 0.01 else Vector2.ZERO
	_update_draw_order()
	_update_walk_phase(delta)
	host.update_body_collider()
	host.move_and_slide()
	if host.current_room != null:
		var local_pos: Vector2 = host.global_position - host.current_room.global_position
		var clamped: Vector2 = host.current_room.clamp_local_position(local_pos)
		host.global_position = host.current_room.global_position + clamped
		host.current_room.poll_spy_passages(host)
	host.queue_redraw()


func arm_passage_entry_block(room: Room, entry_dir: String) -> void:
	_passage_entry_blocks[_passage_block_key(room, entry_dir)] = true


func clear_passage_entry_block(room: Room, exit_dir: String) -> void:
	_passage_entry_blocks.erase(_passage_block_key(room, exit_dir))


func is_passage_bounce_blocked(room: Room, exit_dir: String) -> bool:
	return _passage_entry_blocks.has(_passage_block_key(room, exit_dir))


func _passage_block_key(room: Room, dir_str: String) -> String:
	return "%d:%s" % [room.get_instance_id(), dir_str]


func _finalize_passage_entry_block(room: Room, entry_dir: String) -> void:
	if not is_instance_valid(room) or host.current_room != room:
		return
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	if not is_instance_valid(room) or host.current_room != room:
		return
	var area: Area2D = room.get_node_or_null("Passage_%s" % entry_dir) as Area2D
	if area != null and area.overlaps_body(host):
		return
	clear_passage_entry_block(room, entry_dir)


func _update_walk_phase(delta: float) -> void:
	if host.velocity.length_squared() > 64.0:
		host.walk_phase += delta * SpyBase.WALK_WIGGLE_SPEED
	else:
		host.walk_phase = lerpf(host.walk_phase, 0.0, delta * WALK_PHASE_DECAY)


func _update_draw_order() -> void:
	if host.current_room == null:
		host.z_index = 0
		return
	var local_y: float = host.global_position.y - host.current_room.global_position.y
	host.z_index = clampi(int(local_y), -4096, 4096)


func set_current_room(room: Room) -> void:
	host.current_room = room


func teleport_to_room(room: Room, entry_dir: String, from_room: Room = null) -> void:
	if room == null:
		return
	if host.is_searching():
		host.interaction.cancel_search()
	host.interaction.close_open_furniture()
	var prev_room: Room = from_room if from_room != null else host.current_room
	var prev_local: Vector2 = Vector2.ZERO
	if prev_room != null:
		prev_local = host.global_position - prev_room.global_position
	if prev_room != null and prev_room.spies_inside.has(host):
		prev_room.spies_inside.erase(host)
		prev_room.spy_exited.emit(host)
	host.current_room = room
	if not room.spies_inside.has(host):
		room.spies_inside.append(host)
		room.spy_entered.emit(host)
	room.set_passage_cooldown(host, Room.PASSAGE_COOLDOWN_MS)
	arm_passage_entry_block(room, entry_dir)
	var local_spawn: Vector2 = room.get_door_spawn(entry_dir)
	if prev_room != null:
		local_spawn = RoomPerspective.adjust_passage_entry_position(
			prev_local,
			prev_room.get_room_w(),
			prev_room.get_room_h(),
			entry_dir,
			local_spawn,
			room.get_room_w(),
			room.get_room_h()
		)
	local_spawn += RoomPerspective.door_entry_inward_offset(
		entry_dir, room.get_room_w(), room.get_room_h()
	)
	local_spawn = RoomPerspective.ensure_spawn_clear_of_passage(
		local_spawn, entry_dir, room.get_room_w(), room.get_room_h()
	)
	local_spawn = room.clamp_local_position(local_spawn)
	host.global_position = room.global_position + local_spawn
	host.update_body_collider()
	var entry_door: Door = room.get_door_for_direction(entry_dir)
	if entry_door != null:
		entry_door.try_open_for_spy(host.spy_id, true)
	_finalize_passage_entry_block.call_deferred(room, entry_dir)
	var inward: Vector2 = RoomPerspective.door_entry_inward_offset(
		entry_dir, room.get_room_w(), room.get_room_h()
	)
	if inward.length_squared() > 0.001:
		if host.velocity.length_squared() < 1.0 or host.velocity.dot(inward) <= 0.0:
			host.velocity = inward.normalized() * SPEED
