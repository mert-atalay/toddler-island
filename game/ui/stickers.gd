extends CanvasLayer
## The sticker book. The first time she strokes or feeds an animal, its sticker pops up and the
## animal's name is spoken in English (Windows' own voice). Tab, or the controller's View button,
## opens the book; arrows or the stick choose a sticker and her button plays its sound and name.
## Stickers are kept between sessions.

const Models := preload("res://lib/models.gd")
const SAVE := "user://stickers.json"
const KINDS := [
	["cow", "Cow", "res://assets/animals/quaternius/cow.glb"],
	["horse", "Horse", "res://assets/animals/quaternius/horse.glb"],
	["donkey", "Donkey", "res://assets/animals/quaternius/donkey.glb"],
	["pig", "Pig", "res://assets/animals/quaternius/pig.fbx"],
	["hens", "Hen", "res://assets/animals/quaternius/hen.glb"],
	["dog", "Dog", "res://assets/animals/quaternius/dog.glb"],
	["cat", "Cat", "res://assets/animals/quaternius/cat.glb"],
	["sheep", "Sheep", "res://assets/animals/quaternius/lamb.glb"],
	["deer", "Deer", "res://assets/animals/quaternius/deer.glb"],
	["zebra", "Zebra", "res://assets/animals/quaternius/zebra.fbx"],
	["llama", "Llama", "res://assets/animals/quaternius/llama.fbx"],
	["fish", "Fish", "res://assets/kits/fish/Fish2.fbx"],
	["frog", "Frog", "res://assets/kits/extra/frog.glb"],
	["crab", "Crab", "res://assets/kits/extra/crab.glb"],
	["rabbit", "Rabbit", "res://assets/animals/wild/grayrabbit.glb"],
	["squirrel", "Squirrel", "res://assets/animals/wild/squirrel.glb"],
	["duck", "Duck", "res://assets/animals/wild/mallard.glb"],
	["elephant", "Elephant", "res://assets/animals/new/elephant.glb"],
	["giraffe", "Giraffe", "res://assets/animals/new/giraffe.glb"],
	["lion", "Lion", "res://assets/animals/new/lion.glb"],
	["hippo", "Hippo", "res://assets/animals/new/hippo.glb"],
	["rhino", "Rhino", "res://assets/animals/new/rhino.glb"],
	["tiger", "Tiger", "res://assets/animals/new/tiger.glb"],
	["fox", "Fox", "res://assets/animals/new/Fox.glb"],
	["wolf", "Wolf", "res://assets/animals/new/Wolf.glb"],
	["raccoon", "Raccoon", "res://assets/animals/new/Raccoon.glb"],
	["bear", "Bear", "res://assets/animals/new/bearcub.glb"],
	["alpaca", "Alpaca", "res://assets/animals/new/Alpaca.glb"],
	["moon", "Moonshine", "res://assets/kits/space/astronautA.glb"],
]

const COLS := 8

var life: Node3D
var is_open := false
var earned := {}
var selected := 0
var _icons := {}
var _book: Panel
var _cells: Array = []
var _voice := AudioStreamPlayer.new()


func setup(l: Node3D) -> void:
	life = l
	layer = 4
	add_child(_voice)
	earned = life.save.data["stickers"]
	for k in KINDS:
		_icons[k[0]] = _render_icon(k[2], k[0])
	_build_book()


## Draws one animal into a small picture, once, for its sticker.
func _render_icon(path: String, kind: String) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var holder := Models.spawn(vp, path, 1.0, 50.0 if kind != "cat" else -40.0)
	var size: Vector3 = holder.get_meta("size")
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 1.4
	vp.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.environment.ambient_light_energy = 0.8
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	vp.add_child(env)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(size.y, maxf(size.x, size.z)) * 1.15
	cam.position = Vector3(0, size.y * 0.5, 4.0)
	vp.add_child(cam)
	cam.make_current()
	return vp.get_texture()


func _build_book() -> void:
	_book = Panel.new()
	_book.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.99, 0.95, 0.85, 0.97)
	_book.add_theme_stylebox_override("panel", style)
	_book.visible = false
	add_child(_book)
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 14)
	grid.set_anchors_preset(Control.PRESET_CENTER)
	grid.position = Vector2(-750, -400)
	grid.custom_minimum_size = Vector2(1500, 800)
	_book.add_child(grid)
	for i in KINDS.size():
		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(162, 148)
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(1, 1, 1)
		cs.set_corner_radius_all(120)
		cs.border_color = Color(0.9, 0.75, 0.4)
		cs.set_border_width_all(6)
		cell.add_theme_stylebox_override("panel", cs)
		var pic := TextureRect.new()
		pic.texture = _icons[KINDS[i][0]]
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.offset_left = 22
		pic.offset_top = 18
		pic.offset_right = -22
		pic.offset_bottom = -26
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(pic)
		cell.gui_input.connect(func(e: InputEvent) -> void:
			var mb := e as InputEventMouseButton
			if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				selected = i
				press())
		grid.add_child(cell)
		_cells.append([cell, pic, cs])
	_refresh()


