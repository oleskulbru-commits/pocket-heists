extends "res://tests/test_suite.gd"

const Sim = preload("res://scripts/sim/simulation.gd")
const Timing = preload("res://scripts/sim/timing.gd")
const Catalog = preload("res://tests/sim/catalog.gd")

const COPY := {
	"01": ["Service Entrance", "brass access seal", "Pass through the seal before heading to the exit."],
	"02": ["Dispatch Office", "dispatch ledger", "Take a short detour before you head up the left corridor."],
	"03": ["Packing Floor", "customs stamp", "Cross the lower aisle before heading north."],
	"04": ["Cold Storage", "sealed specimen", "The left corridor has cover."],
	"05": ["Security Annex", "blackbox recorder", "Start across the bottom, then climb through the middle."],
	"06": ["Bonded Vault", "prototype core", "Use the middle passage to change when you reach the exit."],
}

const MARKERS := {
	"01": {"target": "B5", "exit": "F2", "bonus": ""},
	"02": {"target": "D2", "exit": "F2", "bonus": ""},
	"03": {"target": "E6", "exit": "D2", "bonus": "E4"},
	"04": {"target": "D4", "exit": "B2", "bonus": "D6"},
	"05": {"target": "C4", "exit": "F2", "bonus": "E6"},
	"06": {"target": "B4", "exit": "E2", "bonus": "D7"},
}

const BEAT0 := {
	"01": [],
	"02": [["A", "D5", "S"]],
	"03": [["A", "F6", "S"]],
	"04": [["A", "E6", "E"], ["B", "F3", "S"]],
	"05": [["A", "B6", "N"], ["B", "F7", "S"]],
	"06": [["A", "B6", "E"], ["B", "F3", "S"]],
}

const EXPECTED := {
	"01": {"clear": "U6 R4", "par": 10, "bonus": "", "bonus_moves": 0, "catch": ""},
	"02": {
		"clear": "R U L U5 R4",
		"par": 12,
		"bonus": "",
		"bonus_moves": 0,
		"catch": "U6 R4",
		"beat": 8,
		"cell": "D2",
		"guard": "A",
		"reason": "vision",
	},
	"03": {
		"clear": "R4 U2 L4 U4 R2",
		"par": 16,
		"bonus": "R4 U2 L4 U2 R4 U2 L2",
		"bonus_moves": 20,
		"catch": "U2 R4 U4 L2",
		"beat": 7,
		"cell": "F5",
		"guard": "A",
		"reason": "share",
	},
	"04": {
		"clear": "U5 R D R2 U2 L3",
		"par": 14,
		"bonus": "U5 R D L U R D R2 D2 L3 U4",
		"bonus_moves": 22,
		"catch": "",
	},
	"05": {
		"clear": "R2 U3 L U R3 U2",
		"par": 12,
		"bonus": "R2 U3 L U R D2 R2 U4",
		"bonus_moves": 16,
		"catch": "",
	},
	"06": {
		"clear": "U4 R3 D R U L U2",
		"par": 13,
		"bonus": "R2 U R2 U2 L U L3 U2 R3",
		"bonus_moves": 17,
		"catch": "",
	},
}


func suite_name() -> String:
	return "sim"


func run(check) -> void:
	_test_timing(check)
	var fixture = _load_fixture()
	if fixture == null:
		check.fail("routes.json did not parse")
		return
	var rooms: Dictionary = Catalog.by_id()
	_test_fixture_table(check, fixture)
	_test_room_table(check, rooms)
	_test_beat_zero(check, rooms)
	_test_routes(check, rooms, fixture)
	_test_swap(check)
	_test_share(check)
	_test_catch_beats_extract(check)
	_test_wall_blocks_ray(check)
	_test_corner_blocks_ray(check)
	_test_two_guards(check)
	_test_repeat_equal(check)
	_test_invalid_route(check)
	_test_stops_when_cleared(check)
	_test_step_matches_run(check)
	_test_step_freezes_terminal(check)
	_test_no_move_cap(check)
	_test_exit_without_target(check)


func _test_timing(check) -> void:
	check.eq(Timing.BEAT_SEC, 0.30)
	check.eq(Timing.ANTICIPATION_SEC, 0.20)
	check.eq(Timing.CAUGHT_UI_SEC, 0.65)
	check.eq(Timing.RETRY_SEC, 0.25)
	check.eq(Timing.MAX_MOVES, 48)


