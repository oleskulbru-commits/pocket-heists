extends "res://tests/test_suite.gd"

const SessionScript = preload("res://scripts/session/heist_session.gd")
const MemoryScript = preload("res://scripts/session/memory_storage.gd")
const LogScript = preload("res://scripts/session/event_log.gd")
const UserScript = preload("res://scripts/session/user_storage.gd")

const ROOM_IDS := ["01", "02", "03", "04", "05", "06"]
const NAMES := {
	"01": "Service Entrance",
	"02": "Dispatch Office",
	"03": "Packing Floor",
	"04": "Cold Storage",
	"05": "Security Annex",
	"06": "Bonded Vault",
}
const PARS := {"01": 10, "02": 12, "03": 16, "04": 14, "05": 12, "06": 13}
const ACCOUNT_NEEDLES := ["account", "email", "user", "password", "token", "player", "auth", "uid"]


func suite_name() -> String:
	return "session"


func run(check) -> void:
	_boot_empty(check)
	_clear_best_and_unlock(check)
	_bonus_sticks(check)
	_catch_is_memory_only(check)
	_room_six_and_job(check)
	_boot_all_cleared(check)
	_boot_highlights_next(check)
	_corrupt_and_wrong_version(check)
	_failed_write_keeps_playing(check)
	_one_write_per_run(check)
	_pause_and_resume(check)
	_half_run_is_not_restored(check)
	_settings_round_trip(check)
	_event_log(check)
	_query_flag(check)
	_ignored_and_cancel(check)
	_sources_stay_local(check)
	_no_user_files(check)


func _boot_empty(check) -> void:
	print("session: boot empty")
	var session = _open(_memory())
	_eq(check, session.state, "planning", "empty boot state")
	_eq(check, session.room_id, "01", "empty boot room")
	_eq(check, session.persistence, "device", "empty boot persistence")
	_eq(check, session.settings["sound"], true, "sound defaults on")
	_eq(check, session.settings["reduced_motion"], false, "reduced motion defaults off")
	_eq(check, session.settings["tap_route"], false, "tap route defaults off")
	_eq(check, session.settings["bonus_intro_shown"], false, "bonus intro defaults off")
	_eq(check, session.settings["first_commit_done"], false, "first commit defaults off")
	_eq(check, session.rooms_cleared(), 0, "nothing cleared")
	_eq(check, session.highlighted_room(), "", "no highlight before a clear")
	_eq(check, session.catch_count(), 0, "catch count starts at zero")
	var entries: Array = session.room_entries()
	_eq(check, entries.size(), 6, "six room entries")
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var id := str(entry["id"])
		_eq(check, id, ROOM_IDS[index], "entry order")
		_eq(check, entry["name"], NAMES[id], "room name")
		_eq(check, entry["par"], PARS[id], "room par")
		_eq(check, entry["locked"], id != "01", "lock before any clear")
		_eq(check, entry["cleared"], false, "uncleared")
		_eq(check, entry["best_moves"], null, "no best yet")
		_eq(check, entry["bonus"], false, "no bonus yet")
		_eq(check, entry["par_met"], false, "par not met")
		_eq(check, entry["highlight"], false, "no highlight yet")


