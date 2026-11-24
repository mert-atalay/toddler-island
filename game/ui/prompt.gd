extends CanvasLayer
## What her button will do, shown before she presses it. One thing in reach: one rounded card at the
## bottom of the screen with a little picture, the button and a short phrase ("Pick up an apple").
## Several things (or a thing with several choices, like the horse: stroke, feed or ride): up to three
## cards side by side, the chosen one big and glowing. The parent picks with the d-pad left/right (or
## keys 1, 2, 3); her button does the chosen one.
##
## Entries give their phrase with "label" (a String or a Callable returning one), their picture with
## "icon" (a model path), and several choices with "options" (a Callable returning
## [{label, icon, act}]).

const FOOD := {"apple": "res://assets/kits/food/apple.glb", "carrot": "res://assets/kits/food/carrot.glb",
	"seed": "res://assets/kits/food/corn.glb", "hay": "res://assets/kits/food/bread.glb", "ball": "res://assets/kits/picnic/frisbee.gltf"}

var life: Node3D
var _row := HBoxContainer.new()
var _cards: Array = []       # [PanelContainer, TextureRect, Label button, Label text, StyleBoxFlat]
var _choices: Array = []     # [{label, icon, act, pos}]
var _key := ""
var selected := 0
var _icons := {}
var _pad := false


func setup(l: Node3D) -> void:
	life = l
	layer = 3
	_row.add_theme_constant_override("separation", 22)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	for k in 3:
		_cards.append(_make_card())
	_row.visible = false


func _make_card() -> Array:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.98, 0.93, 0.94)
	sb.border_color = Color(1.0, 0.82, 0.4)
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(44)
	sb.content_margin_left = 16
	sb.content_margin_right = 30
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 10
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(70, 70)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(pic)
	var btn := Label.new()
	btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.36, 0.72, 0.3)
	bs.set_corner_radius_all(28)
	btn.add_theme_stylebox_override("normal", bs)
	row.add_child(btn)
	var text := Label.new()
	text.add_theme_font_size_override("font_size", 38)
	text.add_theme_color_override("font_color", Color(0.3, 0.22, 0.14))
	row.add_child(text)
	return [card, pic, btn, text, sb]


