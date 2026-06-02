extends RefCounted
class_name MapStorage

# Guardado y carga de mapas del editor en user://maps/*.json

const MAPS_DIR: String = "user://maps/"
const FILE_VERSION: int = 1


static func ensure_maps_dir() -> bool:
	if DirAccess.dir_exists_absolute(MAPS_DIR):
		return true
	var err: Error = DirAccess.make_dir_recursive_absolute(MAPS_DIR)
	if err != OK:
		push_error("[MapStorage] No se pudo crear %s (error %s)" % [MAPS_DIR, err])
		return false
	return true


static func list_map_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not ensure_maps_dir():
		return result
	var dir: DirAccess = DirAccess.open(MAPS_DIR)
	if dir == null:
		return result
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name: String in names:
		if not file_name.ends_with(".json"):
			continue
		var id: String = file_name.get_basename()
		var data: Dictionary = load_map_data(id)
		if data.is_empty():
			continue
		result.append({
			"id": id,
			"label": String(data.get("name", id)),
			"data": data,
		})
	return result


static func save_map(display_name: String, editor_data: Dictionary) -> String:
	if not ensure_maps_dir():
		return ""
	var trimmed: String = display_name.strip_edges()
	if trimmed.is_empty():
		push_warning("[MapStorage] Nombre de mapa vacio.")
		return ""
	var map_id: String = _sanitize_id(trimmed)
	var payload: Dictionary = editor_data.duplicate(true)
	payload["version"] = FILE_VERSION
	payload["name"] = trimmed
	var path: String = MAPS_DIR + map_id + ".json"
	var json_text: String = JSON.stringify(payload, "\t")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[MapStorage] No se pudo guardar: %s" % path)
		return ""
	file.store_string(json_text)
	file.close()
	return map_id


static func load_map_data(map_id: String) -> Dictionary:
	if map_id.is_empty():
		return {}
	var path: String = MAPS_DIR + map_id + ".json"
	if not FileAccess.file_exists(path):
		push_warning("[MapStorage] No existe: %s" % path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_error("[MapStorage] JSON invalido en %s" % path)
		return {}
	return parsed as Dictionary


static func data_to_layout(data: Dictionary, source_label: String = "") -> LevelLayout:
	var rooms: Dictionary = {}
	for entry: Variant in data.get("rooms", []):
		var gp: Vector2i = _parse_cell(entry)
		if gp.x >= 0:
			rooms[gp] = true
	var door_specs: Array[Dictionary] = []
	for entry: Variant in data.get("doors", []):
		if entry is Dictionary:
			var spec: Dictionary = _parse_door_spec(entry as Dictionary)
			if not spec.is_empty():
				door_specs.append(spec)
	var exit_door: Dictionary = _parse_exit_door(data)
	var player_gp: Vector2i = _parse_cell(data.get("player_spawn"))
	var ai_gp: Vector2i = _parse_cell(data.get("ai_spawn"))
	var label: String = source_label
	if label.is_empty():
		label = String(data.get("name", "saved"))
	return LevelLayout.from_editor(rooms, door_specs, exit_door, player_gp, ai_gp, label)


static func _parse_exit_door(data: Dictionary) -> Dictionary:
	if data.has("exit_door") and data["exit_door"] is Dictionary:
		var spec: Dictionary = _parse_door_spec(data["exit_door"] as Dictionary)
		if not spec.is_empty():
			return spec
	var legacy_cell: Vector2i = _parse_cell(data.get("exit"))
	if legacy_cell.x < 0:
		return {}
	for entry: Variant in data.get("doors", []):
		if entry is Dictionary:
			var spec: Dictionary = _parse_door_spec(entry as Dictionary)
			if spec.is_empty():
				continue
			if (spec["cell"] as Vector2i) == legacy_cell:
				return spec
	return {}


static func _sanitize_id(display_name: String) -> String:
	var slug: String = display_name.to_lower()
	var out: PackedStringArray = PackedStringArray()
	for i: int in slug.length():
		var code: int = slug.unicode_at(i)
		var ch: String = slug[i]
		if (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or ch == "-" or ch == "_":
			out.append(ch)
		elif ch == " ":
			out.append("_")
	var result: String = "".join(out).strip_edges()
	if result.is_empty():
		result = "mapa_%d" % Time.get_ticks_msec()
	return result


static func _parse_cell(value: Variant) -> Vector2i:
	if value == null:
		return Vector2i(-1, -1)
	if value is Vector2i:
		return value as Vector2i
	if value is Array:
		var arr: Array = value as Array
		if arr.size() >= 2:
			return Vector2i(int(arr[0]), int(arr[1]))
	if value is Dictionary:
		var dict: Dictionary = value as Dictionary
		if dict.has("x") and dict.has("y"):
			return Vector2i(int(dict["x"]), int(dict["y"]))
	return Vector2i(-1, -1)


static func _parse_door_spec(entry: Dictionary) -> Dictionary:
	var cell: Vector2i = Vector2i(-1, -1)
	if entry.has("cell"):
		cell = _parse_cell(entry["cell"])
	elif entry.has("x"):
		cell = Vector2i(int(entry["x"]), int(entry["y"]))
	if cell.x < 0:
		return {}
	var dir_str: String = String(entry.get("dir", "")).to_upper()
	if dir_str not in ["N", "S", "E", "W"]:
		return {}
	return {"cell": cell, "dir": dir_str}