func _test_fixture_table(check, fixture: Dictionary) -> void:
	var entries: Array = fixture["rooms"]
	check.eq(entries.size(), 6)
	var ids: Array = []
	for entry in entries:
		var id := str(entry["id"])
		ids.append(id)
		var expected: Dictionary = EXPECTED[id]
		check.eq(str(entry["clear"]), expected["clear"])
		check.eq(int(entry["par"]), int(expected["par"]))
		if str(expected["bonus"]) == "":
			check.eq(entry["bonus"], null)
			check.eq(entry["bonus_moves"], null)
		else:
			check.eq(str(entry["bonus"]), expected["bonus"])
			check.eq(int(entry["bonus_moves"]), int(expected["bonus_moves"]))
		if str(expected["catch"]) == "":
			check.eq(entry["catch"], null)
		else:
			var caught: Dictionary = entry["catch"]
			check.eq(str(caught["route"]), expected["catch"])
			check.eq(int(caught["beat"]), int(expected["beat"]))
			check.eq(str(caught["cell"]), expected["cell"])
			check.eq(str(caught["guard"]), expected["guard"])
			check.eq(str(caught["reason"]), expected["reason"])
	check.eq(ids, ["01", "02", "03", "04", "05", "06"])


func _test_room_table(check, rooms: Dictionary) -> void:
	for id in ["01", "02", "03", "04", "05", "06"]:
		var room = rooms[id]
		var copy: Array = COPY[id]
		var marks: Dictionary = MARKERS[id]
		check.eq(room.id, id)
		check.eq(room.name, copy[0])
		check.eq(room.target_name, copy[1])
		check.eq(room.hint, copy[2])
		check.eq(room.par, int(EXPECTED[id]["par"]))
		check.eq(room.rows.size(), 9)
		for row in room.rows:
			check.eq(str(row).length(), 7)
		check.eq(Catalog.cell_name(room.start), "B8")
		check.eq(Catalog.cell_name(room.target), marks["target"])
		check.eq(Catalog.cell_name(room.exit_cell), marks["exit"])
		if str(marks["bonus"]) == "":
			check.eq(room.bonus, Vector2i(-1, -1))
		else:
			check.eq(Catalog.cell_name(room.bonus), marks["bonus"])


func _test_beat_zero(check, rooms: Dictionary) -> void:
	for id in ["01", "02", "03", "04", "05", "06"]:
		var snap: Dictionary = Sim.initial_snapshot(rooms[id])
		_assert_snapshot_keys(check, snap)
		check.eq(snap["beat"], 0)
		check.eq(snap["player"], rooms[id].start)
		check.eq(snap["player_from"], snap["player"])
		check.eq(snap["has_target"], false)
		check.eq(snap["has_bonus"], false)
		check.eq(snap["terminal"], "")
		check.eq(snap["catch_guard"], "")
		check.eq(snap["catch_reason"], "")
		var expected: Array = BEAT0[id]
		var guards: Array = snap["guards"]
		check.eq(guards.size(), expected.size())
		for i in expected.size():
			var guard: Dictionary = guards[i]
			_assert_guard_keys(check, guard)
			check.eq(guard["id"], expected[i][0])
			check.eq(Catalog.cell_name(guard["cell"]), expected[i][1])
			check.eq(guard["from"], guard["cell"])
			check.eq(guard["facing"], expected[i][2])


func _test_routes(check, rooms: Dictionary, fixture: Dictionary) -> void:
	for entry in fixture["rooms"]:
		var id := str(entry["id"])
		var room = rooms[id]
		var expected: Dictionary = EXPECTED[id]
		var clear_route := Catalog.parse_route(room.start, str(entry["clear"]))
		check.eq(clear_route.size() - 1, int(expected["par"]))
		var cleared = Sim.run(room, clear_route)
		_assert_result_keys(check, cleared)
		_assert_clear(check, cleared, room, int(expected["par"]), false)
		if id == "01":
			var last_clear: Dictionary = cleared["snapshots"][cleared["snapshots"].size() - 1]
			check.eq(last_clear["guards"].size(), 0)
		if entry["bonus"] != null:
			var bonus_route := Catalog.parse_route(room.start, str(entry["bonus"]))
			check.eq(bonus_route.size() - 1, int(expected["bonus_moves"]))
			var bonus = Sim.run(room, bonus_route)
			_assert_clear(check, bonus, room, int(expected["bonus_moves"]), true)
		if entry["catch"] != null:
			var catch_route := Catalog.parse_route(room.start, str(entry["catch"]["route"]))
			var beat := int(expected["beat"])
			check.eq(catch_route.size() - 1 > beat, true)
			var caught = Sim.run(room, catch_route)
			_assert_catch(check, caught, catch_route, beat, str(expected["cell"]), str(expected["guard"]), str(expected["reason"]))
			var last: Dictionary = caught["snapshots"][caught["snapshots"].size() - 1]
			if id == "02":
				check.eq(last["has_target"], false)
				check.eq(last["player"], room.target)
			if id == "03":
				check.eq(last["has_target"], true)


