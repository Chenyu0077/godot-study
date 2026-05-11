extends Control

@onready var rating_label: Label = %RatingValue
@onready var gold_label: Label = %GoldValue
@onready var day_label: Label = %DayValue
@onready var recommend_label: Label = %RecommendValue

func _ready() -> void:
	GameManager.rating_changed.connect(_on_rating_changed)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.day_started.connect(_on_day_started)
	_update_all()

func _update_all() -> void:
	_on_rating_changed(GameManager.rating)
	_on_gold_changed(GameManager.gold)
	rating_label.text = str(GameManager.rating)
	gold_label.text = str(GameManager.gold)
	day_label.text = "第%d天" % GameManager.day

func _on_rating_changed(value: int) -> void:
	if is_instance_valid(rating_label):
		rating_label.text = str(value)

func _on_gold_changed(value: int) -> void:
	if is_instance_valid(gold_label):
		gold_label.text = str(value)

func _on_day_started(day_number: int) -> void:
	if is_instance_valid(day_label):
		day_label.text = "第%d天" % day_number
	if is_instance_valid(recommend_label):
		var recipe = RecipeManager.get_recipe(GameManager.daily_recommendation)
		recommend_label.text = recipe.get("name", "无")
