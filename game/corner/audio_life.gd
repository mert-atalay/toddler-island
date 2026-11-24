extends Node
## The island's sound beyond the animals:
##  - footsteps that match the ground: soft grass, crunchy sand, the dirt path, hollow wood on the
##    jetty and the bridges, and soft dust on the Moon;
##  - music the parent picks (parent menu, N, or the controller's Share button): happy cartoon tunes,
##    cosy gentle tunes, adventure tunes like an old console game (Kevin MacLeod, incompetech.com,
##    CC BY 4.0), the music-box lullabies (made note by note), or quiet. After sunset the music turns cosy;
##  - a babbling stream near the water and a soft wind on the windmill hill, fading in and out;
##  - the parent's voice: record a few words in the parent menu ("Well done, sweetheart!") and they
##    play when she finishes an adventure or walks on the Moon.

const Terrain := preload("res://corner/terrain.gd")
const K := "res://assets/sounds/kit/"
const VOICE_PATH := "user://parent_voice.wav"
const RATE := 22050

var corner: Node3D
var life: Node3D
var explorer: CharacterBody3D
var _steps := {}
var _walked := 0.0
var _last := Vector3.ZERO
var _music := AudioStreamPlayer.new()
var _tunes: Array = []
var _tune_i := 0
var _gap := 3.0
## The music styles in the order N cycles through them, with the names shown on screen.
const STYLES := ["happy", "adventure", "cosy", "musicbox", "off"]
const STYLE_NAMES := {"happy": "Happy music", "adventure": "Adventure music", "cosy": "Cosy music", "musicbox": "Music box", "off": "Music off"}
const MUSIC_DIR := "res://assets/music/"
var style := "happy"
var _tracks := {}      # style -> [paths], shuffled
var _track_i := {}     # style -> next index
var _last_track := ""
var _toast: Label
var _stream_snd := AudioStreamPlayer.new()
var _wind_snd := AudioStreamPlayer.new()
var _voice := AudioStreamPlayer.new()
var _mic := AudioStreamPlayer.new()
var _record: AudioEffectRecord
var recording := false
var _task := -1
var _abort := false


## The tunes are made on a worker thread: wait for it before this node goes away.
func _exit_tree() -> void:
	print("[audio] exit: waiting for the tune maker")
	_abort = true
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	print("[audio] exit: done")


func setup(c: Node3D) -> void:
	corner = c
	life = c.life
	explorer = c.explorer
	_last = explorer.global_position
	for kind in ["grass", "wood", "concrete", "snow"]:
		var list: Array = []
		for i in 4:
			var p := K + "footstep_%s_%03d.ogg" % [kind, i]
			if ResourceLoader.exists(p):
				list.append(load(p))
		_steps[kind] = list
	_music.bus = "Music"
	_music.volume_db = -10.0
	add_child(_music)
	_music.finished.connect(func() -> void: _gap = randf_range(8.0, 16.0) if _playing_style() == "musicbox" else randf_range(2.0, 4.0))
	style = str(life.save.setting("music_style", "happy"))
	if not style in STYLES:
		style = "happy"
	for s in ["happy", "adventure", "cosy"]:
		var list: Array = []
		var dir: String = MUSIC_DIR + s + "/"
		for f in ResourceLoader.list_directory(dir):
			if f.ends_with(".mp3") or f.ends_with(".ogg"):
				list.append(dir + f)
		list.shuffle()
		_tracks[s] = list
		_track_i[s] = 0
	var layer := CanvasLayer.new()
	layer.layer = 7
	add_child(layer)
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 34)
	_toast.add_theme_color_override("font_color", Color(1, 1, 1))
	_toast.add_theme_color_override("font_outline_color", Color(0.15, 0.12, 0.1))
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position = Vector2(-160, 40)
	_toast.custom_minimum_size = Vector2(320, 0)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	layer.add_child(_toast)
	for p in [_stream_snd, _wind_snd]:
		p.bus = "Ambience"
		p.volume_db = -60.0
		add_child(p)
	_stream_snd.stream = _noise_loop(0.65, 0.35, 11)
	_wind_snd.stream = _noise_loop(0.985, 0.0, 12)
	_stream_snd.play()
	_wind_snd.play()
	_voice.bus = "Voice"
	add_child(_voice)
	if FileAccess.file_exists(VOICE_PATH):
		_voice.stream = AudioStreamWAV.load_from_file(VOICE_PATH)
	# make the tunes on a worker thread so the island starts at once
	_task = WorkerThreadPool.add_task(_make_tunes)


