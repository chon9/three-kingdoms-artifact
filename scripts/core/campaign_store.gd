extends RefCounted
## Campaign progress, saved in user://campaign.cfg (versioned):
##   [meta]          version
##   [chapter.<id>]  won, attempts, wins, seals (the seals of every win so
##                   far, CampaignData.SEAL_* bits), best_rounds (the fewest
##                   rounds of a win), first_won_unix
##   [deck]          <chapter id> = "preset:<preset id>" or "own:<deck id>",
##                   the army last taken into that chapter
##   [ui]            last_chapter, seen_epilogue
## Progress is kept by chapter id, never by position, so chapters can be
## added or reordered; sections of ids the campaign no longer has are kept
## but count for nothing. The first chapter is always open; every other one
## opens when the one before it is won.
##
## A missing file starts fresh; an unreadable one starts fresh and is kept
## beside it as <file>.bad; a file written by a newer version is read but
## never written over (read_only). Values of the wrong type read as their
## defaults. A save writes <file>.tmp and moves it over the file, so a crash
## mid-save keeps the last whole progress. Tests point `path` at their own
## user://test_* file.

const CampaignData = preload("res://scripts/core/campaign_data.gd")
const VERSION = 1
const DEFAULT_PATH = "user://campaign.cfg"

## The file progress is read from and written to.
static var path: String = DEFAULT_PATH
## The file came from a newer version: nothing is written.
static var read_only: bool = false
static var _config: ConfigFile = ConfigFile.new()
static var _loaded_path: String = ""

# --- File --------------------------------------------------------------------------

## Reads `file_path` (default: `path`, which it then becomes).
static func load_progress(file_path: String = "") -> void:
	if not file_path.is_empty():
		path = file_path
	_loaded_path = path
	_config = ConfigFile.new()
	read_only = false
	if not FileAccess.file_exists(path):
		return
	var config = ConfigFile.new()
	if config.load(path) != OK:
		# Damaged or hand-edited beyond reading: start fresh, keep the old file.
		DirAccess.copy_absolute(path, path + ".bad")
		return
	var version = config.get_value("meta", "version", VERSION)
	if (version is int or version is float) and int(version) > VERSION:
		read_only = true
	_config = config

## Writes the progress (refused while read_only).
static func save() -> Error:
	_ensure()
	if read_only:
		return ERR_FILE_NO_PERMISSION
	_config.set_value("meta", "version", VERSION)
	if path.begins_with("user://") or path.begins_with("res://"):
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	# Written beside the file, then moved over it (as DeckStore does): a
	# crash mid-write leaves the old progress whole, never a cut-off file.
	var temporary = path + ".tmp"
	var error = _config.save(temporary)
	if error == OK:
		error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		DirAccess.remove_absolute(temporary)
		push_warning("Campaign progress could not be saved to %s: %s" % [path, error_string(error)])
	return error

## Reloads when `path` changed since the last read.
static func _ensure() -> void:
	if _loaded_path != path:
		load_progress()

static func _section(chapter_id: String) -> String:
	return "chapter." + chapter_id

static func _int(section: String, key: String, fallback: int = 0) -> int:
	_ensure()
	var value = _config.get_value(section, key, fallback)
	if value is int or (value is float and is_finite(value)):
		return int(value)
	return fallback

static func _bool(section: String, key: String, fallback: bool = false) -> bool:
	_ensure()
	var value = _config.get_value(section, key, fallback)
	return value if value is bool else fallback

static func _string(section: String, key: String) -> String:
	_ensure()
	var value = _config.get_value(section, key, "")
	return value if value is String else ""

# --- Chapters ----------------------------------------------------------------------

static func is_won(chapter_id: String) -> bool:
	return _bool(_section(chapter_id), "won")

static func attempts(chapter_id: String) -> int:
	return maxi(0, _int(_section(chapter_id), "attempts"))

static func wins(chapter_id: String) -> int:
	return maxi(0, _int(_section(chapter_id), "wins"))

## The seals earned in this chapter so far (CampaignData.SEAL_* bits).
static func seals(chapter_id: String) -> int:
	return _int(_section(chapter_id), "seals") & CampaignData.ALL_SEALS

static func best_rounds(chapter_id: String) -> int:
	return maxi(0, _int(_section(chapter_id), "best_rounds"))

static func first_won_unix(chapter_id: String) -> int:
	return maxi(0, _int(_section(chapter_id), "first_won_unix"))

## The first chapter is always open; any other once the one before is won.
static func is_unlocked(chapter_id: String) -> bool:
	if not CampaignData.has_chapter(chapter_id):
		return false
	var previous = CampaignData.previous_chapter(chapter_id)
	return previous.is_empty() or is_won(previous)

