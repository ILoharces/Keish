extends SpyBase
class_name AiSpy

# Spy controlado por una IA simple basada en estados. Pide rutas al Mansion
# para decidir hacia que puerta caminar y registra muebles ya revisados.

enum State { SEARCH, RETURN, PLACE_TRAP }

const FURNITURE_REACH: float = 80.0
const DOOR_REACH: float = 48.0
const TRAP_PLACE_CHANCE: float = 0.35

var mansion: Mansion = null
var ai_state: int = State.SEARCH
var target_room: Room = null
var target_furniture: Furniture = null
var visited_furniture: Dictionary = {}
var rooms_visited: Dictionary = {}
var decision_timer: float = 0.0
var input_vector: Vector2 = Vector2.ZERO
var place_trap_cooldown: float = 0.0


func _ready() -> void:
	spy_id = ItemDB.SpyId.AI
	super._ready()
	add_to_group("ai_spy")
	search_finished.connect(_on_search_finished)


func _on_search_finished(furniture: Furniture) -> void:
	if furniture != null and is_instance_valid(furniture):
		visited_furniture[furniture.get_instance_id()] = true
	target_furniture = null


func set_mansion(m: Mansion) -> void:
	mansion = m


func _compute_input_vector() -> Vector2:
	return input_vector


func _physics_process(delta: float) -> void:
	if not is_alive:
		input_vector = Vector2.ZERO
		super._physics_process(delta)
		return
	if not DebugFlags.is_ai_active() or not GameState.running:
		input_vector = Vector2.ZERO
		super._physics_process(delta)
		return
	_ai_tick(delta)
	super._physics_process(delta)


func _ai_tick(delta: float) -> void:
	decision_timer = maxf(0.0, decision_timer - delta)
	place_trap_cooldown = maxf(0.0, place_trap_cooldown - delta)
	if current_room == null or mansion == null:
		input_vector = Vector2.ZERO
		return
	# Si estamos abriendo un mueble, esperamos sin moverse.
	if is_searching() or is_stunned():
		input_vector = Vector2.ZERO
		return
	if decision_timer <= 0.0:
		_choose_state()
		decision_timer = randf_range(0.5, 1.2)
	input_vector = _execute_state()


func _choose_state() -> void:
	if GameState.has_all_items(spy_id):
		ai_state = State.RETURN
		target_room = mansion.get_exit_room()
		return
	if DebugFlags.is_furniture_enabled() and DebugFlags.ai_places_traps:
		if place_trap_cooldown <= 0.0 and randf() < TRAP_PLACE_CHANCE and _has_trappable_target():
			ai_state = State.PLACE_TRAP
			return
	if target_room == null or target_room == current_room:
		if DebugFlags.is_furniture_enabled():
			target_furniture = _pick_unvisited_furniture()
			if target_furniture == null:
				rooms_visited[current_room.get_instance_id()] = true
				target_room = mansion.pick_next_search_room(self)
		else:
			rooms_visited[current_room.get_instance_id()] = true
			target_room = mansion.pick_next_search_room(self)
	ai_state = State.SEARCH


func _execute_state() -> Vector2:
	match ai_state:
		State.RETURN:
			return _navigate_step()
		State.PLACE_TRAP:
			return _place_trap_step()
		_:
			return _search_step()


func _search_step() -> Vector2:
	if not DebugFlags.is_furniture_enabled():
		if current_room == target_room or target_room == null:
			rooms_visited[current_room.get_instance_id()] = true
			target_room = mansion.pick_next_search_room(self)
			return Vector2.ZERO
		return _navigate_step()
	if current_room == target_room or target_room == null:
		if target_furniture == null or not is_instance_valid(target_furniture) or visited_furniture.has(target_furniture.get_instance_id()):
			target_furniture = _pick_unvisited_furniture()
		if target_furniture == null:
			rooms_visited[current_room.get_instance_id()] = true
			target_room = mansion.pick_next_search_room(self)
			return Vector2.ZERO
		var to_furn: Vector2 = target_furniture.global_position - global_position
		if to_furn.length() <= FURNITURE_REACH:
			interact_with_nearby()
			return Vector2.ZERO
		return to_furn.normalized()
	return _navigate_step()


func _navigate_step() -> Vector2:
	if target_room == null:
		return Vector2.ZERO
	if mansion == null:
		return Vector2.ZERO
	if current_room == target_room:
		var exit_dir: String = mansion.get_exit_door_direction()
		if exit_dir != "" and current_room == mansion.get_exit_room():
			var exit_pos: Vector2 = current_room.get_door_world_pos(exit_dir)
			var to_exit: Vector2 = exit_pos - global_position
			if to_exit.length() <= DOOR_REACH:
				var exit_door: Door = current_room.get_door_for_direction(exit_dir)
				if exit_door != null and exit_door.is_closed():
					exit_door.try_open_for_spy(spy_id, true)
					return Vector2.ZERO
				return to_exit.normalized() * 0.6
			return to_exit.normalized()
	var dir: String = mansion.next_direction(current_room, target_room)
	if dir == "":
		return Vector2.ZERO
	var door_pos: Vector2 = current_room.get_door_world_pos(dir)
	var to_door: Vector2 = door_pos - global_position
	if to_door.length() <= DOOR_REACH:
		var door: Door = current_room.get_door_for_direction(dir)
		if door != null and door.is_closed():
			door.try_open_for_spy(spy_id, true)
			return Vector2.ZERO
		return to_door.normalized() * 0.6
	return to_door.normalized()


func _place_trap_step() -> Vector2:
	var trap_id: int = _pick_trap_to_place()
	if trap_id == -1:
		ai_state = State.SEARCH
		return Vector2.ZERO
	var target_node: Node = _pick_trap_target_for(trap_id)
	if target_node == null:
		ai_state = State.SEARCH
		return Vector2.ZERO
	var target_pos: Vector2 = (target_node as Node2D).global_position
	var to_target: Vector2 = target_pos - global_position
	if to_target.length() > FURNITURE_REACH:
		return to_target.normalized()
	var furn: Furniture = target_node as Furniture
	if furn != null:
		if not furn.is_raised_open():
			interact_with_nearby()
		if furn.is_raised_open() and furn.is_empty() and try_place_trap(trap_id):
			place_trap_cooldown = 5.0
	ai_state = State.SEARCH
	return Vector2.ZERO


func _pick_trap_to_place() -> int:
	var available: Array[int] = []
	for trap_id: int in ItemDB.get_all_traps():
		if GameState.get_trap_count(spy_id, trap_id) > 0:
			available.append(trap_id)
	if available.is_empty():
		return -1
	return available[randi() % available.size()]


func _pick_trap_target_for(_trap_id: int) -> Node:
	# Todas las trampas (incluido el cubo de agua) se colocan en muebles vacios
	# que ya hemos revisado, no en puertas.
	for furn_node: Node in current_room.furniture_list:
		var furn: Furniture = furn_node as Furniture
		if furn != null and furn.is_empty() and visited_furniture.has(furn.get_instance_id()):
			return furn
	return null


func _has_trappable_target() -> bool:
	for furn_node: Node in current_room.furniture_list:
		var furn: Furniture = furn_node as Furniture
		if furn != null and furn.is_empty():
			return true
	return false


func _pick_unvisited_furniture() -> Furniture:
	if current_room == null:
		return null
	var candidates: Array[Furniture] = []
	for furn_node: Node in current_room.furniture_list:
		var furn: Furniture = furn_node as Furniture
		if furn == null:
			continue
		if visited_furniture.has(furn.get_instance_id()):
			continue
		candidates.append(furn)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]
