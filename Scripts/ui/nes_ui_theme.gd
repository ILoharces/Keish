class_name NesUiTheme
extends RefCounted

# Estilo Spy vs Spy (NES): fondo negro, bordes grises claros, texto blanco.

const COLOR_BG: Color = Color("#000000")
const COLOR_BORDER: Color = Color("#d4d4d4")
const COLOR_BORDER_DARK: Color = Color("#707070")
const COLOR_TEXT: Color = Color("#f0f0f0")
const COLOR_SLOT_EMPTY: Color = Color("#1a1a1a")
const COLOR_TOGGLE_SELECTED: Color = Color("#606060")
const COLOR_TOGGLE_UNSELECTED: Color = Color("#080808")
const COLOR_TIMER_WARN: Color = Color("#ffd54f")
const COLOR_TIMER_DANGER: Color = Color("#ff5252")

const BORDER_WIDTH: int = 4
const FONT_LABEL: int = 14
const FONT_TIMER: int = 32
const FONT_SPY: int = 16

static var _mono_font: Font = null


static func mono_font() -> Font:
	if _mono_font == null:
		var sf: SystemFont = SystemFont.new()
		sf.font_names = PackedStringArray(["Consolas", "Courier New", "Lucida Console", "monospace"])
		sf.font_weight = 700
		_mono_font = sf
	return _mono_font


static func ui_font() -> Font:
	return ThemeDB.fallback_font


static func panel_style(bg: Color = COLOR_BG, border: Color = COLOR_BORDER, radius: int = 0) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_width_left = BORDER_WIDTH
	box.border_width_top = BORDER_WIDTH
	box.border_width_right = BORDER_WIDTH
	box.border_width_bottom = BORDER_WIDTH
	box.border_color = border
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box


static func toggle_button_style(
	selected: bool,
	border: Color = COLOR_BORDER_DARK,
	border_width: int = 2
) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = COLOR_TOGGLE_SELECTED if selected else COLOR_TOGGLE_UNSELECTED
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.border_color = border
	return box


static func style_toggle_button(button: Button) -> void:
	if not button.toggle_mode:
		return
	_apply_toggle_button_styles(button)
	if button.has_meta("_nes_toggle_styled"):
		return
	button.set_meta("_nes_toggle_styled", true)
	button.toggled.connect(_on_toggle_button_toggled.bind(button))
	button.focus_entered.connect(_on_toggle_button_focus.bind(button))
	button.focus_exited.connect(_on_toggle_button_focus.bind(button))


static func refresh_toggle_button(button: Button) -> void:
	if not button.toggle_mode:
		return
	_apply_toggle_button_styles(button)


static func style_toggle_buttons(buttons: Array[Button]) -> void:
	for button: Button in buttons:
		style_toggle_button(button)


static func _apply_toggle_button_styles(button: Button) -> void:
	var selected: bool = button.button_pressed
	button.add_theme_stylebox_override("normal", toggle_button_style(false))
	button.add_theme_stylebox_override("hover", toggle_button_style(false, COLOR_BORDER))
	button.add_theme_stylebox_override("pressed", toggle_button_style(true))
	button.add_theme_stylebox_override("focus", toggle_button_style(selected, COLOR_BORDER))
	button.add_theme_stylebox_override("disabled", toggle_button_style(selected))
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	button.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	button.add_theme_color_override("font_focus_color", COLOR_TEXT)
	button.add_theme_color_override("font_disabled_color", COLOR_TEXT)


static func _on_toggle_button_toggled(_pressed: bool, button: Button) -> void:
	_apply_toggle_button_styles(button)


static func _on_toggle_button_focus(button: Button) -> void:
	_apply_toggle_button_styles(button)


static func inventory_box_style() -> StyleBoxFlat:
	return panel_style(COLOR_BG, COLOR_BORDER, 10)


static func style_caption(label: Label) -> void:
	label.add_theme_font_override("font", ui_font())
	label.add_theme_font_size_override("font_size", FONT_LABEL)
	label.add_theme_color_override("font_color", COLOR_TEXT)


static func style_timer(label: Label) -> void:
	label.add_theme_font_override("font", mono_font())
	label.add_theme_font_size_override("font_size", FONT_TIMER)
	label.add_theme_color_override("font_color", COLOR_TEXT)


static func style_spy_label(label: Label) -> void:
	label.add_theme_font_override("font", ui_font())
	label.add_theme_font_size_override("font_size", FONT_SPY)
	label.add_theme_color_override("font_color", COLOR_TEXT)


static func timer_color(seconds: float) -> Color:
	if seconds < 30.0:
		return COLOR_TIMER_DANGER
	if seconds < 60.0:
		return COLOR_TIMER_WARN
	return COLOR_TEXT


static func health_bar_styles() -> Dictionary:
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color("#2a0a0a")
	bg.border_width_left = 1
	bg.border_width_top = 1
	bg.border_width_right = 1
	bg.border_width_bottom = 1
	bg.border_color = COLOR_BORDER_DARK

	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color("#43a047")

	return {"bg": bg, "fill": fill}


static func health_fill_color(ratio: float) -> Color:
	if ratio <= 0.25:
		return COLOR_TIMER_DANGER
	if ratio <= 0.5:
		return COLOR_TIMER_WARN
	return Color("#43a047")
