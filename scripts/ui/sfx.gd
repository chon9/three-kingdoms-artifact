extends Node
## Interface sounds from the Kenney UI Pack (CC0): a small pool of players so
## overlapping clicks do not cut each other off. Volume follows settings.

const Settings = preload("res://scripts/core/game_settings.gd")
const SOUND_DIR = "res://assets/third_party/kenney_ui_pack/sounds/"
const POOL = 4

var _players: Array = []
var _streams: Dictionary = {}
var _next: int = 0

func _ready() -> void:
	for index in range(POOL):
		var player = AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

## Plays "click-a", "click-b", "switch-a", "switch-b", "tap-a" or "tap-b".
func play(sound: String) -> void:
	if Settings.volume <= 0.0 or _players.is_empty():
		return
	if not _streams.has(sound):
		var path = SOUND_DIR + sound + ".ogg"
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
	var stream = _streams[sound]
	if stream == null:
		return
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = linear_to_db(Settings.volume)
	player.play()