func _test_swap(check) -> void:
	var rows := _bordered()
	_place(rows, "B8", "S")
	_place(rows, "B7", "L")
	_place(rows, "B6", "E")
	var room = Catalog.from_rows("swap", rows, [["A", 1, 0, ["B7", "B8"]]])
	var route := Catalog.parse_route(room.start, "U")
	var result = Sim.run(room, route)
	_assert_catch(check, result, route, 1, "B7", "A", "swap")
	var last: Dictionary = result["snapshots"][result["snapshots"].size() - 1]
	check.eq(last["has_target"], false)
	check.eq(last["player"], room.target)


func _test_share(check) -> void:
	var rows := _bordered()
	_place(rows, "B8", "S")
	_place(rows, "B6", "L")
	_place(rows, "B5", "E")
	var room = Catalog.from_rows("share", rows, [["A", 2, 0, ["B7", "B6"]]])
	var route := Catalog.parse_route(room.start, "U")
	var result = Sim.run(room, route)
	_assert_catch(check, result, route, 1, "B7", "A", "share")
	var last: Dictionary = result["snapshots"][result["snapshots"].size() - 1]
	check.eq(last["has_target"], false)


func _test_catch_beats_extract(check) -> void:
	var rows := _bordered()
	_place(rows, "C8", "S")
	_place(rows, "C7", "L")
	_place(rows, "C6", "E")
	var room = Catalog.from_rows("extract", rows, [["A", 1, 0, ["C4", "C5"]]])
	var route := Catalog.parse_route(room.start, "U U")
	var result = Sim.run(room, route)
	check.eq(result["result"], "caught")
	_assert_catch(check, result, route, 2, "C6", "A", "vision")
	var snaps: Array = result["snapshots"]
	var mid: Dictionary = snaps[1]
	var last: Dictionary = snaps[2]
	check.eq(mid["terminal"], "")
	check.eq(mid["has_target"], true)
	check.eq(mid["player"], room.target)
	check.eq(last["terminal"], "caught")
	check.eq(last["has_target"], true)
	check.eq(last["player"], room.exit_cell)


func _test_wall_blocks_ray(check) -> void:
	var room = Catalog.from_rows("wall", _bordered([Catalog.cell("D3")]), [])
	var cells: Array[Vector2i] = Sim.vision_cells(room, Catalog.cell("D5"), "N")
	var names := _names(cells)
	check.eq(names.has("D4"), true)
	check.eq(names.has("D2"), false)
	check.eq(names.has("E4"), true)
	check.eq(names, ["C3", "E3", "C4", "D4", "E4"])


func _test_corner_blocks_ray(check) -> void:
	var blocked = Catalog.from_rows("corner", _bordered([Catalog.cell("C5")]), [])
	var hidden := _names(Sim.vision_cells(blocked, Catalog.cell("D5"), "N"))
	check.eq(hidden.has("C4"), false)
	check.eq(hidden, ["D2", "C3", "D3", "E3", "D4", "E4"])
	var open_room = Catalog.from_rows("corner-open", _bordered(), [])
	var shown := _names(Sim.vision_cells(open_room, Catalog.cell("D5"), "N"))
	check.eq(shown.has("C4"), true)


func _test_two_guards(check) -> void:
	var rows := _bordered()
	_place(rows, "C8", "S")
	_place(rows, "B2", "L")
	_place(rows, "B3", "E")
	var room = Catalog.from_rows("two", rows, [
		["A", 2, 0, ["C5", "C6"]],
		["B", 1, 0, ["C6", "C7"]],
	])
	var route := Catalog.parse_route(room.start, "U")
	var result = Sim.run(room, route)
	_assert_catch(check, result, route, 1, "C7", "A", "vision")
	var last: Dictionary = result["snapshots"][result["snapshots"].size() - 1]
	var guard_b: Dictionary = _find_guard(last, "B")
	check.eq(guard_b.is_empty(), false)
	check.eq(guard_b["cell"], last["player"])


