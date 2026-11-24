extends Node3D
## Step 1 of the rebuild: every candidate model at its real size, beside a height board and the
## explorer, under the game's lighting. Each animal plays through its animations in turn.
## Mouse: drag to look around, scroll to zoom. Keys 1-7 jump to a row, Tab goes to the next, Esc quits.
## Run with "-- --shots <folder>" to save one picture per row and quit (Claude uses this to check the look).

const SunnyLook := preload("res://look/sunny_look.gd")
const OrbitCamera := preload("res://lineup/orbit_camera.gd")
const Models := preload("res://lib/models.gd")
const EXPLORER := "res://assets/characters/kenney/character-female-b.glb"
const EXPLORER_HEIGHT := 0.95
const ITHAPPY_DIR := "res://assets/animals/ithappy"

var presets: Array = []
var cyclers: Array = []
var shots_dir := ""
var cam: Node3D
var title_label: Label
var help_label: Label
var _skip := RegEx.create_from_string(
	"(?i)(death|die|attack|hit|hurt|fear|shoot|static|wheelchair|drive|fall|pose|clicked|spin|roll|splash|swim|fly|holding|emote-no|kick|melee)")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var k := args.find("--shots")
	if k >= 0 and k + 1 < args.size():
		shots_dir = args[k + 1]
	SunnyLook.apply(self)
	_add_ground()
	_build_rows()
	cam = OrbitCamera.new()
	add_child(cam)
	_add_overlay()
	cam.presets = presets
	cam.go_to(0, true)
	if shots_dir != "":
		_take_shots()


# --- what goes in the lineup -----------------------------------------------------------------
# Each item: [file, name, real height in metres]. Heights are to the top of the head (antlers, roof ridge).

