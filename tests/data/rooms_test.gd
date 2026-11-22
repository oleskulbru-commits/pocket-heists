extends "res://tests/test_suite.gd"

const RoomValidator = preload("res://scripts/data/room_validator.gd")
const RoomFile = preload("res://scripts/data/room_file.gd")

const _FILES: PackedStringArray = [
	"01-service-entrance.json",
	"02-dispatch-office.json",
	"03-packing-floor.json",
	"04-cold-storage.json",
	"05-security-annex.json",
	"06-bonded-vault.json",
]

const _FACING := {
	Vector2i(0, -1): "N",
	Vector2i(1, 0): "E",
	Vector2i(0, 1): "S",
	Vector2i(-1, 0): "W",
}

const _EXPECTED := {
	"01": {
		"name": "Service Entrance",
		"target_name": "brass access seal",
		"par": 10,
		"hint": "Pass through the seal before heading to the exit.",
		"clear": "U6 R4",
		"bonus_route": "",
		"bonus_moves": 0,
		"rows": [
			"#######", "#....E#", "#.....#", "#.##..#", "#L....#",
			"#.....#", "#..##.#", "#S....#", "#######",
		],
		"guards": [],
		"beat0": [],
	},
	"02": {
		"name": "Dispatch Office",
		"target_name": "dispatch ledger",
		"par": 12,
		"hint": "Take a short detour before you head up the left corridor.",
		"clear": "R U L U5 R4",
		"bonus_route": "",
		"bonus_moves": 0,
		"rows": [
			"#######", "#..L.E#", "#.#...#", "#.#.#.#", "#.#.#.#",
			"#.#.#.#", "#...#.#", "#S....#", "#######",
		],
		"guards": [
			{"id": "A", "k": 2, "p": 2, "path": ["D4", "D5", "D6", "D7", "D6", "D5"]},
		],
		"beat0": [["A", "D5", "S"]],
	},
	"03": {
		"name": "Packing Floor",
		"target_name": "customs stamp",
		"par": 16,
		"hint": "Cross the lower aisle before heading north.",
		"clear": "R4 U2 L4 U4 R2",
		"bonus_route": "R4 U2 L4 U2 R4 U2 L2",
		"bonus_moves": 20,
		"rows": [
			"#######", "#..E..#", "#.###.#", "#...B.#", "#.###.#",
			"#...L.#", "#.###.#", "#S....#", "#######",
		],
		"guards": [
			{"id": "A", "k": 2, "p": 6, "path": ["F3", "F4", "F5", "F6", "F7", "F6", "F5", "F4"]},
		],
		"beat0": [["A", "F6", "S"]],
	},
	"04": {
		"name": "Cold Storage",
		"target_name": "sealed specimen",
		"par": 14,
		"hint": "The left corridor has cover.",
		"clear": "U5 R D R2 U2 L3",
		"bonus_route": "U5 R D L U R D R2 D2 L3 U4",
		"bonus_moves": 22,
		"rows": [
			"#######", "#E....#", "#..#..#", "#..L..#", "#.##..#",
			"#..B..#", "#.##..#", "#S....#", "#######",
		],
		"guards": [
			{"id": "A", "k": 2, "p": 0, "path": ["E6", "F6", "F7", "F8", "F7", "F6"]},
			{"id": "B", "k": 2, "p": 1, "path": ["F3", "F4", "F5", "F4"]},
		],
		"beat0": [["A", "E6", "E"], ["B", "F3", "S"]],
	},
	"05": {
		"name": "Security Annex",
		"target_name": "blackbox recorder",
		"par": 12,
		"hint": "Start across the bottom, then climb through the middle.",
		"clear": "R2 U3 L U R3 U2",
		"bonus_route": "R2 U3 L U R D2 R2 U4",
		"bonus_moves": 16,
		"rows": [
			"#######", "#....E#", "#.###.#", "#.L...#", "#...#.#",
			"#.#.B.#", "#.#.#.#", "#S....#", "#######",
		],
		"guards": [
			{"id": "A", "k": 3, "p": 10, "path": ["B3", "B4", "B5", "B6", "B5", "B4"]},
			{"id": "B", "k": 2, "p": 4, "path": ["F5", "F6", "F7", "F8", "F7", "F6"]},
		],
		"beat0": [["A", "B6", "N"], ["B", "F7", "S"]],
	},
	"06": {
		"name": "Bonded Vault",
		"target_name": "prototype core",
		"par": 13,
		"hint": "Use the middle passage to change when you reach the exit.",
		"clear": "U4 R3 D R U L U2",
		"bonus_route": "R2 U R2 U2 L U L3 U2 R3",
		"bonus_moves": 17,
		"rows": [
			"#######", "#...E.#", "#.##..#", "#L....#", "#.##..#",
			"#...#.#", "#.#B..#", "#S....#", "#######",
		],
		"guards": [
			{"id": "A", "k": 2, "p": 0, "path": ["B6", "C6", "D6", "C6"]},
			{"id": "B", "k": 3, "p": 5, "path": ["F2", "F3", "F4", "F5", "F4", "F3"]},
		],
		"beat0": [["A", "B6", "E"], ["B", "F3", "S"]],
	},
}