func _clear_best_and_unlock(check) -> void:
	print("session: clear, best moves, unlock")
	var storage = _memory()
	var session = _open(storage)
	_clear(session, 10, false)
	_eq(check, storage.writes, 1, "first clear writes once")
	_eq(check, session.state, "escaped", "clear ends escaped")
	_eq(check, session.room_id, "01", "still room 01")
	_eq(check, session.rooms["01"]["best_moves"], 10, "best is 10")
	_eq(check, typeof(session.rooms["01"]["best_moves"]), TYPE_INT, "best is an int")
	_eq(check, session.rooms["01"]["cleared"], true, "01 cleared")
	_eq(check, session.rooms["01"]["bonus"], false, "01 has no bonus")
	_true(check, session.is_unlocked("02"), "02 unlocks")
	_true(check, not session.is_unlocked("03"), "03 stays locked")
	_true(check, not session.is_unlocked("04"), "04 stays locked")
	_true(check, not session.is_unlocked("06"), "06 stays locked")
	_eq(check, session.highlighted_room(), "02", "highlight moves to 02")
	var first: Dictionary = _entry(session, "01")
	_eq(check, first["par_met"], true, "par met at 10")
	_eq(check, _entry(session, "02")["highlight"], true, "02 row is next")
	_eq(check, _entry(session, "03")["locked"], true, "03 row locked")
	var parsed = _assert_save_document(check, storage.text, "first clear")
	if parsed != null:
		_eq(check, parsed["rooms"]["01"]["best_moves"], 10, "file stores 10")
		_eq(check, parsed["rooms"]["02"]["best_moves"], null, "file keeps 02 empty")
		_eq(check, parsed["rooms"]["03"]["cleared"], false, "file keeps 03 locked data")
	for word in ["running", "drawing", "paused", "catch", "account", "email"]:
		_true(check, not storage.text.contains(word), "save omits %s" % word)

	session.retry()
	_clear(session, 12, false)
	_eq(check, session.rooms["01"]["best_moves"], 10, "worse clear keeps 10")
	_eq(check, storage.writes, 2, "a new run still saves")
	_eq(check, _entry(session, "01")["par_met"], true, "par stays met")

	session.retry()
	_clear(session, 9, false)
	_eq(check, session.rooms["01"]["best_moves"], 9, "shorter clear replaces best")
	_eq(check, storage.writes, 3, "shorter clear writes")
	session.next_room()
	_eq(check, session.state, "planning", "next room plans")
	_eq(check, session.room_id, "02", "next room is 02")
	_true(check, not session.is_unlocked("03"), "03 still locked")
	_clear(session, 20, false)
	_eq(check, session.rooms["02"]["best_moves"], 20, "02 stores its own best")
	_eq(check, _entry(session, "02")["par_met"], false, "20 misses par 12")
	_eq(check, session.rooms["01"]["best_moves"], 9, "01 best unchanged")


func _bonus_sticks(check) -> void:
	print("session: bonus sticks")
	var storage = _memory()
	var log_storage = _memory()
	var log = LogScript.new(log_storage)
	log.set_enabled(true)
	var session = _open(storage, log)
	_advance_to(session, "03")
	_eq(check, session.room_id, "03", "arrived at 03")
	_eq(check, session.state, "planning", "03 starts in planning")
	_true(check, session.is_unlocked("03"), "03 is unlocked")
	_true(check, not session.is_unlocked("04"), "04 locked before 03")
	_clear(session, 16, true)
	_eq(check, session.rooms["03"]["bonus"], true, "bonus banks")
	_eq(check, session.rooms["03"]["best_moves"], 16, "bonus clear stores 16")
	_eq(check, session.valuables_banked(), 1, "one valuable")
	_eq(check, _entry(session, "03")["par_met"], true, "16 meets par")
	_true(check, _has_clear(log_storage.text, "03", 16, true), "clear event records the bonus")
	var writes_after_bonus: int = storage.writes
	session.retry()
	_clear(session, 20, false)
	_eq(check, session.rooms["03"]["bonus"], true, "later clear keeps the bonus")
	_eq(check, session.rooms["03"]["best_moves"], 16, "later clear keeps the shorter best")
	_eq(check, session.valuables_banked(), 1, "valuable stays banked")
	_true(check, _has_clear(log_storage.text, "03", 20, false), "later clear records bonus false")
	var writes_before_catch: int = storage.writes
	var text_before_catch: String = storage.text
	session.retry()
	session.begin_draw()
	session.commit(_draft(18))
	session.on_caught(7, "A")
	_eq(check, session.state, "caught", "catch after a banked bonus")
	_eq(check, storage.writes, writes_before_catch, "catch does not write")
	_eq(check, storage.text, text_before_catch, "catch does not change the file")
	_eq(check, session.rooms["03"]["bonus"], true, "catch does not remove a bonus")
	_eq(check, session.rooms["03"]["cleared"], true, "catch does not uncleared the room")
	_eq(check, session.catch_count(), 1, "catch increments memory")
	_eq(check, session.valuables_banked(), 1, "valuable unchanged by a catch")
	_true(check, writes_after_bonus > 0, "bonus clear did write")


