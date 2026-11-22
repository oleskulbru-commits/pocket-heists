class_name HeistSession
extends RefCounted
## Visit state for one job. Progress and settings live in a version-1 save.
## A drawing or a running route is never written. Catch counts stay in memory.


const ROOM_IDS: Array[String] = ["01", "02", "03", "04", "05", "06"]

const PARS := {
	"01": 10,
	"02": 12,
	"03": 16,
	"04": 14,
	"05": 12,
	"06": 13,
}

const NAMES := {
	"01": "Service Entrance",
	"02": "Dispatch Office",
	"03": "Packing Floor",
	"04": "Cold Storage",
	"05": "Security Annex",
	"06": "Bonded Vault",
}

const SAVE_VERSION := 1
const PERSIST_DEVICE := "device"
const PERSIST_SESSION := "session"

const ROOMS := "rooms"
const PLANNING := "planning"
const DRAWING := "drawing"
const RUNNING := "running"
const PAUSED := "paused"
const CAUGHT := "caught"
const ESCAPED := "escaped"
const JOB_COMPLETE := "job_complete"

var state: String = ""
var room_id: String = ""
var persistence: String = PERSIST_DEVICE
var return_state: String = ""
var beat_fraction: float = 0.0
var draft: Dictionary = {}
var run_id: int = 0
var settings: Dictionary = {}
var rooms: Dictionary = {}
var catch_counts: Dictionary = {}

var _storage = null
var _log = null
var _cleared_run_id: int = -1


func _init(storage = null, log = null) -> void:
	_storage = storage
	_log = log
	_apply_defaults()


func boot() -> void:
	_apply_defaults()
	run_id = 0
	_cleared_run_id = -1
	catch_counts = {}
	draft = {}
	beat_fraction = 0.0
	return_state = ""
	persistence = PERSIST_DEVICE
	room_id = ""
	state = ""
	if _storage != null:
		var raw = _storage.load_text()
		if typeof(raw) == TYPE_STRING:
			_load(raw)
	var cleared := _cleared_count()
	if cleared <= 0:
		_enter_room("01", true, true, false)
	elif cleared >= ROOM_IDS.size():
		state = JOB_COMPLETE
		room_id = ""
	else:
		state = ROOMS
		room_id = ""


func begin_draw() -> void:
	if state != PLANNING:
		return
	draft = {}
	state = DRAWING


func cancel_draw() -> void:
	if state != DRAWING:
		return
	draft = {}
	state = PLANNING


func commit(next_draft: Dictionary) -> void:
	if state != DRAWING:
		return
	if next_draft.get("valid", false) != true:
		return
	draft = next_draft.duplicate(true)
	run_id += 1
	beat_fraction = 0.0
	state = RUNNING
	_event("attempt", {"room": room_id, "moves": int(next_draft.get("moves", 0))})


## From drawing, the draft is dropped and resume returns to planning.
## From running, pass the clock fraction to keep it across resume.
func pause(fraction: float = -1.0) -> void:
	if state == DRAWING:
		draft = {}
		return_state = PLANNING
		beat_fraction = 0.0
		state = PAUSED
	elif state == PLANNING or state == RUNNING:
		if state == RUNNING and fraction >= 0.0:
			beat_fraction = fraction
		return_state = state
		state = PAUSED


func resume() -> void:
	if state != PAUSED or return_state == "":
		return
	state = return_state


func retry() -> void:
	if state != CAUGHT and state != ESCAPED:
		return
	draft = {}
	beat_fraction = 0.0
	return_state = ""
	state = PLANNING


func restart_room() -> void:
	if state != PLANNING and state != PAUSED and state != CAUGHT and state != ESCAPED:
		return
	if room_id == "":
		return
	_enter_room(room_id, true, true, false)


func open_rooms() -> void:
	if state != PLANNING and state != PAUSED and state != CAUGHT and state != ESCAPED and state != JOB_COMPLETE:
		return
	if room_id != "":
		catch_counts[room_id] = 0
	draft = {}
	beat_fraction = 0.0
	return_state = ""
	room_id = ""
	state = ROOMS


func select_room(id: String) -> void:
	if state != ROOMS:
		return
	if not ROOM_IDS.has(id) or not is_unlocked(id):
		return
	var replay := bool(rooms[id]["cleared"])
	_enter_room(id, true, true, replay)


