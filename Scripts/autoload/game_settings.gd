extends Node

# Ajustes persistentes del juego. Anade nuevas opciones en _DEFINITIONS y propiedades
# tipadas debajo; el menu de ajustes se genera automaticamente a partir de ellas.

signal setting_changed(option_id: String, value: Variant)
signal control_modes_changed

const SETTINGS_PATH: String = "user://game_settings.cfg"

const _DEFINITIONS: Array[Dictionary] = [
	{
		"section_id": "gameplay",
		"title": "Partida",
		"options": [
			{
				"id": "use_ai_default",
				"label": "Jugar contra IA por defecto",
				"type": "bool",
				"hint": "Si esta desactivado, la partida usa dos jugadores locales.",
			},
		],
	},
]

var use_ai_default: bool = true
var p1_control_mode: int = 0
var p2_control_mode: int = 2
var p1_gamepad_aim_mode: int = 0
var p2_gamepad_aim_mode: int = 0

var _values: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sync_properties_to_values()
	load_settings()
	apply_to_match_defaults()


func get_sections() -> Array[Dictionary]:
	return _DEFINITIONS.duplicate(true)


func get_option_value(option_id: String) -> Variant:
	return _values.get(option_id)


func set_option_value(option_id: String, value: Variant) -> void:
	if not _values.has(option_id):
		push_warning("[GameSettings] Opcion desconocida: %s" % option_id)
		return
	if _values[option_id] == value:
		return
	_values[option_id] = value
	_apply_value_to_property(option_id, value)
	save_settings()
	setting_changed.emit(option_id, value)


func set_p1_control_mode(mode: int) -> void:
	if p1_control_mode == mode:
		return
	p1_control_mode = mode
	save_settings()
	control_modes_changed.emit()


func set_p2_control_mode(mode: int) -> void:
	if p2_control_mode == mode:
		return
	p2_control_mode = mode
	save_settings()
	control_modes_changed.emit()


func get_gamepad_aim_mode(player_index: int) -> int:
	if player_index <= 0:
		return clampi(p1_gamepad_aim_mode, 0, 1)
	return clampi(p2_gamepad_aim_mode, 0, 1)


func set_gamepad_aim_mode(player_index: int, mode: int) -> void:
	var clamped: int = clampi(mode, 0, 1)
	if player_index <= 0:
		if p1_gamepad_aim_mode == clamped:
			return
		p1_gamepad_aim_mode = clamped
	else:
		if p2_gamepad_aim_mode == clamped:
			return
		p2_gamepad_aim_mode = clamped
	save_settings()


func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("[GameSettings] No se pudo cargar ajustes: %s" % error_string(err))
	for section: Dictionary in _DEFINITIONS:
		var section_id: String = String(section.get("section_id", ""))
		var options: Array = section.get("options", []) as Array
		for option: Variant in options:
			var entry: Dictionary = option as Dictionary
			var option_id: String = String(entry.get("id", ""))
			if option_id.is_empty():
				continue
			var default_value: Variant = _default_for_option(entry)
			var stored: Variant = default_value
			if err == OK:
				stored = config.get_value(section_id, option_id, default_value)
			_values[option_id] = stored
	if err == OK:
		p1_control_mode = int(config.get_value("controls", "p1_control_mode", 0))
		p2_control_mode = int(config.get_value("controls", "p2_control_mode", 2))
		p1_gamepad_aim_mode = int(config.get_value("controls", "p1_gamepad_aim_mode", 0))
		p2_gamepad_aim_mode = int(config.get_value("controls", "p2_gamepad_aim_mode", 0))
	_sync_values_to_properties()


func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	for section: Dictionary in _DEFINITIONS:
		var section_id: String = String(section.get("section_id", ""))
		var options: Array = section.get("options", []) as Array
		for option: Variant in options:
			var entry: Dictionary = option as Dictionary
			var option_id: String = String(entry.get("id", ""))
			if option_id.is_empty() or not _values.has(option_id):
				continue
			config.set_value(section_id, option_id, _values[option_id])
	config.set_value("controls", "p1_control_mode", p1_control_mode)
	config.set_value("controls", "p2_control_mode", p2_control_mode)
	config.set_value("controls", "p1_gamepad_aim_mode", p1_gamepad_aim_mode)
	config.set_value("controls", "p2_gamepad_aim_mode", p2_gamepad_aim_mode)
	var err: Error = config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("[GameSettings] No se pudo guardar ajustes: %s" % error_string(err))


func apply_to_match_defaults() -> void:
	GameState.use_ai = use_ai_default


func _sync_properties_to_values() -> void:
	_values["use_ai_default"] = use_ai_default


func _sync_values_to_properties() -> void:
	use_ai_default = bool(_values.get("use_ai_default", true))


func _apply_value_to_property(option_id: String, value: Variant) -> void:
	match option_id:
		"use_ai_default":
			use_ai_default = bool(value)
		_:
			pass


func _default_for_option(entry: Dictionary) -> Variant:
	match String(entry.get("type", "")):
		"bool":
			return bool(entry.get("default", false))
		_:
			return entry.get("default", null)
