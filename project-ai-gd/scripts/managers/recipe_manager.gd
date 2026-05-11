extends Node

var _recipes: Array = []
var _ingredients: Array = []
var _symptoms: Array = []
var _recipe_map: Dictionary = {}
var _ingredient_map: Dictionary = {}

func _ready() -> void:
	_load_data()

func _load_data() -> void:
	_recipes = _load_json("res://data/recipes.json")
	_ingredients = _load_json("res://data/ingredients.json")
	_symptoms = _load_json("res://data/symptoms.json")

	_recipe_map.clear()
	for recipe in _recipes:
		_recipe_map[recipe["id"]] = recipe

	_ingredient_map.clear()
	for ingredient in _ingredients:
		_ingredient_map[ingredient["id"]] = ingredient

func _load_json(path: String) -> Array:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to load: " + path)
		return []
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK:
		push_error("JSON parse error in " + path + ": " + json.get_error_message())
		return []
	return json.data

func get_all_recipes() -> Array:
	return _recipes

func get_recipe(recipe_id: String) -> Dictionary:
	return _recipe_map.get(recipe_id, {})

func get_unlocked_recipes() -> Array:
	var result: Array = []
	for recipe in _recipes:
		if GameManager.is_recipe_unlocked(recipe["id"]):
			result.append(recipe)
	return result

func get_recipes_by_condition(condition: String) -> Array:
	var result: Array = []
	for recipe in _recipes:
		if recipe.get("unlock_condition", "") == condition:
			result.append(recipe)
	return result

func get_random_unlocked_recipe_id() -> String:
	var unlocked = get_unlocked_recipes()
	if unlocked.is_empty():
		return ""
	return unlocked[randi() % unlocked.size()]["id"]

func get_ingredient(ingredient_id: String) -> Dictionary:
	return _ingredient_map.get(ingredient_id, {})

func get_all_ingredients() -> Array:
	return _ingredients

func get_all_symptoms() -> Array:
	return _symptoms

func get_symptom(symptom_id: String) -> Dictionary:
	for s in _symptoms:
		if s["id"] == symptom_id:
			return s
	return {}

func get_recipes_for_symptom(symptom_id: String) -> Array:
	var symptom = get_symptom(symptom_id)
	if symptom.is_empty():
		return []
	var result: Array = []
	for recipe_id in symptom.get("recommended_recipes", []):
		var recipe = get_recipe(recipe_id)
		if not recipe.is_empty():
			result.append(recipe)
	return result

func is_recipe_for_symptom(recipe_id: String, symptom_id: String) -> bool:
	var symptom = get_symptom(symptom_id)
	return recipe_id in symptom.get("recommended_recipes", [])