# --- footsteps --------------------------------------------------------------------------------

func _surface() -> Array:
	var p := explorer.global_position
	if life.trip and life.trip.active:
		return ["snow", 0.7, -16.0]
	var ground := Terrain.height(p.x, p.z)
	if p.y > ground + 0.25:
		return ["wood", 1.0, -12.0]
	if Terrain.path_distance(p.x, p.z) < 1.3:
		return ["concrete", 1.15, -20.0]
	if Terrain.is_sand(p.x, p.z) > 0.6:
		return ["snow", 1.1, -15.0]
	return ["grass", 1.0, -13.0]


func _footsteps() -> void:
	var p := explorer.global_position
	var moved := Vector2(p.x - _last.x, p.z - _last.z).length()
	_last = p
	if not explorer.visible or not explorer.is_physics_processing() or not explorer.is_on_floor() or moved > 1.0:
		return
	_walked += moved
	var flat := Vector2(explorer.velocity.x, explorer.velocity.z).length()
	var stride := 0.62 if flat > 2.9 else 0.48
	if _walked < stride:
		return
	_walked = 0.0
	var s := _surface()
	var list: Array = _steps.get(s[0], [])
	if list.is_empty():
		return
	var pl := AudioStreamPlayer.new()
	pl.stream = list[randi() % list.size()]
	pl.pitch_scale = float(s[1]) * randf_range(0.92, 1.08)
	pl.volume_db = float(s[2])
	pl.bus = "Ambience"
	add_child(pl)
	pl.play()
	pl.finished.connect(pl.queue_free)


# --- places -----------------------------------------------------------------------------------

func _places(delta: float) -> void:
	var p := explorer.global_position
	var away: bool = life.trip != null and life.trip.active
	var near_stream := Terrain.stream_distance(p.x, p.z)
	var want_stream := -60.0 if away else lerpf(-14.0, -60.0, clampf((near_stream - 2.0) / 14.0, 0.0, 1.0))
	var hill := Terrain.height(p.x, p.z)
	var want_wind := -60.0 if away else lerpf(-60.0, -18.0, clampf((hill - 3.0) / 7.0, 0.0, 1.0))
	_stream_snd.volume_db = lerpf(_stream_snd.volume_db, want_stream, 1.0 - exp(-delta * 2.0))
	_wind_snd.volume_db = lerpf(_wind_snd.volume_db, want_wind, 1.0 - exp(-delta * 1.0))


## A two-second loop of filtered noise: smooth = how slowly it wanders (wind), babble = how much it
## bubbles (water).
func _noise_loop(smooth: float, babble: float, seed: int) -> AudioStreamWAV:
	var n := RATE * 3
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var s := PackedFloat32Array()
	s.resize(n)
	var v := 0.0
	var lfo := 0.0
	for i in n:
		v = v * smooth + rng.randf_range(-1.0, 1.0) * (1.0 - smooth)
		lfo = 0.5 + 0.5 * sin(i * 0.0011) * sin(i * 0.00037 + 1.0)
		var bub := 1.0 + babble * (sin(i * 0.031 + sin(i * 0.0007) * 40.0)) * rng.randf()
		s[i] = v * (0.6 + 0.4 * lfo) * bub
	return _to_wav(s, 2000, 0.6)


