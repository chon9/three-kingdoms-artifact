extends Node
## Background music (all CC0 / public domain, see CREDITS.md): one owner for
## the whole app (main.gd keeps the single instance; the match screen asks it
## for the match's states). States:
##   "menu"          main menu, decks, settings, the online room, and a result
##                   after a short pause (Lotus Pond, looped)
##   "battle_start"  a match begins: a fanfare under the match intro, once;
##                   it leads into "battle" by itself
##   "battle"        the match (Dragon Dance, looped)
##   "urgency"       any tower has fallen, for the rest of that match
##                   (Determined Pursuit, looped)
##   ""              silence
## Two players crossfade: the new track fades in on the idle player while the
## other fades out, so at most two ever sound and a finished fade leaves one.
## Asking for the state already playing (or already on its way) changes
## nothing. The node and its players, fades and timers run while the tree is
## paused. Levels come from the Music bus and Master (volume and mute; see
## game_settings.gd). Headless runs play into the dummy audio driver.

signal state_changed(state: String)

const Settings = preload("res://scripts/core/game_settings.gd")
const MUSIC = "res://assets/third_party/music/"
const TRACKS = {
	"menu": MUSIC + "bitemegames/menu_lotus_pond.ogg",
	"battle_start": MUSIC + "spring_spring/battle_start_fanfare.ogg",
	"battle": MUSIC + "bitemegames/battle_dragon_dance.ogg",
	"urgency": MUSIC + "emma_ma/urgency_determined_pursuit.ogg",
}
## The one-shot state and the state that follows it.
const STING = "battle_start"
const AFTER_STING = "battle"
## Crossfade length in seconds.
const FADE_SECONDS = 1.2
## The battle loop starts this long before the fanfare ends (its fade-out).
const STING_OVERLAP = 0.4
## The pause between a result and the menu music.
const RESULT_PAUSE = 2.5
## Player volume while faded out.
const SILENT_DB = -80.0

var fade_seconds: float = FADE_SECONDS
## The state playing (or fading in); "" while silent.
var state: String = ""
## A state waiting for its delay (request with `delay`), or "".
var pending: String = ""
## Every state started, in order, and how many (tests read these).
var history: Array = []
var started_count: int = 0
var _players: Array = []
## Index of the player carrying `state`.
var _front: int = 0
var _tween: Tween
var _sting_timer: Timer
var _delay_timer: Timer
var _streams: Dictionary = {}

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.ensure_audio_buses()
	for index in range(2):
		var player = AudioStreamPlayer.new()
		player.name = "Track%d" % index
		player.bus = Settings.MUSIC_BUS
		player.volume_db = SILENT_DB
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)
	_sting_timer = _timer("StingTimer", _on_sting_done)
	_delay_timer = _timer("DelayTimer", _on_delay_done)

## Leaving the tree (the app closing) stops and releases every track.
func _exit_tree() -> void:
	_kill_tween()
	_sting_timer.stop()
	_delay_timer.stop()
	state = ""
	pending = ""
	for player in _players:
		player.stop()
		player.stream = null
	_streams.clear()

func _timer(timer_name: String, callback: Callable) -> Timer:
	var timer = Timer.new()
	timer.name = timer_name
	timer.one_shot = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.timeout.connect(callback)
	add_child(timer)
	return timer

## Asks for `new_state`. With `delay` > 0 the music fades out now and the
## state starts after the delay (a result's pause before the menu music).
## The state already playing, or already waiting for its delay, is left
## alone; "battle" while the fanfare plays is where the fanfare leads anyway.
func request(new_state: String, delay: float = 0.0) -> void:
	if new_state != "" and not TRACKS.has(new_state):
		return
	if _is_current(new_state, delay):
		return
	if delay > 0.0:
		_fade_out_all()
		pending = new_state
		_delay_timer.start(delay)
		return
	_switch(new_state)

