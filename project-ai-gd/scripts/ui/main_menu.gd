extends Control

@onready var btn_start: Button = %BtnStart
@onready var btn_continue: Button = %BtnContinue
@onready var btn_quit: Button = %BtnQuit

func _ready() -> void:
	btn_continue.visible = SaveManager.has_save()
	btn_start.pressed.connect(_on_start_pressed)
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	SaveManager.delete_save()
	GameManager._init_default_unlocks()
	_go_to_restaurant()

func _on_continue_pressed() -> void:
	SaveManager.load_game()
	_go_to_restaurant()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _go_to_restaurant() -> void:
	get_tree().change_scene_to_file("res://scenes/restaurant/restaurant_main.tscn")
