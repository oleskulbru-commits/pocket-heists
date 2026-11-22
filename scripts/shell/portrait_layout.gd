class_name PortraitLayout
extends RefCounted

const MAX_COLUMN_WIDTH := 480
const MAX_COLUMN_HEIGHT := 960
const SIDE_MARGIN := 16
const HEADER_HEIGHT := 64
const FOOTER_MIN_HEIGHT := 88
const MIN_BUTTON_SIZE := 44
const GRID_COLUMNS := 7
const GRID_ROWS := 9

static func fit(viewport: Vector2, safe: Rect2i) -> Dictionary:
	var rotate := viewport.x > viewport.y and viewport.y < 500.0
	var column_size := Vector2i(
		mini(safe.size.x, MAX_COLUMN_WIDTH),
		mini(safe.size.y, MAX_COLUMN_HEIGHT)
	)
	var column_position := Vector2i(
		safe.position.x + _quo(safe.size.x - column_size.x, 2),
		safe.position.y + _quo(safe.size.y - column_size.y, 2)
	)
	var column := Rect2i(column_position, column_size)
	var inner_width := column_size.x - SIDE_MARGIN * 2
	var inner_height := column_size.y - HEADER_HEIGHT - FOOTER_MIN_HEIGHT
	var cell := 0
	if inner_width > 0 and inner_height > 0:
		cell = mini(_quo(inner_width, GRID_COLUMNS), _quo(inner_height, GRID_ROWS))
	var board_size := Vector2i(cell * GRID_COLUMNS, cell * GRID_ROWS)
	var content_position := column_position + Vector2i(SIDE_MARGIN, HEADER_HEIGHT)
	var content_size := Vector2i(inner_width, inner_height)
	var origin := Vector2i(
		content_position.x + _quo(content_size.x - board_size.x, 2),
		content_position.y + _quo(content_size.y - board_size.y, 2)
	)
	var header := Rect2i(column_position, Vector2i(column_size.x, HEADER_HEIGHT))
	var footer := Rect2i(
		Vector2i(column_position.x, column_position.y + column_size.y - FOOTER_MIN_HEIGHT),
		Vector2i(column_size.x, FOOTER_MIN_HEIGHT)
	)
	return {
		"rotate": rotate,
		"column": column,
		"header": header,
		"board": Rect2i(origin, board_size),
		"footer": footer,
		"origin": origin,
		"cell": cell,
	}


static func _quo(numerator: int, denominator: int) -> int:
	return int(float(numerator) / float(denominator))
