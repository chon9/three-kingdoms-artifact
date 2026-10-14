extends Node
## Runs presentation jobs one after another. A job is a Callable that may be
## a coroutine (it may await tweens and timers). While jobs run, `busy` is
## true: the match screen ignores play input and the bot waits.
##
## `speed` scales every wait and tween; `instant` (tests) skips them, so a
## job then completes in the same frame it was pushed.

signal idle

static var speed: float = 1.0
static var instant: bool = false
var busy: bool = false
var _jobs: Array = []

func push(job: Callable) -> void:
	_jobs.append(job)
	if not busy:
		_run()

func clear() -> void:
	_jobs.clear()

func _run() -> void:
	busy = true
	while not _jobs.is_empty():
		var job: Callable = _jobs.pop_front()
		if job.is_valid():
			await job.call()
	busy = false
	idle.emit()

## Seconds scaled by the animation speed (0 when instant).
static func duration(seconds: float) -> float:
	if instant:
		return 0.0
	return seconds / maxf(0.1, speed)

## Awaitable pause: `await queue.wait(0.3)`.
func wait(seconds: float) -> void:
	var scaled = duration(seconds)
	if scaled <= 0.0 or not is_inside_tree():
		return
	await get_tree().create_timer(scaled).timeout

## Awaits a tween if it is still running.
func finish(tween: Tween) -> void:
	if tween != null and tween.is_valid() and tween.is_running():
		await tween.finished
