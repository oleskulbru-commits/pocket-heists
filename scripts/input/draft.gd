extends RefCounted
class_name DraftEditor

## Cell-space draft editor. Samples are board pixels divided by cell size.
## Reason values are codes: none, start_at_thief, through_target, end_at_exit,
## blocked, step_limit, lift_to_run.

const MAX_MOVES := 48
const _NULL_CELL := Vector2i(-1, -1)
const _NUDGE := 0.000001
const _CORNER_EPS := 0.00001

var _rows: PackedStringArray = PackedStringArray()
var _start := Vector2i(-1, -1)
var _target := Vector2i(-1, -1)
var _exit := Vector2i(-1, -1)
var _tap_mode := false

var _cells: Array[Vector2i] = []
var _rejected := false
var _rejected_from := Vector2i(-1, -1)
var _rejected_to := Vector2i(-1, -1)
var _reason := "none"
var _active_pointer := -1
var _invalid_start := false
var _last_point := Vector2.ZERO
var _has_last_point := false
var _ignore_until_tip := false
var _edited := false
var _snapshot: Dictionary = {}


func setup(room: Object, tap_mode: bool) -> void:
	_read_room(room)
	_tap_mode = tap_mode
	reset()


func reset() -> void:
	_clear_route()
	_reason = "none"
	_finish_gesture()
	_snapshot = {}


func pointer_down(pointer_id: int, point: Vector2) -> Dictionary:
	if _tap_mode:
		return _draft()
	if _active_pointer != -1:
		return _draft()
	_active_pointer = pointer_id
	if _cell_of(point) != _start:
		_invalid_start = true
		_reason = "start_at_thief"
		return _draft()
	_invalid_start = false
	_snapshot = _capture()
	_cells.clear()
	_cells.append(_start)
	_clear_rejection()
	_reason = "lift_to_run"
	_edited = false
	_last_point = point
	_has_last_point = true
	return _draft()


func pointer_move(pointer_id: int, point: Vector2) -> Dictionary:
	if _tap_mode or pointer_id != _active_pointer or _invalid_start:
		return _draft()
	if _cells.is_empty():
		return _draft()
	_consume_point(point)
	return _draft()


func pointer_up(pointer_id: int, point: Vector2) -> Dictionary:
	if _tap_mode or pointer_id != _active_pointer:
		return _draft()
	if _invalid_start:
		_finish_gesture()
		return _draft()
	if not _cells.is_empty():
		_consume_point(point)
	if not _edited and not _rejected:
		_restore(_snapshot)
		_finish_gesture()
		return _draft()
	_resolve_release(point)
	_finish_gesture()
	return _draft()


func pointer_cancel(pointer_id: int) -> Dictionary:
	if _active_pointer != -1 and pointer_id != _active_pointer:
		return _draft()
	_clear_route()
	_reason = "none"
	_finish_gesture()
	return _draft()


func tap_cell(cell: Vector2i) -> Dictionary:
	if not _tap_mode:
		return _draft()
	if _cells.is_empty():
		if cell != _start:
			_reason = "start_at_thief"
			return _draft()
		_cells.append(_start)
		_clear_rejection()
		_reason = "none"
		return _draft()
	_try_enter(cell)
	_ignore_until_tip = false
	return _draft()


func clear_draft() -> Dictionary:
	_clear_route()
	_reason = "none"
	_finish_gesture()
	return _draft()


func _read_room(room: Object) -> void:
	_rows = PackedStringArray()
	for row in room.rows:
		_rows.append(String(row))
	_start = _find_glyph("S")
	_target = _find_glyph("L")
	_exit = _find_glyph("E")


func _find_glyph(glyph: String) -> Vector2i:
	for y in _rows.size():
		var x := String(_rows[y]).find(glyph)
		if x >= 0:
			return Vector2i(x, y)
	return _NULL_CELL


func _consume_point(point: Vector2) -> void:
	if not _has_last_point:
		_last_point = point
		_has_last_point = true
		return
	if _ignore_until_tip:
		if _cell_of(point) == _tip():
			_clear_rejection()
			if _reason == "blocked":
				_set_open_reason()
		_last_point = point
		return
	var entered := _walk_segment(_last_point, point)
	_last_point = point
	for cell in entered:
		if _try_enter(cell):
			break


func _try_enter(cell: Vector2i) -> bool:
	var tip := _tip()
	if cell == tip:
		if _ignore_until_tip or _rejected:
			_clear_rejection()
			if _reason == "blocked":
				_set_open_reason()
		return false
	if not _adjacent(tip, cell):
		return true
	if _cells.size() >= 2 and cell == _cells[_cells.size() - 2]:
		_cells.pop_back()
		_edited = true
		_clear_rejection()
		_set_open_reason()
		return false
	# Exit is terminal. Only the previous cell (undo) is still accepted.
	if tip == _exit:
		return false
	if _is_wall(cell) or (cell == _exit and not _contains_target()):
		_rejected = true
		_rejected_from = tip
		_rejected_to = cell
		_reason = "blocked"
		_ignore_until_tip = not _tap_mode
		return true
	if _move_count() >= MAX_MOVES:
		_reason = "step_limit"
		return false
	_cells.append(cell)
	_edited = true
	_clear_rejection()
	_set_open_reason()
	return false


