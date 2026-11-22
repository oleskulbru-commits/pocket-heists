extends "res://tests/test_suite.gd"

const Style := preload("res://scripts/ui/style.gd")

const INK := Color("#F2EEE3")
const MUTED := Color("#A5B1B7")
const BACKDROP := Color("#12181D")


func suite_name() -> String:
	return "flow"


func run(check) -> void:
	_assert_sources(check)
	_assert_pause(check)
	_assert_rooms(check)
	_assert_result(check)
	_assert_job(check)


func _assert_sources(check) -> void:
	var paths := [
		"res://scripts/ui/copy.gd",
		"res://scripts/ui/style.gd",
		"res://scripts/flow/pause.gd",
		"res://scripts/flow/rooms.gd",
		"res://scripts/flow/result.gd",
		"res://scripts/flow/job.gd",
		"res://scenes/flow/pause.tscn",
		"res://scenes/flow/rooms.tscn",
		"res://scenes/flow/result.tscn",
		"res://scenes/flow/job.tscn",
	]
	for path in paths:
		var text := FileAccess.get_file_as_string(path)
		if text.find("HeistSession") != -1:
			check.fail("%s preloads or names HeistSession" % path)


func _assert_pause(check) -> void:
	var screen := _open("res://scenes/flow/pause.tscn")
	_assert_backdrop(check, screen)
	var names := [
		"ResumeButton",
		"RestartButton",
		"RoomsButton",
		"SoundToggle",
		"ReducedMotionToggle",
		"TapRouteToggle",
	]
	for node_name in names:
		var button := _button(screen, node_name)
		check.is_true(button != null)
		check.is_true(button.visible)
		_assert_button_size(check, button)
		_assert_body_font(check, button)
		check.eq(button.get_theme_color("font_color"), INK)
	check.eq(_button(screen, "ResumeButton").text, "Resume")
	check.eq(_button(screen, "RestartButton").text, "Restart room")
	check.eq(_button(screen, "RoomsButton").text, "Rooms")
	check.is_true(_button(screen, "SoundToggle").button_pressed)
	check.is_true(not _button(screen, "ReducedMotionToggle").button_pressed)
	check.is_true(not _button(screen, "TapRouteToggle").button_pressed)
	_assert_press(check, screen, "ResumeButton", "resume_pressed")
	_assert_press(check, screen, "RestartButton", "restart_pressed")
	_assert_press(check, screen, "RoomsButton", "rooms_pressed")
	_round_trip(check, screen, "set_sound", "sound_toggled", "SoundToggle")
	_round_trip(check, screen, "set_reduced_motion", "reduced_motion_toggled", "ReducedMotionToggle")
	_round_trip(check, screen, "set_tap_route", "tap_route_toggled", "TapRouteToggle")
	screen.free()


func _assert_rooms(check) -> void:
	var screen := _open("res://scenes/flow/rooms.tscn")
	_assert_backdrop(check, screen)
	var entries: Array = [
		_entry("01", "Service Entrance", false, true, 10, 10, true, false, false),
		_entry("02", "Dispatch Office", false, true, 14, 12, false, false, false),
		_entry("03", "Packing Floor", false, false, null, 16, false, false, true),
		_entry("04", "Cold Storage", true, false, null, 14, false, false, false),
		_entry("05", "Security Annex", true, false, null, 12, false, false, false),
		_entry("06", "Bonded Vault", true, false, null, 13, false, true, false),
	]
	screen.set_entries(entries)
	var list := screen.find_child("List", true, false) as VBoxContainer
	check.eq(list.get_child_count(), 6)
	for id in ["04", "05", "06"]:
		var row := list.get_node("Room_%s" % id) as Control
		check.is_true(row.visible)
		var select := row.find_child("Select", true, false) as BaseButton
		check.is_true(select.visible)
		check.is_true(select.disabled)
		_assert_button_size(check, select)
		var mark := row.find_child("NextMark", true, false) as Label
		check.is_true(not mark.visible)
	for id in ["01", "02", "03"]:
		var select := list.get_node("Room_%s" % id).find_child("Select", true, false) as BaseButton
		check.is_true(select.visible)
		check.is_true(not select.disabled)
		_assert_button_size(check, select)
		_assert_title_font(check, select)
	var highlighted := list.get_node("Room_03")
	var next_mark := highlighted.find_child("NextMark", true, false) as Label
	check.is_true(next_mark.visible)
	check.eq(next_mark.text, "Next")
	_assert_body_font(check, next_mark)
	check.eq(next_mark.get_theme_color("font_color"), INK)
	check.eq(highlighted.find_child("Select", true, false).text, "03 PACKING FLOOR")
	var cleared := list.get_node("Room_01")
	check.eq(cleared.find_child("MovesLabel", true, false).text, "10 moves")
	check.is_true(cleared.find_child("MovesLabel", true, false).visible)
	check.eq(cleared.find_child("ParLabel", true, false).text, "Par 10")
	check.eq(cleared.find_child("ParLabel", true, false).get_theme_color("font_color"), MUTED)
	check.is_true(cleared.find_child("ParMetLabel", true, false).visible)
	check.eq(cleared.find_child("ParMetLabel", true, false).text, "Par met")
	check.is_true(not cleared.find_child("BonusLabel", true, false).visible)
	check.is_true(not list.get_node("Room_03").find_child("MovesLabel", true, false).visible)
	check.eq(list.get_node("Room_03").find_child("ParLabel", true, false).text, "Par 16")
	var bonus_row := list.get_node("Room_06")
	check.is_true(bonus_row.find_child("BonusLabel", true, false).visible)
	check.eq(bonus_row.find_child("BonusLabel", true, false).text, "Bonus found")
	var picked: Array = []
	screen.room_selected.connect(func(id: String) -> void: picked.append(id))
	highlighted.find_child("Select", true, false).pressed.emit()
	list.get_node("Room_04").find_child("Select", true, false).pressed.emit()
	check.eq(picked.size(), 1)
	check.eq(picked[0], "03")
	_assert_buttons(check, screen)
	screen.free()


