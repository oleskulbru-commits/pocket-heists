extends "res://tests/test_suite.gd"

const _Draft = preload("res://scripts/input/draft.gd")

const _REASONS = [
	"none",
	"start_at_thief",
	"through_target",
	"end_at_exit",
	"blocked",
	"step_limit",
	"lift_to_run",
]

const _SERVICE: Array[String] = [
	"#######",
	"#....E#",
	"#.....#",
	"#.##..#",
	"#L....#",
	"#.....#",
	"#..##.#",
	"#S....#",
	"#######",
]

const _DISPATCH: Array[String] = [
	"#######",
	"#..L.E#",
	"#.#...#",
	"#.#.#.#",
	"#.#.#.#",
	"#.#.#.#",
	"#...#.#",
	"#S....#",
	"#######",
]


func suite_name() -> String:
	return "draft"


func run(check) -> void:
	_same_corridor(check)
	_diagonal_does_not_guess(check)
	_wall_rejects_and_blocks_release(check)
	_undo_one_and_loop_appends(check)
	_exit_requires_target(check)
	_release_inside_and_outside_exit(check)
	_step_limit_refuses_and_undoes(check)
	_second_pointer_is_ignored(check)
	_cancel_clears(check)
	_press_release_without_step_is_noop(check)
	_press_outside_start(check)
	_tap_mode(check)


func _same_corridor(check) -> void:
	var cells = _column(1, 7, 1)
	var stepped = _trace(_SERVICE, cells, "step")
	var jumped = _trace(_SERVICE, cells, "jump")
	var slow = _trace(_SERVICE, cells, "slow")
	_shape(check, stepped)
	_shape(check, jumped)
	_shape(check, slow)
	_eq_cells(check, stepped.cells, cells)
	_eq_cells(check, jumped.cells, cells)
	_eq_cells(check, slow.cells, cells)
	check.eq(stepped.moves, cells.size() - 1)
	check.eq(jumped.moves, stepped.moves)
	check.eq(slow.moves, stepped.moves)
	check.eq(stepped.reason, "lift_to_run")
	check.eq(jumped.reason, "lift_to_run")
	check.is_true(stepped.contains_target)
	check.is_true(not stepped.ends_on_exit)
	check.is_true(not stepped.valid)


func _diagonal_does_not_guess(check) -> void:
	var service = _editor(_SERVICE, false)
	service.pointer_down(1, _center(Vector2i(1, 7)))
	var across = service.pointer_move(1, _center(Vector2i(2, 6)))
	_shape(check, across)
	_eq_cells(check, across.cells, [Vector2i(1, 7)])
	check.is_true(not _has(across.cells, Vector2i(2, 7)))
	check.is_true(not _has(across.cells, Vector2i(1, 6)))
	check.is_true(not _has(across.cells, Vector2i(2, 6)))

	var dispatch = _editor(_DISPATCH, false)
	dispatch.pointer_down(1, _center(Vector2i(1, 7)))
	dispatch.pointer_move(1, _center(Vector2i(1, 6)))
	var into_wall = dispatch.pointer_move(1, _center(Vector2i(2, 5)))
	_shape(check, into_wall)
	_eq_cells(check, into_wall.cells, [Vector2i(1, 7), Vector2i(1, 6)])
	check.is_true(not _has(into_wall.cells, Vector2i(2, 6)))
	check.is_true(not _has(into_wall.cells, Vector2i(1, 5)))
	check.is_true(not _has(into_wall.cells, Vector2i(2, 5)))
	check.is_true(not into_wall.rejected)


func _wall_rejects_and_blocks_release(check) -> void:
	var editor = _editor(_SERVICE, false)
	editor.pointer_down(1, _center(Vector2i(1, 7)))
	var hit = editor.pointer_move(1, _center(Vector2i(0, 7)))
	_shape(check, hit)
	check.is_true(hit.rejected)
	check.eq(hit.reason, "blocked")
	_eq_cells(check, hit.cells, [Vector2i(1, 7)])
	check.eq(hit.rejected_from, Vector2i(1, 7))
	check.eq(hit.rejected_to, Vector2i(0, 7))
	var released = editor.pointer_up(1, _center(Vector2i(0, 7)))
	_shape(check, released)
	check.eq(released.reason, "blocked")
	check.eq(released.cells.size(), 0)
	check.eq(released.moves, 0)
	check.is_true(not released.valid)


