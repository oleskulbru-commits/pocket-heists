class_name RoomData
extends RefCounted
## Grid, markers, and patrols for one room. The simulator does not load files.

var id: String = ""
var name: String = ""
var target_name: String = ""
var par: int = 0
var hint: String = ""
var rows: Array = []
var start: Vector2i = Vector2i.ZERO
var target: Vector2i = Vector2i.ZERO
var exit_cell: Vector2i = Vector2i.ZERO
var bonus: Vector2i = Vector2i(-1, -1)
var guards: Array = []


func _init() -> void:
	rows = []
	guards = []
	bonus = Vector2i(-1, -1)


func add_guard(guard_id: String, interval: int, phase: int, path: Array[Vector2i]) -> void:
	var guard := Guard.new()
	guard.id = guard_id
	guard.k = interval
	guard.p = phase
	var copy: Array[Vector2i] = []
	copy.assign(path)
	guard.path = copy
	guards.append(guard)


func character_at(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= rows.size():
		return "#"
	var row := str(rows[cell.y])
	if cell.x < 0 or cell.x >= row.length():
		return "#"
	return row.substr(cell.x, 1)


func is_floor(cell: Vector2i) -> bool:
	return character_at(cell) != "#"


class Guard extends RefCounted:
	var id: String = ""
	var k: int = 1
	var p: int = 0
	var path: Array[Vector2i] = []

	func _init() -> void:
		var fresh: Array[Vector2i] = []
		path = fresh