func _catch_is_memory_only(check) -> void:
	print("session: catch memory")
	var storage = _memory()
	var session = _open(storage)
	session.begin_draw()
	session.commit(_draft(8))
	session.on_caught(8, "A")
	_eq(check, storage.writes, 0, "catch writes nothing")
	_eq(check, storage.text, "", "catch leaves the file empty")
	_eq(check, session.state, "caught", "catch state")
	_eq(check, session.catch_count(), 1, "memory counter is 1")
	_eq(check, session.catch_count("01"), 1, "counter is for room 01")
	_eq(check, session.catch_count("02"), 0, "other rooms stay at zero")
	_eq(check, session.rooms["01"]["cleared"], false, "catch does not clear")
	_eq(check, session.rooms["01"]["bonus"], false, "catch does not bank a bonus")
	_eq(check, session.rooms["01"]["best_moves"], null, "catch does not set best")
	session.retry()
	_eq(check, session.state, "planning", "retry returns to planning")
	_eq(check, session.catch_count(), 1, "retry keeps the counter")
	_eq(check, session.room_id, "01", "retry stays in the room")
	session.restart_room()
	_eq(check, session.state, "planning", "restart returns to planning")
	_eq(check, session.catch_count(), 0, "restart zeroes the counter")
	session.boot()
	_eq(check, session.catch_count(), 0, "a new boot does not restore catches")
	_eq(check, session.state, "planning", "reboot of an empty file plans 01")


func _room_six_and_job(check) -> void:
	print("session: room 06, finish, job")
	var storage = _memory()
	var session = _open(storage)
	_advance_to(session, "06")
	_eq(check, session.state, "planning", "06 opens in planning")
	_eq(check, session.room_id, "06", "arrived at 06")
	_eq(check, session.rooms_cleared(), 5, "five rooms cleared before the vault")
	_clear(session, 10, false)
	_eq(check, session.state, "escaped", "vault clear stays on the escape screen")
	_eq(check, session.room_id, "06", "vault clear stays in 06")
	_eq(check, storage.writes, 6, "each clear writes once")
	var early = _open(storage)
	_eq(check, early.state, "job_complete", "reload of six clears is job complete")
	_eq(check, early.rooms_cleared(), 6, "reload counts six")
	_eq(check, early.valuables_banked(), 0, "no bonus on this sweep")
	_eq(check, early.highlighted_room(), "", "a finished job has no next room")
	session.next_room()
	_eq(check, session.state, "escaped", "next is ignored on 06")
	session.finish()
	_eq(check, session.state, "job_complete", "finish reaches job complete")
	_eq(check, storage.writes, 6, "finish does not write again")
	session.replay_vault()
	_eq(check, session.state, "planning", "replay vault plans")
	_eq(check, session.room_id, "06", "replay vault opens 06")
	_eq(check, session.catch_count(), 0, "replay vault zeroes catches")


func _boot_all_cleared(check) -> void:
	print("session: boot all cleared")
	var storage = _memory(_save(ROOM_IDS))
	var session = _open(storage)
	_eq(check, session.state, "job_complete", "full save boots job complete")
	_eq(check, session.rooms_cleared(), 6, "full save counts six")
	_eq(check, session.room_id, "", "job complete has no active room")
	_eq(check, storage.writes, 0, "boot does not write")


