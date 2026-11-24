extends Node
## The parent's chosen recordings. Calls play from the animal (so "I hear a cow, where is it?"
## works), never the same clip twice in a row; a greeted animal is always clearly audible.

var bank := {}  # animal -> {calls: [AudioStream], ambient: [AudioStream]}
var _last := {}
var chime: AudioStream
var pop: AudioStream


func _ready() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sounds/game.json"))
	for animal in manifest:
		var entry := {"calls": [], "ambient": []}
		for clip in manifest[animal]:
			var path := "res://assets/sounds/" + String(clip["file"]).get_file()
			if not ResourceLoader.exists(path):
				continue
			var stream: AudioStream = load(path)
			(entry["ambient" if clip["kind"] == "ambient" else "calls"] as Array).append(stream)
		bank[animal] = entry
	chime = load("res://assets/sounds/chime.wav")
	pop = load("res://assets/sounds/pop.wav")
	# birdsong under everything, quietly
	var bg: Array = bank.get("background", {}).get("ambient", [])
	if not bg.is_empty():
		var song: AudioStream = bg[0]
		if song is AudioStreamMP3:
			(song as AudioStreamMP3).loop = true
		var p := AudioStreamPlayer.new()
		p.stream = song
		p.volume_db = -14.0
		p.bus = "Ambience"
		p.autoplay = true
		add_child(p)


func pick(animal: String) -> AudioStream:
	var calls: Array = bank.get(animal, {}).get("calls", [])
	if calls.is_empty():
		return null
	var i := randi() % calls.size()
	if calls.size() > 1 and i == _last.get(animal, -1):
		i = (i + 1) % calls.size()
	_last[animal] = i
	return calls[i]


## Plays an animal's call from its position. near = a greeting or a stroke: loud and clear.
func call_from(animal: String, voice: AudioStreamPlayer3D, near: bool) -> float:
	var s := pick(animal)
	if s == null:
		return 0.0
	voice.stream = s
	voice.bus = "Animals"
	voice.unit_size = 8.0 if near else 4.0
	voice.volume_db = 0.0 if near else -6.0
	voice.play()
	return s.get_length()


func play_flat(stream: AudioStream, db := -6.0) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