func _undo_one_and_loop_appends(check) -> void:
	var undo = _editor(_SERVICE, false)
	undo.pointer_down(1, _center(Vector2i(1, 7)))
	undo.pointer_move(1, _center(Vector2i(1, 6)))
	undo.pointer_move(1, _center(Vector2i(1, 5)))
	var back = undo.pointer_move(1, _center(Vector2i(1, 6)))
	_shape(check, back)
	_eq_cells(check, back.cells, [Vector2i(1, 7), Vector2i(1, 6)])
	check.eq(back.moves, 1)
	check.eq(back.reason, "lift_to_run")

	var loop = _editor(_SERVICE, false)
	var cycle: Array[Vector2i] = [
		Vector2i(2, 7),
		Vector2i(2, 6),
		Vector2i(1, 6),
		Vector2i(1, 7),
	]
	loop.pointer_down(1, _center(Vector2i(1, 7)))
	var drafted: Dictionary = {}
	for i in 4:
		drafted = loop.pointer_move(1, _center(cycle[i]))
	_shape(check, drafted)
	check.eq(drafted.moves, 4)
	check.eq(drafted.cells.size(), 5)
	check.eq(drafted.cells[0], Vector2i(1, 7))
	check.eq(drafted.cells[4], Vector2i(1, 7))
	check.eq(drafted.reason, "lift_to_run")


func _exit_requires_target(check) -> void:
	var blocked = _editor(_SERVICE, false)
	var early: Array[Vector2i] = [
		Vector2i(1, 7),
		Vector2i(2, 7),
		Vector2i(3, 7),
		Vector2i(4, 7),
		Vector2i(5, 7),
		Vector2i(5, 6),
		Vector2i(5, 5),
		Vector2i(5, 4),
		Vector2i(5, 3),
		Vector2i(5, 2),
	]
	blocked.pointer_down(1, _center(early[0]))
	for i in range(1, early.size()):
		blocked.pointer_move(1, _center(early[i]))
	var rejected = blocked.pointer_move(1, _center(Vector2i(5, 1)))
	_shape(check, rejected)
	check.is_true(rejected.rejected)
	check.eq(rejected.reason, "blocked")
	check.is_true(not rejected.contains_target)
	check.is_true(not _has(rejected.cells, Vector2i(5, 1)))
	check.eq(rejected.cells[rejected.cells.size() - 1], Vector2i(5, 2))

	var route = _moves(Vector2i(1, 7), "U6 R4")
	var held = _editor(_SERVICE, false)
	_draw_until(held, route, route.size() - 1)
	var entered = held.pointer_move(1, _center(route[route.size() - 1]))
	_shape(check, entered)
	_eq_cells(check, entered.cells, route)
	check.eq(entered.moves, 10)
	check.is_true(entered.contains_target)
	check.is_true(entered.ends_on_exit)
	var extra = held.pointer_move(1, _center(Vector2i(5, 2)))
	_eq_cells(check, extra.cells, route)
	check.eq(extra.moves, 10)
	check.is_true(not extra.rejected)
	var walled = held.pointer_move(1, _center(Vector2i(6, 1)))
	_eq_cells(check, walled.cells, route)
	check.eq(walled.moves, 10)

	var leaving = _editor(_SERVICE, false)
	_draw_until(leaving, route, route.size())
	var undone = leaving.pointer_move(1, _center(route[route.size() - 2]))
	_shape(check, undone)
	check.eq(undone.moves, 9)
	check.eq(undone.cells[undone.cells.size() - 1], route[route.size() - 2])
	check.is_true(not undone.ends_on_exit)
	check.is_true(not undone.valid)


func _release_inside_and_outside_exit(check) -> void:
	var route = _moves(Vector2i(1, 7), "U6 R4")
	check.eq(route.size() - 1, 10)

	var committed = _editor(_SERVICE, false)
	_draw_until(committed, route, route.size() - 1)
	var inside = committed.pointer_up(1, _center(route[route.size() - 1]))
	_shape(check, inside)
	check.is_true(inside.valid)
	check.eq(inside.moves, 10)
	check.is_true(inside.contains_target)
	check.is_true(inside.ends_on_exit)
	_eq_cells(check, inside.cells, route)
	check.eq(inside.reason, "none")

	var outside = _editor(_SERVICE, false)
	_draw_until(outside, route, route.size())
	var missed = outside.pointer_up(1, _center(Vector2i(5, 2)))
	_shape(check, missed)
	check.eq(missed.reason, "end_at_exit")
	check.eq(missed.cells.size(), 0)
	check.eq(missed.moves, 0)
	check.is_true(not missed.valid)

	var partial = _editor(_SERVICE, false)
	_draw_until(partial, route, 7)
	var short = partial.pointer_up(1, _center(route[6]))
	_shape(check, short)
	check.eq(short.reason, "end_at_exit")
	check.eq(short.cells.size(), 0)
	check.is_true(not short.valid)

	var missing = _editor(_SERVICE, false)
	missing.pointer_down(1, _center(Vector2i(1, 7)))
	missing.pointer_move(1, _center(Vector2i(2, 7)))
	var early = missing.pointer_up(1, _center(Vector2i(2, 7)))
	_shape(check, early)
	check.eq(early.reason, "through_target")
	check.eq(early.cells.size(), 0)
	check.is_true(not early.valid)


