class_name SpyHudPanel
extends PanelContainer

# Panel de estadísticas reutilizable (TIME, vida, inventario) para un espía.

const INV_BOX_MIN: Vector2 = Vector2(140, 120)
const HEALTH_BAR_WIDTH: float = 10.0
const HEALTH_BAR_HEIGHT: float = 72.0

var spy_id: int = 0
var show_room_label: bool = false
var time_label: Label = null
var ammo_label: Label = null
var room_label: Label = null
var health_bar: ProgressBar = null
var inv_box: PanelContainer = null
var slot_ids: Array[int] = []
var swatches: Array[ColorRect] = []


func setup(p_spy_id: int, p_show_room_label: bool) -> void:
	spy_id = p_spy_id
	show_room_label = p_show_room_label
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", NesUiTheme.panel_style())
	_build_content()


func _build_content() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	margin.add_child(body)

	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	body.add_child(col)

	col.add_child(_make_time_row())
	ammo_label = Label.new()
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.visible = false
	NesUiTheme.style_caption(ammo_label)
	col.add_child(ammo_label)
	if show_room_label:
		room_label = Label.new()
		room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		NesUiTheme.style_caption(room_label)
		col.add_child(room_label)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	inv_box = _make_inventory_box()
	col.add_child(inv_box)

	health_bar = _make_health_bar()
	body.add_child(health_bar)


func _make_time_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var title: Label = Label.new()
	title.text = "TIME"
	NesUiTheme.style_caption(title)
	row.add_child(title)
	time_label = Label.new()
	time_label.text = "05:00"
	time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	NesUiTheme.style_timer(time_label)
	row.add_child(time_label)
	return row


func _make_health_bar() -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	bar.max_value = SpyBase.MAX_HEALTH
	bar.value = SpyBase.MAX_HEALTH
	bar.show_percentage = false
	var bar_styles: Dictionary = NesUiTheme.health_bar_styles()
	bar.add_theme_stylebox_override("background", bar_styles["bg"] as StyleBoxFlat)
	bar.add_theme_stylebox_override("fill", bar_styles["fill"] as StyleBoxFlat)
	return bar


func _make_inventory_box() -> PanelContainer:
	var outer: PanelContainer = PanelContainer.new()
	outer.add_theme_stylebox_override("panel", NesUiTheme.inventory_box_style())
	outer.custom_minimum_size = INV_BOX_MIN
	outer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	outer.add_child(margin)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	margin.add_child(grid)
	for item_id: int in ItemDB.get_all_items():
		var swatch: ColorRect = ColorRect.new()
		swatch.custom_minimum_size = Vector2(36, 28)
		swatch.color = NesUiTheme.COLOR_SLOT_EMPTY
		grid.add_child(swatch)
		slot_ids.append(item_id)
		swatches.append(swatch)
	return outer


func set_time_text(text: String, timer_color: Color) -> void:
	if time_label == null:
		return
	time_label.text = text
	time_label.add_theme_color_override("font_color", timer_color)


func update_health(current: float, maximum: float) -> void:
	if health_bar == null:
		return
	health_bar.max_value = maximum
	health_bar.value = current
	var ratio: float = current / maximum if maximum > 0.0 else 0.0
	var styles: Dictionary = NesUiTheme.health_bar_styles()
	var fill: StyleBoxFlat = (styles["fill"] as StyleBoxFlat).duplicate() as StyleBoxFlat
	fill.bg_color = NesUiTheme.health_fill_color(ratio)
	health_bar.add_theme_stylebox_override("fill", fill)


func update_ammo(spy: SpyBase, weapon_id: StringName) -> void:
	if ammo_label == null:
		return
	var text: String = GameState.get_equipped_ammo_label(spy, weapon_id)
	if text.is_empty():
		ammo_label.visible = false
		ammo_label.text = ""
		return
	ammo_label.visible = true
	ammo_label.text = text


func update_inventory() -> void:
	var items: Array = GameState.get_items(spy_id)
	for i: int in slot_ids.size():
		var item_id: int = slot_ids[i]
		var swatch: ColorRect = swatches[i]
		if swatch == null:
			continue
		var owned: bool = items.has(item_id)
		swatch.color = ItemDB.ITEM_COLORS.get(item_id, Color.WHITE) if owned else NesUiTheme.COLOR_SLOT_EMPTY
		swatch.modulate = Color.WHITE


func set_room_text(text: String) -> void:
	if room_label != null:
		room_label.text = text


func blink_inventory() -> void:
	var items: Array = GameState.get_items(spy_id)
	for i: int in slot_ids.size():
		if not items.has(slot_ids[i]):
			continue
		var swatch: ColorRect = swatches[i]
		if swatch == null:
			continue
		swatch.modulate = Color.WHITE
		var tween: Tween = create_tween()
		tween.set_loops(4)
		tween.tween_property(swatch, "modulate", Color(1.0, 1.0, 0.45), 0.12)
		tween.tween_property(swatch, "modulate", Color.WHITE, 0.12)