## An act opens with its first chapter.
static func act_unlocked(act_id: String) -> bool:
	var chapters = CampaignData.act_chapters(act_id)
	return not chapters.is_empty() and is_unlocked(chapters[0])

static func epilogue_unlocked() -> bool:
	var after = CampaignData.epilogue_unlock_after()
	return not after.is_empty() and is_won(after)

## The first open chapter not won yet (the last chapter when all are won).
static func furthest_chapter() -> String:
	for chapter_id in CampaignData.chapter_ids():
		if is_unlocked(chapter_id) and not is_won(chapter_id):
			return chapter_id
	return CampaignData.last_chapter()

## Records a finished match of `chapter_id` (a defeat, a draw or a concession
## is `won` false) and saves. Returns {"chapter", "won", "seals" (this
## match's), "new_seals" (seals not held before), "first_win", "unlocked" (the
## chapter this win opened, or ""), "rounds", "towers_lost"}; {} for an
## unknown chapter.
static func record(chapter_id: String, won: bool, towers_lost: int, rounds: int) -> Dictionary:
	if not CampaignData.has_chapter(chapter_id):
		return {}
	_ensure()
	var section = _section(chapter_id)
	var before = seals(chapter_id)
	var was_won = is_won(chapter_id)
	var mask = CampaignData.seals_for(won, towers_lost, rounds, CampaignData.par_rounds(chapter_id))
	_config.set_value(section, "attempts", attempts(chapter_id) + 1)
	if won:
		_config.set_value(section, "won", true)
		_config.set_value(section, "wins", wins(chapter_id) + 1)
		_config.set_value(section, "seals", before | mask)
		var best = best_rounds(chapter_id)
		_config.set_value(section, "best_rounds", rounds if best == 0 else mini(best, rounds))
		if first_won_unix(chapter_id) == 0:
			_config.set_value(section, "first_won_unix", int(Time.get_unix_time_from_system()))
	save()
	var first_win = won and not was_won
	return {"chapter": chapter_id, "won": won, "seals": mask, "new_seals": mask & ~before & CampaignData.ALL_SEALS,
		"first_win": first_win, "unlocked": CampaignData.next_chapter(chapter_id) if first_win else "",
		"rounds": rounds, "towers_lost": towers_lost}

## {"won", "total", "seals", "max_seals", "attempts"} over the campaign's
## chapters (ids it no longer has do not count).
static func progress() -> Dictionary:
	var result = {"won": 0, "total": 0, "seals": 0, "max_seals": 0, "attempts": 0}
	for chapter_id in CampaignData.chapter_ids():
		result.total += 1
		result.max_seals += CampaignData.SEAL_BITS.size()
		result.attempts += attempts(chapter_id)
		if is_won(chapter_id):
			result.won += 1
			result.seals += CampaignData.seal_count(seals(chapter_id))
	return result

# --- Choices -----------------------------------------------------------------------

## The army last taken into `chapter_id`: "preset:<id>", "own:<deck id>" or "".
static func deck_choice(chapter_id: String) -> String:
	return _string("deck", chapter_id)

static func set_deck_choice(chapter_id: String, value: String) -> void:
	_ensure()
	if value.is_empty():
		if _config.has_section_key("deck", chapter_id):
			_config.erase_section_key("deck", chapter_id)
	else:
		_config.set_value("deck", chapter_id, value)
	save()

static func last_chapter() -> String:
	return _string("ui", "last_chapter")

static func set_last_chapter(chapter_id: String) -> void:
	if last_chapter() == chapter_id:
		return
	_config.set_value("ui", "last_chapter", chapter_id)
	save()

static func seen_epilogue() -> bool:
	return _bool("ui", "seen_epilogue")

static func set_seen_epilogue(value: bool = true) -> void:
	_ensure()
	_config.set_value("ui", "seen_epilogue", value)
	save()

# --- Whole progress ----------------------------------------------------------------

## Forgets every result and choice (only the first chapter stays open).
## Refused while read_only (a newer version's progress).
static func reset() -> Error:
	_ensure()
	if read_only:
		return ERR_FILE_NO_PERMISSION
	_config = ConfigFile.new()
	return save()

## Testing and screenshots: every chapter won once, with `seal_mask`.
static func unlock_all(seal_mask: int = CampaignData.SEAL_WIN) -> void:
	_ensure()
	for chapter_id in CampaignData.chapter_ids():
		var section = _section(chapter_id)
		_config.set_value(section, "won", true)
		_config.set_value(section, "wins", maxi(1, wins(chapter_id)))
		_config.set_value(section, "attempts", maxi(1, attempts(chapter_id)))
		_config.set_value(section, "seals", seals(chapter_id) | (seal_mask & CampaignData.ALL_SEALS) | CampaignData.SEAL_WIN)
	save()