func _step_limit_refuses_and_undoes(check) -> void:
	var editor = _editor(_SERVICE, false)
	var cycle: Array[Vector2i] = [
		Vector2i(2, 7),
		Vector2i(2, 6),
		Vector2i(1, 6),
		Vector2i(1, 7),
	]
	var drafted = editor.pointer_down(1, _center(Vector2i(1, 7)))
	for i in 48:
		drafted = editor.pointer_move(1, _center(cycle[i % 4]))
	_shape(check, drafted)
	check.eq(drafted.moves, 48)
	check.eq(drafted.reason, "lift_to_run")
	var refused = editor.pointer_move(1, _center(cycle[0]))
	_shape(check, refused)
	check.eq(refused.moves, 48)
	check.eq(refused.reason, "step_limit")
	check.is_true(not refused.rejected)
	check.eq(refused.cells.size(), drafted.cells.size())
	var tip: Vector2i = refused.cells[refused.cells.size() - 1]
	var prev: Vector2i = refused.cells[refused.cells.size() - 2]
	editor.pointer_move(1, _center(tip))
	var undone = editor.pointer_move(1, _center(prev))
	_shape(check, undone)
	check.eq(undone.moves, 47)
	check.eq(undone.reason, "lift_to_run")
	check.eq(undone.cells[undone.cells.size() - 1], prev)


func _second_pointer_is_ignored(check) -> void:
	var editor = _editor(_SERVICE, false)
	editor.pointer_down(1, _center(Vector2i(1, 7)))
	var before = editor.pointer_move(1, _center(Vector2i(1, 6)))
	var down2 = editor.pointer_down(2, _center(Vector2i(4, 5)))
	var move2 = editor.pointer_move(2, _center(Vector2i(5, 1)))
	var up2 = editor.pointer_up(2, _center(Vector2i(5, 1)))
	var cancel2 = editor.pointer_cancel(2)
	for draft in [down2, move2, up2, cancel2]:
		_shape(check, draft)
		_eq_cells(check, draft.cells, before.cells)
		check.eq(draft.moves, before.moves)
		check.eq(draft.reason, before.reason)
		check.eq(draft.valid, before.valid)
		check.eq(draft.rejected, before.rejected)
	var after = editor.pointer_move(1, _center(Vector2i(1, 5)))
	check.eq(after.moves, before.moves + 1)
	check.eq(after.cells[after.cells.size() - 1], Vector2i(1, 5))


func _cancel_clears(check) -> void:
	var editor = _editor(_SERVICE, false)
	editor.pointer_down(1, _center(Vector2i(1, 7)))
	editor.pointer_move(1, _center(Vector2i(1, 6)))
	var cleared = editor.pointer_cancel(1)
	_shape(check, cleared)
	check.eq(cleared.cells.size(), 0)
	check.eq(cleared.moves, 0)
	check.eq(cleared.reason, "none")
	check.is_true(not cleared.valid)
	check.is_true(not cleared.rejected)
	var again = editor.pointer_down(1, _center(Vector2i(1, 7)))
	var moved = editor.pointer_move(1, _center(Vector2i(1, 6)))
	check.eq(again.reason, "lift_to_run")
	_eq_cells(check, moved.cells, [Vector2i(1, 7), Vector2i(1, 6)])


