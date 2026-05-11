extends Control

signal shop_closed()

@onready var recipe_list: GridContainer = %RecipeList
@onready var ingredient_list: GridContainer = %IngredientList
@onready var gold_label: Label = %ShopGoldLabel
@onready var btn_close: Button = %BtnCloseShop
@onready var tab_container: TabContainer = %ShopTabs

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

const METHOD_ICONS := {"炖": "🍲", "煮": "🥘", "炒": "🍳", "蒸": "♨️", "焖": "🫕", "泡": "🍵"}

func _ready() -> void:
	btn_close.pressed.connect(_on_close)
	_refresh_shop()

func _refresh_shop() -> void:
	gold_label.text = "金币: %d" % GameManager.gold
	_populate_recipes()
	_populate_ingredients()

func _populate_recipes() -> void:
	for child in recipe_list.get_children():
		child.queue_free()
	var all_recipes = RecipeManager.get_all_recipes()
	for recipe in all_recipes:
		if GameManager.is_recipe_unlocked(recipe["id"]):
			continue
		recipe_list.add_child(_create_recipe_card(recipe))

func _populate_ingredients() -> void:
	for child in ingredient_list.get_children():
		child.queue_free()
	var all_ingredients = RecipeManager.get_all_ingredients()
	for ingredient in all_ingredients:
		ingredient_list.add_child(_create_ingredient_card(ingredient))

func _create_recipe_card(recipe: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_SIZE, CARD_SIZE)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.75, 0.4, 0.15)
	style.border_width_left = 2; style.border_width_top = 2
	style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = Color(0.9, 0.75, 0.4, 0.5)
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
	var icon = _create_icon(icon_text, Color(0.9, 0.75, 0.4))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)

	var name_label = Label.new()
	name_label.text = recipe["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_label)

	var price = _get_recipe_price(recipe)
	var price_label = Label.new()
	price_label.text = "%d金币" % price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 11)
	price_label.modulate = Color(0.9, 0.8, 0.4)
	vbox.add_child(price_label)

	var btn = Button.new()
	btn.text = "购买"
	btn.custom_minimum_size.y = 22
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(_buy_recipe.bind(recipe["id"], price))
	if GameManager.gold < price:
		btn.disabled = true
	vbox.add_child(btn)

	return panel

func _create_ingredient_card(ingredient: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_SIZE, CARD_SIZE)

	var category = ingredient.get("category", "")
	var color = CATEGORY_COLORS.get(category, Color(0.7, 0.7, 0.7))
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

	var icon = _create_icon(ingredient["name"].left(1), color)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)

	var name_label = Label.new()
	var owned = GameManager.inventory.get(ingredient["id"], 0)
	name_label.text = "%s (x%d)" % [ingredient["name"], owned]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(name_label)

	var price_label = Label.new()
	price_label.text = "%d金币" % ingredient["price"]
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 11)
	price_label.modulate = Color(0.9, 0.8, 0.4)
	vbox.add_child(price_label)

	var btn = Button.new()
	btn.text = "购买"
	btn.custom_minimum_size.y = 22
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(_buy_ingredient.bind(ingredient["id"], ingredient["price"]))
	if GameManager.gold < ingredient["price"]:
		btn.disabled = true
	vbox.add_child(btn)

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

func _buy_recipe(recipe_id: String, price: int) -> void:
	if GameManager.spend_gold(price):
		GameManager.unlock_recipe(recipe_id)
		_refresh_shop()

func _buy_ingredient(ingredient_id: String, price: int) -> void:
	if GameManager.spend_gold(price):
		GameManager.add_to_inventory(ingredient_id, 1)
		_refresh_shop()

func _get_recipe_price(recipe: Dictionary) -> int:
	return 20 + recipe.get("steps", []).size() * 10

func _on_close() -> void:
	shop_closed.emit()
	visible = false
