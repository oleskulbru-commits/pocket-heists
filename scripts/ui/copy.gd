class_name HeistCopy
extends RefCounted

## Sentences from the specification. Placeholders use these arg keys:
## target_name, n, par, id, name, hint.

static func line(id: String, args: Dictionary = {}) -> String:
	match id:
		"first_load":
			return "Drag from the thief through the seal to the exit."
		"objective":
			return "Take the %s" % str(args.get("target_name", ""))
		"objective_exit":
			return "Get to the exit"
		"guards_teach":
			return "Guards move when you do. Walls block their view."
		"bonus_teach":
			return "A bonus is optional. Reach the exit to keep it."
		"start_at_thief":
			return "Start at the thief."
		"through_target":
			return "Go through the target first"
		"end_at_exit":
			return "End at the exit"
		"blocked":
			return "Route is blocked"
		"step_limit":
			return "48-step limit"
		"lift_to_run":
			return "Lift to run"
		"on_the_move":
			return "On the move"
		"steps":
			var count := int(args.get("n", 0))
			if count == 1:
				return "1 step"
			return "%d steps" % count
		"caught":
			return "Caught"
		"par_met":
			return "Par met"
		"bonus_found":
			return "Bonus found"
		"moves":
			return "%d moves" % int(args.get("n", 0))
		"par":
			return "Par %d" % int(args.get("par", 0))
		"job_complete":
			return "Job complete"
		"rooms_cleared":
			return "%d rooms cleared" % int(args.get("n", 0))
		"valuables":
			return "Valuables banked: %d of 4" % int(args.get("n", 0))
		"persist_warn":
			return "Progress is saved for this visit only."
		"rotate":
			return "Rotate to portrait"
		"room_title":
			var room_id := str(args.get("id", ""))
			var room_name := str(args.get("name", "")).to_upper()
			return "%s %s" % [room_id, room_name]
		"hint":
			return str(args.get("hint", ""))
		_:
			return ""