func _boot_highlights_next(check) -> void:
	print("session: boot highlights 03")
	var storage = _memory(_save(["01", "02"]))
	var session = _open(storage)
	_eq(check, session.state, "rooms", "partial save opens the list")
	_eq(check, session.highlighted_room(), "03", "03 is highlighted")
	_eq(check, session.room_id, "", "the list has no active room")
	_eq(check, _entry(session, "03")["highlight"], true, "03 row is marked")
	_eq(check, _entry(session, "01")["highlight"], false, "01 is not next")
	_eq(check, _entry(session, "02")["highlight"], false, "02 is not next")
	_eq(check, _entry(session, "03")["locked"], false, "03 is unlocked")
	_eq(check, _entry(session, "04")["locked"], true, "04 is locked")
	_eq(check, _entry(session, "01")["cleared"], true, "01 restored")
	_eq(check, _entry(session, "02")["cleared"], true, "02 restored")
	_eq(check, session.rooms["01"]["best_moves"], 10, "restored best")
	_eq(check, session.rooms["03"]["best_moves"], null, "03 has no best")
	session.select_room("04")
	_eq(check, session.state, "rooms", "locked room is not selected")
	session.select_room("03")
	_eq(check, session.state, "planning", "unlocked room opens")
	_eq(check, session.room_id, "03", "selected 03")
	_eq(check, session.catch_count(), 0, "select zeroes the catch count")


func _corrupt_and_wrong_version(check) -> void:
	print("session: corrupt and version 2")
	for junk in ["{not-json", "null", "[", "{\"version\":1", "   \n  "]:
		var broken = _open(_memory(junk))
		_eq(check, broken.state, "planning", "bad file plans 01")
		_eq(check, broken.room_id, "01", "bad file room")
		_eq(check, broken.settings["sound"], true, "bad file keeps default sound")
		_eq(check, broken.rooms["01"]["cleared"], false, "bad file clears nothing")
		_eq(check, broken.rooms_cleared(), 0, "bad file has no progress")
	var partial := '{"version":1,"settings":{"sound":false},"rooms":[]}'
	var partial_session = _open(_memory(partial))
	_eq(check, partial_session.settings["sound"], true, "partial file does not apply settings")
	_eq(check, partial_session.rooms["01"]["cleared"], false, "partial file does not apply rooms")
	var newer := JSON.stringify({
		"version": 2,
		"settings": {
			"sound": false,
			"reduced_motion": true,
			"tap_route": true,
			"bonus_intro_shown": true,
			"first_commit_done": true,
		},
		"rooms": {
			"01": {"cleared": true, "best_moves": 4, "bonus": true},
		},
	})
	var session = _open(_memory(newer))
	_eq(check, session.state, "planning", "version 2 plans 01")
	_eq(check, session.room_id, "01", "version 2 room")
	_eq(check, session.settings["sound"], true, "version 2 drops settings")
	_eq(check, session.settings["reduced_motion"], false, "version 2 drops reduced motion")
	_eq(check, session.settings["tap_route"], false, "version 2 drops tap route")
	_eq(check, session.rooms["01"]["cleared"], false, "version 2 drops clears")
	_eq(check, session.rooms["01"]["best_moves"], null, "version 2 drops best")
	_eq(check, session.rooms["01"]["bonus"], false, "version 2 drops bonus")
	_eq(check, session.rooms_cleared(), 0, "version 2 has no progress")


func _failed_write_keeps_playing(check) -> void:
	print("session: refused write")
	var storage = _memory()
	var session = _open(storage)
	storage.accept_writes = false
	session.set_sound(false)
	_eq(check, session.persistence, "session", "refused write is session persistence")
	_eq(check, session.settings["sound"], false, "setting stays in memory")
	_eq(check, storage.writes, 0, "refused write is not counted")
	_eq(check, storage.text, "", "refused write leaves the file")
	session.begin_draw()
	session.commit(_draft(7))
	_eq(check, session.state, "running", "commit still runs")
	_eq(check, storage.text, "", "commit does not save a run")
	session.on_cleared(7, false)
	_eq(check, session.state, "escaped", "clear still finishes")
	_eq(check, session.rooms["01"]["best_moves"], 7, "clear stays in memory")
	_eq(check, session.persistence, "session", "failed clear stays session-only")
	_eq(check, storage.text, "", "failed clear does not replace the file")
	storage.accept_writes = true
	session.set_sound(true)
	_eq(check, session.persistence, "device", "a later save clears the warning")
	_eq(check, storage.writes, 1, "the recovered save writes")
	var parsed = JSON.parse_string(storage.text)
	_eq(check, parsed["settings"]["sound"], true, "recovered file has the setting")
	_eq(check, parsed["rooms"]["01"]["best_moves"], 7, "recovered file keeps the clear")


