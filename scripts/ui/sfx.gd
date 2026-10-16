extends Node
## Interface sounds (all CC0, see CREDITS.md): the Kenney UI Pack's clicks,
## switches and taps, Kenney Interface Sounds' chimes (your action, the
## opponent passing or getting ready) and a Kenney Impact Sounds bell (the
## match intro's stamp). A small pool of players lets overlapping clicks ring
## together; alerts have a player of their own so a click never cuts a chime
## off. Every player plays on the SFX bus: its level is the effects volume,
## and Master carries the master volume and the mute (game_settings.gd).

const Settings = preload("res://scripts/core/game_settings.gd")
const UI_PACK = "res://assets/third_party/kenney_ui_pack/sounds/"
const INTERFACE = "res://assets/third_party/kenney_interface_sounds/sounds/"
const IMPACT = "res://assets/third_party/kenney_impact_sounds/sounds/"
## Sound name -> file.
const SOUNDS = {
	"click-a": UI_PACK + "click-a.ogg",
	"click-b": UI_PACK + "click-b.ogg",
	"switch-a": UI_PACK + "switch-a.ogg",
	"switch-b": UI_PACK + "switch-b.ogg",
	"tap-a": UI_PACK + "tap-a.ogg",
	"tap-b": UI_PACK + "tap-b.ogg",
	# It became your action.
	"turn": INTERFACE + "confirmation_002.ogg",
	# The opponent passed.
	"opponent_pass": INTERFACE + "glass_001.ogg",
	# The opponent is ready (a rematch or the first match of a room).
	"ready": INTERFACE + "confirmation_004.ogg",
	# The match intro's seal stamp.
	"versus": IMPACT + "impactBell_heavy_000.ogg",
}
## Per-sound level trims in dB (measured with ffmpeg volumedetect: the clicks
## average about -24 dBFS, the chimes start 10 dB above): the your-action
## chime stays clearly above the clicks, the others sit with them.
const TRIM_DB = {"turn": -4.0, "opponent_pass": -3.0, "ready": -7.0, "versus": -2.0}
const POOL = 4

var _players: Array = []
var _alert: AudioStreamPlayer
var _streams: Dictionary = {}
var _next: int = 0
## The last sound actually started ("" before any), and how many started
## (tests read these; headless runs play into the dummy audio driver).
var last_played: String = ""
var played_count: int = 0
## How often each sound started.
var counts: Dictionary = {}

func _ready() -> void:
	Settings.ensure_audio_buses()
	for index in range(POOL):
		var player = AudioStreamPlayer.new()
		player.bus = Settings.SFX_BUS
		add_child(player)
		_players.append(player)
	_alert = AudioStreamPlayer.new()
	_alert.name = "Alert"
	_alert.bus = Settings.SFX_BUS
	add_child(_alert)

## The players (tests check their bus).
func players() -> Array:
	return _players + [_alert]

## Plays one of SOUNDS from the shared pool.
func play(sound: String) -> void:
	if _players.is_empty():
		return
	var player: AudioStreamPlayer = _players[_next]
	if _start(player, sound):
		_next = (_next + 1) % _players.size()

## An alert (your action): its own player, and only while alerts are on.
func play_alert(sound: String) -> void:
	if not Settings.turn_alert or _alert == null:
		return
	_start(_alert, sound)

func _start(player: AudioStreamPlayer, sound: String) -> bool:
	# Silent (muted, or a level at 0): nothing starts.
	if Settings.effective_sfx_volume() <= 0.0:
		return false
	var stream = _stream(sound)
	if stream == null:
		return false
	player.stream = stream
	# The level comes from the buses; only the per-sound trim is set here.
	player.volume_db = float(TRIM_DB.get(sound, 0.0))
	player.play()
	last_played = sound
	played_count += 1
	counts[sound] = int(counts.get(sound, 0)) + 1
	return true

func _stream(sound: String) -> AudioStream:
	if not _streams.has(sound):
		var path = str(SOUNDS.get(sound, ""))
		_streams[sound] = load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
	return _streams[sound]
