extends Control

signal recipe_selected(recipe_id: String)
signal dialog_closed()

@onready var timer_label: Label = %TimerLabel
@onready var btn_close: Button = %BtnClose
@onready var npc_portrait: Label = %NpcPortrait
@onready var npc_name_label: Label = %NpcNameLabel
@onready var chat_scroll: ScrollContainer = %ChatScroll
@onready var chat_messages: VBoxContainer = %ChatMessages
@onready var options_area: VBoxContainer = %OptionsArea
@onready var btn_make: Button = %BtnMake

var _customer_data: Dictionary = {}
var _selected_recipe_id: String = ""
var _patience_current: float = 0.0
var _patience_max: float = 45.0
var _is_active: bool = false

const TYPE_ICONS := {
	"normal": "🧑",
	"sick": "🤒",
	"special": "🧐",
}

func _ready() -> void:
	btn_close.pressed.connect(_on_close)
	btn_make.pressed.connect(_on_make_pressed)
	visible = false

func _process(delta: float) -> void:
	if not _is_active:
		return
	_patience_current -= delta
	if _patience_current <= 0:
		_patience_current = 0
		_is_active = false
		visible = false
		dialog_closed.emit()
		return
	_update_timer_display()

func _update_timer_display() -> void:
	var minutes = int(_patience_current) / 60
	var seconds = int(_patience_current) % 60
	timer_label.text = "倒计时 %02d:%02d" % [minutes, seconds]

func show_normal_order(customer_data: Dictionary) -> void:
	_setup_customer(customer_data)
	var recipe_id = customer_data.get("requested_recipe", "")
	var recipe = RecipeManager.get_recipe(recipe_id)
	_add_npc_message("老板，我想点一份 %s" % recipe.get("name", ""))
	_add_player_message("好嘞！我这就给您准备！")
	_show_recipe_option(recipe_id, recipe.get("name", ""))
	visible = true

func show_symptom_dialog(customer_data: Dictionary) -> void:
	_setup_customer(customer_data)
	var desc = customer_data.get("symptom_description", "")
	var symptom_name = customer_data.get("symptom_name", "")
	_add_npc_message("老板，我最近%s，有什么清润的吃食推荐吗？" % desc)
	_add_player_message("让我看看能给您推荐什么药膳…")
	_show_symptom_options(customer_data)
	visible = true

func show_special_request(customer_data: Dictionary) -> void:
	_setup_customer(customer_data)
	var recipe_name = customer_data.get("recipe_name", "")
	_add_npc_message("老板，我想要一份 %s，听说你这里有？" % recipe_name)
	_add_player_message("抱歉客官，这道菜目前不在菜单上，需要去商店购买食谱。")
	_add_npc_message("哦…那我下次再来吧。")
	btn_make.visible = false
	visible = true

func _setup_customer(data: Dictionary) -> void:
	_customer_data = data
	_is_active = true
	_patience_max = data.get("patience", 45.0)
	_patience_current = _patience_max
	_clear_chat()
	_clear_options()
	btn_make.visible = false
	_selected_recipe_id = ""

	var type = data.get("type", "normal")
	npc_portrait.text = TYPE_ICONS.get(type, "🧑")
	match type:
		"normal":
			npc_name_label.text = "普通客人"
		"sick":
			npc_name_label.text = "不适客人"
		"special":
			npc_name_label.text = "特殊客人"
	_update_timer_display()

func _add_npc_message(text: String) -> void:
	var rtl = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.text = "[color=#cc3333][b]NPC[/b][/color]\n%s" % text
	chat_messages.add_child(rtl)
	_scroll_to_bottom()

func _add_player_message(text: String) -> void:
	var rtl = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.text = "[color=#339933][b]我[/b][/color]\n%s" % text
	chat_messages.add_child(rtl)
	_scroll_to_bottom()

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)

func _show_recipe_option(recipe_id: String, recipe_name: String) -> void:
	_clear_options()
	var btn = Button.new()
	btn.text = "制作：%s" % recipe_name
	btn.custom_minimum_size.y = 36
	btn.pressed.connect(_on_recipe_chosen.bind(recipe_id))
	options_area.add_child(btn)

func _show_symptom_options(customer_data: Dictionary) -> void:
	_clear_options()
	var symptom_id = customer_data.get("symptom_id", "")
	var recipes = RecipeManager.get_recipes_for_symptom(symptom_id)
	var shown: Array[String] = []

	for r in recipes:
		if GameManager.is_recipe_unlocked(r["id"]):
			_add_option_button(r["name"], r["id"])
			shown.append(r["id"])

	var unlocked = RecipeManager.get_unlocked_recipes()
	for r in unlocked:
		if r["id"] not in shown and options_area.get_child_count() < 4:
			_add_option_button(r["name"], r["id"])

func _add_option_button(text: String, recipe_id: String) -> void:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size.y = 36
	btn.pressed.connect(_on_recipe_chosen.bind(recipe_id))
	options_area.add_child(btn)

func _on_recipe_chosen(recipe_id: String) -> void:
	_selected_recipe_id = recipe_id
	var recipe = RecipeManager.get_recipe(recipe_id)
	_clear_options()

	var customer_type = _customer_data.get("type", "normal")
	if customer_type == "sick":
		var symptom_id = _customer_data.get("symptom_id", "")
		if not RecipeManager.is_recipe_for_symptom(recipe_id, symptom_id):
			_add_player_message("我推荐这道 %s 给您试试" % recipe.get("name", recipe_id))
			_add_npc_message("这个好像不太对症吧…算了，我去别家看看。")
			btn_make.visible = false
			_is_active = false
			await get_tree().create_timer(2.0).timeout
			visible = false
			recipe_selected.emit(recipe_id)
			return

	_add_player_message("客官来得正好！试试这道 %s" % recipe.get("name", recipe_id))
	_add_npc_message("好，那就来这个吧！")
	btn_make.visible = true

func _on_make_pressed() -> void:
	_is_active = false
	visible = false
	recipe_selected.emit(_selected_recipe_id)

func _on_close() -> void:
	_is_active = false
	visible = false
	dialog_closed.emit()

func _clear_chat() -> void:
	for child in chat_messages.get_children():
		child.queue_free()

func _clear_options() -> void:
	for child in options_area.get_children():
		child.queue_free()
