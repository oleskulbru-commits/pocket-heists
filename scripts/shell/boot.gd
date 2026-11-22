extends Node

const APP_SCENE := "res://scenes/game/app.tscn"
const LAYOUT := preload("res://scripts/shell/portrait_layout.gd")
const GRID := preload("res://scripts/shell/grid_board.gd")
const GATE := preload("res://scripts/shell/rotate_gate.gd")
const BACKDROP := Color("#12181D")
const BAR := Color("#182126")

var _pixels: Node2D
var _backdrop: ColorRect
var _header: ColorRect
var _footer: ColorRect
var _board: Node2D
var _gate: Control


func _ready() -> void:
	if ResourceLoader.exists(APP_SCENE):
		get_tree().change_scene_to_file(APP_SCENE)
		return
	_pixels = Node2D.new()
	_pixels.name = "CssPixels"
	add_child(_pixels)
	_backdrop = _bar("Backdrop", BACKDROP)
	_header = _bar("Header", BAR)
	_footer = _bar("Footer", BAR)
	_board = GRID.new()
	_board.name = "Board"
	_pixels.add_child(_board)
	_gate = GATE.new()
	_gate.name = "RotateGate"
	_pixels.add_child(_gate)
	get_tree().root.size_changed.connect(_apply_layout)
	_apply_layout()


func _bar(node_name: String, color: Color) -> ColorRect:
	var bar := ColorRect.new()
	bar.name = node_name
	bar.color = color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pixels.add_child(bar)
	return bar


func _apply_layout() -> void:
	var css := _css_size()
	if css.x < 1.0 or css.y < 1.0:
		return
	var logical := get_viewport().get_visible_rect().size
	_pixels.scale = Vector2(logical.x / css.x, logical.y / css.y)
	var layout: Dictionary = LAYOUT.fit(css, _safe_rect(css))
	var show_column := not bool(layout["rotate"])
	_backdrop.position = Vector2.ZERO
	_backdrop.size = css
	_header.visible = show_column
	_footer.visible = show_column
	_board.visible = show_column
	_gate.position = Vector2.ZERO
	_gate.size = css
	_gate.apply(layout)
	if not show_column:
		return
	var header: Rect2i = layout["header"]
	var footer: Rect2i = layout["footer"]
	var origin: Vector2i = layout["origin"]
	var cell := int(layout["cell"])
	_header.position = Vector2(header.position)
	_header.size = Vector2(header.size)
	_footer.position = Vector2(footer.position)
	_footer.size = Vector2(footer.size)
	_board.position = Vector2(origin)
	_board.scale = Vector2(cell, cell)
	_board.queue_redraw()


func _css_size() -> Vector2:
	var window := Vector2(DisplayServer.window_get_size())
	var pixel_ratio := DisplayServer.screen_get_scale()
	if pixel_ratio <= 0.0:
		pixel_ratio = 1.0
	return window / pixel_ratio


func _safe_rect(css: Vector2) -> Rect2i:
	var width := maxi(roundi(css.x), 0)
	var height := maxi(roundi(css.y), 0)
	var insets := _safe_insets()
	var inner_width := width - insets.x - insets.z
	var inner_height := height - insets.y - insets.w
	if inner_width <= 0 or inner_height <= 0:
		return Rect2i(0, 0, width, height)
	return Rect2i(insets.x, insets.y, inner_width, inner_height)


func _safe_insets() -> Vector4i:
	if not OS.has_feature("web"):
		return Vector4i.ZERO
	var raw = JavaScriptBridge.eval("window.pocketHeistsSafeInsets && window.pocketHeistsSafeInsets()", true)
	if typeof(raw) != TYPE_STRING:
		return Vector4i.ZERO
	var parts := (raw as String).split(",")
	if parts.size() != 4:
		return Vector4i.ZERO
	return Vector4i(int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3]))