func _row_defs() -> Array:
	var q := "res://assets/animals/quaternius/"
	var y := "res://assets/animals/quirky/"
	var c := "res://assets/characters/kenney/character-"
	var n := "res://assets/nature/quaternius/"
	var b := "res://assets/buildings/quaternius-farm/"
	return [
		{"key": "quaternius", "title": "Quaternius animals: free, the eight you picked",
			"board": 2.5, "step": 0.5, "gap": 0.9, "yaw": 55.0, "items": [
				[q + "cow.glb", "Cow", 1.5], [q + "horse.glb", "Horse", 1.8], [q + "donkey.glb", "Donkey", 1.35],
				[q + "deer.glb", "Stag", 2.0], [q + "sheep.fbx", "Sheep", 0.9], [q + "pig.fbx", "Pig", 0.75],
				[q + "dog.glb", "Dog", 0.75], [q + "cat.glb", "Cat", 0.32]]},
		{"key": "ithappy", "title": "ithappy Animals: free demo of the pack I recommend",
			"board": 2.5, "step": 0.5, "gap": 0.9, "yaw": 55.0, "items": _scan_ithappy(),
			"empty_note": "The ithappy free demo goes here.\nIt needs you to download it: see the chat."},
		{"key": "quirky", "title": "Quirky Series: free sample, shown at farm-animal sizes to judge the look",
			"board": 2.0, "step": 0.5, "gap": 0.9, "yaw": 55.0, "items": [
				[y + "Pudu_Animations.glb", "Pudu, a tiny deer", 0.9], [y + "Colobus_Animations.glb", "Colobus monkey", 0.9],
				[y + "Muskrat_Animations.glb", "Muskrat", 0.55], [y + "Sparrow_Animations.glb", "Sparrow", 0.45],
				[y + "Gecko_Animations.glb", "Gecko", 0.3]]},
		{"key": "explorer", "title": "Explorer candidates: Kenney Mini Characters, free, shown 0.95 m tall",
			"board": 1.5, "step": 0.25, "gap": 0.6, "yaw": 25.0, "explorer": false, "items": [
				[c + "female-a.glb", "A", 0.95], [c + "female-b.glb", "B", 0.95], [c + "female-c.glb", "C", 0.95],
				[c + "female-d.glb", "D", 0.95], [c + "female-e.glb", "E", 0.95], [c + "female-f.glb", "F", 0.95],
				[c + "male-a.glb", "G", 0.95], [c + "male-c.glb", "H", 0.95]]},
		{"key": "trees", "title": "Trees at real size: the first version had them up to 17 m",
			"board": 13.0, "step": 1.0, "gap": 1.5, "yaw": 0.0, "native": true, "label_scale": 1.8, "chunk": 40.0, "items": [
				[n + "CommonTree_1.gltf", "Orchard tree", 5.0], [n + "CommonTree_3.gltf", "Forest tree", 12.0],
				[n + "Pine_2.gltf", "Pine", 11.0]]},
		{"key": "plants", "title": "Bushes, flowers and grass at real size: the first version had them 2 to 5 times too big",
			"board": 1.5, "step": 0.25, "gap": 0.5, "yaw": 0.0, "native": true, "label_scale": 0.8, "chunk": 6.0, "items": [
				[n + "Rock_Medium_1.gltf", "Rock", 1.0], [n + "Bush_Common_Flowers.gltf", "Flowering bush", 1.0],
				[n + "Bush_Common.gltf", "Bush", 0.9], [n + "Fern_1.gltf", "Fern", 0.6],
				[n + "Flower_3_Group.gltf", "Flowers", 0.45], [n + "Flower_4_Group.gltf", "Flowers", 0.5],
				[n + "Grass_Common_Short.gltf", "Grass", 0.3], [n + "Grass_Wispy_Short.gltf", "Grass", 0.35],
				[n + "Clover_1.gltf", "Clover", 0.15], [n + "Mushroom_Common.gltf", "Mushroom", 0.12]]},
		{"key": "buildings", "title": "Farm buildings: Quaternius, free",
			"board": 13.0, "step": 1.0, "gap": 3.0, "yaw": 25.0, "label_scale": 2.6, "chunk": 32.0, "items": [
				[b + "Barn.fbx", "Barn", 9.0], [q + "cow.glb", "Cow", 1.5], [b + "SmallBarn.fbx", "Small barn", 6.0],
				[b + "OpenBarn.fbx", "Open barn", 6.0], [b + "ChickenCoop.fbx", "Chicken coop", 2.4],
				[b + "Well.fbx", "Well", 2.4], [b + "Fence.fbx", "Fence", 1.1], [b + "Silo.fbx", "Silo", 10.0],
				[b + "Windmill.fbx", "Windmill", 12.0]]},
	]


func _scan_ithappy() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(ITHAPPY_DIR):
		return out
	# chicken before chick, so "chicken" files get the hen height
	var heights := {"horse": 1.8, "chicken": 0.45, "chick": 0.15, "dog": 0.7, "deer": 1.7, "cat": 0.32,
		"tiger": 1.1, "penguin": 0.7, "cow": 1.5, "pig": 0.75, "sheep": 0.9, "goat": 0.85, "donkey": 1.35, "duck": 0.4}
	for f in DirAccess.get_files_at(ITHAPPY_DIR):
		var low := f.to_lower()
		if not (low.ends_with(".glb") or low.ends_with(".gltf") or low.ends_with(".fbx")):
			continue
		var h := 1.0
		for key in heights:
			if low.contains(key):
				h = heights[key]
				break
		out.append([ITHAPPY_DIR + "/" + f, f.get_basename(), h])
	return out


# --- building the rows -----------------------------------------------------------------------

## Rows stand side by side along one line, so no row ever blocks the view of another.
var row_labels: Array = []  # per row: the labels shown only while that row is in view
var row_titles: Array = []  # per row: its title, also shown in the overview
var _current_labels: Array = []


var _row_items: Array = []  # per placed model in the current row: {x, w, h}


