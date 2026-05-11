extends Node

const SAVE_PATH := "user://savegame.json"

func save_game() -> void:
	var data = GameManager.get_save_data()
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("Failed to open save file for writing")
		return
	file.store_string(JSON.stringify(data, "\t"))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open save file for reading")
		return false
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK:
		push_error("Save file parse error: " + json.get_error_message())
		return false
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("Save file has invalid format")
		return false
	GameManager.load_save_data(json.data)
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
