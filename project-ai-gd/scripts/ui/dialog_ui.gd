extends Control

signal recipe_selected(recipe_id: String)
signal dialog_closed()

@onready var portrait: TextureRect = %Portrait
@onready var dialog_text: RichTextLabel = %DialogText
@onready var options_container: VBoxContainer = %OptionsContainer
@onready var btn_close: Button = %BtnClose

var _symptom_id: String = ""
var _customer_data: Dictionary = {}

func _ready() -> void:
	btn_close.pressed.connect(_on_close)
	visible = false

func show_normal_order(customer_data: Dictionary) -> void:
	_customer_data = customer_data
	var recipe_id = customer_data.get("requested_recipe", "")
	var recipe = RecipeManager.get_recipe(recipe_id)
	dialog_text.text = "客人想要点一份 [b]%s[/b]" % recipe.get("name", "未知菜品")
	_clear_options()
	_add_option_button(recipe.get("name", ""), recipe_id)
	btn_close.visible = true
	visible = true

func show_symptom_dialog(customer_data: Dictionary) -> void:
	_customer_data = customer_data
	_symptom_id = customer_data.get("symptom_id", "")
	var symptom_desc = customer_data.get("symptom_description", "")
	dialog_text.text = "[i]%s[/i]\n\n你觉得该推荐什么药膳？" % symptom_desc
	_clear_options()

	var recipes = RecipeManager.get_recipes_for_symptom(_symptom_id)
	var unlocked = RecipeManager.get_unlocked_recipes()
	var shown: Array[String] = []
	for r in recipes:
		if GameManager.is_recipe_unlocked(r["id"]):
			_add_option_button(r["name"], r["id"])
			shown.append(r["id"])

	# Add 1-2 wrong options
	for r in unlocked:
		if r["id"] not in shown and shown.size() + _get_option_count() < 4:
			_add_option_button(r["name"], r["id"])

	btn_close.visible = true
	visible = true

func show_special_request(customer_data: Dictionary) -> void:
	_customer_data = customer_data
	var recipe_name = customer_data.get("recipe_name", "特殊菜品")
	dialog_text.text = "客人想要一份 [b]%s[/b]，但这道菜不在菜单上！\n需要去商店购买食谱。" % recipe_name
	_clear_options()
	btn_close.visible = true
	visible = true

func _clear_options() -> void:
	for child in options_container.get_children():
		child.queue_free()

func _get_option_count() -> int:
	return options_container.get_child_count()

func _add_option_button(text: String, recipe_id: String) -> void:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size.y = 40
	btn.pressed.connect(_on_option_selected.bind(recipe_id))
	options_container.add_child(btn)

func _on_option_selected(recipe_id: String) -> void:
	visible = false
	recipe_selected.emit(recipe_id)

func _on_close() -> void:
	visible = false
	dialog_closed.emit()