func _assert_result(check) -> void:
	var screen := _open("res://scenes/flow/result.tscn")
	_assert_backdrop(check, screen)
	screen.show_caught()
	check.eq(_label(screen, "CaughtLabel").text, "Caught")
	check.is_true(_label(screen, "CaughtLabel").visible)
	check.eq(_label(screen, "CaughtLabel").get_theme_color("font_color"), INK)
	_assert_body_font(check, _label(screen, "CaughtLabel"))
	check.is_true(_button(screen, "RetryButton").visible)
	check.is_true(not _button(screen, "RetryButton").disabled)
	check.is_true(_button(screen, "RoomsButton").visible)
	check.is_true(not _button(screen, "NextButton").visible)
	check.is_true(not _button(screen, "FinishButton").visible)
	check.is_true(not _label(screen, "MovesLabel").visible)
	check.is_true(not _label(screen, "ParLabel").visible)
	check.is_true(not _label(screen, "BonusLabel").visible)
	_assert_press(check, screen, "RetryButton", "retry_pressed")
	_assert_press(check, screen, "RoomsButton", "rooms_pressed")

	screen.show_escaped(10, 10, true, false, false, false)
	check.is_true(not _label(screen, "CaughtLabel").visible)
	check.eq(_label(screen, "MovesLabel").text, "10 moves")
	check.is_true(_label(screen, "MovesLabel").visible)
	check.eq(_label(screen, "ParLabel").text, "Par 10")
	check.is_true(_label(screen, "ParLabel").visible)
	check.eq(_label(screen, "ParLabel").get_theme_color("font_color"), MUTED)
	check.is_true(_label(screen, "ParMetLabel").visible)
	check.eq(_label(screen, "ParMetLabel").text, "Par met")
	check.is_true(not _label(screen, "BonusLabel").visible)
	check.is_true(_button(screen, "NextButton").visible)
	check.is_true(_button(screen, "RetryButton").visible)
	check.is_true(_button(screen, "RoomsButton").visible)
	check.is_true(not _button(screen, "FinishButton").visible)
	_assert_press(check, screen, "NextButton", "next_pressed")

	screen.show_escaped(20, 16, false, true, false, false)
	check.is_true(not _label(screen, "ParMetLabel").visible)
	check.is_true(not _label(screen, "BonusLabel").visible)
	check.eq(_label(screen, "MovesLabel").text, "20 moves")
	check.eq(_label(screen, "ParLabel").text, "Par 16")
	check.is_true(_button(screen, "NextButton").visible)
	check.is_true(not _button(screen, "FinishButton").visible)

	screen.show_escaped(22, 14, false, true, true, false)
	check.is_true(_label(screen, "BonusLabel").visible)
	check.eq(_label(screen, "BonusLabel").text, "Bonus found")
	check.is_true(_button(screen, "NextButton").visible)

	screen.show_escaped(13, 13, true, true, false, true)
	check.is_true(_button(screen, "FinishButton").visible)
	check.is_true(not _button(screen, "NextButton").visible)
	check.is_true(_button(screen, "RetryButton").visible)
	check.is_true(_button(screen, "RoomsButton").visible)
	check.eq(_label(screen, "MovesLabel").text, "13 moves")
	check.eq(_label(screen, "ParLabel").text, "Par 13")
	check.is_true(_label(screen, "ParMetLabel").visible)
	check.is_true(not _label(screen, "BonusLabel").visible)
	_assert_press(check, screen, "FinishButton", "finish_pressed")

	screen.show_escaped(17, 13, false, true, true, true)
	check.is_true(_button(screen, "FinishButton").visible)
	check.is_true(not _button(screen, "NextButton").visible)
	check.is_true(_label(screen, "BonusLabel").visible)
	check.eq(_label(screen, "BonusLabel").text, "Bonus found")
	check.is_true(not _label(screen, "ParMetLabel").visible)
	_assert_buttons(check, screen)
	screen.free()


