class_name ResultScreen
extends Control

signal retry_pressed
signal next_pressed
signal finish_pressed
signal rooms_pressed

const Style := preload("res://scripts/ui/style.gd")
const Copy := preload("res://scripts/ui/copy.gd")

var _built := false
var _caught: Label
var _moves: Label
var _par: Label
var _par_met: Label
var _bonus: Label
var _retry: Button
var _next: Button
var _finish: Button
var _rooms: Button


func _init() -> void:
	_ensure()


func show_caught() -> void:
	_ensure()
	_caught.text = Copy.line("caught")
	_caught.visible = true
	_moves.visible = false
	_par.visible = false
	_par_met.visible = false
	_bonus.visible = false
	_show_actions(true, true, false, false)


func show_escaped(moves: int, par: int, par_met: bool, bonus_present: bool, bonus_found: bool, is_vault: bool) -> void:
	_ensure()
	_caught.visible = false
	_moves.text = Copy.line("moves", {"n": moves})
	_moves.visible = true
	_par.text = Copy.line("par", {"par": par})
	_par.visible = true
	_par_met.text = Copy.line("par_met")
	_par_met.visible = par_met
	_bonus.text = Copy.line("bonus_found")
	_bonus.visible = bonus_present and bonus_found
	_show_actions(true, true, not is_vault, is_vault)


func _ensure() -> void:
	if _built:
		return
	_built = true
	Style.mount(self)
	var column := Style.column(self)
	_caught = Style.make_label("CaughtLabel", false)
	_caught.add_theme_font_size_override("font_size", 28)
	_moves = Style.make_label("MovesLabel", false)
	_par = Style.make_label("ParLabel", true)
	_par_met = Style.make_label("ParMetLabel", false)
	_bonus = Style.make_label("BonusLabel", false)
	for label in [_caught, _moves, _par, _par_met, _bonus]:
		label.visible = false
		column.add_child(label)
	column.add_child(Style.spacer())
	_retry = _add_action(column, "RetryButton", "Retry", retry_pressed)
	_rooms = _add_action(column, "RoomsButton", "Rooms", rooms_pressed)
	_next = _add_action(column, "NextButton", "Next", next_pressed)
	_finish = _add_action(column, "FinishButton", "Finish", finish_pressed)
	_show_actions(false, false, false, false)


func _add_action(column: VBoxContainer, node_name: String, text: String, pressed_signal: Signal) -> Button:
	var button := Style.make_button(text)
	button.name = node_name
	button.pressed.connect(pressed_signal.emit)
	column.add_child(button)
	return button


func _show_actions(retry: bool, rooms: bool, next: bool, finish: bool) -> void:
	_retry.visible = retry
	_retry.disabled = false
	_rooms.visible = rooms
	_rooms.disabled = false
	_next.visible = next
	_next.disabled = false
	_finish.visible = finish
	_finish.disabled = false