func _build_rows() -> void:
	var x := 0.0
	for def in _row_defs():
		_current_labels = []
		_row_items = []
		var r := _place_row(def, x)
		row_labels.append(_current_labels)
		var row := row_labels.size() - 1
		var width: float = r["x1"] - r["x0"]
		var top: float = def["board"]
		presets.append({
			"key": def["key"], "title": def["title"], "row": row,
			"target": Vector3((r["x0"] + r["x1"]) * 0.5, top * 0.4, -r["depth"] * 0.25),
			"yaw": 0.0, "pitch": -0.14, "dist": maxf(maxf(width * 0.74, top * 2.3), 3.5)})
		_add_close_presets(def, row, float(def.get("chunk", 8.0)))
		x = r["x1"] + 16.0


## Closer views of a long row, a few models at a time, so details can be judged.
func _add_close_presets(def: Dictionary, row: int, chunk: float) -> void:
	var groups: Array = []
	var cur: Array = []
	for it in _row_items:
		if not cur.is_empty() and it["x"] + it["w"] * 0.5 - (cur[0]["x"] - cur[0]["w"] * 0.5) > chunk:
			groups.append(cur)
			cur = []
		cur.append(it)
	if not cur.is_empty():
		groups.append(cur)
	if groups.size() < 2:
		return
	for g in groups.size():
		var items: Array = groups[g]
		var a: float = items[0]["x"] - items[0]["w"] * 0.5
		var b: float = items[-1]["x"] + items[-1]["w"] * 0.5
		var h := 0.0
		for it in items:
			h = maxf(h, it["h"])
		presets.append({
			"key": "%s-close%d" % [def["key"], g + 1], "title": "%s (close, %d of %d)" % [def["title"], g + 1, groups.size()],
			"row": row, "target": Vector3((a + b) * 0.5, h * 0.55, 0.0), "yaw": 0.0, "pitch": -0.12,
			"dist": maxf(maxf((b - a) * 1.05, h * 2.8), 2.2)})


func _place_row(def: Dictionary, x_start: float) -> Dictionary:
	var items: Array = def["items"].duplicate()
	if def.get("explorer", true):
		items.push_front([EXPLORER, "Explorer", EXPLORER_HEIGHT])
	var label_scale: float = def.get("label_scale", 1.0)
	var gap: float = def["gap"]
	var x := x_start + 0.9 * label_scale
	var depth := 1.0
	var spawned := 0
	for it in items:
		var holder := _spawn(it[0], float(it[2]), float(def.get("yaw", 50.0)))
		if holder == null:
			continue
		spawned += 1
		var size: Vector3 = holder.get_meta("size")
		var info := "%s m" % _fmt(float(it[2]))
		if def.get("native", false) and it[0] != EXPLORER:
			info += ", file %s m" % _fmt(float(holder.get_meta("native")))
		# room for the model and for its label, whichever is wider (the animation name joins the label later)
		var name_px := 0.0046 * label_scale
		var anim_room := 0 if def.get("native", false) or def["key"] == "buildings" else 18
		var label_w := maxf(String(it[1]).length() * 48.0 * 0.5 * name_px,
			(info.length() + anim_room) * 48.0 * 0.5 * 0.0032 * label_scale)
		var w := maxf(size.x, label_w)
		x += w * 0.5
		holder.position = Vector3(x, 0.0, 0.0)
		depth = maxf(depth, size.z)
		var top := size.y + 0.1 + 0.16 * label_scale
		_current_labels.append(_label(String(it[1]), Vector3(x, top + 0.17 * label_scale, 0.0), name_px))
		var info_label := _label(info, Vector3(x, top, 0.0), 0.0032 * label_scale, Color(0.22, 0.36, 0.27))
		info_label.set_meta("info", info)
		_current_labels.append(info_label)
		_setup_animation(holder, info_label)
		_row_items.append({"x": x, "w": w, "h": size.y + 0.4 * label_scale})
		print("[lineup] %s / %s: file %.2f m -> %.2f m, footprint %.2f x %.2f" % [
			def["key"], it[1], holder.get_meta("native"), size.y, size.x, size.z])
		x += w * 0.5 + gap
	var x0 := x_start
	var x1 := maxf(x - gap + 0.4, x_start + 6.0)
	if spawned <= 1 and def.has("empty_note"):
		_current_labels.append(_label(def["empty_note"], Vector3(x_start + 4.5, 1.1, 0.0), 0.006, Color(0.55, 0.25, 0.2)))
		x1 = maxf(x1, x_start + 9.0)
	var back := -depth * 0.5 - 0.4
	_ruler(x0, x1, back, float(def["board"]), float(def["step"]), label_scale)
	var title := _label(def["title"], Vector3(x0, float(def["board"]) + 0.4 * label_scale, back),
		0.0055 * label_scale, Color(0.12, 0.12, 0.12), HORIZONTAL_ALIGNMENT_LEFT)
	row_titles.append(title)
	return {"x0": x0, "x1": x1, "depth": depth + 1.0}


