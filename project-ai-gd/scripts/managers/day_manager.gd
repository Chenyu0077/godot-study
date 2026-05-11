extends Node

signal customer_queue_ready(customers: Array)
signal day_complete(summary: Dictionary)

var _customer_queue: Array = []
var _current_customer_index: int = 0
var _spawned_count: int = 0
var _day_summary: Dictionary = {}

func start_new_day() -> void:
	_current_customer_index = 0
	_spawned_count = 0
	_day_summary = {"served": 0, "success": 0, "failed": 0, "timeout": 0}
	_generate_customer_queue()
	GameManager.start_day()
	customer_queue_ready.emit(_customer_queue)

func _generate_customer_queue() -> void:
	_customer_queue.clear()
	var count = GameManager.get_max_customers_today()
	for i in range(count):
		_customer_queue.append(_generate_customer_data())

func _generate_customer_data() -> Dictionary:
	var roll = randf()
	var type: String
	if roll < 0.60:
		type = "normal"
	elif roll < 0.85:
		type = "sick"
	else:
		type = "special"

	var customer := {
		"type": type,
		"patience": randf_range(30.0, 60.0),
	}

	match type:
		"normal":
			var recipes = RecipeManager.get_unlocked_recipes()
			if not recipes.is_empty():
				var chosen = recipes[randi() % recipes.size()]
				customer["requested_recipe"] = chosen["id"]
		"sick":
			var symptoms = RecipeManager.get_all_symptoms()
			if not symptoms.is_empty():
				var chosen = symptoms[randi() % symptoms.size()]
				customer["symptom_id"] = chosen["id"]
				customer["symptom_name"] = chosen["name"]
				customer["symptom_description"] = chosen["description"]
		"special":
			var all_recipes = RecipeManager.get_all_recipes()
			var locked: Array = []
			for r in all_recipes:
				if not GameManager.is_recipe_unlocked(r["id"]):
					locked.append(r)
			if not locked.is_empty():
				var chosen = locked[randi() % locked.size()]
				customer["requested_recipe"] = chosen["id"]
				customer["recipe_name"] = chosen["name"]
			else:
				customer["type"] = "normal"
				var recipes = RecipeManager.get_unlocked_recipes()
				if not recipes.is_empty():
					var chosen = recipes[randi() % recipes.size()]
					customer["requested_recipe"] = chosen["id"]

	return customer

func pop_next_unspawned_customer() -> Dictionary:
	if _spawned_count < _customer_queue.size():
		var customer = _customer_queue[_spawned_count]
		_spawned_count += 1
		return customer
	return {}

func has_unspawned_customers() -> bool:
	return _spawned_count < _customer_queue.size()

func get_current_customer() -> Dictionary:
	if _current_customer_index < _customer_queue.size():
		return _customer_queue[_current_customer_index]
	return {}

func advance_to_next_customer() -> bool:
	_current_customer_index += 1
	return _current_customer_index < _customer_queue.size()

func record_result(success: bool, timeout: bool = false) -> void:
	_day_summary["served"] += 1
	if timeout:
		_day_summary["timeout"] += 1
	elif success:
		_day_summary["success"] += 1
	else:
		_day_summary["failed"] += 1

func end_day() -> Dictionary:
	GameManager.end_day()
	day_complete.emit(_day_summary)
	return _day_summary

func get_remaining_customers() -> int:
	return _customer_queue.size() - _current_customer_index

func get_customer_queue() -> Array:
	return _customer_queue

func get_total_customer_count() -> int:
	return _customer_queue.size()

func get_spawned_count() -> int:
	return _spawned_count