func _resolve_release(point: Vector2) -> void:
	var inside_exit := _cell_of(point) == _exit
	var committable := (
		not _rejected
		and inside_exit
		and _contains_target()
		and _ends_on_exit()
		and _move_count() >= 1
		and _move_count() <= MAX_MOVES
	)
	if committable:
		_reason = "none"
		_clear_rejection()
		return
	var why := "end_at_exit"
	if _rejected:
		why = "blocked"
	elif not _contains_target():
		why = "through_target"
	_clear_route()
	_reason = why


func _walk_segment(from: Vector2, to: Vector2) -> Array[Vector2i]:
	var start := _nudge_inside(from)
	var end := _nudge_inside(to)
	var entered: Array[Vector2i] = []
	var dx := end.x - start.x
	var dy := end.y - start.y
	if absf(dx) <= 0.0000001 and absf(dy) <= 0.0000001:
		return entered

	var cx := floori(start.x)
	var cy := floori(start.y)
	var step_x := 0
	var step_y := 0
	var t_max_x := INF
	var t_max_y := INF
	var t_delta_x := INF
	var t_delta_y := INF

	if dx > 0.0:
		step_x = 1
		t_delta_x = 1.0 / dx
		t_max_x = (float(cx + 1) - start.x) * t_delta_x
	elif dx < 0.0:
		step_x = -1
		t_delta_x = 1.0 / -dx
		t_max_x = (start.x - float(cx)) * t_delta_x

	if dy > 0.0:
		step_y = 1
		t_delta_y = 1.0 / dy
		t_max_y = (float(cy + 1) - start.y) * t_delta_y
	elif dy < 0.0:
		step_y = -1
		t_delta_y = 1.0 / -dy
		t_max_y = (start.y - float(cy)) * t_delta_y

	var guard := 0
	while guard < 256:
		guard += 1
		if t_max_x > 1.0 and t_max_y > 1.0:
			break
		# A corner crossing is ambiguous. Do not emit the diagonal cell.
		if absf(t_max_x - t_max_y) <= _CORNER_EPS and t_max_x <= 1.0 and t_max_y <= 1.0:
			break
		if t_max_x < t_max_y:
			if t_max_x >= 1.0:
				break
			cx += step_x
			t_max_x += t_delta_x
			entered.append(Vector2i(cx, cy))
		else:
			if t_max_y >= 1.0:
				break
			cy += step_y
			t_max_y += t_delta_y
			entered.append(Vector2i(cx, cy))
	return entered


func _nudge_inside(point: Vector2) -> Vector2:
	var nudged := point
	if nudged.x - floorf(nudged.x) <= 0.0000001:
		nudged.x += _NUDGE
	if nudged.y - floorf(nudged.y) <= 0.0000001:
		nudged.y += _NUDGE
	return nudged


func _draft() -> Dictionary:
	return {
		"cells": _copy_cells(_cells),
		"moves": _move_count(),
		"valid": _is_valid(),
		"contains_target": _contains_target(),
		"ends_on_exit": _ends_on_exit(),
		"rejected": _rejected,
		"rejected_from": _rejected_from,
		"rejected_to": _rejected_to,
		"reason": _reason,
	}


func _capture() -> Dictionary:
	return {
		"cells": _copy_cells(_cells),
		"rejected": _rejected,
		"rejected_from": _rejected_from,
		"rejected_to": _rejected_to,
		"reason": _reason,
	}


func _restore(snap: Dictionary) -> void:
	_cells = _copy_cells(snap.cells)
	_rejected = snap.rejected
	_rejected_from = snap.rejected_from
	_rejected_to = snap.rejected_to
	_reason = snap.reason
	_ignore_until_tip = false


func _clear_route() -> void:
	_cells.clear()
	_clear_rejection()


func _clear_rejection() -> void:
	_rejected = false
	_rejected_from = _NULL_CELL
	_rejected_to = _NULL_CELL
	_ignore_until_tip = false


func _finish_gesture() -> void:
	_active_pointer = -1
	_invalid_start = false
	_has_last_point = false
	_ignore_until_tip = false
	_edited = false


func _set_open_reason() -> void:
	_reason = "none" if _tap_mode else "lift_to_run"


func _copy_cells(source: Array) -> Array[Vector2i]:
	var copy: Array[Vector2i] = []
	for cell in source:
		copy.append(cell)
	return copy


func _move_count() -> int:
	if _cells.is_empty():
		return 0
	return _cells.size() - 1


func _contains_target() -> bool:
	return _cells.has(_target)


func _ends_on_exit() -> bool:
	return not _cells.is_empty() and _tip() == _exit


func _is_valid() -> bool:
	return (
		not _rejected
		and _contains_target()
		and _ends_on_exit()
		and _move_count() >= 1
		and _move_count() <= MAX_MOVES
	)


func _tip() -> Vector2i:
	return _cells[_cells.size() - 1]


func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func _is_wall(cell: Vector2i) -> bool:
	return _glyph(cell) == "#"


func _glyph(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= _rows.size() or cell.x < 0:
		return "#"
	var row := String(_rows[cell.y])
	if cell.x >= row.length():
		return "#"
	return row.substr(cell.x, 1)


func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x), floori(point.y))