## True when `new_state` (asked with `delay`) is already what plays or waits.
func _is_current(new_state: String, delay: float) -> bool:
	if not _delay_timer.is_stopped():
		# Waiting for `pending`: asking for it again (delayed or not) keeps
		# the wait, unless it is wanted now.
		return new_state == pending and delay > 0.0
	if new_state == state:
		return true
	return state == STING and new_state == AFTER_STING

## The track a state plays ("" for none).
func stream_for(state_name: String) -> AudioStream:
	if not TRACKS.has(state_name):
		return null
	if not _streams.has(state_name):
		var path = str(TRACKS[state_name])
		var stream = load(path) if ResourceLoader.exists(path) else null
		if stream != null and state_name != STING and "loop" in stream:
			stream.loop = true # Set on import too; the loops must never stop.
		_streams[state_name] = stream
	return _streams[state_name]

## The two players (tests check that fades never stack more).
func players() -> Array:
	return _players

## The players currently sounding.
func playing_players() -> Array:
	return _players.filter(func(player): return player.playing)

## The player carrying the current state.
func front_player() -> AudioStreamPlayer:
	return _players[_front]

## True while a crossfade or fade-out runs.
func fading() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()

## Ends the fanfare now (its timer would): the battle loop takes over.
func finish_sting() -> void:
	if state == STING:
		_sting_timer.stop()
		_on_sting_done()

func _on_sting_done() -> void:
	if state == STING:
		_switch(AFTER_STING, 1.0)

func _on_delay_done() -> void:
	var next = pending
	pending = ""
	_switch(next)

## Crossfades from the current track to `new_state`'s.
func _switch(new_state: String, seconds: float = -1.0) -> void:
	var length = fade_seconds if seconds < 0.0 else seconds
	_delay_timer.stop()
	_sting_timer.stop()
	pending = ""
	_kill_tween()
	var stream = stream_for(new_state)
	if stream == null:
		state = ""
		_fade_out_all(length)
		state_changed.emit(state)
		return
	var outgoing: AudioStreamPlayer = _players[_front]
	_front = 1 - _front
	var incoming: AudioStreamPlayer = _players[_front]
	incoming.stop()
	incoming.stream = stream
	incoming.volume_db = SILENT_DB if length > 0.0 else 0.0
	incoming.play()
	state = new_state
	history.append(new_state)
	started_count += 1
	if new_state == STING:
		_sting_timer.start(maxf(0.1, stream.get_length() - STING_OVERLAP))
	if length <= 0.0:
		outgoing.stop()
	else:
		_tween = create_tween()
		_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tween.set_parallel(true)
		_tween.tween_method(_set_gain.bind(incoming), _gain(incoming), 1.0, length)
		if outgoing.playing:
			_tween.tween_method(_set_gain.bind(outgoing), _gain(outgoing), 0.0, length)
		_tween.chain().tween_callback(outgoing.stop)
	state_changed.emit(state)

## Fades every player out (and stops it); `state` becomes "".
func _fade_out_all(seconds: float = -1.0) -> void:
	var length = fade_seconds if seconds < 0.0 else seconds
	_kill_tween()
	_sting_timer.stop()
	state = ""
	var sounding = playing_players()
	if sounding.is_empty():
		return
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)
	for player in sounding:
		_tween.tween_method(_set_gain.bind(player), _gain(player), 0.0, maxf(length, 0.01))
	_tween.chain().tween_callback(func():
		for player in sounding:
			player.stop())

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

## A player's level as linear gain (the fades run in linear gain, not dB).
func _gain(player: AudioStreamPlayer) -> float:
	return 0.0 if player.volume_db <= SILENT_DB + 0.5 else db_to_linear(player.volume_db)

func _set_gain(gain: float, player: AudioStreamPlayer) -> void:
	player.volume_db = SILENT_DB if gain <= 0.0001 else maxf(SILENT_DB, linear_to_db(gain))
