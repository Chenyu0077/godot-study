extends Control

@onready var hud: Control = %HUD
@onready var customer_area: Control = %CustomerArea
@onready var dialog_ui_wrapper: Control = %DialogUI
@onready var cooking_ui_wrapper: Control = %CookingUI
@onready var cooking_ui: Control = %CookingUI.get_node("CookingInstance")
@onready var btn_serve: Button = %BtnNextCustomer
@onready var btn_end_day: Button = %BtnEndDay
@onready var customer_info: Label = %CustomerInfo
@onready var day_summary_panel: Control = %DaySummaryPanel
@onready var summary_label: Label = %SummaryLabel
@onready var btn_next_day: Button = %BtnNextDay
@onready var customer_queue_container: HBoxContainer = %CustomerQueueContainer
@onready var btn_shop: Button = %BtnShop
@onready var btn_menu: Button = %BtnMenu
@onready var btn_inventory: Button = %BtnInventory

var _day_manager: Node
var _dialog_ui: Control
var _current_recipe_id: String = ""
var _current_customer: Dictionary = {}
var _customer_scene: PackedScene = preload("res://scenes/restaurant/customer.tscn")
var _customer_pool: CustomerPool
var _visible_queue: Array = []
var _is_serving: bool = false
var _arrival_timer: Timer

var _shop_scene: PackedScene = preload("res://scenes/shop/shop.tscn")
var _menu_scene: PackedScene = preload("res://scenes/menu/menu.tscn")
var _inventory_scene: PackedScene = preload("res://scenes/inventory/inventory.tscn")

func _ready() -> void:
	_day_manager = preload("res://scripts/managers/day_manager.gd").new()
	add_child(_day_manager)
	_customer_pool = CustomerPool.new(_customer_scene, 5)

	_dialog_ui = %DialogUI.get_node("ChatDialogInstance")
	dialog_ui_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooking_ui_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_dialog_ui.recipe_selected.connect(_on_recipe_selected)
	_dialog_ui.dialog_closed.connect(_on_dialog_closed)
	cooking_ui.cooking_finished.connect(_on_cooking_finished)
	cooking_ui.cooking_cancelled.connect(_on_cooking_cancelled)
	cooking_ui.open_shop_requested.connect(_on_cooking_shop_requested)
	btn_serve.pressed.connect(_serve_next_customer)
	btn_end_day.pressed.connect(_on_end_day)
	btn_next_day.pressed.connect(_on_next_day)
	btn_shop.pressed.connect(_open_shop)
	btn_menu.pressed.connect(_open_menu)
	btn_inventory.pressed.connect(_open_inventory)

	_arrival_timer = Timer.new()
	_arrival_timer.one_shot = true
	_arrival_timer.timeout.connect(_on_arrival_timer_timeout)
	add_child(_arrival_timer)

	cooking_ui_wrapper.visible = false
	day_summary_panel.visible = false

	_day_manager.start_new_day()
	_enter_idle_state()

func _enter_idle_state() -> void:
	_is_serving = false
	btn_serve.visible = false
	btn_end_day.visible = true
	customer_info.text = "等待客人到来…"
	_schedule_next_arrival()

func _schedule_next_arrival() -> void:
	if _day_manager.has_unspawned_customers():
		var delay = randf_range(3.0, 8.0)
		_arrival_timer.start(delay)

func _on_arrival_timer_timeout() -> void:
	var customer_data = _day_manager.pop_next_unspawned_customer()
	if customer_data.is_empty():
		return
	_spawn_customer_node(customer_data)
	_update_serve_button()
	_schedule_next_arrival()

func _spawn_customer_node(data: Dictionary) -> void:
	var node = _customer_pool.acquire()
	customer_queue_container.add_child(node)
	node.setup(data)
	if not node.patience_expired.is_connected(_on_patience_expired):
		node.patience_expired.connect(_on_patience_expired)
	_visible_queue.append(node)
	customer_info.text = "有客人来了！"

func _update_serve_button() -> void:
	if not _is_serving and _visible_queue.size() > 0:
		btn_serve.visible = true
		btn_serve.text = "接待客人（等待%d）" % _visible_queue.size()
	else:
		btn_serve.visible = false

func _serve_next_customer() -> void:
	if _visible_queue.is_empty():
		return
	_is_serving = true
	btn_serve.visible = false
	btn_end_day.visible = false

	var serving_node = _visible_queue[0]
	serving_node.pause_patience()
	_current_customer = serving_node.customer_data

	_show_customer(_current_customer)

func _show_customer(customer: Dictionary) -> void:
	var type = customer.get("type", "normal")
	match type:
		"normal":
			customer_info.text = "正在接待客人…"
			_dialog_ui.show_normal_order(customer)
		"sick":
			var symptom_name = customer.get("symptom_name", "")
			customer_info.text = "客人身体不适（%s）" % symptom_name
			_dialog_ui.show_symptom_dialog(customer)
		"special":
			customer_info.text = "客人有特殊请求"
			_dialog_ui.show_special_request(customer)

