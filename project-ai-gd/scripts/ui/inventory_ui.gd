extends Control

signal inventory_closed()

@onready var grid: GridContainer = %InventoryGrid
@onready var detail_label: Label = %DetailLabel
@onready var btn_close: Button = %BtnCloseInventory

func _ready() -> void:
	btn_close.pressed.connect(_on_close)
	_refresh()

func _refresh() -> void:
	for child in grid.get_children():
		child.queue_free()
	detail_label.text = "点击食材查看详情"

	for ingredient_id in GameManager.inventory:
		var quantity = GameManager.inventory[ingredient_id]
		if quantity <= 0:
			continue
		var ingredient = RecipeManager.get_ingredient(ingredient_id)
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(100, 80)
		btn.text = "%s\nx%d" % [ingredient.get("name", ingredient_id), quantity]
		btn.pressed.connect(_show_detail.bind(ingredient_id))
		grid.add_child(btn)

	if GameManager.inventory.is_empty():
		var empty_label = Label.new()
		empty_label.text = "仓库空空如也"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(empty_label)

func _show_detail(ingredient_id: String) -> void:
	var ingredient = RecipeManager.get_ingredient(ingredient_id)
	var quantity = GameManager.inventory.get(ingredient_id, 0)
	detail_label.text = "%s\n分类: %s\n功效: %s\n库存: %d" % [
		ingredient.get("name", ""),
		ingredient.get("category", ""),
		", ".join(ingredient.get("effects", [])),
		quantity
	]

func _on_close() -> void:
	inventory_closed.emit()
	visible = false
