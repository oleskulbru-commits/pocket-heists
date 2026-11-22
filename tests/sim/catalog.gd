extends RefCounted
## Builds RoomData from the C5 tables. The simulator never reads this.

const RoomScript = preload("res://scripts/sim/room_data.gd")


static func by_id() -> Dictionary:
	var rooms: Dictionary = {}
	for room in [
		_service(),
		_dispatch(),
		_packing(),
		_cold(),
		_annex(),
		_vault(),
	]:
		rooms[room.id] = room
	return rooms


static func from_rows(id: String, rows: Array, guard_specs: Array):
	return _make(id, id, "", 0, "", rows, guard_specs)


static func cell(token: String) -> Vector2i:
	var col := token.unicode_at(0) - "A".unicode_at(0)
	var row := token.substr(1).to_int() - 1
	return Vector2i(col, row)


static func cell_name(c: Vector2i) -> String:
	return char(c.x + 65) + str(c.y + 1)


static func parse_route(start: Vector2i, text: String) -> Array[Vector2i]:
	var route: Array[Vector2i] = [start]
	var compact := text.replace(" ", "")
	var i := 0
	while i < compact.length():
		var step := _delta(compact.substr(i, 1))
		i += 1
		var count := 0
		var saw_digit := false
		while i < compact.length() and compact.substr(i, 1).is_valid_int():
			saw_digit = true
			count = count * 10 + compact.substr(i, 1).to_int()
			i += 1
		if not saw_digit:
			count = 1
		for _step_index in count:
			route.append(route[route.size() - 1] + step)
	return route


static func _service():
	return _make(
		"01",
		"Service Entrance",
		"brass access seal",
		10,
		"Pass through the seal before heading to the exit.",
		["#######", "#....E#", "#.....#", "#.##..#", "#L....#", "#.....#", "#..##.#", "#S....#", "#######"],
		[]
	)


static func _dispatch():
	return _make(
		"02",
		"Dispatch Office",
		"dispatch ledger",
		12,
		"Take a short detour before you head up the left corridor.",
		["#######", "#..L.E#", "#.#...#", "#.#.#.#", "#.#.#.#", "#.#.#.#", "#...#.#", "#S....#", "#######"],
		[["A", 2, 2, ["D4", "D5", "D6", "D7", "D6", "D5"]]]
	)


static func _packing():
	return _make(
		"03",
		"Packing Floor",
		"customs stamp",
		16,
		"Cross the lower aisle before heading north.",
		["#######", "#..E..#", "#.###.#", "#...B.#", "#.###.#", "#...L.#", "#.###.#", "#S....#", "#######"],
		[["A", 2, 6, ["F3", "F4", "F5", "F6", "F7", "F6", "F5", "F4"]]]
	)


static func _cold():
	return _make(
		"04",
		"Cold Storage",
		"sealed specimen",
		14,
		"The left corridor has cover.",
		["#######", "#E....#", "#..#..#", "#..L..#", "#.##..#", "#..B..#", "#.##..#", "#S....#", "#######"],
		[
			["A", 2, 0, ["E6", "F6", "F7", "F8", "F7", "F6"]],
			["B", 2, 1, ["F3", "F4", "F5", "F4"]],
		]
	)


static func _annex():
	return _make(
		"05",
		"Security Annex",
		"blackbox recorder",
		12,
		"Start across the bottom, then climb through the middle.",
		["#######", "#....E#", "#.###.#", "#.L...#", "#...#.#", "#.#.B.#", "#.#.#.#", "#S....#", "#######"],
		[
			["A", 3, 10, ["B3", "B4", "B5", "B6", "B5", "B4"]],
			["B", 2, 4, ["F5", "F6", "F7", "F8", "F7", "F6"]],
		]
	)


static func _vault():
	return _make(
		"06",
		"Bonded Vault",
		"prototype core",
		13,
		"Use the middle passage to change when you reach the exit.",
		["#######", "#...E.#", "#.##..#", "#L....#", "#.##..#", "#...#.#", "#.#B..#", "#S....#", "#######"],
		[
			["A", 2, 0, ["B6", "C6", "D6", "C6"]],
			["B", 3, 5, ["F2", "F3", "F4", "F5", "F4", "F3"]],
		]
	)


static func _make(
	id: String,
	room_name: String,
	target_name: String,
	par: int,
	hint: String,
	rows: Array,
	guard_specs: Array
):
	var room = RoomScript.new()
	room.id = id
	room.name = room_name
	room.target_name = target_name
	room.par = par
	room.hint = hint
	room.rows = rows.duplicate()
	for spec in guard_specs:
		room.add_guard(str(spec[0]), int(spec[1]), int(spec[2]), _path(spec[3]))
	_scan(room)
	return room


static func _path(tokens: Array) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	for token in tokens:
		path.append(cell(str(token)))
	return path


static func _scan(room) -> void:
	room.bonus = Vector2i(-1, -1)
	for y in room.rows.size():
		var row := str(room.rows[y])
		for x in row.length():
			var mark := row.substr(x, 1)
			var c := Vector2i(x, y)
			if mark == "S":
				room.start = c
			elif mark == "L":
				room.target = c
			elif mark == "E":
				room.exit_cell = c
			elif mark == "B":
				room.bonus = c


static func _delta(dir: String) -> Vector2i:
	if dir == "U":
		return Vector2i(0, -1)
	if dir == "D":
		return Vector2i(0, 1)
	if dir == "L":
		return Vector2i(-1, 0)
	return Vector2i(1, 0)