func _spawn(path: String, height: float, yaw_deg: float) -> Node3D:
	return Models.spawn(self, path, height, yaw_deg)


# --- animations: each model plays through its gentle animations in turn --------------------

func _setup_animation(holder: Node3D, label: Label3D) -> void:
	var players := holder.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		label.text = label.get_meta("info", "")
		return
	var player := players[0] as AnimationPlayer
	var names: Array = []
	var seen := {}
	for anim_name in player.get_animation_list():
		var short := _short(anim_name)
		if anim_name == "RESET" or _skip.search(short) != null or seen.has(short.to_lower()):
			continue
		seen[short.to_lower()] = true
		names.append(anim_name)
	if names.is_empty():
		label.text = "%s · no animations" % label.get_meta("info", "")
		return
	names.sort_custom(func(a, b): return _rank(a) < _rank(b))
	for anim_name in names:
		if _loops(anim_name):
			player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	var cycler := {"player": player, "names": names, "i": 0, "t": 0.0, "dur": 3.0, "label": label}
	cyclers.append(cycler)
	_play(cycler)


func _play(cycler: Dictionary) -> void:
	var player: AnimationPlayer = cycler["player"]
	var anim_name: String = cycler["names"][cycler["i"]]
	player.play(anim_name, 0.3)
	var anim := player.get_animation(anim_name)
	var dur := clampf(anim.length, 2.5, 5.0)
	if anim.loop_mode == Animation.LOOP_NONE:
		dur = maxf(anim.length + 0.6, 1.5)
	cycler["dur"] = dur
	cycler["t"] = 0.0
	var count: int = cycler["names"].size()
	var label := cycler["label"] as Label3D
	label.text = "%s · %s (%d of %d)" % [label.get_meta("info", ""), _short(anim_name), cycler["i"] + 1, count]


func _process(delta: float) -> void:
	if shots_dir != "":
		return
	for cycler in cyclers:
		cycler["t"] += delta
		if cycler["t"] >= cycler["dur"]:
			cycler["i"] = (cycler["i"] + 1) % cycler["names"].size()
			_play(cycler)


func _short(anim_name: String) -> String:
	return anim_name.get_slice("|", anim_name.get_slice_count("|") - 1)


func _rank(anim_name: String) -> int:
	var s := _short(anim_name).to_lower()
	if s.contains("idle"):
		return 0
	if s.contains("walk"):
		return 1
	if s.contains("eat") or s.contains("munch") or s.contains("graze"):
		return 2
	if s.contains("sit") or s.contains("lie") or s.contains("sleep"):
		return 3
	if s.contains("run") or s.contains("gallop") or s.contains("sprint"):
		return 4
	return 5


