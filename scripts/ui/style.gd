class_name FlowStyle
extends RefCounted

## Palette and fonts for the flow screens.
## Colors match HeistTheme. When that class is loadable, its constants win.

const THEME_PATH := "res://scripts/presentation/theme.gd"

const BACKDROP := Color("#12181D")
const WALL := Color("#182126")
const FLOOR := Color("#27343A")
const SEAM := Color("#435159")
const ROUTE := Color("#82F3E4")
const ROUTE_OUTLINE := Color("#12181D")
const LOOT := Color("#F5CE79")
const EXIT := Color("#BFE7A0")
const VISION := Color("#FF866F")
const INK := Color("#F2EEE3")
const MUTED := Color("#A5B1B7")

const MIN_BUTTON := Vector2(44, 44)

static var _theme: Script = null
static var _theme_checked := false
static var _members: Dictionary = {}


static func color(key: String) -> Color:
	var value = _theme_member(key)
	if value is Color:
		return value
	match key:
		"BACKDROP":
			return BACKDROP
		"WALL":
			return WALL
		"FLOOR":
			return FLOOR
		"SEAM":
			return SEAM
		"ROUTE":
			return ROUTE
		"ROUTE_OUTLINE":
			return ROUTE_OUTLINE
		"LOOT":
			return LOOT
		"EXIT":
			return EXIT
		"VISION":
			return VISION
		"INK":
			return INK
		"MUTED":
			return MUTED
		_:
			return INK


static func title_font() -> Font:
	var value = _theme_member("title_font")
	if value is Font:
		return value
	var found := _best_font(["barlow"], "semi")
	if found != null:
		return found
	return ThemeDB.fallback_font


static func body_font() -> Font:
	var value = _theme_member("body_font")
	if value is Font:
		return value
	var found := _best_font(["atkinson"], "regular")
	if found != null:
		return found
	return ThemeDB.fallback_font


static func mount(host: Control) -> void:
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.offset_left = 0.0
	host.offset_top = 0.0
	host.offset_right = 0.0
	host.offset_bottom = 0.0
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = color("BACKDROP")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(backdrop)


static func column(host: Control) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "Column"
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(box)
	return box


static func spacer() -> Control:
	var space := Control.new()
	space.name = "Spacer"
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return space


static func make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	apply_button(button, false)
	return button


static func make_check(text: String) -> CheckButton:
	var button := CheckButton.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	apply_button(button, false)
	return button


static func make_label(node_name: String, secondary: bool) -> Label:
	var label := Label.new()
	label.name = node_name
	apply_label(label, secondary, false)
	return label


static func apply_button(button: BaseButton, title: bool) -> void:
	button.custom_minimum_size = MIN_BUTTON
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", title_font() if title else body_font())
	button.add_theme_font_size_override("font_size", 20 if title else 18)
	button.add_theme_color_override("font_color", color("INK"))
	button.add_theme_color_override("font_hover_color", color("INK"))
	button.add_theme_color_override("font_pressed_color", color("INK"))
	button.add_theme_color_override("font_disabled_color", color("MUTED"))
	button.add_theme_color_override("font_hover_pressed_color", color("INK"))
	button.add_theme_color_override("font_focus_color", color("INK"))
	var normal := _box(color("FLOOR"), color("SEAM"))
	var hover := _box(color("SEAM"), color("INK"))
	var pressed := _box(color("WALL"), color("ROUTE"))
	var disabled := _box(color("WALL"), color("SEAM"))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("hover_pressed", pressed)


static func apply_label(label: Label, secondary: bool, title: bool) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", title_font() if title else body_font())
	label.add_theme_font_size_override("font_size", 22 if title else 16)
	label.add_theme_color_override("font_color", color("MUTED") if secondary else color("INK"))


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


static func _theme_member(key: String):
	if _members.has(key):
		return _members[key]
	var script := _theme_script()
	var value = null
	if script != null:
		var constants: Dictionary = script.get_script_constant_map()
		if constants.has(key) and constants[key] != null:
			value = constants[key]
		elif _is_font_key(key) and _theme_class_ready():
			value = _read_static(key)
	_members[key] = value
	return value


static func _theme_script() -> Script:
	if _theme_checked:
		return _theme
	_theme_checked = true
	if ResourceLoader.exists(THEME_PATH):
		var loaded = load(THEME_PATH)
		if loaded is Script:
			_theme = loaded
	return _theme


static func _is_font_key(key: String) -> bool:
	return key == "title_font" or key == "body_font"


static func _theme_class_ready() -> bool:
	for entry in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == "HeistTheme":
			return true
	return false


static func _read_static(key: String):
	var reader := GDScript.new()
	reader.source_code = "extends RefCounted\nstatic func read():\n\treturn HeistTheme.%s\n" % key
	if reader.reload() != OK:
		return null
	return reader.call("read")


static func _best_font(needles: PackedStringArray, prefer: String) -> Font:
	var dir := DirAccess.open("res://assets/fonts")
	if dir == null:
		return null
	var preferred := ""
	var fallback := ""
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var lower := file_name.to_lower()
			var ext_ok := lower.ends_with(".ttf") or lower.ends_with(".otf") or lower.ends_with(".otc")
			if ext_ok:
				var matched := true
				for needle in needles:
					if lower.find(needle) == -1:
						matched = false
						break
				if matched:
					if fallback == "":
						fallback = file_name
					if prefer != "" and lower.find(prefer) != -1:
						preferred = file_name
		file_name = dir.get_next()
	dir.list_dir_end()
	var pick := preferred if preferred != "" else fallback
	if pick == "":
		return null
	var font = load("res://assets/fonts/%s" % pick)
	if font is Font:
		return font
	return null
