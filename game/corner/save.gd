extends RefCounted
## One small save file for everything that should last between sessions: stickers, souvenirs, the
## garden, achievements, adventures done and the parent's settings. Written on every change, with the
## previous copy kept as a backup.

const PATH := "user://save.json"
const BACKUP := "user://save.backup.json"
const VERSION := 1

var data := {
	"version": VERSION, "stickers": {}, "souvenirs": {}, "achievements": {}, "garden": {},
	"eggs": 0, "visit_count": 0, "days": 0,
	"settings": {"session_minutes": 15.0, "volume": {"Master": 0.0, "Music": -6.0, "Ambience": -4.0, "Animals": 0.0, "Voice": 0.0},
		"quiet_launch": false, "child_name": "Mercan", "true_size_earth": false, "real_time_earth": false},
}


func load_or_create() -> void:
	for p in [PATH, BACKUP]:
		if FileAccess.file_exists(p):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
			if parsed is Dictionary:
				_merge(data, parsed)
				break
	# stickers from the first version of the game
	if data["stickers"].is_empty() and FileAccess.file_exists("user://stickers.json"):
		var old = JSON.parse_string(FileAccess.get_file_as_string("user://stickers.json"))
		if old is Dictionary:
			data["stickers"] = old


func write() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(BACKUP))
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func setting(key: String, default = null):
	return data["settings"].get(key, default)


func set_setting(key: String, value) -> void:
	data["settings"][key] = value
	write()


func _merge(into: Dictionary, from: Dictionary) -> void:
	for k in from:
		if into.has(k) and into[k] is Dictionary and from[k] is Dictionary:
			_merge(into[k], from[k])
		else:
			into[k] = from[k]