func _loops(anim_name: String) -> bool:
	var s := _short(anim_name).to_lower()
	for word in ["idle", "walk", "run", "gallop", "sprint", "eat", "munch", "graze", "sleep"]:
		if s.contains(word):
			return true
	return false


# --- ground, height boards and labels ------------------------------------------------------

func _add_ground() -> void:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.40, 0.60, 0.27))
	ramp.set_color(1, Color(0.53, 0.70, 0.32))
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = ramp
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.uv1_scale = Vector3(60, 60, 1)
	mat.roughness = 1.0
	mat.uv1_scale = Vector3(600, 600, 1)
	var plane := PlaneMesh.new()
	plane.size = Vector2(6000, 6000)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = mat
	ground.position.x = 120.0
	add_child(ground)


## A striped measuring pole at the left of the row, and faint height lines behind the models.
func _ruler(x0: float, x1: float, z: float, top: float, step: float, label_scale: float) -> void:
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.78, 0.27, 0.22)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.96, 0.95, 0.92)
	var line := StandardMaterial3D.new()
	line.albedo_color = Color(0.25, 0.25, 0.25, 0.28)
	line.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var pole := 0.05 * maxf(1.0, label_scale)
	var h := 0.0
	var i := 0
	while h < top - 0.001:
		_box(Vector3(pole, step, pole), Vector3(x0, h + step * 0.5, z), red if i % 2 == 0 else white)
		h += step
		i += 1
	h = step
	while h <= top + 0.001:
		var whole := absf(h - roundf(h)) < 0.001
		var bar := _box(Vector3(x1 - x0, 0.016 if whole else 0.008, 0.004), Vector3((x0 + x1) * 0.5, h, z), line)
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_current_labels.append(_label("%s m" % _fmt(h), Vector3(x0 - pole - 0.06 * label_scale, h, z),
			0.0034 * label_scale, Color(0.3, 0.28, 0.25), HORIZONTAL_ALIGNMENT_RIGHT))
		h += step


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	add_child(inst)
	return inst


func _label(text: String, pos: Vector3, pixel := 0.0042, color := Color(0.12, 0.12, 0.12),
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = pixel
	l.font_size = 48
	l.outline_size = 14
	l.modulate = color
	l.outline_modulate = Color(1, 1, 1, 0.92)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.horizontal_alignment = align
	l.position = pos
	add_child(l)
	return l


func _fmt(v: float) -> String:
	return ("%.2f" % v).trim_suffix("0").trim_suffix("0").trim_suffix(".")


# --- on-screen help and the picture taker ---------------------------------------------------

func _add_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	title_label = Label.new()
	title_label.position = Vector2(24, 14)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	title_label.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	title_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(title_label)
	help_label = Label.new()
	help_label.position = Vector2(24, 56)
	help_label.add_theme_font_size_override("font_size", 17)
	help_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	help_label.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	help_label.add_theme_constant_override("outline_size", 6)
	help_label.text = "Drag the mouse to look around  ·  scroll to zoom  ·  W A S D to move  ·  keys 1 to %d jump to a group  ·  Tab and Shift+Tab step through close-ups  ·  Esc quits" % row_labels.size()
	help_label.visible = shots_dir == ""
	layer.add_child(help_label)
	cam.preset_changed.connect(_on_preset)


func _on_preset(i: int) -> void:
	title_label.text = "%d. %s" % [i + 1, presets[i]["title"]]
	# only the row in view shows its labels; the overview shows just the row titles
	var row: int = presets[i]["row"]
	for r in row_labels.size():
		for l in row_labels[r]:
			(l as Label3D).visible = r == row
		(row_titles[r] as Label3D).visible = row == -1 or r == row


func _take_shots() -> void:
	get_window().size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(shots_dir)
	for i in presets.size():
		cam.go_to(i, true)
		for f in 45:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := shots_dir.path_join("%02d-%s.png" % [i + 1, presets[i]["key"]])
		img.save_png(path)
		print("[lineup] saved ", path)
	get_tree().quit()
