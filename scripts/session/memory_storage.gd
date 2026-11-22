class_name MemoryStorage
extends "res://scripts/session/heist_storage.gd"
## In-memory stand-in for the save file. Unit tests use this instead of user://.


var text: String = ""
var accept_writes: bool = true
var writes: int = 0


func load_text() -> String:
	return text


func store_text(value: String) -> bool:
	if not accept_writes:
		return false
	text = value
	writes += 1
	return true
