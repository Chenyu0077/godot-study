extends Control

signal menu_closed()

@onready var tab_container: TabContainer = %MenuTabs
@onready var btn_close: Button = %BtnCloseMenu

const CARD_SIZE := 120
const GRID_COLUMNS := 5
const CATEGORIES := ["春", "夏", "秋", "冬", "全部"]

const SEASON_COLORS := {
	"春": Color(0.6, 0.85, 0.55),
	"夏": Color(0.4, 0.8, 0.85),
	"秋": Color(0.9, 0.75, 0.4),
	"冬": Color(0.7, 0.6, 0.85),
}

const METHOD_ICONS := {"炖": "🍲", "煮": "🥘", "炒": "🍳", "蒸": "♨️", "焖": "🫕", "泡": "🍵"}

func _ready() -> void:
	btn_close.pressed.connect(_on_close)
	_build_tabs()

func _build_tabs() -> void:
	for child in tab_container.get_children():
		child.queue_free()

	for category in CATEGORIES:
		var scroll = ScrollContainer.new()
		scroll.name = category
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var grid = GridContainer.new()
		grid.columns = GRID_COLUMNS
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		scroll.add_child(grid)
		tab_container.add_child(scroll)
		_populate_category(grid, category)

func _populate_category(container: GridContainer, category: String) -> void:
	var all_recipes = RecipeManager.get_all_recipes()
	for recipe in all_recipes:
		var matches = false
		if category == "全部":
			matches = true
		elif recipe.get("season", "") == category:
			matches = true
		if not matches:
			continue
		container.add_child(_create_recipe_card(recipe))

func _create_recipe_card(recipe: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_SIZE, CARD_SIZE)
	var unlocked = GameManager.is_recipe_unlocked(recipe["id"])

	var season = recipe.get("season", "")
	var color = SEASON_COLORS.get(season, Color(0.7, 0.7, 0.7))
	if not unlocked:
		color = Color(0.4, 0.4, 0.4)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(color, 0.15)
	style.border_width_left = 2; style.border_width_top = 2
	style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = Color(color, 0.5)
	style.corner_radius_top_left = 8; style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
	style.content_margin_left = 4; style.content_margin_top = 4
	style.content_margin_right = 4; style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var method = recipe.get("cooking_method", "")
	var icon_text = METHOD_ICONS.get(method, "🍽️")
	if not unlocked:
		icon_text = "🔒"
	var icon = _create_icon(icon_text, color)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)

	var name_label = Label.new()
	name_label.text = recipe["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	if not unlocked:
		name_label.modulate = Color(0.5, 0.5, 0.5)
	vbox.add_child(name_label)

	var info_label = Label.new()
	if unlocked:
		info_label.text = recipe.get("solar_term", "")
	else:
		info_label.text = _format_unlock(recipe.get("unlock_condition", ""))
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 10)
	info_label.modulate = Color(0.6, 0.6, 0.6)
	vbox.add_child(info_label)

	var diff_label = Label.new()
	var steps = recipe.get("steps", []).size()
	diff_label.text = "★".repeat(mini(steps, 3))
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(diff_label)

	return panel

func _create_icon(text: String, color: Color) -> PanelContainer:
	var container = PanelContainer.new()
	container.custom_minimum_size = Vector2(40, 40)
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = 6; s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6; s.corner_radius_bottom_right = 6
	container.add_theme_stylebox_override("panel", s)
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	container.add_child(label)
	return container

func _format_unlock(condition: String) -> String:
	match condition:
		"default": return "默认"
		"rating_20": return "评价≥20"
		"rating_50": return "评价≥50"
		"rating_100": return "评价≥100"
		_: return condition

func _on_close() -> void:
	menu_closed.emit()
	visible = false
