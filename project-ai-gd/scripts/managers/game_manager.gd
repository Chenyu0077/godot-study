extends Node

signal day_started(day_number: int)
signal day_ended(day_number: int)
signal rating_changed(new_rating: int)
signal gold_changed(new_gold: int)
signal customer_count_changed(new_count: int)

var rating: int = 0:
	set(value):
		rating = max(0, value)
		rating_changed.emit(rating)

var customer_count: int = 5:
	set(value):
		customer_count = max(1, value)
		customer_count_changed.emit(customer_count)

var gold: int = 50:
	set(value):
		gold = max(0, value)
		gold_changed.emit(gold)

var day: int = 1
var daily_recommendation: String = ""
var unlocked_recipes: Array[String] = []
var inventory: Dictionary = {}

const UNLOCK_THRESHOLDS := {
	20: "rating_20",
	50: "rating_50",
	100: "rating_100"
}

func _ready() -> void:
	_init_default_unlocks()

func _init_default_unlocks() -> void:
	unlocked_recipes = []
	var recipes = RecipeManager.get_all_recipes()
	for recipe in recipes:
		if recipe.get("unlock_condition", "") == "default":
			unlocked_recipes.append(recipe["id"])

func start_day() -> void:
	daily_recommendation = RecipeManager.get_random_unlocked_recipe_id()
	day_started.emit(day)

func end_day() -> void:
	day_ended.emit(day)
	day += 1
	SaveManager.save_game()

func add_rating(amount: int) -> void:
	rating += amount
	_check_unlocks()

func add_gold(amount: int) -> void:
	gold += amount

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false

func add_to_inventory(ingredient_id: String, quantity: int = 1) -> void:
	if inventory.has(ingredient_id):
		inventory[ingredient_id] += quantity
	else:
		inventory[ingredient_id] = quantity

func remove_from_inventory(ingredient_id: String, quantity: int = 1) -> bool:
	if inventory.has(ingredient_id) and inventory[ingredient_id] >= quantity:
		inventory[ingredient_id] -= quantity
		if inventory[ingredient_id] <= 0:
			inventory.erase(ingredient_id)
		return true
	return false

func has_ingredients(ingredient_ids: Array) -> bool:
	for id in ingredient_ids:
		if not inventory.has(id) or inventory[id] <= 0:
			return false
	return true

func unlock_recipe(recipe_id: String) -> void:
	if recipe_id not in unlocked_recipes:
		unlocked_recipes.append(recipe_id)

func is_recipe_unlocked(recipe_id: String) -> bool:
	return recipe_id in unlocked_recipes

func _check_unlocks() -> void:
	for threshold in UNLOCK_THRESHOLDS:
		if rating >= threshold:
			var condition = UNLOCK_THRESHOLDS[threshold]
			var recipes = RecipeManager.get_recipes_by_condition(condition)
			for recipe in recipes:
				unlock_recipe(recipe["id"])

func get_max_customers_today() -> int:
	return 3 + floori(rating / 10.0)

func get_save_data() -> Dictionary:
	return {
		"rating": rating,
		"customer_count": customer_count,
		"gold": gold,
		"day": day,
		"unlocked_recipes": unlocked_recipes,
		"inventory": inventory,
	}

func load_save_data(data: Dictionary) -> void:
	rating = int(data.get("rating", 0))
	customer_count = int(data.get("customer_count", 5))
	gold = int(data.get("gold", 50))
	day = int(data.get("day", 1))

	unlocked_recipes.clear()
	var saved_recipes = data.get("unlocked_recipes", [])
	for r in saved_recipes:
		unlocked_recipes.append(str(r))

	inventory = {}
	var saved_inv = data.get("inventory", {})
	for key in saved_inv:
		inventory[str(key)] = int(saved_inv[key])