func _press_release_without_step_is_noop(check) -> void:
	var fresh = _editor(_SERVICE, false)
	fresh.pointer_down(1, _center(Vector2i(1, 7)))
	var click = fresh.pointer_up(1, _center(Vector2i(1, 7)))
	_shape(check, click)
	check.eq(click.cells.size(), 0)
	check.eq(click.moves, 0)
	check.eq(click.reason, "none")
	check.is_true(not click.valid)

	var wiggle = _editor(_SERVICE, false)
	wiggle.pointer_down(1, _center(Vector2i(1, 7)))
	wiggle.pointer_move(1, Vector2(1.25, 7.4))
	var stayed = wiggle.pointer_up(1, Vector2(1.7, 7.8))
	_shape(check, stayed)
	check.eq(stayed.cells.size(), 0)
	check.eq(stayed.reason, "none")

	var prior = _editor(_SERVICE, false)
	prior.pointer_down(1, _center(Vector2i(1, 7)))
	prior.pointer_move(1, _center(Vector2i(2, 7)))
	var failed = prior.pointer_up(1, _center(Vector2i(2, 7)))
	check.eq(failed.reason, "through_target")
	prior.pointer_down(1, _center(Vector2i(1, 7)))
	var kept = prior.pointer_up(1, _center(Vector2i(1, 7)))
	_shape(check, kept)
	_eq_cells(check, kept.cells, failed.cells)
	check.eq(kept.moves, failed.moves)
	check.eq(kept.reason, failed.reason)
	check.eq(kept.valid, failed.valid)
	check.eq(kept.rejected, failed.rejected)


func _press_outside_start(check) -> void:
	var editor = _editor(_SERVICE, false)
	var pressed = editor.pointer_down(1, _center(Vector2i(4, 5)))
	_shape(check, pressed)
	check.eq(pressed.reason, "start_at_thief")
	check.eq(pressed.cells.size(), 0)
	check.eq(pressed.moves, 0)
	check.is_true(not pressed.valid)
	var slid = editor.pointer_move(1, _center(Vector2i(1, 7)))
	check.eq(slid.reason, "start_at_thief")
	check.eq(slid.cells.size(), 0)
	editor.pointer_up(1, _center(Vector2i(4, 5)))
	var restarted = editor.pointer_down(1, _center(Vector2i(1, 7)))
	check.eq(restarted.reason, "lift_to_run")
	_eq_cells(check, restarted.cells, [Vector2i(1, 7)])


func _tap_mode(check) -> void:
	var editor = _editor(_SERVICE, true)
	var started = editor.tap_cell(Vector2i(1, 7))
	var stepped = editor.tap_cell(Vector2i(1, 6))
	var further = editor.tap_cell(Vector2i(1, 5))
	_shape(check, started)
	_shape(check, further)
	_eq_cells(check, started.cells, [Vector2i(1, 7)])
	_eq_cells(check, stepped.cells, [Vector2i(1, 7), Vector2i(1, 6)])
	_eq_cells(check, further.cells, [Vector2i(1, 7), Vector2i(1, 6), Vector2i(1, 5)])
	check.eq(further.moves, 2)
	check.is_true(not further.valid)
	check.eq(further.reason, "none")

	var undone = editor.tap_cell(Vector2i(1, 6))
	_shape(check, undone)
	_eq_cells(check, undone.cells, [Vector2i(1, 7), Vector2i(1, 6)])
	check.eq(undone.moves, 1)

	var ignored = editor.tap_cell(Vector2i(4, 5))
	_eq_cells(check, ignored.cells, undone.cells)
	check.eq(ignored.moves, undone.moves)

	var emptied = editor.clear_draft()
	_shape(check, emptied)
	check.eq(emptied.cells.size(), 0)
	check.eq(emptied.moves, 0)
	check.eq(emptied.reason, "none")
	check.is_true(not emptied.valid)

	var route = _moves(Vector2i(1, 7), "U6 R4")
	var draft = editor.tap_cell(route[0])
	check.is_true(not draft.valid)
	for i in range(1, route.size()):
		draft = editor.tap_cell(route[i])
		_shape(check, draft)
		if i < route.size() - 1:
			check.is_true(not draft.valid)
	check.is_true(draft.valid)
	check.eq(draft.moves, 10)
	check.is_true(draft.contains_target)
	check.is_true(draft.ends_on_exit)
	check.eq(draft.reason, "none")
	_eq_cells(check, draft.cells, route)

	var left = editor.tap_cell(route[route.size() - 2])
	check.is_true(not left.valid)
	check.eq(left.moves, 9)
	check.is_true(not left.ends_on_exit)

	var gone = editor.clear_draft()
	check.eq(gone.cells.size(), 0)
	check.is_true(not gone.valid)


