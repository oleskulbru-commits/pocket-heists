class_name HeistSim
extends RefCounted
## Pure route resolution. No scenes, input, clock, or files.


static func vision_cells(room: RoomData, origin: Vector2i, facing: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var facing_vec := _facing_vector(facing)
	for y in room.rows.size():
		var row := str(room.rows[y])
		for x in row.length():
			var target := Vector2i(x, y)
			if row.substr(x, 1) == "#":
				continue
			if not _in_cone(target - origin, facing_vec):
				continue
			if not _clear_line(room, origin, target):
				continue
			cells.append(target)
	return cells


static func initial_snapshot(room: RoomData) -> Dictionary:
	var guards: Array = []
	for guard in room.guards:
		var pose := _pose(room, guard, 0)
		guards.append({
			"id": guard.id,
			"cell": pose["cell"],
			"from": pose["cell"],
			"facing": pose["facing"],
			"vision": pose["vision"],
		})
	return {
		"beat": 0,
		"player": room.start,
		"player_from": room.start,
		"guards": guards,
		"has_target": false,
		"has_bonus": false,
		"terminal": "",
		"catch_guard": "",
		"catch_reason": "",
	}


static func step(room: RoomData, snapshot: Dictionary, next_cell: Vector2i) -> Dictionary:
	if str(snapshot["terminal"]) != "":
		return snapshot.duplicate(true)
	var beat := int(snapshot["beat"]) + 1
	var prev_player: Vector2i = snapshot["player"]
	var old_guards: Array = snapshot["guards"]
	var guards: Array = []
	for i in room.guards.size():
		var guard = room.guards[i]
		var prev_cell: Vector2i = old_guards[i]["cell"]
		var pose := _pose(room, guard, beat)
		guards.append({
			"id": guard.id,
			"cell": pose["cell"],
			"from": prev_cell,
			"facing": pose["facing"],
			"vision": pose["vision"],
		})
	var catch_guard := ""
	var catch_reason := ""
	for i in guards.size():
		var current: Dictionary = guards[i]
		var old_cell: Vector2i = old_guards[i]["cell"]
		var new_cell: Vector2i = current["cell"]
		if next_cell == new_cell:
			catch_guard = str(current["id"])
			catch_reason = "share"
			break
		if next_cell == old_cell and new_cell == prev_player:
			catch_guard = str(current["id"])
			catch_reason = "swap"
			break
		var seen: Array = current["vision"]
		if seen.has(next_cell):
			catch_guard = str(current["id"])
			catch_reason = "vision"
			break
	var has_target: bool = bool(snapshot["has_target"])
	var has_bonus: bool = bool(snapshot["has_bonus"])
	var terminal := ""
	if catch_guard != "":
		terminal = "caught"
	else:
		var ch: String = room.character_at(next_cell)
		if ch == "L":
			has_target = true
		elif ch == "B":
			has_bonus = true
		if ch == "E" and has_target:
			terminal = "cleared"
	return {
		"beat": beat,
		"player": next_cell,
		"player_from": prev_player,
		"guards": guards,
		"has_target": has_target,
		"has_bonus": has_bonus,
		"terminal": terminal,
		"catch_guard": catch_guard,
		"catch_reason": catch_reason,
	}


static func run(room: RoomData, route: Array[Vector2i]) -> Dictionary:
	var bad := _invalid_index(room, route)
	if bad >= 0:
		return {
			"result": "invalid_route",
			"snapshots": [],
			"moves": 0,
			"invalid_index": bad,
		}
	var snapshots: Array = [initial_snapshot(room)]
	for i in range(1, route.size()):
		var current: Dictionary = snapshots[snapshots.size() - 1]
		var advanced := step(room, current, route[i])
		snapshots.append(advanced)
		if str(advanced["terminal"]) != "":
			break
	var last: Dictionary = snapshots[snapshots.size() - 1]
	var result := "unfinished"
	if last["terminal"] == "caught":
		result = "caught"
	elif last["terminal"] == "cleared":
		result = "cleared"
	return {
		"result": result,
		"snapshots": snapshots,
		"moves": snapshots.size() - 1,
		"invalid_index": -1,
	}


static func _invalid_index(room: RoomData, route: Array[Vector2i]) -> int:
	if route.is_empty() or route[0] != room.start or not room.is_floor(route[0]):
		return 0
	for i in range(1, route.size()):
		if not _is_step(room, route[i - 1], route[i]):
			return i
	return -1


static func _is_step(room: RoomData, previous: Vector2i, next_cell: Vector2i) -> bool:
	var delta := next_cell - previous
	if absi(delta.x) + absi(delta.y) != 1:
		return false
	return room.is_floor(next_cell)


static func _pose(room: RoomData, guard, beat: int) -> Dictionary:
	var path: Array = guard.path
	var length: int = path.size()
	# Non-negative, so truncating float division matches floor((beat + phase) / interval).
	var index := int(float(beat + int(guard.p)) / float(guard.k)) % length
	var cell: Vector2i = path[index]
	var nxt: Vector2i = path[(index + 1) % length]
	var facing := _facing_name(nxt - cell)
	return {
		"cell": cell,
		"facing": facing,
		"vision": vision_cells(room, cell, facing),
	}


static func _in_cone(offset: Vector2i, facing: Vector2i) -> bool:
	var left := Vector2i(-facing.y, facing.x)
	var forward := offset.x * facing.x + offset.y * facing.y
	var lateral := absi(offset.x * left.x + offset.y * left.y)
	return forward >= 1 and lateral <= forward and forward + lateral <= 3


static func _clear_line(room: RoomData, origin: Vector2i, target: Vector2i) -> bool:
	var x0 := float(origin.x) + 0.5
	var y0 := float(origin.y) + 0.5
	var x1 := float(target.x) + 0.5
	var y1 := float(target.y) + 0.5
	for y in room.rows.size():
		var row := str(room.rows[y])
		for x in row.length():
			if row.substr(x, 1) != "#":
				continue
			var wall := Vector2i(x, y)
			if wall == origin or wall == target:
				continue
			if _segment_hits_rect(x0, y0, x1, y1, float(x), float(y), float(x + 1), float(y + 1)):
				return false
	return true


static func _segment_hits_rect(
	x0: float,
	y0: float,
	x1: float,
	y1: float,
	min_x: float,
	min_y: float,
	max_x: float,
	max_y: float
) -> bool:
	var dx := x1 - x0
	var dy := y1 - y0
	var span: Array = [0.0, 1.0]
	if not _clip(-dx, x0 - min_x, span):
		return false
	if not _clip(dx, max_x - x0, span):
		return false
	if not _clip(-dy, y0 - min_y, span):
		return false
	if not _clip(dy, max_y - y0, span):
		return false
	return float(span[0]) <= float(span[1])


static func _clip(p: float, q: float, span: Array) -> bool:
	var t0: float = span[0]
	var t1: float = span[1]
	if p == 0.0:
		return q >= 0.0
	var along := q / p
	if p < 0.0:
		if along > t1:
			return false
		if along > t0:
			span[0] = along
	else:
		if along < t0:
			return false
		if along < t1:
			span[1] = along
	return true


static func _facing_vector(facing: String) -> Vector2i:
	if facing == "N":
		return Vector2i(0, -1)
	if facing == "E":
		return Vector2i(1, 0)
	if facing == "S":
		return Vector2i(0, 1)
	return Vector2i(-1, 0)


static func _facing_name(delta: Vector2i) -> String:
	if delta == Vector2i(0, -1):
		return "N"
	if delta == Vector2i(1, 0):
		return "E"
	if delta == Vector2i(0, 1):
		return "S"
	return "W"
