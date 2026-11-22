class_name EventLog
extends RefCounted
## One JSON object per line. Default off. Writes user://events.jsonl only when
## no storage was injected and the log is enabled. Never opens a network connection.


const PATH := "user://events.jsonl"

var enabled: bool = false
var _storage = null


func _init(storage = null) -> void:
	_storage = storage


func set_enabled(on: bool) -> void:
	enabled = on


## Turn the log on for this visit when the page query contains log=1.
func enable_from_query(query: String) -> void:
	if query_enables(query):
		enabled = true


static func query_enables(query: String) -> bool:
	var text := query.strip_edges()
	var hash := text.find("#")
	if hash != -1:
		text = text.substr(0, hash)
	var mark := text.find("?")
	if mark != -1:
		text = text.substr(mark + 1)
	elif text.contains("://"):
		return false
	if text.begins_with("?"):
		text = text.substr(1)
	for part in text.split("&", false):
		var pair := part.split("=", true, 1)
		var key := str(pair[0])
		var value := ""
		if pair.size() > 1:
			value = str(pair[1])
		if key == "log" and value == "1":
			return true
	return false


func text() -> String:
	if _storage != null:
		return str(_storage.load_text())
	if not FileAccess.file_exists(PATH):
		return ""
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return ""
	var value := file.get_as_text()
	file.close()
	return value


func record(event_name: String, fields: Dictionary = {}) -> void:
	if not enabled:
		return
	var names := _field_names(event_name)
	if names.is_empty():
		return
	var payload := {"event": event_name}
	for key in names:
		if not fields.has(key):
			continue
		var value = fields[key]
		var kind := typeof(value)
		if kind != TYPE_BOOL and kind != TYPE_INT and kind != TYPE_FLOAT and kind != TYPE_STRING:
			continue
		payload[key] = value
	_append(JSON.stringify(payload))


func _field_names(event_name: String) -> Array:
	match event_name:
		"room_start":
			return ["room"]
		"attempt":
			return ["room", "moves"]
		"catch":
			return ["room", "beat", "guard"]
		"clear":
			return ["room", "moves", "bonus"]
		"replay":
			return ["room"]
		_:
			return []


func _append(line: String) -> void:
	if _storage != null:
		var prior := str(_storage.load_text())
		var next := line + "\n"
		if not prior.is_empty():
			if not prior.ends_with("\n"):
				prior += "\n"
			next = prior + line + "\n"
		_storage.store_text(next)
		return
	var file := FileAccess.open(PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_string(line + "\n")
	file.close()
