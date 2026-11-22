extends TestSuite

const Layout := preload("res://scripts/shell/portrait_layout.gd")
const Gate := preload("res://scripts/shell/rotate_gate.gd")


func suite_name() -> String:
	return "layout"


func run(check) -> void:
	check.eq(Gate.MESSAGE, "Rotate to portrait", "rotate message")
	check.eq(Layout.MIN_BUTTON_SIZE, 44, "minimum button")
	_check_phone(check, Vector2(390, 844), Rect2i(0, 0, 390, 844), "390x844")
	_check_on_screen(check, Vector2(320, 568), Rect2i(0, 0, 320, 568), "320x568")
	var landscape: Dictionary = Layout.fit(Vector2(700, 400), Rect2i(0, 0, 700, 400))
	check.eq(landscape["rotate"], true, "700x400 rotate")
	var desktop: Dictionary = Layout.fit(Vector2(1440, 900), Rect2i(0, 0, 1440, 900))
	check.eq(desktop["rotate"], false, "1440x900 rotate")
	check.is_true(desktop["column"].size.x <= 480, "1440x900 column width")
	check.is_true(desktop["column"].size.y <= 960, "1440x900 column height")
	_check_column_centered(check, desktop, Rect2i(0, 0, 1440, 900), "1440x900")
	var inset_safe := Rect2i(100, 50, 600, 700)
	var inset: Dictionary = Layout.fit(Vector2(1440, 900), inset_safe)
	check.eq(inset["rotate"], false, "inset rotate uses the viewport")
	check.eq(inset["column"].size, Vector2i(480, 700), "inset column size")
	_check_column_centered(check, inset, inset_safe, "inset")
	check.eq(Layout.fit(Vector2(500, 499), Rect2i(0, 0, 500, 499))["rotate"], true, "short landscape edge")
	check.eq(Layout.fit(Vector2(500, 500), Rect2i(0, 0, 500, 500))["rotate"], false, "square")


func _check_phone(check, viewport: Vector2, safe: Rect2i, label: String) -> void:
	var layout: Dictionary = Layout.fit(viewport, safe)
	check.eq(layout["rotate"], false, "%s rotate" % label)
	_check_cell(check, layout, label)
	_check_column_centered(check, layout, safe, label)
	_check_regions(check, layout, label)


func _check_on_screen(check, viewport: Vector2, safe: Rect2i, label: String) -> void:
	var layout: Dictionary = Layout.fit(viewport, safe)
	var screen := Rect2i(Vector2i.ZERO, Vector2i(roundi(viewport.x), roundi(viewport.y)))
	for region in ["header", "board", "footer"]:
		var rect: Rect2i = layout[region]
		check.is_true(rect.size.x > 0 and rect.size.y > 0, "%s %s has area" % [label, region])
		check.is_true(screen.encloses(rect), "%s %s on screen" % [label, region])
	_check_cell(check, layout, label)
	_check_regions(check, layout, label)


func _check_cell(check, layout: Dictionary, label: String) -> void:
	var cell = layout["cell"]
	var column: Rect2i = layout["column"]
	var inner_width := column.size.x - Layout.SIDE_MARGIN * 2
	var inner_height := column.size.y - Layout.HEADER_HEIGHT - Layout.FOOTER_MIN_HEIGHT
	check.eq(typeof(cell), TYPE_INT, "%s cell type" % label)
	check.is_true(cell > 0, "%s cell positive" % label)
	check.is_true(cell * 7 <= inner_width and cell * 9 <= inner_height, "%s cell fits" % label)
	check.is_true((cell + 1) * 7 > inner_width or (cell + 1) * 9 > inner_height, "%s cell is greatest" % label)
	var board: Rect2i = layout["board"]
	check.eq(board.size, Vector2i(cell * 7, cell * 9), "%s board is 7 by 9" % label)
	check.eq(board.position, layout["origin"], "%s origin" % label)
	check.is_true(column.encloses(board), "%s board inside column" % label)


func _check_regions(check, layout: Dictionary, label: String) -> void:
	var column: Rect2i = layout["column"]
	var header: Rect2i = layout["header"]
	var footer: Rect2i = layout["footer"]
	var board: Rect2i = layout["board"]
	check.eq(header, Rect2i(column.position, Vector2i(column.size.x, Layout.HEADER_HEIGHT)), "%s header" % label)
	check.eq(footer.end, column.end, "%s footer bottom" % label)
	check.is_true(footer.size.y >= Layout.FOOTER_MIN_HEIGHT, "%s footer height" % label)
	check.is_true(board.position.x >= column.position.x + Layout.SIDE_MARGIN, "%s left margin" % label)
	check.is_true(board.end.x <= column.end.x - Layout.SIDE_MARGIN, "%s right margin" % label)
	check.is_true(board.position.y >= header.end.y, "%s below header" % label)
	check.is_true(board.end.y <= footer.position.y, "%s above footer" % label)
	var above := board.position.y - header.end.y
	var below := footer.position.y - board.end.y
	check.is_true(absi(above - below) <= 1, "%s centered under the header" % label)
	var left := board.position.x - (column.position.x + Layout.SIDE_MARGIN)
	var right := (column.end.x - Layout.SIDE_MARGIN) - board.end.x
	check.is_true(absi(left - right) <= 1, "%s centered in the margins" % label)


func _check_column_centered(check, layout: Dictionary, safe: Rect2i, label: String) -> void:
	var column: Rect2i = layout["column"]
	check.is_true(column.size.x <= Layout.MAX_COLUMN_WIDTH, "%s column width cap" % label)
	check.is_true(column.size.y <= Layout.MAX_COLUMN_HEIGHT, "%s column height cap" % label)
	check.is_true(safe.encloses(column), "%s column inside safe" % label)
	var left := column.position.x - safe.position.x
	var right := safe.end.x - column.end.x
	var top := column.position.y - safe.position.y
	var bottom := safe.end.y - column.end.y
	check.is_true(absi(left - right) <= 1, "%s column centered x" % label)
	check.is_true(absi(top - bottom) <= 1, "%s column centered y" % label)