func suite_name() -> String:
	return "rooms"


func run(check) -> void:
	_files(check)
	_move_counts(check)
	_shipping_files_are_valid(check)
	_broken_border(check)
	_second_start(check)
	_bonus_in_room_01(check)
	_diagonal_patrol(check)
	_par_mismatch(check)
	_load_all(check)


func _files(check) -> void:
	var dir := DirAccess.open("res://data/rooms")
	check.is_true(dir != null)
	if dir == null:
		check.fail("missing data/rooms")
		return
	var names: PackedStringArray = dir.get_files()
	var json_names: PackedStringArray = []
	for file_name in names:
		if file_name.ends_with(".json"):
			json_names.append(file_name)
	json_names.sort()
	check.eq(json_names, _FILES)


func _move_counts(check) -> void:
	check.eq(RoomValidator.move_count("U6 R4"), 10)
	check.eq(RoomValidator.move_count("U"), 1)
	check.eq(RoomValidator.move_count("U2 R3"), 5)
	check.eq(RoomValidator.move_count("  U6   R4 "), 10)
	check.eq(RoomValidator.move_count(""), 0)
	check.eq(RoomValidator.move_count("X"), -1)
	for id in _EXPECTED:
		check.eq(RoomValidator.CLEAR_ROUTE[id], _EXPECTED[id]["clear"])
		check.eq(RoomValidator.move_count(_EXPECTED[id]["clear"]), _EXPECTED[id]["par"])


func _shipping_files_are_valid(check) -> void:
	for file_name in _FILES:
		var errors := RoomValidator.validate_file("res://data/rooms".path_join(file_name))
		check.is_true(errors.is_empty())
		if not errors.is_empty():
			check.fail("%s: %s" % [file_name, " ".join(errors)])


func _broken_border(check) -> void:
	var room := _read("01-service-entrance.json")
	room["rows"][0] = "#.#####"
	var errors := RoomValidator.validate(room)
	check.is_true(not errors.is_empty())
	check.is_true(" ".join(errors).contains("border"))


func _second_start(check) -> void:
	var room := _read("01-service-entrance.json")
	room["rows"][2] = "#S....#"
	var errors := RoomValidator.validate(room)
	check.is_true(not errors.is_empty())
	check.is_true(" ".join(errors).contains("exactly one S"))


func _bonus_in_room_01(check) -> void:
	var room := _read("01-service-entrance.json")
	room["rows"][2] = "#B....#"
	var errors := RoomValidator.validate(room)
	check.is_true(not errors.is_empty())
	check.is_true(" ".join(errors).contains("bonus"))


func _diagonal_patrol(check) -> void:
	var room := _read("02-dispatch-office.json")
	room["guards"][0]["path"] = ["D8", "C7", "C8"]
	var errors := RoomValidator.validate(room)
	check.is_true(not errors.is_empty())
	check.is_true(" ".join(errors).contains("edge-adjacent"))


func _par_mismatch(check) -> void:
	var room := _read("01-service-entrance.json")
	room["par"] = 11
	var errors := RoomValidator.validate(room)
	check.is_true(not errors.is_empty())
	check.is_true(" ".join(errors).contains("par"))