func _test_repeat_equal(check) -> void:
	var room = Catalog.by_id()["02"]
	var route := Catalog.parse_route(room.start, "U6 R4")
	var first = Sim.run(room, route)
	var second = Sim.run(room, route)
	check.eq(first["result"], "caught")
	check.eq(_dump(first), _dump(second))
	check.eq(first["snapshots"] == second["snapshots"], true)
	check.eq(first["result"] == second["result"], true)
	check.eq(first["moves"] == second["moves"], true)


func _test_invalid_route(check) -> void:
	var room = Catalog.by_id()["01"]
	var diagonal: Array[Vector2i] = [room.start, room.start + Vector2i(1, -1)]
	var result = Sim.run(room, diagonal)
	check.eq(result["result"], "invalid_route")
	check.eq(result["invalid_index"], 1)
	check.eq(result["snapshots"].size(), 0)
	check.eq(result["moves"], 0)
	var later: Array[Vector2i] = [
		room.start,
		room.start + Vector2i(0, -1),
		room.start + Vector2i(1, -2),
	]
	var indexed = Sim.run(room, later)
	check.eq(indexed["result"], "invalid_route")
	check.eq(indexed["invalid_index"], 2)
	check.eq(indexed["snapshots"].size(), 0)
	var into_wall: Array[Vector2i] = [room.start, room.start + Vector2i(-1, 0)]
	var wall = Sim.run(room, into_wall)
	check.eq(wall["result"], "invalid_route")
	check.eq(wall["invalid_index"], 1)
	var empty: Array[Vector2i] = []
	var missing = Sim.run(room, empty)
	check.eq(missing["result"], "invalid_route")
	check.eq(missing["invalid_index"], 0)
	check.eq(missing["snapshots"].size(), 0)


func _test_stops_when_cleared(check) -> void:
	var room = Catalog.by_id()["01"]
	var route := Catalog.parse_route(room.start, "U6 R4")
	route.append(route[route.size() - 1] + Vector2i(0, 1))
	var result = Sim.run(room, route)
	check.eq(result["result"], "cleared")
	check.eq(result["moves"], 10)
	check.eq(result["snapshots"].size(), 11)


func _test_step_matches_run(check) -> void:
	var room = Catalog.by_id()["01"]
	var route := Catalog.parse_route(room.start, "U")
	var snap0: Dictionary = Sim.initial_snapshot(room)
	var snap1: Dictionary = Sim.step(room, snap0, route[1])
	var played = Sim.run(room, route)
	check.eq(snap0["beat"], 0)
	check.eq(snap1["beat"], 1)
	check.eq(_dump(played["snapshots"][1]), _dump(snap1))


func _test_step_freezes_terminal(check) -> void:
	var room = Catalog.by_id()["02"]
	var route := Catalog.parse_route(room.start, "U6 R4")
	var played = Sim.run(room, route)
	var last: Dictionary = played["snapshots"][played["snapshots"].size() - 1]
	var again: Dictionary = Sim.step(room, last, last["player"] + Vector2i(1, 0))
	check.eq(again["beat"], last["beat"])
	check.eq(again["terminal"], "caught")
	check.eq(again["player"], last["player"])
	check.eq(again["has_target"], false)


func _test_no_move_cap(check) -> void:
	var room = Catalog.by_id()["01"]
	var route: Array[Vector2i] = [room.start]
	var right: Vector2i = room.start + Vector2i(1, 0)
	for i in 49:
		if i % 2 == 0:
			route.append(right)
		else:
			route.append(room.start)
	var result = Sim.run(room, route)
	check.eq(result["result"], "unfinished")
	check.eq(result["moves"], 49)
	check.eq(result["invalid_index"], -1)


func _test_exit_without_target(check) -> void:
	var room = Catalog.by_id()["01"]
	var route := Catalog.parse_route(room.start, "R4 U6")
	var result = Sim.run(room, route)
	check.eq(result["result"], "unfinished")
	check.eq(result["moves"], 10)
	check.eq(result["invalid_index"], -1)
	var last: Dictionary = result["snapshots"][result["snapshots"].size() - 1]
	check.eq(last["player"], room.exit_cell)
	check.eq(last["has_target"], false)
	check.eq(last["terminal"], "")


