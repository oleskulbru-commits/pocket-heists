class_name RoomFile
extends RefCounted

# RoomData is owned by the simulation lane. Compile of this preload is checked
# at the Wave 1 gate. Each guard is RoomData.Guard (id, k, p, path) when that
# inner class exists; otherwise a dictionary with those fields.
const RoomDataScript = preload("res://scripts/sim/room_data.gd")
const RoomValidator = preload("res://scripts/data/room_validator.gd")


static func load_all() -> Array:
	var rooms: Array = []
	for path in _json_paths():
		var raw = RoomValidator.read_json(path)
		if typeof(raw) != TYPE_DICTIONARY:
			push_error("Skipping unreadable room %s" % path)
			continue
		var problems := RoomValidator.validate(raw)
		if not problems.is_empty():
			push_error("Skipping invalid room %s: %s" % [path, " ".join(problems)])
			continue
		rooms.append(_build(raw))
	rooms.sort_custom(func(a, b): return str(a.id) < str(b.id))
	return rooms


static func _json_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open("res://data/rooms")
	if dir == null:
		push_error("Missing res://data/rooms")
		return paths
	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			paths.append("res://data/rooms".path_join(file_name))
	paths.sort()
	return paths


static func _build(raw: Dictionary):
	var room = RoomDataScript.new()
	room.id = str(raw["id"])
	room.name = str(raw["name"])
	room.target_name = str(raw["target_name"])
	room.par = int(raw["par"])
	room.hint = str(raw["hint"])
	var rows: Array[String] = []
	for row in raw["rows"]:
		rows.append(str(row))
	room.rows = rows
	room.start = RoomValidator.marker_cell(rows, "S")
	room.target = RoomValidator.marker_cell(rows, "L")
	room.exit_cell = RoomValidator.marker_cell(rows, "E")
	room.bonus = RoomValidator.marker_cell(rows, "B")
	var guards: Array = []
	for entry in raw["guards"]:
		guards.append(_make_guard(entry))
	room.guards = guards
	return room


static func _make_guard(entry: Dictionary):
	var path: Array[Vector2i] = []
	for token in entry["path"]:
		path.append(RoomValidator.parse_cell(str(token)))
	# The preload resolves as the class, so read inner classes off the script resource.
	var data_script := RoomDataScript as GDScript
	var constants: Dictionary = data_script.get_script_constant_map()
	if constants.has("Guard"):
		var guard = constants["Guard"].new()
		guard.id = str(entry["id"])
		guard.k = int(entry["k"])
		guard.p = int(entry["p"])
		guard.path = path
		return guard
	return {
		"id": str(entry["id"]),
		"k": int(entry["k"]),
		"p": int(entry["p"]),
		"path": path,
	}
