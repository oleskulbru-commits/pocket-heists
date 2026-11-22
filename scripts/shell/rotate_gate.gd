class_name RotateGate
extends Control

const MESSAGE := "Rotate to portrait"
const BACKDROP := Color("#12181D")
const INK := Color("#F2EEE3")

var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = BACKDROP
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_label = Label.new()
	_label.name = "Message"
	_label.text = MESSAGE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_color_override("font_color", INK)
	_label.add_theme_font_size_override("font_size", 32)
	add_child(_label)
	visible = false


func apply(layout: Dictionary) -> void:
	visible = bool(layout.get("rotate", false))