func _assert_job(check) -> void:
	var screen := _open("res://scenes/flow/job.tscn")
	_assert_backdrop(check, screen)
	screen.show_result(6, 2)
	check.eq(_label(screen, "TitleLabel").text, "Job complete")
	check.eq(_label(screen, "TitleLabel").get_theme_color("font_color"), INK)
	_assert_body_font(check, _label(screen, "TitleLabel"))
	check.eq(_label(screen, "RoomsClearedLabel").text, "6 rooms cleared")
	check.eq(_label(screen, "ValuablesLabel").text, "Valuables banked: 2 of 4")
	check.eq(_label(screen, "ValuablesLabel").get_theme_color("font_color"), INK)
	check.is_true(_button(screen, "RoomsButton").visible)
	check.eq(_button(screen, "RoomsButton").text, "Rooms")
	check.is_true(_button(screen, "ReplayVaultButton").visible)
	check.eq(_button(screen, "ReplayVaultButton").text, "Replay vault")
	_assert_press(check, screen, "RoomsButton", "rooms_pressed")
	_assert_press(check, screen, "ReplayVaultButton", "replay_vault_pressed")
	_assert_buttons(check, screen)
	screen.free()


func _entry(id: String, room_name: String, locked: bool, cleared: bool, best_moves, par: int, par_met: bool, bonus: bool, highlight: bool) -> Dictionary:
	return {
		"id": id,
		"name": room_name,
		"locked": locked,
		"cleared": cleared,
		"best_moves": best_moves,
		"par": par,
		"par_met": par_met,
		"bonus": bonus,
		"highlight": highlight,
	}


func _open(path: String) -> Node:
	var packed := load(path) as PackedScene
	var node := packed.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	return node


func _button(screen: Node, node_name: String) -> BaseButton:
	return screen.find_child(node_name, true, false) as BaseButton


func _label(screen: Node, node_name: String) -> Label:
	return screen.find_child(node_name, true, false) as Label


func _assert_backdrop(check, screen: Node) -> void:
	var backdrop := screen.find_child("Backdrop", true, false) as ColorRect
	check.eq(backdrop.color, BACKDROP)


func _assert_button_size(check, button: BaseButton) -> void:
	var minimum := button.custom_minimum_size
	if minimum.x < 44.0 or minimum.y < 44.0:
		check.fail("%s custom minimum is %s" % [button.name, minimum])
	var combined := button.get_combined_minimum_size()
	if combined.x < 44.0 or combined.y < 44.0:
		check.fail("%s combined minimum is %s" % [button.name, combined])


func _assert_buttons(check, node: Node) -> void:
	if node is BaseButton:
		_assert_button_size(check, node)
	for child in node.get_children():
		_assert_buttons(check, child)


func _assert_body_font(check, control: Control) -> void:
	check.eq(control.get_theme_font("font"), Style.body_font())


func _assert_title_font(check, control: Control) -> void:
	check.eq(control.get_theme_font("font"), Style.title_font())


func _assert_press(check, screen: Node, node_name: String, signal_name: String) -> void:
	var hits: Array = []
	screen.connect(signal_name, func() -> void: hits.append(true))
	_button(screen, node_name).pressed.emit()
	check.eq(hits.size(), 1)


func _round_trip(check, screen: Node, setter: String, signal_name: String, node_name: String) -> void:
	var toggle := _button(screen, node_name)
	screen.call(setter, true)
	check.is_true(toggle.button_pressed)
	screen.call(setter, false)
	check.is_true(not toggle.button_pressed)
	var got: Array = []
	screen.connect(signal_name, func(on: bool) -> void: got.append(on))
	toggle.set_pressed(true)
	toggle.set_pressed(false)
	check.eq(got.size(), 2)
	check.eq(got[0], true)
	check.eq(got[1], false)
