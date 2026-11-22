class_name JobScreen
extends Control

signal rooms_pressed
signal replay_vault_pressed

const Style := preload("res://scripts/ui/style.gd")
const Copy := preload("res://scripts/ui/copy.gd")

var _built := false
var _title: Label
var _rooms_cleared: Label
var _valuables: Label


func _init() -> void:
	_ensure()


func show_result(rooms_cleared: int, valuables: int) -> void:
	_ensure()
	_title.text = Copy.line("job_complete")
	_rooms_cleared.text = Copy.line("rooms_cleared", {"n": rooms_cleared})
	_valuables.text = Copy.line("valuables", {"n": valuables})


func _ensure() -> void:
	if _built:
		return
	_built = true
	Style.mount(self)
	var column := Style.column(self)
	_title = Style.make_label("TitleLabel", false)
	_title.add_theme_font_size_override("font_size", 28)
	_rooms_cleared = Style.make_label("RoomsClearedLabel", false)
	_valuables = Style.make_label("ValuablesLabel", false)
	column.add_child(_title)
	column.add_child(_rooms_cleared)
	column.add_child(_valuables)
	column.add_child(Style.spacer())
	var rooms := Style.make_button("Rooms")
	rooms.name = "RoomsButton"
	rooms.pressed.connect(rooms_pressed.emit)
	column.add_child(rooms)
	var replay := Style.make_button("Replay vault")
	replay.name = "ReplayVaultButton"
	replay.pressed.connect(replay_vault_pressed.emit)
	column.add_child(replay)
