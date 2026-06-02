extends Node

const WEAPONS_DIR: String = "res://resources/weapons/"

var _weapons: Dictionary = {}


func _ready() -> void:
	_load_weapons()


func _load_weapons() -> void:
	_weapons.clear()
	if not DirAccess.dir_exists_absolute(WEAPONS_DIR):
		push_warning("[WeaponDB] No se encontro carpeta: %s" % WEAPONS_DIR)
		return
	for file_name: String in DirAccess.get_files_at(WEAPONS_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var path: String = WEAPONS_DIR.path_join(file_name)
		var weapon: WeaponData = load(path) as WeaponData
		if weapon != null and not weapon.weapon_id.is_empty():
			_weapons[weapon.weapon_id] = weapon


func get_weapon(id: StringName) -> WeaponData:
	return _weapons.get(id) as WeaponData


func get_all_weapons() -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for key: Variant in _weapons.keys():
		var weapon: WeaponData = _weapons[key] as WeaponData
		if weapon != null:
			result.append(weapon)
	return result


func get_weapon_name(id: StringName) -> String:
	var weapon: WeaponData = get_weapon(id)
	if weapon == null:
		return String(id)
	return weapon.display_name
