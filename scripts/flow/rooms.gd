class_name RoomsScreen
extends Control

signal room_selected(id: String)

const Style := preload("res://scripts/ui/style.gd")
const Copy := preload("res://scripts/ui/copy.gd")

var _built := false
var _list: VBoxContainer


func _init() -> void:
	_ensure()


func set_entries(entries: Array) -> void:
	_ensure()
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()
	for entry in entries:
		if entry is Dictionary:
			_list.add_child(_make_row(entry))


func _ensure() -> void:
	if _built:
		return
	_built = true
	Style.mount(self)
	var column := Style.column(self)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)


func _make_row(entry: Dictionary) -> Control:
	var id := str(entry.get("id", ""))
	var row := VBoxContainer.new()
	row.name = "Room_%s" % id
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 2)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 8)
	row.add_child(header)

	var select := Style.make_button(Copy.line("room_title", {
		"id": id,
		"name": str(entry.get("name", "")),
	}))
	select.name = "Select"
	Style.apply_button(select, true)
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var locked := bool(entry.get("locked", false))
	select.disabled = locked
	select.visible = true
	if not locked:
		select.pressed.connect(_emit_room.bind(id))
	header.add_child(select)

	var next_mark := Label.new()
	next_mark.name = "NextMark"
	next_mark.text = "Next"
	next_mark.visible = bool(entry.get("highlight", false))
	next_mark.custom_minimum_size = Vector2(72, 44)
	next_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	next_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Style.apply_label(next_mark, false, false)
	header.add_child(next_mark)

	_add_status(row, "MovesLabel", _moves_text(entry), _has_moves(entry))
	var par_value = entry.get("par")
	var par_text := ""
	if par_value != null:
		par_text = Copy.line("par", {"par": int(par_value)})
	_add_status(row, "ParLabel", par_text, par_value != null)
	_add_status(row, "ParMetLabel", Copy.line("par_met"), bool(entry.get("par_met", false)))
	_add_status(row, "BonusLabel", Copy.line("bonus_found"), bool(entry.get("bonus", false)))
	return row


func _add_status(row: VBoxContainer, node_name: String, text: String, show: bool) -> void:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.visible = show
	Style.apply_label(label, true, false)
	row.add_child(label)


func _has_moves(entry: Dictionary) -> bool:
	return bool(entry.get("cleared", false)) and entry.get("best_moves") != null


func _moves_text(entry: Dictionary) -> String:
	if not _has_moves(entry):
		return ""
	return Copy.line("moves", {"n": int(entry.get("best_moves"))})


func _emit_room(id: String) -> void:
	room_selected.emit(id)
