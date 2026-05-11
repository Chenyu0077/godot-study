extends Control

signal inventory_closed()

@onready var grid: GridContainer = %InventoryGrid
@onready var btn_close: Button = %BtnCloseInventory

const CARD_SIZE := 120

const CATEGORY_COLORS := {
	"荤菜": Color(0.85, 0.55, 0.45), "蔬菜": Color(0.5, 0.8, 0.5),
	"补益": Color(0.9, 0.75, 0.4), "补气": Color(0.95, 0.8, 0.5),
	"补血": Color(0.85, 0.4, 0.4), "清热": Color(0.5, 0.85, 0.85),
	"祛湿": Color(0.6, 0.75, 0.9), "安神": Color(0.75, 0.6, 0.85),
	"理气": Color(0.7, 0.85, 0.6), "温中": Color(0.9, 0.65, 0.4),
	"润肺": Color(0.8, 0.9, 0.95), "消食": Color(0.85, 0.8, 0.5),
	"养阴": Color(0.7, 0.8, 0.9), "解表": Color(0.6, 0.9, 0.7),
	"收涩": Color(0.8, 0.7, 0.6), "主食": Color(0.9, 0.88, 0.75),
}

var _tooltip: PanelContainer = null

func _ready() -> void:
	btn_close.pressed.connect(_on_close)
	grid.columns = 5
	_create_tooltip()
	_refresh()

func _create_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.visible = false
	_tooltip.z_index = 100
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.12, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.7, 0.4, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	_tooltip.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.name = "TooltipLabel"
	label.add_theme_font_size_override("font_size", 13)
	_tooltip.add_child(label)

	add_child(_tooltip)

func _refresh() -> void:
	for child in grid.get_children():
		child.queue_free()

	for ingredient_id in GameManager.inventory:
		var quantity = GameManager.inventory[ingredient_id]
		if quantity <= 0:
			continue
		var ingredient = RecipeManager.get_ingredient(ingredient_id)
		var card = _create_card(ingredient, quantity)
		grid.add_child(card)

	if GameManager.inventory.is_empty():
		var empty_label = Label.new()
		empty_label.text = "仓库空空如也"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(CARD_SIZE * 3, CARD_SIZE)
		grid.add_child(empty_label)

func _create_card(ingredient: Dictionary, quantity: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_SIZE, CARD_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var category = ingredient.get("category", "")
	var color = CATEGORY_COLORS.get(category, Color(0.7, 0.7, 0.7))
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color, 0.15)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(color, 0.5)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 6
	style.content_margin_top = 6
	style.content_margin_right = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	panel.mouse_entered.connect(_on_card_hover.bind(panel, ingredient, quantity))
	panel.mouse_exited.connect(_on_card_exit)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var icon_container = PanelContainer.new()
	icon_container.custom_minimum_size = Vector2(44, 44)
	icon_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = color
	icon_style.corner_radius_top_left = 6
	icon_style.corner_radius_top_right = 6
	icon_style.corner_radius_bottom_left = 6
	icon_style.corner_radius_bottom_right = 6
	icon_container.add_theme_stylebox_override("panel", icon_style)
	var icon_label = Label.new()
	icon_label.text = ingredient["name"].left(1)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 20)
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_container.add_child(icon_label)
	vbox.add_child(icon_container)

	var name_label = Label.new()
	name_label.text = ingredient.get("name", "")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	var qty_label = Label.new()
	qty_label.text = "x%d" % quantity
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_label.add_theme_font_size_override("font_size", 12)
	qty_label.modulate = Color(0.8, 0.8, 0.5)
	qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(qty_label)

	return panel

func _on_card_hover(card: PanelContainer, ingredient: Dictionary, quantity: int) -> void:
	var label = _tooltip.get_node("TooltipLabel") as Label
	label.text = "%s\n分类: %s\n功效: %s\n库存: %d" % [
		ingredient.get("name", ""),
		ingredient.get("category", ""),
		", ".join(ingredient.get("effects", [])),
		quantity
	]
	_tooltip.visible = true
	_tooltip.reset_size()
	var card_rect = card.get_global_rect()
	var tip_pos = Vector2(card_rect.position.x + card_rect.size.x + 8, card_rect.position.y)
	var viewport_size = get_viewport_rect().size
	if tip_pos.x + _tooltip.size.x > viewport_size.x:
		tip_pos.x = card_rect.position.x - _tooltip.size.x - 8
	if tip_pos.y + _tooltip.size.y > viewport_size.y:
		tip_pos.y = viewport_size.y - _tooltip.size.y - 4
	_tooltip.global_position = tip_pos

func _on_card_exit() -> void:
	_tooltip.visible = false

func _on_close() -> void:
	inventory_closed.emit()
	visible = false
