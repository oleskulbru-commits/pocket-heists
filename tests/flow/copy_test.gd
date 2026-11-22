extends "res://tests/test_suite.gd"

const Copy := preload("res://scripts/ui/copy.gd")


func suite_name() -> String:
	return "copy"


func run(check) -> void:
	check.eq(Copy.line("first_load"), "Drag from the thief through the seal to the exit.")
	check.eq(Copy.line("objective", {"target_name": "brass access seal"}), "Take the brass access seal")
	check.eq(Copy.line("objective", {"target_name": "dispatch ledger"}), "Take the dispatch ledger")
	check.eq(Copy.line("objective", {"target_name": "customs stamp"}), "Take the customs stamp")
	check.eq(Copy.line("objective", {"target_name": "sealed specimen"}), "Take the sealed specimen")
	check.eq(Copy.line("objective", {"target_name": "blackbox recorder"}), "Take the blackbox recorder")
	check.eq(Copy.line("objective", {"target_name": "prototype core"}), "Take the prototype core")
	check.eq(Copy.line("objective_exit"), "Get to the exit")
	check.eq(Copy.line("guards_teach"), "Guards move when you do. Walls block their view.")
	check.eq(Copy.line("bonus_teach"), "A bonus is optional. Reach the exit to keep it.")
	check.eq(Copy.line("start_at_thief"), "Start at the thief.")
	check.eq(Copy.line("through_target"), "Go through the target first")
	check.eq(Copy.line("end_at_exit"), "End at the exit")
	check.eq(Copy.line("blocked"), "Route is blocked")
	check.eq(Copy.line("step_limit"), "48-step limit")
	check.eq(Copy.line("lift_to_run"), "Lift to run")
	check.eq(Copy.line("on_the_move"), "On the move")
	check.eq(Copy.line("steps", {"n": 1}), "1 step")
	check.eq(Copy.line("steps", {"n": 10}), "10 steps")
	check.eq(Copy.line("steps", {"n": 0}), "0 steps")
	check.eq(Copy.line("caught"), "Caught")
	check.eq(Copy.line("par_met"), "Par met")
	check.eq(Copy.line("bonus_found"), "Bonus found")
	check.eq(Copy.line("moves", {"n": 12}), "12 moves")
	check.eq(Copy.line("moves", {"n": 1}), "1 moves")
	check.eq(Copy.line("par", {"par": 10}), "Par 10")
	check.eq(Copy.line("job_complete"), "Job complete")
	check.eq(Copy.line("rooms_cleared", {"n": 6}), "6 rooms cleared")
	check.eq(Copy.line("rooms_cleared", {"n": 1}), "1 rooms cleared")
	check.eq(Copy.line("valuables", {"n": 2}), "Valuables banked: 2 of 4")
	check.eq(Copy.line("persist_warn"), "Progress is saved for this visit only.")
	check.eq(Copy.line("rotate"), "Rotate to portrait")
	check.eq(Copy.line("room_title", {"id": "01", "name": "Service Entrance"}), "01 SERVICE ENTRANCE")
	check.eq(Copy.line("room_title", {"id": "06", "name": "Bonded Vault"}), "06 BONDED VAULT")
	check.eq(
		Copy.line("hint", {"hint": "Pass through the seal before heading to the exit."}),
		"Pass through the seal before heading to the exit."
	)
	check.eq(
		Copy.line("hint", {"hint": "Take a short detour before you head up the left corridor."}),
		"Take a short detour before you head up the left corridor."
	)
	check.eq(Copy.line("title_screen"), "")
	check.eq(Copy.line("settings"), "")
