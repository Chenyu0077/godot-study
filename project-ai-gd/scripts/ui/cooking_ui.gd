extends Control

signal cooking_finished(grade: int)
signal cooking_cancelled()
signal open_shop_requested()

@onready var ingredient_panel: Control = %IngredientPanel
@onready var power_bar_panel: Control = %PowerBarPanel
@onready var result_panel: Control = %ResultPanel
@onready var arc_display: Control = %ArcDisplay
@onready var step_label: Label = %StepLabel
@onready var timer_bar: ProgressBar = %TimerBar
@onready var feedback_label: Label = %FeedbackLabel
@onready var result_label: Label = %ResultLabel
@onready var stars_label: Label = %StarsLabel
@onready var btn_start_cooking: Button = %BtnStartCooking
@onready var btn_back: Button = %BtnBackFromCooking
@onready var btn_buy: Button = %BtnBuyIngredients
@onready var btn_continue: Button = %BtnResultContinue
@onready var ingredient_grid: GridContainer = %IngredientGrid

var _cooking_system: CookingSystem
var _recipe: Dictionary = {}
var _waiting_for_next_step: bool = false
var _selected_ingredients: Dictionary = {}
var _required_ingredients: Array = []

func _ready() -> void:
	_cooking_system = CookingSystem.new()
	add_child(_cooking_system)

	_cooking_system.step_started.connect(_on_step_started)
	_cooking_system.step_completed.connect(_on_step_completed)
	_cooking_system.cooking_complete.connect(_on_cooking_complete)

	btn_start_cooking.pressed.connect(_on_start_cooking)
	btn_back.pressed.connect(_on_back_pressed)
	btn_buy.pressed.connect(_on_buy_pressed)
	btn_continue.pressed.connect(_on_result_continue)

	_show_ingredient_phase()

func setup(recipe: Dictionary) -> void:
	_recipe = recipe
	_selected_ingredients.clear()
	_required_ingredients = _recipe.get("ingredients", [])
	_populate_ingredients()
	_show_ingredient_phase()

func _populate_ingredients() -> void:
	for child in ingredient_grid.get_children():
		child.queue_free()

	var all_ingredients = RecipeManager.get_all_ingredients()
	for ingredient in all_ingredients:
		var ing_id = ingredient["id"]
		var owned = GameManager.inventory.get(ing_id, 0)
		var is_required = ing_id in _required_ingredients
		if owned <= 0 and not is_required:
			continue

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(90, 70)
		btn.text = "%s\n(x%d)" % [ingredient.get("name", ing_id), owned]
		btn.toggle_mode = true

		if owned <= 0:
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5)
		elif is_required:
			btn.modulate = Color(1.0, 1.0, 0.8)

		btn.toggled.connect(_on_ingredient_toggled.bind(ing_id, btn))
		ingredient_grid.add_child(btn)

	_update_start_button()

func _on_ingredient_toggled(pressed: bool, ing_id: String, btn: Button) -> void:
	if pressed:
		_selected_ingredients[ing_id] = true
		btn.modulate = Color(0.5, 1.0, 0.5)
	else:
		_selected_ingredients.erase(ing_id)
		if ing_id in _required_ingredients:
			btn.modulate = Color(1.0, 1.0, 0.8)
		else:
			btn.modulate = Color.WHITE
	_update_start_button()

func _update_start_button() -> void:
	var all_selected = true
	for ing_id in _required_ingredients:
		if not _selected_ingredients.has(ing_id):
			all_selected = false
			break
	btn_start_cooking.disabled = not all_selected
	if all_selected:
		btn_start_cooking.text = "开始烹饪"
	else:
		var count = 0
		for ing_id in _required_ingredients:
			if _selected_ingredients.has(ing_id):
				count += 1
		btn_start_cooking.text = "选择食材（%d/%d）" % [count, _required_ingredients.size()]

func _show_ingredient_phase() -> void:
	ingredient_panel.visible = true
	power_bar_panel.visible = false
	result_panel.visible = false

func _show_power_bar_phase() -> void:
	ingredient_panel.visible = false
	power_bar_panel.visible = true
	result_panel.visible = false
	feedback_label.text = ""

func _show_result_phase(score: float, grade: int) -> void:
	ingredient_panel.visible = false
	power_bar_panel.visible = false
	result_panel.visible = true

	var stars = RatingSystem.get_grade_stars(grade)
	var grade_name = RatingSystem.get_grade_name(grade)
	stars_label.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	result_label.text = "%s\n得分: %.0f" % [grade_name, score]

func _on_back_pressed() -> void:
	cooking_cancelled.emit()

func _on_buy_pressed() -> void:
	open_shop_requested.emit()

func refresh_ingredients() -> void:
	_selected_ingredients.clear()
	_populate_ingredients()

func _on_start_cooking() -> void:
	for ing_id in _required_ingredients:
		GameManager.remove_from_inventory(ing_id, 1)
	_show_power_bar_phase()
	_cooking_system.start_cooking(_recipe)

func _process(_delta: float) -> void:
	if _cooking_system and _cooking_system.is_active() and not _waiting_for_next_step:
		if is_instance_valid(arc_display):
			arc_display.queue_redraw()
		if is_instance_valid(timer_bar):
			var t = _cooking_system.get_time_remaining()
			var step_idx = _cooking_system.get_current_step_index()
			if step_idx < _recipe.get("steps", []).size():
				var total = _recipe["steps"][step_idx].get("time_limit", 5.0)
				timer_bar.value = (t / total) * 100.0

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not _cooking_system or not _cooking_system.is_active():
		return
	if _waiting_for_next_step:
		if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
			_waiting_for_next_step = false
			_cooking_system.proceed_to_next_step()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		_cooking_system.hit()
		get_viewport().set_input_as_handled()

func _on_step_started(step_index: int, step_data: Dictionary) -> void:
	step_label.text = "第%d步: %s" % [step_index + 1, step_data.get("step_name", "")]
	feedback_label.text = ""
	_waiting_for_next_step = false

func _on_step_completed(_step_index: int, score: float, zone_name: String) -> void:
	feedback_label.text = zone_name + "!"
	if score >= 100:
		feedback_label.add_theme_color_override("font_color", Color.GOLD)
	elif score >= 70:
		feedback_label.add_theme_color_override("font_color", Color.ORANGE)
	elif score >= 40:
		feedback_label.add_theme_color_override("font_color", Color.GRAY)
	else:
		feedback_label.add_theme_color_override("font_color", Color.RED)
	_waiting_for_next_step = true

func _on_cooking_complete(total_score: float, grade: int) -> void:
	_show_result_phase(total_score, grade)

func _on_result_continue() -> void:
	cooking_finished.emit(RatingSystem.get_grade_from_score(_cooking_system.get_total_score()))

func get_needle_angle() -> float:
	if _cooking_system:
		return _cooking_system.get_needle_angle()
	return 0.0

func get_perfect_zone_size() -> float:
	if _cooking_system:
		return _cooking_system.get_perfect_zone_size()
	return 0.25
