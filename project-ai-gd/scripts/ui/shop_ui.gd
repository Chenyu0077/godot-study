extends Control

signal shop_closed()

@onready var recipe_list: VBoxContainer = %RecipeList
@onready var ingredient_list: VBoxContainer = %IngredientList
@onready var gold_label: Label = %ShopGoldLabel
@onready var btn_close: Button = %BtnCloseShop
@onready var tab_container: TabContainer = %ShopTabs

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
		var hbox = HBoxContainer.new()
		var label = Label.new()
		label.text = "%s（%s）" % [recipe["name"], ", ".join(recipe.get("effects", []))]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var price_label = Label.new()
		var price = _get_recipe_price(recipe)
		price_label.text = "%d金币" % price
		var btn = Button.new()
		btn.text = "购买"
		btn.pressed.connect(_buy_recipe.bind(recipe["id"], price))
		hbox.add_child(label)
		hbox.add_child(price_label)
		hbox.add_child(btn)
		recipe_list.add_child(hbox)

func _populate_ingredients() -> void:
	for child in ingredient_list.get_children():
		child.queue_free()

	var all_ingredients = RecipeManager.get_all_ingredients()
	for ingredient in all_ingredients:
		var hbox = HBoxContainer.new()
		var label = Label.new()
		var owned = GameManager.inventory.get(ingredient["id"], 0)
		label.text = "%s（库存:%d）" % [ingredient["name"], owned]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var price_label = Label.new()
		price_label.text = "%d金币" % ingredient["price"]
		var btn = Button.new()
		btn.text = "购买"
		btn.pressed.connect(_buy_ingredient.bind(ingredient["id"], ingredient["price"]))
		hbox.add_child(label)
		hbox.add_child(price_label)
		hbox.add_child(btn)
		ingredient_list.add_child(hbox)

func _buy_recipe(recipe_id: String, price: int) -> void:
	if GameManager.spend_gold(price):
		GameManager.unlock_recipe(recipe_id)
		_refresh_shop()

func _buy_ingredient(ingredient_id: String, price: int) -> void:
	if GameManager.spend_gold(price):
		GameManager.add_to_inventory(ingredient_id, 1)
		_refresh_shop()

func _get_recipe_price(recipe: Dictionary) -> int:
	var base = 20
	var step_count = recipe.get("steps", []).size()
	return base + step_count * 10

func _on_close() -> void:
	shop_closed.emit()
	visible = false