func _icon(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	if not _icons.has(path):
		_icons[path] = life.stickers._render_icon(path, "prompt_" + path.get_file())
	return _icons[path]


## The choices her button has right now: [{label, icon, act, pos}], best first. Empty = nothing.
func compute() -> Array:
	var ex: CharacterBody3D = life.explorer
	if life.title and life.title.showing:
		return []
	if life.stickers.is_open or (life.menu and life.menu.is_open()) or life.day.ended:
		return []
	if life.play and (life.play.riding or life.play.board_ui):
		return []
	if life.trip and life.trip.active:
		var t: Array = life.trip.prompt()
		return [] if t[0] == "" else [{"label": t[0], "icon": t[1], "act": Callable(), "pos": ex.global_position}]
	if ex.busy > 0.25:
		return []
	if ex.carrying == "ball":
		return [{"label": "Throw the ball", "icon": FOOD["ball"], "act": Callable(), "pos": ex.global_position}]
	if ex.carrying == "seed":
		return [{"label": "Scatter the seeds", "icon": FOOD["seed"], "act": Callable(), "pos": ex.global_position}]
	if ex.carrying == "kite":
		return [{"label": "Let the kite go home", "icon": "", "act": Callable(), "pos": ex.global_position}]
	var out: Array = []
	for e in life.interact.candidates(3):
		var pos: Vector3 = (e["pos"] as Callable).call()
		if e.has("options"):
			for o in (e["options"] as Callable).call():
				var d: Dictionary = o
				out.append({"label": d["label"], "icon": d.get("icon", e.get("icon", "")), "act": d["act"], "pos": pos})
		else:
			var label: Variant = e.get("label", "")
			if label is Callable:
				label = (label as Callable).call()
			if String(label) == "":
				label = String(e["name"]).capitalize()
			out.append({"label": String(label), "icon": e.get("icon", ""), "act": e["act"], "pos": pos})
		if out.size() >= 3:
			break
	return out.slice(0, 3)


## The chosen one, or {} when there is nothing. Her button calls its "act" (an empty act means her
## button's own handling: throwing the ball, the trip...).
func current() -> Dictionary:
	_refresh(compute())
	if _choices.is_empty():
		return {}
	return _choices[clampi(selected, 0, _choices.size() - 1)]


func choose(i: int) -> void:
	if _choices.size() > 0:
		selected = clampi(i, 0, _choices.size() - 1)
		_show_selection()


func _unhandled_input(event: InputEvent) -> void:
	if _choices.size() < 2:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode in [KEY_1, KEY_2, KEY_3]:
		choose(int(key.keycode - KEY_1))
		get_viewport().set_input_as_handled()
	var pad := event as InputEventJoypadButton
	if pad and pad.pressed and pad.button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		var step := -1 if pad.button_index == JOY_BUTTON_DPAD_LEFT else 1
		choose((selected + step + _choices.size()) % _choices.size())
		life.sound.play_flat(life.sound.pop, -16.0)
		get_viewport().set_input_as_handled()


func _refresh(choices: Array) -> void:
	var key := "|".join(choices.map(func(c: Dictionary) -> String: return c["label"]))
	_choices = choices
	if key == _key:
		return
	var same_first := _key.get_slice("|", 0) == key.get_slice("|", 0)
	_key = key
	if not same_first:
		selected = 0
	selected = clampi(selected, 0, maxi(choices.size() - 1, 0))
	if choices.is_empty():
		var tw := create_tween()
		tw.tween_property(_row, "modulate:a", 0.0, 0.15)
		tw.tween_callback(func() -> void: _row.visible = _key != "")
		return
	for k in 3:
		var c: Array = _cards[k]
		var card: PanelContainer = c[0]
		card.visible = k < choices.size()
		if not card.visible:
			continue
		var tex := _icon(String(choices[k]["icon"]))
		(c[1] as TextureRect).texture = tex
		(c[1] as TextureRect).visible = tex != null
		(c[3] as Label).text = choices[k]["label"]
	_row.visible = true
	_row.modulate.a = 0.0
	create_tween().tween_property(_row, "modulate:a", 1.0, 0.15)
	_show_selection()


func _show_selection() -> void:
	var many := _choices.size() > 1
	for k in _choices.size():
		var c: Array = _cards[k]
		var on := k == selected
		var sb: StyleBoxFlat = c[4]
		sb.border_color = Color(1.0, 0.75, 0.2) if on else Color(0.85, 0.78, 0.65)
		sb.set_border_width_all(7 if on else 3)
		sb.bg_color = Color(1.0, 0.98, 0.93, 0.96 if on else 0.75)
		var btn: Label = c[2]
		btn.visible = on
		(c[3] as Label).add_theme_font_size_override("font_size", 38 if on or not many else 28)
		(c[1] as TextureRect).custom_minimum_size = Vector2(70, 70) if on or not many else Vector2(48, 48)
		(c[0] as PanelContainer).modulate.a = 1.0 if on else 0.8
	_place()


func _place() -> void:
	await get_tree().process_frame
	_row.reset_size()
	var vs := get_viewport().get_visible_rect().size
	_row.position = Vector2((vs.x - _row.size.x) * 0.5, vs.y - _row.size.y - 34.0)


func _process(_delta: float) -> void:
	if Input.get_connected_joypads().size() > 0 != _pad:
		_pad = not _pad
	for c in _cards:
		var btn: Label = c[2]
		btn.text = "A" if _pad else "Space"
		btn.add_theme_font_size_override("font_size", 30 if _pad else 22)
		btn.custom_minimum_size = Vector2(56, 56) if _pad else Vector2(96, 56)
	_refresh(compute())