func _one_write_per_run(check) -> void:
	print("session: one write per run")
	var storage = _memory()
	var session = _open(storage)
	session.begin_draw()
	session.commit(_draft(10))
	session.on_cleared(10, false)
	session.on_cleared(8, true)
	_eq(check, storage.writes, 1, "second on_cleared does not write")
	_eq(check, session.rooms["01"]["best_moves"], 10, "second result is ignored")
	_eq(check, session.rooms["01"]["bonus"], false, "second result does not bank a bonus")
	_eq(check, session.state, "escaped", "state stays escaped")


func _pause_and_resume(check) -> void:
	print("session: pause and resume")
	var storage = _memory()
	var session = _open(storage)
	session.begin_draw()
	session.commit(_draft(6))
	session.pause(0.5)
	_eq(check, session.state, "paused", "running pause")
	_eq(check, session.return_state, "running", "running pause returns to the run")
	_eq(check, session.beat_fraction, 0.5, "pause keeps the beat fraction")
	_eq(check, storage.writes, 0, "pause does not save")
	session.resume()
	_eq(check, session.state, "running", "resume returns to running")
	_eq(check, session.beat_fraction, 0.5, "resume keeps the fraction")
	session.pause()
	_eq(check, session.state, "paused", "pause without a new fraction")
	_eq(check, session.beat_fraction, 0.5, "missing fraction keeps the old one")
	session.resume()
	_eq(check, session.state, "running", "second resume is running")

	session = _open(_memory())
	session.begin_draw()
	session.pause(0.25)
	_eq(check, session.state, "paused", "drawing pause")
	_eq(check, session.return_state, "planning", "drawing pause returns to planning")
	_eq(check, session.draft.size(), 0, "drawing pause clears the draft")
	_eq(check, session.beat_fraction, 0.0, "drawing pause drops the fraction")
	session.commit(_draft(4))
	_eq(check, session.state, "paused", "commit is ignored while paused")
	session.resume()
	_eq(check, session.state, "planning", "resume after a drawing pause")
	session.restart_room()
	_eq(check, session.state, "planning", "restart from planning")
	_eq(check, session.catch_count(), 0, "restart catch count")


func _half_run_is_not_restored(check) -> void:
	print("session: half-finished run")
	var storage = _memory()
	var session = _open(storage)
	_clear(session, 10, false)
	var saved: String = storage.text
	session.retry()
	session.begin_draw()
	session.commit(_draft(4))
	session.pause(0.5)
	_eq(check, session.state, "paused", "paused mid-run")
	_eq(check, storage.writes, 1, "the run was not saved")
	_eq(check, storage.text, saved, "pause does not touch the file")
	var reloaded = _open(storage)
	_eq(check, reloaded.state, "rooms", "reload opens the list")
	_eq(check, reloaded.highlighted_room(), "02", "reload highlights the next room")
	_eq(check, reloaded.room_id, "", "reload is not inside the run")
	_eq(check, reloaded.catch_count(), 0, "reload has no catch memory")
	_eq(check, reloaded.rooms["01"]["best_moves"], 10, "reload keeps the clear")


