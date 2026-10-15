extends SceneTree
## Records the golden bot matches of the CURRENT engine into
## tests/data/goldens/<suite>.json (EFFECT_SYSTEM_SPEC.md §13.5).
##
##   godot --headless --path . --script res://tools/record_goldens.gd
##   godot --headless --path . --script res://tools/record_goldens.gd -- --suite classic
##
## Re-record only in a commit that intends a rules change (FX or RQ) and say
## why in the commit message. Then run tests/golden_test.gd, which must pass.

const Goldens = preload("res://tests/golden/golden_games.gd")

func _initialize() -> void:
	var suites: Array = Goldens.SUITES.duplicate()
	var args = OS.get_cmdline_user_args()
	var index = args.find("--suite")
	if index != -1 and index + 1 < args.size():
		suites = [args[index + 1]]
		if suites[0] not in Goldens.SUITES:
			printerr("Unknown suite %s; expected one of %s." % [suites[0], Goldens.SUITES])
			quit(2)
			return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Goldens.GOLDEN_DIR))
	for suite in suites:
		var started = Time.get_ticks_msec()
		var records: Array = []
		var steps = 0
		for game in Goldens.games(suite):
			var record = Goldens.record_game(game)
			if int(record.winner) == -1:
				printerr("Golden game %s did not finish within %d commands." % [game.id, game.max_steps])
				quit(1)
				return
			records.append(record)
			steps += int(record.step_count)
		var file = FileAccess.open(Goldens.path_of(suite), FileAccess.WRITE)
		if file == null:
			printerr("Cannot write %s." % Goldens.path_of(suite))
			quit(1)
			return
		file.store_string(Goldens.serialize(suite, records))
		file.close()
		print("RECORDED %s: %d games, %d commands in %.1f s -> %s" % [suite, records.size(), steps,
			(Time.get_ticks_msec() - started) / 1000.0, Goldens.path_of(suite)])
	quit(0)