func next_room() -> void:
	if state != ESCAPED:
		return
	var idx := ROOM_IDS.find(room_id)
	if idx < 0 or idx >= ROOM_IDS.size() - 1:
		return
	var previous := room_id
	catch_counts[previous] = 0
	_enter_room(ROOM_IDS[idx + 1], true, true, false)


func finish() -> void:
	if state != ESCAPED or room_id != "06":
		return
	draft = {}
	beat_fraction = 0.0
	state = JOB_COMPLETE


func replay_vault() -> void:
	if state != JOB_COMPLETE:
		return
	_enter_room("06", true, true, true)


func on_caught(beat: int, guard_id: String) -> void:
	if state != RUNNING:
		return
	state = CAUGHT
	beat_fraction = 0.0
	if room_id != "":
		catch_counts[room_id] = int(catch_counts.get(room_id, 0)) + 1
	# A catch never writes and never banks a bonus.
	_event("catch", {"room": room_id, "beat": int(beat), "guard": guard_id})


func on_cleared(moves: int, collected_bonus: bool) -> void:
	if state != RUNNING or not rooms.has(room_id):
		return
	# A second result for this commit must not write or change the record.
	if _cleared_run_id == run_id:
		return
	_cleared_run_id = run_id
	state = ESCAPED
	var entry: Dictionary = rooms[room_id].duplicate()
	entry["cleared"] = true
	var stored = entry["best_moves"]
	if stored == null or int(moves) < int(stored):
		entry["best_moves"] = int(moves)
	if collected_bonus:
		entry["bonus"] = true
	rooms[room_id] = entry
	_event("clear", {
		"room": room_id,
		"moves": int(moves),
		"bonus": collected_bonus,
	})
	_write()


func set_sound(on: bool) -> void:
	settings["sound"] = on
	_write()


func set_reduced_motion(on: bool) -> void:
	settings["reduced_motion"] = on
	_write()


func set_tap_route(on: bool) -> void:
	settings["tap_route"] = on
	_write()


func note_bonus_intro() -> void:
	settings["bonus_intro_shown"] = true
	_write()


func note_first_commit() -> void:
	settings["first_commit_done"] = true
	_write()


func is_unlocked(id: String) -> bool:
	var idx := ROOM_IDS.find(id)
	if idx < 0:
		return false
	if idx == 0:
		return true
	return bool(rooms[ROOM_IDS[idx - 1]]["cleared"])


func highlighted_room() -> String:
	var cleared := _cleared_count()
	if cleared <= 0 or cleared >= ROOM_IDS.size():
		return ""
	for id in ROOM_IDS:
		if not bool(rooms[id]["cleared"]):
			return id
	return ""


func catch_count(id: String = "") -> int:
	var key := room_id if id == "" else id
	return int(catch_counts.get(key, 0))


func rooms_cleared() -> int:
	return _cleared_count()


func valuables_banked() -> int:
	var total := 0
	for id in ["03", "04", "05", "06"]:
		if bool(rooms[id]["bonus"]):
			total += 1
	return total


func room_entries() -> Array:
	var highlight := highlighted_room()
	var entries: Array = []
	for id in ROOM_IDS:
		var record: Dictionary = rooms[id]
		var best = record["best_moves"]
		var cleared := bool(record["cleared"])
		var par := int(PARS[id])
		var par_met := cleared and best != null and int(best) <= par
		entries.append({
			"id": id,
			"name": String(NAMES[id]),
			"locked": not is_unlocked(id),
			"cleared": cleared,
			"best_moves": best,
			"par": par,
			"par_met": par_met,
			"bonus": bool(record["bonus"]),
			"highlight": highlight != "" and id == highlight,
		})
	return entries


func _enter_room(id: String, zero_catch: bool, log_start: bool, log_replay: bool) -> void:
	room_id = id
	state = PLANNING
	draft = {}
	beat_fraction = 0.0
	return_state = ""
	if zero_catch:
		catch_counts[id] = 0
	if log_start:
		_event("room_start", {"room": id})
	if log_replay:
		_event("replay", {"room": id})