func _settings_round_trip(check) -> void:
	print("session: settings")
	var storage = _memory()
	var session = _open(storage)
	session.set_sound(false)
	session.set_reduced_motion(true)
	session.set_tap_route(true)
	session.note_bonus_intro()
	session.note_first_commit()
	_eq(check, storage.writes, 5, "each setting writes immediately")
	_eq(check, session.state, "planning", "settings do not leave planning")
	var parsed = _assert_save_document(check, storage.text, "settings")
	if parsed == null:
		return
	_eq(check, parsed["settings"]["sound"], false, "file sound")
	_eq(check, parsed["settings"]["reduced_motion"], true, "file reduced motion")
	_eq(check, parsed["settings"]["tap_route"], true, "file tap route")
	_eq(check, parsed["settings"]["bonus_intro_shown"], true, "file bonus intro")
	_eq(check, parsed["settings"]["first_commit_done"], true, "file first commit")
	_eq(check, parsed["rooms"]["01"]["best_moves"], null, "settings save keeps null best")
	_eq(check, parsed["rooms"]["06"]["cleared"], false, "settings save keeps 06")
	var again = _open(storage)
	_eq(check, again.state, "planning", "settings reload stays in 01")
	_eq(check, again.room_id, "01", "settings reload room")
	_eq(check, again.settings["sound"], false, "reloaded sound")
	_eq(check, again.settings["reduced_motion"], true, "reloaded reduced motion")
	_eq(check, again.settings["tap_route"], true, "reloaded tap route")
	_eq(check, again.settings["bonus_intro_shown"], true, "reloaded bonus intro")
	_eq(check, again.settings["first_commit_done"], true, "reloaded first commit")
	_eq(check, again.rooms["04"]["best_moves"], null, "reloaded best stays null")


func _event_log(check) -> void:
	print("session: event log")
	var quiet_storage = _memory()
	var quiet_log_storage = _memory()
	var quiet_log = LogScript.new(quiet_log_storage)
	var quiet = _open(quiet_storage, quiet_log)
	_exercise_log(quiet)
	_eq(check, quiet_log_storage.text, "", "log stays empty while disabled")
	_eq(check, quiet_log_storage.writes, 0, "disabled log does not write")

	var log_storage = _memory()
	var log = LogScript.new(log_storage)
	log.set_enabled(true)
	var session = _open(_memory(), log)
	_exercise_log(session)
	var events := _events(log_storage.text)
	var expected := [
		{"event": "room_start", "room": "01"},
		{"event": "attempt", "room": "01", "moves": 8},
		{"event": "catch", "room": "01", "beat": 8, "guard": "A"},
		{"event": "attempt", "room": "01", "moves": 10},
		{"event": "clear", "room": "01", "moves": 10, "bonus": false},
		{"event": "room_start", "room": "01"},
		{"event": "replay", "room": "01"},
	]
	_eq(check, events.size(), expected.size(), "event count")
	var seen := {}
	for index in events.size():
		var item = events[index]
		if typeof(item) != TYPE_DICTIONARY:
			check.fail("event line is not an object")
			continue
		_assert_event_keys(check, item)
		if index < expected.size():
			for key in expected[index].keys():
				_eq(check, item.get(key), expected[index][key], "event %s %s" % [str(index), str(key)])
		seen[str(item.get("event", ""))] = true
	for name in ["room_start", "attempt", "catch", "clear", "replay"]:
		_true(check, seen.has(name), "log records %s" % name)

	var vault_log_storage = _memory()
	var vault_log = LogScript.new(vault_log_storage)
	vault_log.set_enabled(true)
	var vault = _open(_memory(_save(ROOM_IDS)), vault_log)
	_eq(check, vault.state, "job_complete", "vault log boots finished")
	_eq(check, vault_log_storage.text, "", "job boot does not log a room")
	vault.replay_vault()
	var replay_events := _events(vault_log_storage.text)
	_eq(check, replay_events.size(), 2, "replay vault logs two lines")
	if replay_events.size() == 2:
		_eq(check, replay_events[0].get("event"), "room_start", "replay vault starts the room")
		_eq(check, replay_events[1].get("event"), "replay", "replay vault records replay")
		_eq(check, replay_events[1].get("room"), "06", "replay vault room")
		_assert_event_keys(check, replay_events[0])
		_assert_event_keys(check, replay_events[1])