func _refresh() -> void:
	for i in _cells.size():
		var got := earned.has(KINDS[i][0])
		var pic: TextureRect = _cells[i][1]
		pic.modulate = Color(1, 1, 1) if got else Color(0.15, 0.13, 0.12, 0.35)
		var cs: StyleBoxFlat = _cells[i][2]
		cs.border_color = Color(0.95, 0.45, 0.4) if i == selected else (Color(1.0, 0.78, 0.15) if KINDS[i][0] == "moon" else Color(0.9, 0.75, 0.4))
		if KINDS[i][0] == "moon":
			cs.bg_color = Color(1.0, 0.93, 0.6) if got else Color(1, 1, 1)
		cs.set_border_width_all(12 if i == selected else 6)


func toggle() -> void:
	is_open = not is_open
	_book.visible = is_open
	_refresh()


func earn(kind: String, quiet := false) -> void:
	if earned.has(kind) or not _icons.has(kind):
		return
	earned[kind] = true
	life.save.data["stickers"] = earned
	life.save.write()
	_refresh()
	# the new sticker pops up in the corner of the screen
	var pop := TextureRect.new()
	pop.texture = _icons[kind]
	pop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pop.size = Vector2(220, 220)
	pop.position = Vector2(get_viewport().get_visible_rect().size.x - 260, 40)
	pop.pivot_offset = Vector2(110, 110)
	pop.scale = Vector2.ZERO
	add_child(pop)
	var tw := create_tween()
	tw.tween_property(pop, "scale", Vector2.ONE * 1.1, 0.35).set_trans(Tween.TRANS_BACK)
	tw.tween_property(pop, "scale", Vector2.ONE, 0.15)
	tw.tween_interval(2.0)
	tw.tween_property(pop, "modulate:a", 0.0, 0.6)
	tw.tween_callback(pop.queue_free)
	if quiet:
		return
	life.sound.play_flat(life.sound.chime, -8.0)
	_say_later(_name_of(kind), 1.2)


func _name_of(kind: String) -> String:
	for k in KINDS:
		if k[0] == kind:
			return k[1]
	return kind


## Says a word in English after a pause (so it follows the animal's own sound).
func _say_later(word: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	var voices := DisplayServer.tts_get_voices_for_language("en")
	if voices.is_empty():
		return
	DisplayServer.tts_speak(word, voices[0], 70, 1.0, 0.85)


## Her button in the book: the chosen animal's sound, then its name.
func press() -> void:
	var kind: String = KINDS[selected][0]
	if not earned.has(kind):
		life.sound.play_flat(life.sound.pop, -10.0)
		return
	var s: AudioStream = life.sound.pick(kind)
	var wait := 0.3
	if s:
		_voice.stream = s
		_voice.play()
		wait = s.get_length() + 0.2
	var cell: Panel = _cells[selected][0]
	cell.pivot_offset = cell.size * 0.5
	var tw := create_tween()
	tw.tween_property(cell, "scale", Vector2.ONE * 1.12, 0.12)
	tw.tween_property(cell, "scale", Vector2.ONE, 0.2)
	_say_later(_name_of(kind), wait)


func move(dir: Vector2i) -> void:
	var col := selected % COLS + dir.x
	var row := selected / COLS + dir.y
	selected = mini(clampi(row, 0, (KINDS.size() - 1) / COLS) * COLS + clampi(col, 0, COLS - 1), KINDS.size() - 1)
	_refresh()


func _process(_delta: float) -> void:
	if is_open:
		life.explorer.busy = 0.3  # she stands still while the book is open


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		match k.keycode:
			KEY_LEFT, KEY_A:
				move(Vector2i(-1, 0))
			KEY_RIGHT, KEY_D:
				move(Vector2i(1, 0))
			KEY_UP, KEY_W:
				move(Vector2i(0, -1))
			KEY_DOWN, KEY_S:
				move(Vector2i(0, 1))
	var jb := event as InputEventJoypadButton
	if jb and jb.pressed:
		match jb.button_index:
			JOY_BUTTON_DPAD_LEFT:
				move(Vector2i(-1, 0))
			JOY_BUTTON_DPAD_RIGHT:
				move(Vector2i(1, 0))
			JOY_BUTTON_DPAD_UP:
				move(Vector2i(0, -1))
			JOY_BUTTON_DPAD_DOWN:
				move(Vector2i(0, 1))
	var jm := event as InputEventJoypadMotion
	if jm and absf(jm.axis_value) > 0.7 and jm.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		move(Vector2i(int(signf(jm.axis_value)), 0) if jm.axis == JOY_AXIS_LEFT_X else Vector2i(0, int(signf(jm.axis_value))))