func _on_recipe_selected(recipe_id: String) -> void:
	_current_recipe_id = recipe_id
	var customer_type = _current_customer.get("type", "normal")

	if customer_type == "sick":
		var symptom_id = _current_customer.get("symptom_id", "")
		if not RecipeManager.is_recipe_for_symptom(recipe_id, symptom_id):
			RatingSystem.apply_symptom_result(false)
			customer_info.text = "推荐失败！客人不满意地离开了…"
			_day_manager.record_result(false)
			_after_customer_served()
			return

	var recipe = RecipeManager.get_recipe(recipe_id)
	if recipe.is_empty():
		return
	cooking_ui.setup(recipe)
	cooking_ui_wrapper.visible = true

func _on_cooking_cancelled() -> void:
	cooking_ui_wrapper.visible = false
	customer_info.text = "食材不足，无法烹饪"
	_day_manager.record_result(false)
	_after_customer_served()

func _on_cooking_shop_requested() -> void:
	var shop = _shop_scene.instantiate()
	add_child(shop)
	shop.shop_closed.connect(func():
		shop.queue_free()
		cooking_ui.refresh_ingredients()
	)

func _on_cooking_finished(grade: int) -> void:
	cooking_ui_wrapper.visible = false
	var is_daily = _current_recipe_id == GameManager.daily_recommendation
	var rewards = RatingSystem.apply_cooking_result(grade, is_daily)

	var customer_type = _current_customer.get("type", "normal")
	if customer_type == "sick" and grade != RatingSystem.CookingGrade.FAIL:
		RatingSystem.apply_symptom_result(true)

	var success = grade != RatingSystem.CookingGrade.FAIL
	_day_manager.record_result(success)

	var grade_name = RatingSystem.get_grade_name(grade)
	customer_info.text = "制作%s！评价+%d 金币+%d" % [grade_name, rewards["rating"], rewards["gold"]]
	_after_customer_served()

func _on_dialog_closed() -> void:
	var customer_type = _current_customer.get("type", "normal")
	if customer_type == "special":
		customer_info.text = "客人的请求暂时无法满足"
	else:
		customer_info.text = "客人离开了"
	_day_manager.record_result(false)
	_after_customer_served()

func _on_patience_expired(customer_data: Dictionary) -> void:
	if _is_serving and not _visible_queue.is_empty() and _visible_queue[0].customer_data == customer_data:
		cooking_ui_wrapper.visible = false
		_dialog_ui.visible = false
		customer_info.text = "正在服务的客人等不及走了！"
		_day_manager.record_result(false, true)
		RatingSystem.apply_timeout_penalty()
		_after_customer_served()
		return

	var expired_node: Control = null
	for node in _visible_queue:
		if node.customer_data == customer_data:
			expired_node = node
			break
	if expired_node:
		_visible_queue.erase(expired_node)
		_customer_pool.return_node(expired_node)
		RatingSystem.apply_timeout_penalty()
		_day_manager.record_result(false, true)
		if not _is_serving:
			customer_info.text = "一位客人等不及走了…"
			_update_serve_button()

func _after_customer_served() -> void:
	if not _visible_queue.is_empty():
		var served_node = _visible_queue.pop_front()
		served_node.mark_served()
		_customer_pool.return_node(served_node)

	_is_serving = false

	if _visible_queue.size() > 0 or _day_manager.has_unspawned_customers():
		customer_info.text = "等待客人到来…"
		_update_serve_button()
		btn_end_day.visible = true
	else:
		customer_info.text = "今天的客人都服务完了"
		btn_end_day.visible = true
		_update_serve_button()

func _on_end_day() -> void:
	_arrival_timer.stop()
	btn_serve.visible = false
	btn_end_day.visible = false
	for node in _visible_queue:
		if is_instance_valid(node):
			_customer_pool.return_node(node)
	_visible_queue.clear()

	var summary = _day_manager.end_day()
	day_summary_panel.visible = true
	summary_label.text = "第%d天结束\n接待: %d | 成功: %d | 失败: %d | 超时: %d\n当前评价: %d | 金币: %d" % [
		GameManager.day - 1,
		summary.get("served", 0),
		summary.get("success", 0),
		summary.get("failed", 0),
		summary.get("timeout", 0),
		GameManager.rating,
		GameManager.gold,
	]

func _on_next_day() -> void:
	day_summary_panel.visible = false
	_day_manager.start_new_day()
	_enter_idle_state()

func _open_shop() -> void:
	var shop = _shop_scene.instantiate()
	add_child(shop)
	shop.shop_closed.connect(func(): shop.queue_free())

func _open_menu() -> void:
	var menu = _menu_scene.instantiate()
	add_child(menu)
	menu.menu_closed.connect(func(): menu.queue_free())

func _open_inventory() -> void:
	var inv = _inventory_scene.instantiate()
	add_child(inv)
	inv.inventory_closed.connect(func(): inv.queue_free())