func _query_flag(check) -> void:
	print("session: log query")
	var log = LogScript.new(_memory())
	_true(check, log.query_enables("log=1"), "log=1")
	_true(check, log.query_enables("?log=1"), "?log=1")
	_true(check, log.query_enables("foo=bar&log=1"), "log among other keys")
	_true(check, log.query_enables("log=1&x=2"), "log first")
	_true(check, log.query_enables("?room=01&log=1"), "room and log")
	_true(check, log.query_enables("https://play.example/?log=1"), "page url")
	_true(check, log.query_enables("?log=1#sheet"), "query before a hash")
	_true(check, not log.query_enables(""), "empty query")
	_true(check, not log.query_enables("?"), "bare question mark")
	_true(check, not log.query_enables("log=0"), "log=0")
	_true(check, not log.query_enables("log=12"), "log=12")
	_true(check, not log.query_enables("logout=1"), "logout")
	_true(check, not log.query_enables("catalog=1"), "catalog")
	_true(check, not log.query_enables("?Log=1"), "case sensitive")
	_true(check, not log.query_enables("https://play.example/"), "url without the flag")
	log.enable_from_query("log=0")
	_eq(check, log.enabled, false, "other queries leave the log off")
	log.enable_from_query("?log=1")
	_eq(check, log.enabled, true, "log=1 enables the visit")
	log.enable_from_query("")
	_eq(check, log.enabled, true, "a later empty query does not disable it")


func _ignored_and_cancel(check) -> void:
	print("session: ignored calls and cancel")
	var storage = _memory()
	var session = _open(storage)
	session.cancel_draw()
	session.commit(_draft(1))
	session.resume()
	session.retry()
	session.next_room()
	session.finish()
	session.replay_vault()
	session.select_room("01")
	session.on_caught(1, "A")
	session.on_cleared(1, true)
	_eq(check, session.state, "planning", "wrong calls stay in planning")
	_eq(check, storage.writes, 0, "wrong calls do not save")
	session.begin_draw()
	session.on_caught(1, "A")
	session.on_cleared(1, true)
	session.commit({"valid": false, "moves": 4})
	session.commit({})
	_eq(check, session.state, "drawing", "invalid commit stays in drawing")
	_eq(check, storage.writes, 0, "invalid commit does not save")
	session.cancel_draw()
	_eq(check, session.state, "planning", "cancel returns to planning")
	session.begin_draw()
	session.commit(_draft(3))
	session.open_rooms()
	_eq(check, session.state, "running", "open rooms is ignored during a run")
	session.on_caught(1, "B")
	session.open_rooms()
	_eq(check, session.state, "rooms", "open rooms from caught")
	_eq(check, session.catch_count("01"), 0, "leaving the room zeroes the counter")


func _sources_stay_local(check) -> void:
	print("session: no sim and no network")
	var paths := [
		"res://scripts/session/heist_storage.gd",
		"res://scripts/session/memory_storage.gd",
		"res://scripts/session/user_storage.gd",
		"res://scripts/session/event_log.gd",
		"res://scripts/session/heist_session.gd",
	]
	for path in paths:
		var src := FileAccess.get_file_as_string(path)
		if path.ends_with("user_storage.gd") and not src.contains("\"user://save.json\""):
			check.fail("user storage path")
		if path.ends_with("event_log.gd") and not src.contains("\"user://events.jsonl\""):
			check.fail("event log path")
		if src.contains("HeistSim") or src.contains("simulation.gd"):
			check.fail("%s calls the simulator" % path)
		for needle in ["HTTPRequest", "HTTPClient", "https://", "http://", "WebSocket"]:
			if src.contains(needle):
				check.fail("%s contains %s" % [path, needle])


func _no_user_files(check) -> void:
	print("session: unit tests stay off user://")
	_true(check, not FileAccess.file_exists("user://save.json"), "save.json was not created")
	_true(check, not FileAccess.file_exists("user://events.jsonl"), "events.jsonl was not created")


func _exercise_log(session) -> void:
	session.begin_draw()
	session.commit(_draft(8))
	session.on_caught(8, "A")
	session.retry()
	session.begin_draw()
	session.commit(_draft(10))
	session.on_cleared(10, false)
	session.open_rooms()
	session.select_room("01")