func _load_all(check) -> void:
	var rooms: Array = RoomFile.load_all()
	check.eq(rooms.size(), 6)
	var ids: PackedStringArray = []
	for room in rooms:
		ids.append(str(room.id))
	check.eq(ids, PackedStringArray(["01", "02", "03", "04", "05", "06"]))
	for room in rooms:
		var expected: Dictionary = _EXPECTED[str(room.id)]
		check.eq(str(room.name), expected["name"])
		check.eq(str(room.target_name), expected["target_name"])
		check.eq(int(room.par), expected["par"])
		check.eq(str(room.hint), expected["hint"])
		check.eq(PackedStringArray(room.rows), PackedStringArray(expected["rows"]))
		check.eq(room.start, RoomValidator.marker_cell(expected["rows"], "S"))
		check.eq(room.target, RoomValidator.marker_cell(expected["rows"], "L"))
		check.eq(room.exit_cell, RoomValidator.marker_cell(expected["rows"], "E"))
		var bonus: Vector2i = RoomValidator.marker_cell(expected["rows"], "B")
		check.eq(room.bonus, bonus)
		_guards(check, room, expected)
		_walk(check, expected["rows"], expected["clear"], expected["par"], false)
		if str(expected["bonus_route"]) != "":
			_walk(check, expected["rows"], expected["bonus_route"], expected["bonus_moves"], true)


func _guards(check, room, expected: Dictionary) -> void:
	var guards: Array = room.guards
	var spec: Array = expected["guards"]
	check.eq(guards.size(), spec.size())
	if guards.size() != spec.size():
		return
	for index in guards.size():
		var guard = guards[index]
		var wanted: Dictionary = spec[index]
		check.eq(str(_field(guard, "id")), wanted["id"])
		check.eq(int(_field(guard, "k")), wanted["k"])
		check.eq(int(_field(guard, "p")), wanted["p"])
		var path: Array = _field(guard, "path")
		var wanted_path: Array = wanted["path"]
		check.eq(path.size(), wanted_path.size())
		if path.size() != wanted_path.size():
			continue
		for step in path.size():
			check.eq(path[step], RoomValidator.parse_cell(wanted_path[step]))
		var beat0: Array = expected["beat0"][index]
		var opened := _opening(guard)
		check.eq(str(opened["id"]), beat0[0])
		check.eq(opened["cell"], RoomValidator.parse_cell(beat0[1]))
		check.eq(opened["facing"], beat0[2])


func _opening(guard) -> Dictionary:
	var path: Array = _field(guard, "path")
	var interval := int(_field(guard, "k"))
	var phase := int(_field(guard, "p"))
	var index := int(floor(float(phase) / float(interval))) % path.size()
	var cell: Vector2i = path[index]
	var nxt: Vector2i = path[(index + 1) % path.size()]
	return {"id": _field(guard, "id"), "cell": cell, "facing": _FACING[nxt - cell]}


func _walk(check, rows: Array, route: String, moves: int, require_bonus: bool) -> void:
	var pos := RoomValidator.marker_cell(rows, "S")
	var text := route.replace(" ", "")
	var seen_target := false
	var seen_bonus := false
	var count := 0
	var i := 0
	while i < text.length():
		var step := text.substr(i, 1)
		var delta := _delta(step)
		if delta == Vector2i.ZERO:
			check.fail("bad route token in %s" % route)
			return
		i += 1
		var digits := ""
		while i < text.length() and text.substr(i, 1).is_valid_int():
			digits += text.substr(i, 1)
			i += 1
		var repeat := 1 if digits.is_empty() else int(digits)
		for _n in repeat:
			pos += delta
			count += 1
			if not _floor_at(rows, pos):
				check.fail("%s leaves the floor at %s" % [route, pos])
				return
			var tile := str(rows[pos.y]).substr(pos.x, 1)
			if tile == "L":
				seen_target = true
			if tile == "B":
				seen_bonus = true
	check.eq(count, moves)
	check.is_true(seen_target)
	check.eq(pos, RoomValidator.marker_cell(rows, "E"))
	if require_bonus:
		check.is_true(seen_bonus)


func _floor_at(rows: Array, cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= rows.size():
		return false
	var row := str(rows[cell.y])
	if cell.x < 0 or cell.x >= row.length():
		return false
	return row.substr(cell.x, 1) != "#"


func _delta(step: String) -> Vector2i:
	match step:
		"U":
			return Vector2i(0, -1)
		"D":
			return Vector2i(0, 1)
		"L":
			return Vector2i(-1, 0)
		"R":
			return Vector2i(1, 0)
	return Vector2i.ZERO


func _field(guard, key: String):
	if typeof(guard) == TYPE_DICTIONARY:
		return guard[key]
	return guard.get(key)


func _read(file_name: String) -> Dictionary:
	return RoomValidator.read_json("res://data/rooms".path_join(file_name))
