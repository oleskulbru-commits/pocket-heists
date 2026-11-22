class_name UserStorage
extends "res://scripts/session/heist_storage.gd"
## Device save at user://save.json. A missing or unreadable file loads as empty text.


const PATH := "user://save.json"


func load_text() -> String:
	if not FileAccess.file_exists(PATH):
		return ""
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return ""
	var value := file.get_as_text()
	file.close()
	return value


func store_text(value: String) -> bool:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(value)
	if file.get_error() != OK:
		file.close()
		return false
	file.close()
	return true
