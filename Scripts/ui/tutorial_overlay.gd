extends CanvasLayer
class_name TutorialOverlay

# Tutorial de primera ejecucion: ventanas de texto por pasos antes del menu principal.

signal finished

const OVERLAY_COLOR: Color = Color(0.0, 0.0, 0.0, 0.72)
const PANEL_MIN_SIZE: Vector2 = Vector2(560, 320)

const _STEPS: Array[Dictionary] = [
	{
		"title": "Bienvenido a Kage",
		"body": (
			"Kage es un prototipo de espias en una mansion, inspirado en Spy vs Spy.\n\n"
			+ "Esta version es extremadamente cruda: hay muchos errores, sistemas "
			+ "incompletos y comportamientos inesperados. Gracias por probarla y "
			+ "reportar lo que falle."
		),
	},
	{
		"title": "Aviso importante",
		"body": (
			"El respawn todavia no funciona bien. Puede fallar el reaparecer, "
			+ "teletransportarte a sitios raros o restar tiempo de forma confusa.\n\n"
			+ "No esperes pulido en muertes y reapariciones; estamos depurandolo."
		),
	},
	{
		"title": "De que va el juego",
		"body": (
			"Dos espias (blanco vs negro) compiten en la misma mansion.\n\n"
			+ "Objetivo: reunir los 5 objetos secretos. Primero necesitas el maletin; "
			+ "luego puedes coger llave, dinero, pasaporte y microfilm. Escapa por la "
			+ "puerta de salida con todo el botin.\n\n"
			+ "Cada espia tiene unos 5 minutos de reloj personal. Ganas escapando o si "
			+ "el rival se queda sin tiempo."
		),
	},
	{
		"title": "Controles",
		"body": (
			"Jugador 1 (blanco): WASD mover; raton apunta dentro de las ventanas de "
			+ "vista; clic izquierdo dispara; E interactuar; Q/R trampas; Tab trapulator; "
			+ "M mapa; Esc pausa.\n\n"
			+ "Jugador 2 (negro, sin IA): flechas mover; O disparar. El apuntado con "
			+ "solo teclado esta muy limitado; se recomienda mando (stick derecho apunta, "
			+ "RT dispara, R3 cambia modo de mirilla).\n\n"
			+ "Modos de control en Ajustes."
		),
	},
	{
		"title": "Armas",
		"body": (
			"Las armas aparecen en el mapa: recogelas y equipalas en las manos. La "
			+ "mirilla solo se mueve dentro de las dos ventanas de vista (blanco y negro).\n\n"
			+ "Pistola y metralleta: apunta y dispara con clic izquierdo (P1) o RT (mando).\n\n"
			+ "Canon orbital (laser): pulsa disparar para armarlo, mueve la mirilla a la "
			+ "ventana del rival y apunta a la habitacion donde esta (o donde crees que "
			+ "estara); vuelve a disparar para lanzar el rayo. Golpea sin estar en la misma "
			+ "sala. Solo lleva un disparo por carga.\n\n"
			+ "Matar al rival no termina la partida: suelta todo su botin y le penaliza el "
			+ "reloj. Tras morir reaparece en una habitacion aleatoria (con los problemas "
			+ "del respawn que comentamos)."
		),
	},
	{
		"title": "Trampas y HUD",
		"body": (
			"Coloca trampas con Q/R y el trapulator (Tab). El mapa (M) muestra la mansion.\n\n"
			+ "El HUD muestra inventario, tiempo y estado de cada espia.\n\n"
			+ "La victoria es por escape con los 5 objetos o por agotar el tiempo del "
			+ "rival, no por una sola muerte. Pulsa Entendido para ir al menu."
		),
	},
]

@onready var _overlay: ColorRect = %Overlay
@onready var _panel: PanelContainer = %Panel
@onready var _title_label: Label = %TitleLabel
@onready var _body_label: Label = %BodyLabel
@onready var _page_label: Label = %PageLabel
@onready var _skip_button: Button = %SkipButton
@onready var _next_button: Button = %NextButton

var _step_index: int = 0


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_overlay.color = OVERLAY_COLOR
	_panel.custom_minimum_size = PANEL_MIN_SIZE
	_panel.add_theme_stylebox_override("panel", NesUiTheme.panel_style())
	_title_label.add_theme_font_override("font", NesUiTheme.ui_font())
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT)
	_body_label.add_theme_font_override("font", NesUiTheme.ui_font())
	_body_label.add_theme_font_size_override("font_size", NesUiTheme.FONT_LABEL)
	_body_label.add_theme_color_override("font_color", NesUiTheme.COLOR_TEXT)
	_page_label.add_theme_font_override("font", NesUiTheme.mono_font())
	_page_label.add_theme_font_size_override("font_size", NesUiTheme.FONT_LABEL)
	_page_label.add_theme_color_override("font_color", NesUiTheme.COLOR_BORDER)
	_skip_button.pressed.connect(_on_skip_pressed)
	_next_button.pressed.connect(_on_next_pressed)


func show_tutorial() -> void:
	_step_index = 0
	_apply_step()
	visible = true
	_next_button.grab_focus()


func reset_and_show() -> void:
	show_tutorial()


func is_showing() -> bool:
	return visible


func _apply_step() -> void:
	var step: Dictionary = _STEPS[_step_index]
	_title_label.text = String(step.get("title", ""))
	_body_label.text = String(step.get("body", ""))
	var total: int = _STEPS.size()
	_page_label.text = "%d / %d" % [_step_index + 1, total]
	var is_last: bool = _step_index >= total - 1
	_next_button.text = "Entendido" if is_last else "Siguiente"


func _on_skip_pressed() -> void:
	_finish_tutorial()


func _on_next_pressed() -> void:
	if _step_index >= _STEPS.size() - 1:
		_finish_tutorial()
		return
	_step_index += 1
	_apply_step()
	_next_button.grab_focus()


func _finish_tutorial() -> void:
	GameSettings.mark_tutorial_completed()
	visible = false
	finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		_on_next_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_skip_pressed()
		get_viewport().set_input_as_handled()