func _to_wav(s: PackedFloat32Array, xfade: int, level: float) -> AudioStreamWAV:
	var n := s.size()
	if xfade > 0:
		for i in xfade:
			var k := float(i) / xfade
			s[i] = s[i] * k + s[n - xfade + i] * (1.0 - k)
	var peak := 0.0001
	for x in s:
		peak = maxf(peak, absf(x))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(s[i] / peak * level, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if xfade > 0:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = n - xfade
	return w


# --- music box --------------------------------------------------------------------------------

## Note names to semitones above C5.
const NOTE := {"G4": -5, "A4": -3, "B4": -1, "C5": 0, "D5": 2, "E5": 4, "F5": 5, "G5": 7, "A5": 9, "B5": 11, "C6": 12, "D6": 14, "E6": 16, "G6": 19, "C7": 24, "E7": 28, "G7": 31}

## [note, beats]; "-" is a rest.
const TWINKLE := [["C5", 1], ["C5", 1], ["G5", 1], ["G5", 1], ["A5", 1], ["A5", 1], ["G5", 2],
	["F5", 1], ["F5", 1], ["E5", 1], ["E5", 1], ["D5", 1], ["D5", 1], ["C5", 2],
	["G5", 1], ["G5", 1], ["F5", 1], ["F5", 1], ["E5", 1], ["E5", 1], ["D5", 2],
	["G5", 1], ["G5", 1], ["F5", 1], ["F5", 1], ["E5", 1], ["E5", 1], ["D5", 2],
	["C5", 1], ["C5", 1], ["G5", 1], ["G5", 1], ["A5", 1], ["A5", 1], ["G5", 2],
	["F5", 1], ["F5", 1], ["E5", 1], ["E5", 1], ["D5", 1], ["D5", 1], ["C5", 3]]
const BRAHMS := [["E5", 0.5], ["E5", 0.5], ["G5", 2], ["E5", 0.5], ["E5", 0.5], ["G5", 2],
	["E5", 0.5], ["G5", 0.5], ["C6", 1], ["B5", 1.5], ["A5", 0.5], ["A5", 1], ["G5", 1],
	["D5", 0.5], ["E5", 0.5], ["F5", 1], ["D5", 1], ["D5", 0.5], ["E5", 0.5], ["F5", 2],
	["D5", 0.5], ["F5", 0.5], ["B5", 0.5], ["A5", 0.5], ["G5", 1], ["B5", 1], ["C6", 3]]
const HUSH := [["G5", 0.5], ["E5", 0.5], ["E5", 0.5], ["E5", 0.5], ["F5", 0.5], ["E5", 0.5], ["D5", 1],
	["D5", 0.5], ["D5", 0.5], ["D5", 0.5], ["G5", 0.5], ["F5", 0.5], ["E5", 1.5],
	["G5", 0.5], ["G5", 0.5], ["G5", 0.5], ["G5", 0.5], ["A5", 0.5], ["G5", 0.5], ["F5", 0.5], ["E5", 0.5], ["D5", 0.5],
	["C5", 0.5], ["E5", 0.5], ["D5", 0.5], ["C5", 2]]


## Music made once and kept in user://music, so later starts load it at once.
func _cached(name: String, make: Callable) -> AudioStreamWAV:
	var path := "user://music/%s.wav" % name
	if FileAccess.file_exists(path):
		var w := AudioStreamWAV.load_from_file(path)
		if w:
			if name == "space":
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_end = w.data.size() / 2 - int(RATE * 1.5)
			return w
	var made: AudioStreamWAV = make.call()
	if made and not _abort:
		DirAccess.make_dir_recursive_absolute("user://music")
		made.save_to_wav(path)
	return made


func _make_tunes() -> void:
	var tunes := [_cached("twinkle", func() -> AudioStreamWAV: return _render(TWINKLE, 0.5)),
		_cached("brahms", func() -> AudioStreamWAV: return _render(BRAHMS, 0.55)),
		_cached("hush", func() -> AudioStreamWAV: return _render(HUSH, 0.42))]
	var shine := _cached("moonshine", _render_moonshine)
	if _abort:
		return
	call_deferred("_tunes_ready", tunes)
	call_deferred("_shine_ready", shine)
	var space := _cached("space", _render_space)
	if _abort:
		return
	call_deferred("_space_ready", space)


## A fresh copy made here on the main thread: sounds built on the worker thread are only used as data.
func _main_copy(w: AudioStreamWAV) -> AudioStreamWAV:
	if w == null:
		return null
	var c := AudioStreamWAV.new()
	c.format = AudioStreamWAV.FORMAT_16_BITS
	c.mix_rate = w.mix_rate
	c.stereo = false
	c.data = w.data.duplicate()
	var frames := c.data.size() / 2
	if w.loop_mode != AudioStreamWAV.LOOP_DISABLED and w.loop_end > 0:
		c.loop_mode = AudioStreamWAV.LOOP_FORWARD
		c.loop_begin = 0
		c.loop_end = clampi(w.loop_end, 1, frames - 1)
	return c


func _tunes_ready(tunes: Array) -> void:
	_tunes = tunes.map(func(w: AudioStreamWAV) -> AudioStreamWAV: return _main_copy(w))


var _shine: AudioStreamWAV


func _shine_ready(w: AudioStreamWAV) -> void:
	_shine = _main_copy(w)


## The "You are my moonshine" music: soft warm chords rising under a music-box melody, with tiny
## star chimes twinkling over the top. Our own little tune, about eleven seconds long.
const SHINE_MELODY := [["E5", 0.5], ["G5", 0.5], ["C6", 1.0], ["B5", 0.5], ["A5", 0.5], ["G5", 1.0],
	["A5", 0.5], ["C6", 0.5], ["E6", 1.0], ["D6", 2.0], ["E6", 0.5], ["D6", 0.5], ["C6", 3.0]]
const SHINE_CHORDS := [[[0, 4, 7], 2.0], [[-3, 0, 4], 2.0], [[-7, -3, 0], 2.0], [[-5, -1, 2], 2.0], [[0, 4, 7, 12], 3.5]]


func _render_moonshine() -> AudioStreamWAV:
	var total := 12.5
	var count := int(total * RATE)
	var s := PackedFloat32Array()
	s.resize(count)
	# the warm pad: each chord swells in and fades, two slightly detuned voices per note
	var t0 := 0.0
	for ch in SHINE_CHORDS:
		if _abort:
			return null
		var dur: float = ch[1]
		var a := int(t0 * RATE)
		var n := int((dur + 1.2) * RATE)
		for semis in ch[0]:
			var f := 261.63 * pow(2.0, float(semis) / 12.0)
			for i in mini(n, count - a):
				var x := float(i) / RATE
				var env := minf(1.0, x / 0.7) * clampf((dur + 1.2 - x) / 1.2, 0.0, 1.0)
				s[a + i] += env * 0.11 * (sin(TAU * f * x) + sin(TAU * f * 1.004 * x) + 0.3 * sin(TAU * f * 2.0 * x))
		t0 += dur
	# the music-box melody, a little louder
	var mel := _render(SHINE_MELODY, 0.5)
	var md := mel.data
	var offset := int(0.25 * RATE)
	for i in mini(md.size() / 2, count - offset):
		s[offset + i] += md.decode_s16(i * 2) / 32767.0 * 0.75
	# star chimes
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var ct := 0.6
	while ct < total - 1.5:
		var note: String = ["C7", "E7", "G7", "G6", "E6"][rng.randi() % 5]
		var f := 523.25 * pow(2.0, float(NOTE[note]) / 12.0)
		var a := int(ct * RATE)
		for i in mini(int(RATE * 1.2), count - a):
			var x := float(i) / RATE
			s[a + i] += exp(-x * 5.0) * minf(1.0, x * 600.0) * 0.12 * sin(TAU * f * x)
		ct += rng.randf_range(0.25, 0.7)
	# fade the very end
	for i in int(RATE * 1.5):
		s[count - 1 - i] *= float(i) / (RATE * 1.5)
	return _to_wav(s, 0, 0.8)


var _space_snd := AudioStreamPlayer.new()
var _space_on := false


func _space_ready(w: AudioStreamWAV) -> void:
	_space_snd.stream = _main_copy(w)
	if _space_on and not _space_snd.playing:
		_space_snd.play()


## Deep space: a slow ambient loop, 48 seconds. A low drone that breathes, dreamy chords that drift
## from one to the next, a soft cosmic wind, and now and then a far-off twinkle that rings for a long time.
func _render_space() -> AudioStreamWAV:
	var total := 48.0
	var n := int(total * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2001
	# the drone: A1 and E2 with a slow swell
	for i in n:
		var x := float(i) / RATE
		var breathe := 0.75 + 0.25 * sin(TAU * x / 16.0)
		s[i] = breathe * 0.16 * (sin(TAU * 55.0 * x) + 0.6 * sin(TAU * 82.41 * x + 0.3) + 0.25 * sin(TAU * 110.0 * x * 1.002))
	# drifting chords (semitones above A3 = 220 Hz), 12 s each, long crossfades, loops back to the first
	var chords := [[0, 4, 7, 11, 14], [-3, 0, 4, 7, 10], [-7, -3, 0, 4, 9], [-5, -1, 2, 7, 11]]
	for c in chords.size():
		var start := c * 12.0 - 3.0
		for semis in chords[c]:
			if _abort:
				return null
			var fr := 220.0 * pow(2.0, float(semis) / 12.0)
			var a := int(maxf(start, 0.0) * RATE)
			var length := int(18.0 * RATE)
			for k in length:
				var x := start + float(k) / RATE
				var idx := int(fposmod(x, total) * RATE)
				if idx >= n:
					continue
				var t := float(k) / RATE
				var env := sin(PI * clampf(t / 18.0, 0.0, 1.0))
				env *= env
				s[idx] += env * 0.035 * (sin(TAU * fr * t) + sin(TAU * fr * 1.0035 * t) * 0.8 + sin(TAU * fr * 2.0 * t) * 0.15)
	# cosmic wind: slowly wandering filtered noise
	var v := 0.0
	var v2 := 0.0
	for i in n:
		v = v * 0.997 + rng.randf_range(-1.0, 1.0) * 0.003
		v2 = v2 * 0.9 + v * 0.1
		var x := float(i) / RATE
		s[i] += v2 * 2.2 * (0.6 + 0.4 * sin(TAU * x / 11.0))
	# far-off twinkles
	var t := 1.5
	while t < total - 4.0:
		var note: String = ["E6", "G6", "C7", "D6", "A5", "E7"][rng.randi() % 6]
		var fr := 523.25 * pow(2.0, float(NOTE.get(note, 12)) / 12.0)
		var a := int(t * RATE)
		for k in mini(int(RATE * 3.5), n - a):
			var x := float(k) / RATE
			s[a + k] += exp(-x * 1.2) * minf(1.0, x * 200.0) * 0.05 * (sin(TAU * fr * x) + 0.4 * sin(TAU * fr * 2.01 * x))
		t += rng.randf_range(1.8, 4.5)
	return _to_wav(s, int(RATE * 1.5), 0.7)


## Turns the deep-space music on (fading in) or off (fading out); the island music waits meanwhile.
func space_music(on: bool) -> void:
	_space_on = on
	if _space_snd.get_parent() == null:
		_space_snd.bus = "Music"
		add_child(_space_snd)
	var tw := create_tween()
	if on:
		_music.stop()
		if _space_snd.stream == null:
			return
		if not _space_snd.playing:
			_space_snd.volume_db = -40.0
			_space_snd.play()
		tw.tween_property(_space_snd, "volume_db", -4.0, 4.0)
	else:
		tw.tween_property(_space_snd, "volume_db", -40.0, 3.0)
		tw.tween_callback(_space_snd.stop)
		_gap = 4.0


## Plays the moonshine music (the other music pauses for it).
func play_moonshine() -> void:
	if _shine == null:
		_shine = _render_moonshine()
	_music.stop()
	_gap = 30.0
	var p := AudioStreamPlayer.new()
	p.stream = _shine
	p.bus = "Music"
	p.volume_db = -2.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## One tune as a music box: each note a bright tine that rings and fades.
func _render(tune: Array, beat: float) -> AudioStreamWAV:
	var total := 0.0
	for n in tune:
		total += float(n[1]) * beat
	var ring := int(RATE * 1.6)
	var count := int((total + 1.8) * RATE)
	var s := PackedFloat32Array()
	s.resize(count)
	var cache := {}
	var t := 0.0
	for n in tune:
		var name: String = n[0]
		if NOTE.has(name):
			if not cache.has(name):
				var f := 523.25 * pow(2.0, float(NOTE[name]) / 12.0)
				var w := PackedFloat32Array()
				w.resize(ring)
				for i in ring:
					var x := float(i) / RATE
					var env := exp(-x * 3.2) * minf(1.0, x * 400.0)
					w[i] = env * (sin(TAU * f * x) + 0.35 * sin(TAU * f * 2.0 * x) * exp(-x * 6.0) + 0.18 * sin(TAU * f * 5.4 * x) * exp(-x * 14.0))
				cache[name] = w
			var wave: PackedFloat32Array = cache[name]
			var start := int(t * RATE)
			for i in mini(ring, count - start):
				s[start + i] += wave[i]
		t += float(n[1]) * beat
	return _to_wav(s, 0, 0.5)


## What plays now: the chosen style, except that after sunset the lively styles turn cosy.
func _playing_style() -> String:
	var night: bool = life.day != null and life.day.day_fraction() > 0.85
	if night and style in ["happy", "adventure"]:
		return "cosy"
	return style


func _music_tick(delta: float) -> void:
	if _music.playing or _space_on or style == "off":
		return
	_gap -= delta
	if _gap > 0.0:
		return
	var s := _playing_style()
	if s == "musicbox" or (_tracks.get(s, []) as Array).is_empty():
		if _tunes.is_empty():
			return
		var night: bool = life.day != null and life.day.day_fraction() > 0.85
		_music.stream = _tunes[1] if night else _tunes[_tune_i % _tunes.size()]
		_tune_i += 1
		_music.volume_db = -10.0
	else:
		var list: Array = _tracks[s]
		var i: int = _track_i[s]
		if i >= list.size():
			list.shuffle()
			if list.size() > 1 and list[0] == _last_track:
				list.reverse()
			i = 0
		_last_track = list[i]
		_track_i[s] = i + 1
		var st := load(_last_track) as AudioStream
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = false
		_music.stream = st
		_music.volume_db = -15.0 if s != "cosy" else -13.0
	_music.play()


## Picks a music style (saved), fading out what plays now.
func set_style(s: String) -> void:
	if not s in STYLES:
		return
	style = s
	life.save.set_setting("music_style", s)
	_show(STYLE_NAMES[s])
	if _space_on:
		return
	if _music.playing:
		var tw := create_tween()
		tw.tween_property(_music, "volume_db", -45.0, 0.8)
		tw.tween_callback(_music.stop)
	_gap = 1.0


## The next style (N, or the Share button).
func cycle_style() -> void:
	set_style(STYLES[(STYLES.find(style) + 1) % STYLES.size()])


func _show(text: String) -> void:
	_toast.text = "♪  " + text
	var tw := create_tween()
	_toast.modulate.a = 1.0
	tw.tween_interval(1.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.8)


# --- the parent's voice -----------------------------------------------------------------------

func play_voice(delay := 2.6) -> void:
	if _voice.stream == null:
		return
	await get_tree().create_timer(delay).timeout
	_voice.play()


func has_voice() -> bool:
	return _voice.stream != null


## Records five seconds from the microphone and keeps it for the happy moments.
func record_voice() -> void:
	if recording:
		return
	var bus := AudioServer.get_bus_index("Record")
	if bus == -1:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "Record")
		AudioServer.set_bus_volume_db(bus, -80.0)
		_record = AudioEffectRecord.new()
		AudioServer.add_bus_effect(bus, _record)
		_mic.stream = AudioStreamMicrophone.new()
		_mic.bus = "Record"
		add_child(_mic)
	recording = true
	_mic.play()
	_record.set_recording_active(true)
	await get_tree().create_timer(5.0).timeout
	_record.set_recording_active(false)
	_mic.stop()
	recording = false
	var clip := _record.get_recording()
	if clip:
		clip.save_to_wav(VOICE_PATH)
		_voice.stream = clip
		_voice.play()


func _process(delta: float) -> void:
	_footsteps()
	_places(delta)
	_music_tick(delta)
