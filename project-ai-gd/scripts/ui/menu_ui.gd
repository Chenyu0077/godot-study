extends Control

signal menu_closed()

@onready var tab_container: TabContainer = %MenuTabs
@onready var btn_close: Button = %BtnCloseMenu

const CATEGORIES := ["清热", "补益", "安神", "祛湿", "理气", "全部"]

func _ready() -> void:
	btn_close.pressed.connect(_on_close)
	_build_tabs()

func _build_tabs() -> void:
	for child in tab_container.get_children():
		child.queue_free()

	for category in CATEGORIES:
		var scroll = ScrollContainer.new()
		scroll.name = category
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(vbox)
		tab_container.add_child(scroll)
		_populate_category(vbox, category)

func _populate_category(container: VBoxContainer, category: String) -> void:
	var all_recipes = RecipeManager.get_all_recipes()
	for recipe in all_recipes:
		var matches = false
		if category == "全部":
			matches = true
		else:
			for ingredient_id in recipe.get("ingredients", []):
				var ingredient = RecipeManager.get_ingredient(ingredient_id)
				if ingredient.get("category", "") == category:
					matches = true
					break
			for effect in recipe.get("effects", []):
				if category in effect:
					matches = true
					break

		if not matches:
			continue

		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size.y = 40

		var name_label = Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var unlocked = GameManager.is_recipe_unlocked(recipe["id"])

		if unlocked:
			name_label.text = "%s  [%s]  %s" % [
				recipe["name"],
				recipe.get("cooking_method", ""),
				", ".join(recipe.get("effects", []))
			]
		else:
			name_label.text = "%s  (未解锁 - %s)" % [recipe["name"], recipe.get("unlock_condition", "")]
			name_label.modulate = Color(0.5, 0.5, 0.5)

		var ingredients_label = Label.new()
		var ingredient_names: Array[String] = []
		for ing_id in recipe.get("ingredients", []):
			var ing = RecipeManager.get_ingredient(ing_id)
			ingredient_names.append(ing.get("name", ing_id))
		ingredients_label.text = "食材: " + ", ".join(ingredient_names)

		hbox.add_child(name_label)
		hbox.add_child(ingredients_label)
		container.add_child(hbox)

func _on_close() -> void:
	menu_closed.emit()
	visible = false
