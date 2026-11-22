class_name PauseScreen
extends Control

signal resume_pressed
signal restart_pressed
signal rooms_pressed
signal sound_toggled(on: bool)
signal reduced_motion_toggled(on: bool)
signal tap_route_toggled(on: bool)

const Style := preload("res://scripts/ui/style.gd")

var _built := false
var _sound: CheckButton
var _reduced_motion: CheckButton
var _tap_route: CheckButton


func _init() -> void:
	_ensure()


func set_sound(on: bool) -> void:
	_ensure()
	_sound.set_pressed_no_signal(on)


func set_reduced_motion(on: bool) -> void:
	_ensure()
	_reduced_motion.set_pressed_no_signal(on)


func set_tap_route(on: bool) -> void:
	_ensure()
	_tap_route.set_pressed_no_signal(on)


func _ensure() -> void:
	if _built:
		return
	_built = true
	Style.mount(self)
	var column := Style.column(self)
	_add_action(column, "ResumeButton", "Resume", resume_pressed)
	_add_action(column, "RestartButton", "Restart room", restart_pressed)
	_add_action(column, "RoomsButton", "Rooms", rooms_pressed)
	_sound = _add_toggle(column, "SoundToggle", "Sound", sound_toggled)
	_reduced_motion = _add_toggle(column, "ReducedMotionToggle", "Reduced motion", reduced_motion_toggled)
	_tap_route = _add_toggle(column, "TapRouteToggle", "Tap route", tap_route_toggled)
	# Visit defaults: sound on, reduced motion off, tap route off.
	set_sound(true)
	set_reduced_motion(false)
	set_tap_route(false)


func _add_action(column: VBoxContainer, node_name: String, text: String, pressed_signal: Signal) -> void:
	var button := Style.make_button(text)
	button.name = node_name
	button.pressed.connect(pressed_signal.emit)
	column.add_child(button)


func _add_toggle(column: VBoxContainer, node_name: String, text: String, toggled_signal: Signal) -> CheckButton:
	var button := Style.make_check(text)
	button.name = node_name
	button.toggled.connect(toggled_signal.emit)
	column.add_child(button)
	return button