func _advance_to(session, id: String) -> void:
	var hops := 0
	while str(session.room_id) != id and hops < 6:
		_clear(session, 10, false)
		session.next_room()
		hops += 1


func _clear(session, moves: int, bonus: bool) -> void:
	session.begin_draw()
	session.commit(_draft(moves))
	if session.state != "running":
		push_error("commit did not start a run")
		return
	session.on_cleared(moves, bonus)


func _draft(moves: int) -> Dictionary:
	return {"valid": true, "moves": moves, "cells": []}


func _memory(text: String = "") :
	var storage = MemoryScript.new()
	storage.text = text
	return storage


func _open(storage, log = null):
	var session = SessionScript.new(storage, log)
	session.boot()
	return session


func _entry(session, id: String) -> Dictionary:
	for entry in session.room_entries():
		if str(entry["id"]) == id:
			return entry
	return {}


func _save(cleared_ids: Array) -> String:
	var rooms := {}
	for id in ROOM_IDS:
		var cleared := cleared_ids.has(id)
		var best = null
		if cleared:
			best = 10
		rooms[id] = {"cleared": cleared, "best_moves": best, "bonus": false}
	return JSON.stringify({
		"version": 1,
		"settings": {
			"sound": true,
			"reduced_motion": false,
			"tap_route": false,
			"bonus_intro_shown": false,
			"first_commit_done": false,
		},
		"rooms": rooms,
	})


func _events(text: String) -> Array:
	var out: Array = []
	for line in text.split("\n", false):
		out.append(JSON.parse_string(line))
	return out


func _has_clear(text: String, id: String, moves: int, bonus: bool) -> bool:
	for item in _events(text):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if item.get("event") != "clear":
			continue
		if str(item.get("room")) != id:
			continue
		if int(item.get("moves")) != moves:
			continue
		if bool(item.get("bonus")) != bonus:
			continue
		return true
	return false


func _assert_event_keys(check, item: Dictionary) -> void:
	for key in item.keys():
		var lowered := str(key).to_lower()
		for needle in ACCOUNT_NEEDLES:
			if needle in lowered:
				check.fail("event field looks like an account: %s" % str(key))
		var allowed := ["event", "room", "moves", "beat", "guard", "bonus"]
		if not allowed.has(str(key)):
			check.fail("unexpected event field %s" % str(key))


func _assert_save_document(check, text: String, label: String):
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		check.fail("%s save did not parse" % label)
		return null
	_eq(check, _sorted_keys(parsed), ["rooms", "settings", "version"], "%s save keys" % label)
	_eq(check, int(parsed["version"]), 1, "%s version" % label)
	var version_kind := typeof(parsed["version"])
	_true(check, version_kind == TYPE_INT or version_kind == TYPE_FLOAT, "%s version type" % label)
	var settings: Dictionary = parsed["settings"]
	_eq(check, _sorted_keys(settings), [
		"bonus_intro_shown",
		"first_commit_done",
		"reduced_motion",
		"sound",
		"tap_route",
	], "%s setting keys" % label)
	var rooms: Dictionary = parsed["rooms"]
	_eq(check, _sorted_keys(rooms), ROOM_IDS.duplicate(), "%s room ids" % label)
	for id in ROOM_IDS:
		var record: Dictionary = rooms[id]
		_eq(check, _sorted_keys(record), ["best_moves", "bonus", "cleared"], "%s %s keys" % [label, id])
		_true(check, record.has("best_moves"), "%s %s best key" % [label, id])
	return parsed


func _sorted_keys(data: Dictionary) -> Array:
	var keys: Array = []
	for key in data.keys():
		keys.append(str(key))
	keys.sort()
	return keys


func _eq(check, actual, expected, label: String) -> void:
	if actual != expected:
		var message := "%s | expected [%s] got [%s]" % [label, str(expected), str(actual)]
		push_error(message)
		check.fail(message)
	else:
		check.eq(actual, expected)


func _true(check, value, label: String) -> void:
	if value == true:
		check.is_true(true)
	else:
		push_error(label)
		check.fail(label)
