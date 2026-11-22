extends TestSuite

const CUES: PackedStringArray = [
	"launch",
	"footstep",
	"pickup",
	"bonus",
	"caught",
	"escaped",
]

const ALL: PackedStringArray = [
	"ambience",
	"launch",
	"footstep",
	"pickup",
	"bonus",
	"caught",
	"escaped",
]


func suite_name() -> String:
	return "audio"


func run(expect) -> void:
	for cue_name in ALL:
		_check_file(expect, cue_name)
		_check_import(expect, cue_name)
	_check_offline(expect)
	_check_playback(expect)


func _check_file(expect, cue_name: String) -> void:
	var path := "res://assets/audio/%s.ogg" % cue_name
	if not FileAccess.file_exists(path):
		expect.fail("missing %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		expect.fail("unreadable %s" % path)
		return
	var magic := file.get_buffer(4).get_string_from_ascii()
	file.close()
	if magic != "OggS":
		expect.fail("%s is not an OGG file" % path)
	var stream := load(path) as AudioStreamOggVorbis
	if stream == null:
		expect.fail("%s did not import as an in-memory Ogg Vorbis sample" % path)
		return
	if not stream.can_be_sampled():
		expect.fail("%s is not a static sample" % cue_name)
	var length := stream.get_length()
	if length <= 0.05:
		expect.fail("%s has no duration" % cue_name)
	if length > 30.0:
		expect.fail("%s is longer than 30s (%s)" % [cue_name, length])
	if cue_name == "ambience":
		if not stream.has_loop():
			expect.fail("ambience does not loop")
	else:
		if stream.has_loop():
			expect.fail("%s should not loop" % cue_name)
		if length > 5.0:
			expect.fail("%s is not a short cue (%ss)" % [cue_name, length])
	var sequence := stream.get_packet_sequence()
	if sequence == null or sequence.packet_data.is_empty():
		expect.fail("%s has no packet data in RAM" % cue_name)
		return
	var bytes := 0
	for page in sequence.packet_data:
		if page is Array:
			for packet in page:
				bytes += (packet as PackedByteArray).size()
		else:
			bytes += (page as PackedByteArray).size()
	if bytes < 64:
		expect.fail("%s is not stored as sample data" % cue_name)
	for prop in stream.get_property_list():
		var prop_name := str(prop.get("name", ""))
		if prop_name.contains("disk"):
			expect.fail("%s exposes a disk-stream property %s" % [cue_name, prop_name])


func _check_import(expect, cue_name: String) -> void:
	var path := "res://assets/audio/%s.ogg.import" % cue_name
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		expect.fail("missing import flags for %s" % cue_name)
		return
	if not text.contains("oggvorbis"):
		expect.fail("%s is not imported as Ogg Vorbis" % cue_name)
	if text.contains("stream_from_disk") or text.contains("importer=\"keep\""):
		expect.fail("%s is set to stream from disk" % cue_name)
	if cue_name == "ambience":
		if not text.contains("loop=true"):
			expect.fail("ambience import does not loop")
	elif text.contains("loop=true"):
		expect.fail("%s import should not loop" % cue_name)


func _check_offline(expect) -> void:
	var src := FileAccess.get_file_as_string("res://scripts/audio/heist_audio.gd")
	if src.is_empty():
		expect.fail("HeistAudio script is missing")
		return
	for token in [
		"HTTPRequest",
		"HTTPClient",
		"WebSocketPeer",
		"TCPServer",
		"StreamPeerTCP",
		"PacketPeerUDP",
		"OS.shell_open",
		"OS.execute",
		"http://",
		"https://",
	]:
		if src.contains(token):
			expect.fail("HeistAudio references %s" % token)


func _check_playback(expect) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		expect.fail("no scene tree")
		return
	var silent := HeistAudio.new()
	silent.set_enabled(false)
	for cue_name in CUES:
		silent.play(cue_name)
	silent.play("missing")
	silent.start_ambience()
	silent.start_ambience()
	silent.free()

	var audio := HeistAudio.new()
	tree.root.add_child(audio)
	if audio.get_child_count() != 7:
		expect.fail("expected 7 players, got %s" % audio.get_child_count())
	var ambience := audio.get_node_or_null("ambience") as AudioStreamPlayer
	if ambience == null:
		expect.fail("missing ambience player")
		audio.free()
		return
	if ambience.playing or ambience.autoplay:
		expect.fail("ambience started before the first press")
	_expect_sample(expect, ambience, "ambience")

	audio.set_enabled(false)
	for cue_name in CUES:
		audio.play(cue_name)
		var player := audio.get_node_or_null(cue_name) as AudioStreamPlayer
		if player == null:
			expect.fail("missing player %s" % cue_name)
			continue
		if player.playing:
			expect.fail("%s played while the bus was disabled" % cue_name)
		_expect_sample(expect, player, cue_name)
	if ambience.playing:
		expect.fail("ambience played while the bus was disabled")

	audio.set_enabled(true)
	# The headless driver never mixes stream fade-out, which leaks playbacks at exit.
	# Sample playback is the web path and shuts down cleanly here.
	for child in audio.get_children():
		(child as AudioStreamPlayer).playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE
	audio.play("launch")
	audio.play("missing")
	var launch := audio.get_node_or_null("launch") as AudioStreamPlayer
	if launch != null and not launch.playing:
		expect.fail("launch did not play on an enabled bus")
	audio.start_ambience()
	if not ambience.playing:
		expect.fail("ambience did not start")
	var players_before := audio.get_child_count()
	ambience.stop()
	audio.start_ambience()
	if ambience.playing or audio.get_child_count() != players_before:
		expect.fail("start_ambience was not idempotent")
	audio.set_enabled(true)
	if not ambience.playing:
		expect.fail("sound on did not resume ambience")
	audio.set_enabled(false)
	if launch != null and launch.playing:
		expect.fail("launch kept playing after the bus stopped")
	if ambience.playing:
		expect.fail("ambience kept playing after the bus stopped")
	audio.free()


func _expect_sample(expect, player: AudioStreamPlayer, cue_name: String) -> void:
	var stream := player.stream
	if stream == null or not stream.can_be_sampled():
		expect.fail("%s is not an in-memory sample" % cue_name)
		return
	if OS.has_feature("web") and not AudioServer.is_stream_registered_as_sample(stream):
		expect.fail("%s was not registered as a sample" % cue_name)
	if OS.has_feature("web"):
		if player.playback_type != AudioServer.PLAYBACK_TYPE_SAMPLE:
			expect.fail("%s playback is not a sample on the web export" % cue_name)
	elif player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM:
		expect.fail("%s is set to stream playback" % cue_name)