func _trace(rows: Array[String], cells: Array[Vector2i], mode: String) -> Dictionary:
	var editor = _editor(rows, false)
	var last = editor.pointer_down(1, _center(cells[0]))
	if mode == "jump":
		last = editor.pointer_move(1, _center(cells[cells.size() - 1]))
	elif mode == "step":
		for i in range(1, cells.size()):
			last = editor.pointer_move(1, _center(cells[i]))
	else:
		for i in range(1, cells.size()):
			var origin = _center(cells[i - 1])
			var goal = _center(cells[i])
			for step in range(1, 5):
				last = editor.pointer_move(1, origin.lerp(goal, float(step) / 4.0))
	return last


func _draw_until(editor, cells: Array[Vector2i], count: int) -> void:
	editor.pointer_down(1, _center(cells[0]))
	var limit = count
	if limit > cells.size():
		limit = cells.size()
	for i in range(1, limit):
		editor.pointer_move(1, _center(cells[i]))


func _editor(rows: Array[String], tap_mode: bool):
	var editor = _Draft.new()
	editor.setup(_room(rows), tap_mode)
	return editor


func _room(rows: Array[String]) -> Object:
	var path = "res://scripts/sim/room_data.gd"
	if FileAccess.file_exists(path):
		var script: Script = load(path)
		if script != null:
			var loaded: Object = script.new()
			_apply_room(loaded, rows)
			return loaded
	var room = _MinimalRoom.new()
	room.rows = rows.duplicate()
	room.start = _find(rows, "S")
	room.target = _find(rows, "L")
	room.exit_cell = _find(rows, "E")
	room.bonus = Vector2i(-1, -1)
	room.guards = []
	return room


func _apply_room(room: Object, rows: Array[String]) -> void:
	var values = {
		"id": "01",
		"name": "",
		"target_name": "",
		"par": 0,
		"hint": "",
		"rows": rows,
		"start": _find(rows, "S"),
		"target": _find(rows, "L"),
		"exit_cell": _find(rows, "E"),
		"bonus": Vector2i(-1, -1),
		"guards": [],
	}
	for key in values.keys():
		if not _has_property(room, String(key)):
			continue
		var current = room.get(key)
		if current is PackedStringArray:
			var packed = PackedStringArray()
			for row in rows:
				packed.append(row)
			room.set(key, packed)
		else:
			room.set(key, values[key])


func _has_property(room: Object, prop: String) -> bool:
	for info in room.get_property_list():
		if String(info.name) == prop:
			return true
	return false


func _find(rows: Array[String], glyph: String) -> Vector2i:
	for y in rows.size():
		var x = rows[y].find(glyph)
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


func _moves(start: Vector2i, spec: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [start]
	for token in spec.split(" ", false):
		var step = Vector2i.ZERO
		match token.substr(0, 1):
			"U":
				step = Vector2i(0, -1)
			"D":
				step = Vector2i(0, 1)
			"L":
				step = Vector2i(-1, 0)
			"R":
				step = Vector2i(1, 0)
		var count = 1
		if token.length() > 1:
			count = token.substr(1).to_int()
		for _i in count:
			cells.append(cells[cells.size() - 1] + step)
	return cells


func _column(x: int, y_from: int, y_to: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var y = y_from
	var step = -1 if y_to < y_from else 1
	while true:
		cells.append(Vector2i(x, y))
		if y == y_to:
			break
		y += step
	return cells


func _center(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5)


func _has(cells: Array, cell: Vector2i) -> bool:
	return cells.has(cell)


func _shape(check, draft: Dictionary) -> void:
	for key in [
		"cells",
		"moves",
		"valid",
		"contains_target",
		"ends_on_exit",
		"rejected",
		"rejected_from",
		"rejected_to",
		"reason",
	]:
		check.is_true(draft.has(key))
	check.is_true(_REASONS.has(String(draft.reason)))
	var expect_moves = 0
	if draft.cells.size() > 0:
		expect_moves = draft.cells.size() - 1
		check.eq(draft.cells[0], Vector2i(1, 7))
	check.eq(draft.moves, expect_moves)


func _eq_cells(check, actual: Array, expected: Array) -> void:
	check.eq(actual.size(), expected.size())
	var count: int = actual.size()
	if expected.size() < count:
		count = expected.size()
	for i in count:
		check.eq(actual[i], expected[i])


class _MinimalRoom:
	extends RefCounted
	var id = ""
	var name = ""
	var target_name = ""
	var par = 0
	var hint = ""
	var rows: Array[String] = []
	var start = Vector2i(-1, -1)
	var target = Vector2i(-1, -1)
	var exit_cell = Vector2i(-1, -1)
	var bonus = Vector2i(-1, -1)
	var guards: Array = []