func _assert_clear(check, result: Dictionary, room, moves: int, bonus: bool) -> void:
	check.eq(result["result"], "cleared")
	check.eq(result["moves"], moves)
	check.eq(result["invalid_index"], -1)
	var snaps: Array = result["snapshots"]
	check.eq(snaps.size(), moves + 1)
	var first: Dictionary = snaps[0]
	check.eq(first["beat"], 0)
	check.eq(first["player"], first["player_from"])
	check.eq(first["terminal"], "")
	check.eq(first["has_target"], false)
	check.eq(first["has_bonus"], false)
	var last: Dictionary = snaps[snaps.size() - 1]
	check.eq(last["beat"], moves)
	check.eq(last["player"], room.exit_cell)
	check.eq(last["terminal"], "cleared")
	check.eq(last["has_target"], true)
	check.eq(last["has_bonus"], bonus)
	check.eq(last["catch_guard"], "")
	check.eq(last["catch_reason"], "")


func _assert_catch(check, result: Dictionary, route: Array, beat: int, cell_name: String, guard_id: String, reason: String) -> void:
	check.eq(result["result"], "caught")
	check.eq(result["moves"], beat)
	check.eq(result["invalid_index"], -1)
	var snaps: Array = result["snapshots"]
	check.eq(snaps.size(), beat + 1)
	var last: Dictionary = snaps[snaps.size() - 1]
	check.eq(last["beat"], beat)
	check.eq(last["terminal"], "caught")
	check.eq(Catalog.cell_name(last["player"]), cell_name)
	check.eq(last["player"], route[beat])
	check.eq(last["player_from"], route[beat - 1])
	check.eq(last["catch_guard"], guard_id)
	check.eq(last["catch_reason"], reason)
	var guard := _find_guard(last, guard_id)
	check.eq(guard.is_empty(), false)
	if guard.is_empty():
		return
	if reason == "share":
		check.eq(guard["cell"], last["player"])
	elif reason == "swap":
		check.eq(last["player"], guard["from"])
		check.eq(guard["cell"], last["player_from"])
	elif reason == "vision":
		check.eq((guard["vision"] as Array).has(last["player"]), true)


func _assert_result_keys(check, result: Dictionary) -> void:
	for key in ["result", "snapshots", "moves", "invalid_index"]:
		check.eq(result.has(key), true)


func _assert_snapshot_keys(check, snap: Dictionary) -> void:
	for key in ["beat", "player", "player_from", "guards", "has_target", "has_bonus", "terminal", "catch_guard", "catch_reason"]:
		check.eq(snap.has(key), true)


func _assert_guard_keys(check, guard: Dictionary) -> void:
	for key in ["id", "cell", "from", "facing", "vision"]:
		check.eq(guard.has(key), true)


func _find_guard(snap: Dictionary, guard_id: String) -> Dictionary:
	for entry in snap["guards"]:
		if str(entry["id"]) == guard_id:
			return entry
	return {}


func _bordered(extra_walls: Array = []) -> Array:
	var rows: Array = []
	for y in 9:
		var row := ""
		for x in 7:
			var mark := "."
			if x == 0 or y == 0 or x == 6 or y == 8 or extra_walls.has(Vector2i(x, y)):
				mark = "#"
			row += mark
		rows.append(row)
	return rows


func _place(rows: Array, token: String, mark: String) -> void:
	var c: Vector2i = Catalog.cell(token)
	var row := str(rows[c.y])
	rows[c.y] = row.substr(0, c.x) + mark + row.substr(c.x + 1)


func _names(cells: Array) -> Array:
	var names: Array = []
	for c in cells:
		names.append(Catalog.cell_name(c))
	return names


func _load_fixture():
	var text := FileAccess.get_file_as_string("res://data/fixtures/routes.json")
	if text.is_empty():
		return null
	return JSON.parse_string(text)


func _dump(value) -> String:
	if value is Vector2i:
		return "v%d_%d" % [value.x, value.y]
	if value is bool:
		return "true" if value else "false"
	if value is int:
		return str(value)
	if value is float:
		return str(value)
	if value is String or value is StringName:
		return str(value)
	if value == null:
		return "null"
	if value is Array:
		var parts := PackedStringArray()
		for item in value:
			parts.append(_dump(item))
		return "[" + ",".join(parts) + "]"
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var parts := PackedStringArray()
		for key in keys:
			parts.append("%s=%s" % [str(key), _dump(value[key])])
		return "{" + ",".join(parts) + "}"
	return str(value)
