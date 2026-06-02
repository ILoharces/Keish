extends CanvasLayer
class_name GameOverPanel

# Panel modal de fin de partida. Se muestra cuando GameState.game_over emite
# y permite reiniciar pulsando el boton (o Enter / R).

var panel: PanelContainer
var label: Label
var subtitle: Label
var button: Button


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
	GameState.game_over.connect(_on_game_over)


func _build_ui() -> void:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 220)
	center.add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	label = Label.new()
	label.add_theme_font_size_override("font_size", 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	subtitle = Label.new()
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	button = Button.new()
	button.text = "Reiniciar (Enter)"
	button.pressed.connect(_on_restart_pressed)
	box.add_child(button)


func _on_game_over(winner_id: int) -> void:
	var copy: Dictionary = _build_end_copy(winner_id)
	label.text = copy.get("title", "Fin de partida") as String
	subtitle.text = copy.get("subtitle", "") as String
	visible = true
	button.grab_focus()


func _build_end_copy(winner_id: int) -> Dictionary:
	if winner_id == GameState.WINNER_TIMEOUT:
		return {
			"title": "TIEMPO AGOTADO",
			"subtitle": "Nadie escapo a tiempo",
		}
	var winner_name: String = _spy_label(winner_id)
	var loser_id: int = _loser_id(winner_id)
	var loser_name: String = _spy_label(loser_id) if loser_id >= 0 else ""
	match GameState.match_end_reason:
		GameState.MatchEndReason.ESCAPE:
			return {
				"title": "%s GANA" % winner_name,
				"subtitle": "Escapo con los 5 objetos",
			}
		GameState.MatchEndReason.TRAP:
			return {
				"title": "%s GANA" % winner_name,
				"subtitle": "%s cayo en una trampa" % loser_name,
			}
		GameState.MatchEndReason.WEAPON:
			var weapon_name: String = WeaponDB.get_weapon_name(GameState.elimination_weapon_id)
			if weapon_name.is_empty():
				weapon_name = "un arma"
			return {
				"title": "%s GANA" % winner_name,
				"subtitle": "%s eliminado con %s" % [loser_name, weapon_name],
			}
		GameState.MatchEndReason.TIMEOUT:
			return {
				"title": "%s GANA" % winner_name,
				"subtitle": "%s se quedo sin tiempo" % loser_name,
			}
	return _legacy_end_copy(winner_id)


func _legacy_end_copy(winner_id: int) -> Dictionary:
	if winner_id == ItemDB.SpyId.PLAYER:
		if GameState.use_ai:
			return {"title": "VICTORIA", "subtitle": "Has ganado la partida"}
		return {"title": "BLANCO GANA", "subtitle": ""}
	if winner_id == ItemDB.SpyId.AI:
		if GameState.use_ai:
			return {"title": "DERROTA", "subtitle": "Has perdido la partida"}
		return {"title": "NEGRO GANA", "subtitle": ""}
	return {"title": "Fin de partida", "subtitle": ""}


func _spy_label(spy_id: int) -> String:
	if spy_id == ItemDB.SpyId.PLAYER:
		return "BLANCO"
	if spy_id == ItemDB.SpyId.AI:
		return "NEGRO" if not GameState.use_ai else "IA"
	return "???"


func _loser_id(winner_id: int) -> int:
	if winner_id == ItemDB.SpyId.PLAYER:
		return ItemDB.SpyId.AI
	if winner_id == ItemDB.SpyId.AI:
		return ItemDB.SpyId.PLAYER
	return GameState.WINNER_NONE


func _on_restart_pressed() -> void:
	visible = false
	GameState.reset_match()
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("restart"):
		_on_restart_pressed()
