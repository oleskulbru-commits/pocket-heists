class_name HeistAudio
extends Node

const CUES: PackedStringArray = [
	"launch",
	"footstep",
	"pickup",
	"bonus",
	"caught",
	"escaped",
]

const STREAMS: Dictionary = {
	"ambience": preload("res://assets/audio/ambience.ogg"),
	"launch": preload("res://assets/audio/launch.ogg"),
	"footstep": preload("res://assets/audio/footstep.ogg"),
	"pickup": preload("res://assets/audio/pickup.ogg"),
	"bonus": preload("res://assets/audio/bonus.ogg"),
	"caught": preload("res://assets/audio/caught.ogg"),
	"escaped": preload("res://assets/audio/escaped.ogg"),
}

const _GAIN_DB: Dictionary = {
	"ambience": -8.0,
	"launch": -4.0,
	"footstep": -10.0,
	"pickup": -6.0,
	"bonus": -5.0,
	"caught": -4.0,
	"escaped": -5.0,
}

var _enabled := true
var _players_ready := false
var _ambience_started := false
var _ambience: AudioStreamPlayer
var _cues: Dictionary = {}


func _ready() -> void:
	_ensure_players()
	if _enabled and _ambience_started and _ambience:
		_ambience.play()


func set_enabled(on: bool) -> void:
	_enabled = on
	if not _players_ready:
		return
	if not on:
		_stop_all()
		return
	if _ambience_started and _ambience and not _ambience.playing:
		_ambience.play()


func play(cue: String) -> void:
	if not _enabled or not is_inside_tree():
		return
	_ensure_players()
	var player: AudioStreamPlayer = _cues.get(cue)
	if player == null or player.stream == null:
		return
	player.play()


func start_ambience() -> void:
	if _ambience_started:
		return
	_ambience_started = true
	if not _enabled or not is_inside_tree():
		return
	_ensure_players()
	if _ambience:
		_ambience.play()


func _ensure_players() -> void:
	if _players_ready:
		return
	_ambience = _make_player("ambience")
	for cue in CUES:
		_cues[cue] = _make_player(cue)
	_players_ready = true


func _make_player(cue: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = cue
	player.stream = STREAMS[cue]
	player.volume_db = float(_GAIN_DB[cue])
	# Web export plays these as samples. Desktop keeps the platform default so the editor can hear them.
	player.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_DEFAULT
	player.autoplay = false
	add_child(player)
	var stream := player.stream
	if OS.has_feature("web") and stream != null and stream.can_be_sampled() and not AudioServer.is_stream_registered_as_sample(stream):
		AudioServer.register_stream_as_sample(stream)
	return player


func _stop_all() -> void:
	if _ambience:
		_ambience.stop()
	for player in _cues.values():
		(player as AudioStreamPlayer).stop()
