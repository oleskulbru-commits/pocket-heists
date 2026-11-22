class_name HeistStorage
extends RefCounted
## Save backend. `load_text` returns the file contents, or "" when there is no file.
## `store_text` returns false when the write is refused.


func load_text() -> String:
	return ""


func store_text(_text: String) -> bool:
	return false
