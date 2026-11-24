extends CanvasLayer
## The title screen: the island in the background, the name, and one big round button. Her button,
## a click, Enter or any controller button starts the day, so nothing happens before you are ready.

signal started

var _root: Control
var showing := true


func _ready() -> void:
	layer = 8
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var veil := ColorRect.new()
	veil.color = Color(1.0, 0.96, 0.85, 0.35)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(veil)
	var title := Label.new()
	title.text = "Toddler Island"
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_color_override("font_outline_color", Color(0.85, 0.45, 0.3))
	title.add_theme_constant_override("outline_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-500, 110)
	title.size = Vector2(1000, 140)
	_root.add_child(title)
	var play := Button.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.7, 0.23)
	style.set_corner_radius_all(110)
	style.border_color = Color(1, 1, 1)
	style.set_border_width_all(10)
	style.shadow_size = 12
	style.shadow_color = Color(0, 0, 0, 0.25)
	for st in ["normal", "hover", "pressed", "focus"]:
		play.add_theme_stylebox_override(st, style)
	play.text = "▶"
	play.add_theme_font_size_override("font_size", 110)
	play.add_theme_color_override("font_color", Color(1, 1, 1))
	play.set_anchors_preset(Control.PRESET_CENTER)
	play.size = Vector2(220, 220)
	play.position = Vector2(-110, -40)
	play.pressed.connect(start)
	_root.add_child(play)


func start() -> void:
	if not showing:
		return
	showing = false
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.8)
	tw.tween_callback(_root.hide)
	started.emit()


func _input(event: InputEvent) -> void:
	if not showing:
		return
	if (event is InputEventKey and event.pressed and not event.echo and event.keycode != KEY_ESCAPE) \
			or (event is InputEventJoypadButton and event.pressed):
		start()
		get_viewport().set_input_as_handled()
