class_name RoomValidator
extends RefCounted

const ROOM_IDS: PackedStringArray = ["01", "02", "03", "04", "05", "06"]

const GUARD_COUNT := {
	"01": 0,
	"02": 1,
	"03": 1,
	"04": 2,
	"05": 2,
	"06": 2,
}

const CLEAR_ROUTE := {
	"01": "U6 R4",
	"02": "R U L U5 R4",
	"03": "R4 U2 L4 U4 R2",
	"04": "U5 R D R2 U2 L3",
	"05": "R2 U3 L U R3 U2",
	"06": "U4 R3 D R U L U2",
}

const _GUARD_IDS: PackedStringArray = ["A", "B"]
const _TILES := "#.SLEB"
const _STEPS := "UDLR"
const _REQUIRED_KEYS: PackedStringArray = ["id", "name", "target_name", "par", "hint", "rows", "guards"]


static func validate_file(path: String) -> Array[String]:
	var raw = read_json(path)
	if typeof(raw) != TYPE_DICTIONARY:
		return ["unreadable room file: %s" % path]
	return validate(raw)


static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


static func validate(room: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in _REQUIRED_KEYS:
		if not room.has(key):
			errors.append("missing %s" % key)
	if not errors.is_empty():
		return errors

	var id := ""
	if typeof(room["id"]) != TYPE_STRING or not ROOM_IDS.has(room["id"]):
		errors.append("unknown room id")
	else:
		id = room["id"]

	if typeof(room["name"]) != TYPE_STRING or str(room["name"]).is_empty():
		errors.append("name must be a string")
	if typeof(room["target_name"]) != TYPE_STRING or str(room["target_name"]).is_empty():
		errors.append("target_name must be a string")
	if typeof(room["hint"]) != TYPE_STRING or str(room["hint"]).is_empty():
		errors.append("hint must be a string")

	var par = _whole_number(room["par"])
	if par == null:
		errors.append("par must be an integer")
	elif id != "" and par != move_count(CLEAR_ROUTE[id]):
		errors.append("par does not match clear route")

	var rows_ok := _validate_rows(room["rows"], id, errors)
	_validate_guards(room["guards"], id, room["rows"] if rows_ok else [], errors)
	return errors


static func move_count(route: String) -> int:
	var text := route.replace(" ", "")
	var total := 0
	var i := 0
	while i < text.length():
		var step := text.substr(i, 1)
		if not _STEPS.contains(step):
			return -1
		i += 1
		var digits := ""
		while i < text.length() and text.substr(i, 1).is_valid_int():
			digits += text.substr(i, 1)
			i += 1
		total += 1 if digits.is_empty() else int(digits)
	return total


static func parse_cell(token: String) -> Vector2i:
	if token.length() != 2:
		return Vector2i(-1, -1)
	var column := token.unicode_at(0)
	var row := token.unicode_at(1)
	if column < 65 or column > 71 or row < 49 or row > 57:
		return Vector2i(-1, -1)
	return Vector2i(column - 65, row - 49)


static func marker_cell(rows: Array, marker: String) -> Vector2i:
	for y in rows.size():
		var row := str(rows[y])
		for x in row.length():
			if row.substr(x, 1) == marker:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


static func _validate_rows(rows, id: String, errors: Array[String]) -> bool:
	if typeof(rows) != TYPE_ARRAY or rows.size() != 9:
		errors.append("rows must be 9 strings of length 7")
		return false
	for row in rows:
		if typeof(row) != TYPE_STRING or str(row).length() != 7:
			errors.append("rows must be 9 strings of length 7")
			return false
	for y in 9:
		var row := str(rows[y])
		for x in 7:
			var tile := row.substr(x, 1)
			if not _TILES.contains(tile):
				errors.append("unknown tile")
			if (x == 0 or x == 6 or y == 0 or y == 8) and tile != "#":
				errors.append("border is not all walls")
	var counts := {"S": 0, "L": 0, "E": 0, "B": 0}
	for row in rows:
		var text := str(row)
		for i in text.length():
			var tile := text.substr(i, 1)
			if counts.has(tile):
				counts[tile] += 1
	if counts["S"] != 1:
		errors.append("expected exactly one S")
	if counts["L"] != 1:
		errors.append("expected exactly one L")
	if counts["E"] != 1:
		errors.append("expected exactly one E")
	if counts["B"] > 1:
		errors.append("expected at most one B")
	if counts["B"] > 0 and (id == "01" or id == "02"):
		errors.append("bonus is only allowed in rooms 03-06")
	return true


static func _validate_guards(guards, id: String, rows: Array, errors: Array[String]) -> void:
	if typeof(guards) != TYPE_ARRAY:
		errors.append("guards must be an array")
		return
	if id != "" and guards.size() != GUARD_COUNT[id]:
		errors.append("expected %d guards" % GUARD_COUNT[id])
	for index in guards.size():
		var guard = guards[index]
		if typeof(guard) != TYPE_DICTIONARY:
			errors.append("guard is not an object")
			continue
		if index < _GUARD_IDS.size():
			if str(guard.get("id", "")) != _GUARD_IDS[index]:
				errors.append("guard ids must be A then B")
		else:
			errors.append("guard ids must be A then B")
		var interval = _whole_number(guard.get("k", null))
		if interval == null or interval < 1:
			errors.append("k must be >= 1")
		var phase = _whole_number(guard.get("p", null))
		if phase == null or phase < 0:
			errors.append("p must be >= 0")
		_validate_path(guard.get("path", null), rows, errors)


static func _validate_path(path, rows: Array, errors: Array[String]) -> void:
	if typeof(path) != TYPE_ARRAY or path.size() < 2:
		errors.append("path must visit at least two cells")
		return
	var cells: Array[Vector2i] = []
	for token in path:
		if typeof(token) != TYPE_STRING:
			errors.append("path cell is not floor")
			return
		var cell := parse_cell(str(token))
		if cell.x < 0 or rows.is_empty() or not _is_floor(rows, cell):
			errors.append("path cell is not floor")
			return
		cells.append(cell)
	for index in cells.size():
		var nxt: Vector2i = cells[(index + 1) % cells.size()]
		if not _edge_adjacent(cells[index], nxt):
			errors.append("patrol step is not edge-adjacent")
			return


static func _is_floor(rows: Array, cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= rows.size():
		return false
	var row := str(rows[cell.y])
	if cell.x < 0 or cell.x >= row.length():
		return false
	return row.substr(cell.x, 1) != "#"


static func _edge_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


static func _whole_number(value) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and value == floor(value):
		return int(value)
	return null
