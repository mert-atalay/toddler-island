extends CanvasLayer
## The parent's menu: P, or the controller's Start button. Session length (when sunset comes),
## volume, sunset now, a new morning, and clearing the sticker book. Mouse or controller to choose.

var life: Node3D
var _panel: PanelContainer
var _length_label: Label


func setup(l: Node3D) -> void:
	life = l
	layer = 6
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.98, 0.93, 0.97)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-280, -330)
	_panel.custom_minimum_size = Vector2(560, 0)
	_panel.visible = false
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	box.add_child(_text("Parent menu", 30))
	_length_label = _text("", 18)
	box.add_child(_length_label)
	var lengths := HBoxContainer.new()
	for m in [10, 15, 20, 30, 0]:
		var b := Button.new()
		b.text = "%d min" % m if m > 0 else "No sunset"
		b.pressed.connect(func() -> void:
			life.day.session_minutes = float(m)
			life.save.set_setting("session_minutes", float(m))
			_update())
		lengths.add_child(b)
	box.add_child(lengths)
	for bus in ["Master", "Music", "Ambience", "Animals", "Voice"]:
		var row := HBoxContainer.new()
		var name_l := _text({"Master": "All sound", "Music": "Music", "Ambience": "Background", "Animals": "Animals", "Voice": "Voices"}[bus], 16)
		name_l.custom_minimum_size = Vector2(130, 0)
		row.add_child(name_l)
		var vol := HSlider.new()
		vol.min_value = -30.0
		vol.max_value = 6.0
		vol.custom_minimum_size = Vector2(300, 0)
		var idx := AudioServer.get_bus_index(bus)
		vol.value = AudioServer.get_bus_volume_db(idx) if idx >= 0 else 0.0
		vol.value_changed.connect(func(v: float) -> void:
			var i := AudioServer.get_bus_index(bus)
			if i >= 0:
				AudioServer.set_bus_volume_db(i, v)
			var vols: Dictionary = life.save.setting("volume", {})
			vols[bus] = v
			life.save.set_setting("volume", vols))
		row.add_child(vol)
		box.add_child(row)
	box.add_child(_text("Music (or N / the Share button)", 18))
	var styles := HBoxContainer.new()
	for s in ["happy", "adventure", "cosy", "musicbox", "off"]:
		var mb := Button.new()
		mb.text = {"happy": "Happy", "adventure": "Adventure", "cosy": "Cosy", "musicbox": "Music box", "off": "Off"}[s]
		mb.pressed.connect(func() -> void:
			if life.audio:
				life.audio.set_style(s))
		styles.add_child(mb)
	box.add_child(styles)
	for row in [["Sunset now", func() -> void: life.day.sunset_now()],
			["New morning", func() -> void: life.day.new_morning()],
			["Clear the sticker book", func() -> void:
				life.stickers.earned = {}
				life.save.data["stickers"] = life.stickers.earned
				life.save.write()
				life.stickers._refresh()],
			["Record my voice (5 seconds)", func() -> void:
				if life.audio:
					life.audio.record_voice()],
			["Play my voice", func() -> void:
				if life.audio:
					life.audio.play_voice(0.0)],
			["Quiet rocket launch on/off", func() -> void:
				life.save.set_setting("quiet_launch", not life.save.setting("quiet_launch", false))],
			["Close", func() -> void: toggle()]]:
		var b2 := Button.new()
		b2.text = row[0]
		b2.pressed.connect(row[1])
		box.add_child(b2)
	box.add_child(_text("Esc quits the game.", 14))


func _text(s: String, size: int) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.2, 0.18, 0.15))
	return l


func _update() -> void:
	var m: float = life.day.session_minutes
	var left := maxf(0.0, m * 60.0 - life.day.t) / 60.0
	_length_label.text = ("Sunset after %d minutes (about %d left)" % [int(m), ceili(left)]) if m > 0.0 else "No sunset: the day goes on"


func toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_update()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var first := _panel.find_children("*", "Button", true, false)
		if not first.is_empty():
			(first[0] as Button).grab_focus()
	elif get_window().mode == Window.MODE_FULLSCREEN:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func is_open() -> bool:
	return _panel.visible