func _event(event_name: String, fields: Dictionary) -> void:
	if _log == null or not _log.has_method("record"):
		return
	_log.record(event_name, fields)


func _write() -> void:
	if _storage == null or not _storage.has_method("store_text"):
		persistence = PERSIST_SESSION
		return
	var ok = _storage.store_text(_encode())
	if ok != true:
		persistence = PERSIST_SESSION
	else:
		persistence = PERSIST_DEVICE


func _encode() -> String:
	var room_out := {}
	for id in ROOM_IDS:
		var record: Dictionary = rooms[id]
		room_out[id] = {
			"cleared": bool(record["cleared"]),
			"best_moves": record["best_moves"],
			"bonus": bool(record["bonus"]),
		}
	var payload := {
		"version": SAVE_VERSION,
		"settings": {
			"sound": bool(settings["sound"]),
			"reduced_motion": bool(settings["reduced_motion"]),
			"tap_route": bool(settings["tap_route"]),
			"bonus_intro_shown": bool(settings["bonus_intro_shown"]),
			"first_commit_done": bool(settings["first_commit_done"]),
		},
		"rooms": room_out,
	}
	var body := JSON.stringify(payload)
	if not body.ends_with("\n"):
		body += "\n"
	return body


func _load(text: String) -> void:
	if text.strip_edges() == "":
		return
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return
	var parsed = parser.data
	if not _save_ok(parsed):
		return
	var next_settings := _settings_from(parsed["settings"])
	var next_rooms := _rooms_from(parsed["rooms"])
	if next_settings.is_empty() or next_rooms.is_empty():
		return
	settings = next_settings
	rooms = next_rooms


func _save_ok(parsed) -> bool:
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	if not parsed.has("version"):
		return false
	var version = parsed["version"]
	var kind := typeof(version)
	if kind != TYPE_INT and kind != TYPE_FLOAT:
		return false
	if version != SAVE_VERSION:
		return false
	if typeof(parsed.get("settings")) != TYPE_DICTIONARY:
		return false
	if typeof(parsed.get("rooms")) != TYPE_DICTIONARY:
		return false
	return true


func _settings_from(raw: Dictionary) -> Dictionary:
	var next := _default_settings()
	for key in next.keys():
		if not raw.has(key):
			continue
		if typeof(raw[key]) != TYPE_BOOL:
			return {}
		next[key] = raw[key]
	return next


func _rooms_from(raw: Dictionary) -> Dictionary:
	var next := _default_rooms()
	for id in ROOM_IDS:
		if not raw.has(id):
			continue
		if typeof(raw[id]) != TYPE_DICTIONARY:
			return {}
		var built := _room_from(raw[id])
		if built.is_empty():
			return {}
		next[id] = built
	return next


func _room_from(entry: Dictionary) -> Dictionary:
	if entry.has("cleared") and typeof(entry["cleared"]) != TYPE_BOOL:
		return {}
	if entry.has("bonus") and typeof(entry["bonus"]) != TYPE_BOOL:
		return {}
	var best = null
	if entry.has("best_moves") and entry["best_moves"] != null:
		var raw_best = entry["best_moves"]
		var kind := typeof(raw_best)
		if kind != TYPE_INT and kind != TYPE_FLOAT:
			return {}
		if kind == TYPE_FLOAT and raw_best != floor(raw_best):
			return {}
		best = int(raw_best)
	var cleared := false
	if entry.has("cleared"):
		cleared = entry["cleared"]
	var bonus := false
	if entry.has("bonus"):
		bonus = entry["bonus"]
	return {"cleared": cleared, "best_moves": best, "bonus": bonus}


func _apply_defaults() -> void:
	settings = _default_settings()
	rooms = _default_rooms()


func _default_settings() -> Dictionary:
	return {
		"sound": true,
		"reduced_motion": false,
		"tap_route": false,
		"bonus_intro_shown": false,
		"first_commit_done": false,
	}


func _default_rooms() -> Dictionary:
	var out := {}
	for id in ROOM_IDS:
		out[id] = {"cleared": false, "best_moves": null, "bonus": false}
	return out


func _cleared_count() -> int:
	var total := 0
	for id in ROOM_IDS:
		if bool(rooms[id]["cleared"]):
			total += 1
	return total
