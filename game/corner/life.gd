extends Node3D
## Everything alive in the corner: the animals, the food she can carry, her button, the parent's call,
## distant calls, and the soak test that checks the animals over a long run.
##
## Her button: space or almost any other key, A B X Y on the first controller, or any button on a
## second controller. Next to an animal she strokes it, or feeds it if she carries food it likes.
## With the seed bag she scatters seed for the hens. With nothing near she waves and a butterfly comes.
## The parent's call: C, or a shoulder button. Animals look up and come over; the dog always comes.

const Terrain := preload("res://corner/terrain.gd")
const Models := preload("res://lib/models.gd")
const Animal := preload("res://corner/animal.gd")
const SoundBank := preload("res://corner/sound_bank.gd")
const Fx := preload("res://look/fx.gd")
const Jobs := preload("res://corner/jobs.gd")
const Day := preload("res://corner/day.gd")
const Stickers := preload("res://ui/stickers.gd")
const ParentMenu := preload("res://ui/parent_menu.gd")
const Prompt := preload("res://ui/prompt.gd")
const Places := preload("res://corner/places.gd")
const Paths := preload("res://corner/paths.gd")
const Interact := preload("res://corner/interact.gd")
const Save := preload("res://corner/save.gd")
const Title := preload("res://ui/title.gd")
const A := "res://assets/animals/quaternius/"
const P := "res://assets/props/quaternius/"

## The farmyard inside the fence (animals stay in it; the explorer comes in through the gate).
const YARD := Rect2(-23.2, -20.2, 34.4, 20.5)
const HEN_YARD := Rect2(4.2, -18.0, 7.0, 9.6)
const ANYWHERE := Rect2(-50.0, -70.0, 160.0, 150.0)
const ORCHARD_FIELD := Rect2(54.0, -32.0, 18.0, 16.0)
const WOOD := Rect2(66.0, -30.0, 28.0, 56.0)
const VISITOR_FIELD := Rect2(-13.0, -40.0, 14.0, 10.0)
## The safari plain (round the waterhole) and the treehouse camp in the wood.
const SAFARI_FIELD := Rect2(-49.0, 27.0, 33.0, 30.0)
const CAMP_FIELD := Rect2(85.0, -21.0, 20.0, 22.0)
const W := "res://assets/animals/new/"
## Shady spots the safari and camp animals rest in (under the acacias, by the treehouse).
const SAFARI_SHADE := [Vector2(-40.0, 34.0), Vector2(-28.0, 31.0), Vector2(-44.0, 48.0), Vector2(-33.0, 53.0)]
const CAMP_SHADE := [Vector2(90.0, -16.0), Vector2(101.0, -4.0), Vector2(99.0, -17.0)]

var SPECIES := {
	"cow": {"file": A + "cow.glb", "height": 1.5, "speed": 0.8, "run_speed": 1.6, "radius": 0.7,
		"likes": ["hay", "apple", "grass"], "herd": "cows", "sound": "cow", "area": YARD, "home": Vector2(-7.0, -4.8)},
	"horse": {"file": A + "horse.glb", "height": 1.8, "speed": 1.0, "run_speed": 2.4, "radius": 0.6,
		"likes": ["apple", "carrot", "grass"], "herd": "horses", "sound": "horse", "area": YARD, "home": Vector2(-3.0, -4.8)},
	"donkey": {"file": A + "donkey.glb", "height": 1.35, "speed": 0.85, "run_speed": 1.9, "radius": 0.5,
		"likes": ["carrot", "apple", "grass"], "herd": "horses", "sound": "donkey", "area": YARD, "home": Vector2(-10.5, -4.8)},
	"pig": {"file": A + "pig.fbx", "height": 0.75, "speed": 0.0, "radius": 0.55,
		"likes": ["apple", "carrot"], "sound": "pig", "drinks": false, "area": YARD},
	"hen": {"file": A + "hen2.glb", "height": 0.42, "speed": 0.55, "run_speed": 1.3, "radius": 0.2,
		"likes": ["seed"], "herd": "hens", "sound": "hens", "walk_anim_scale": 0.55, "drinks": false, "area": HEN_YARD, "home": Vector2(7.5, -13.2)},
	"cat": {"file": A + "cat.glb", "height": 0.32, "speed": 0.0, "radius": 0.25, "yaw_offset": -PI / 2,
		"likes": [], "sound": "cat", "drinks": false, "area": ANYWHERE},
	"sheep": {"file": A + "lamb.glb", "height": 0.9, "speed": 0.5, "run_speed": 1.2, "radius": 0.5,
		"likes": ["apple", "grass"], "herd": "sheep", "sound": "sheep", "drinks": false, "area": ORCHARD_FIELD},
	"lamb": {"file": A + "lamb.glb", "height": 0.55, "speed": 0.6, "run_speed": 1.4, "radius": 0.3, "mother": "sheep",
		"likes": ["apple", "grass"], "sound": "sheep", "drinks": false, "area": ORCHARD_FIELD},
	"calf": {"file": A + "cow.glb", "height": 0.95, "speed": 0.9, "run_speed": 1.7, "radius": 0.45, "mother": "cow",
		"likes": ["hay", "apple", "grass"], "sound": "cow", "area": YARD, "home": Vector2(-7.0, -4.8)},
	"foal": {"file": A + "white_horse.glb", "height": 1.15, "speed": 1.0, "run_speed": 2.2, "radius": 0.4, "mother": "horse",
		"likes": ["apple", "carrot", "grass"], "sound": "horse", "area": YARD, "home": Vector2(-3.0, -4.8)},
	"doe": {"file": A + "doe.glb", "height": 1.6, "speed": 0.8, "run_speed": 2.0, "radius": 0.55, "herd": "deer",
		"likes": ["apple", "carrot"], "sound": "deer", "drinks": false, "area": WOOD},
	"fawn": {"file": A + "doe.glb", "height": 0.95, "speed": 0.9, "run_speed": 2.0, "radius": 0.35, "mother": "doe",
		"likes": ["apple", "carrot"], "sound": "deer", "drinks": false, "area": WOOD},
	"zebra": {"file": A + "zebra.fbx", "height": 1.45, "speed": 0.0, "radius": 0.6,
		"likes": ["apple", "carrot"], "sound": "horse", "sticker": "zebra", "drinks": false, "area": VISITOR_FIELD},
	"llama": {"file": A + "llama.fbx", "height": 1.7, "speed": 0.0, "radius": 0.55,
		"likes": ["apple", "carrot"], "sound": "", "sticker": "llama", "drinks": false, "area": VISITOR_FIELD},

	# the safari plain (still models rigged and animated in code, lib/autorig.gd)
	"elephant": {"file": W + "elephant.glb", "height": 2.8, "speed": 0.55, "run_speed": 1.1, "radius": 1.4,
		"sticker": "elephant", "likes": ["apple", "carrot"], "herd": "elephants", "sound": "elephant", "drinks": false, "area": SAFARI_FIELD, "shade": SAFARI_SHADE},
	"baby elephant": {"file": W + "elephant.glb", "height": 1.45, "speed": 0.65, "run_speed": 1.3, "radius": 0.75, "mother": "elephant",
		"sticker": "elephant", "likes": ["apple", "carrot"], "sound": "elephant", "pitch": 1.35, "drinks": false, "area": SAFARI_FIELD, "shade": SAFARI_SHADE},
	"giraffe": {"file": W + "giraffe.glb", "height": 4.3, "speed": 0.7, "run_speed": 1.6, "radius": 0.8,
		"sticker": "giraffe", "likes": ["apple"], "herd": "giraffes", "sound": "", "drinks": false, "area": SAFARI_FIELD, "shade": SAFARI_SHADE},
	"baby giraffe": {"file": W + "giraffe.glb", "height": 2.4, "speed": 0.8, "run_speed": 1.7, "radius": 0.5, "mother": "giraffe",
		"sticker": "giraffe", "likes": ["apple"], "sound": "", "drinks": false, "area": SAFARI_FIELD, "shade": SAFARI_SHADE},
	"lion": {"file": W + "lion.glb", "height": 1.3, "speed": 0.7, "run_speed": 2.0, "radius": 0.65,
		"sticker": "lion", "likes": [], "herd": "lions", "sound": "lion", "drinks": false, "area": SAFARI_FIELD, "shade": SAFARI_SHADE},
	"lion cub": {"file": W + "lion.glb", "height": 0.62, "speed": 0.8, "run_speed": 2.0, "radius": 0.35, "mother": "lion",
		"sticker": "lion", "likes": [], "sound": "lion", "pitch": 1.7, "drinks": false, "area": SAFARI_FIELD, "shade": SAFARI_SHADE},
	"hippo": {"file": W + "hippo.glb", "height": 1.55, "speed": 0.4, "run_speed": 0.9, "radius": 1.1,
		"sticker": "hippo", "likes": ["apple", "carrot", "grass"], "sound": "bear", "pitch": 0.8, "drinks": false, "area": SAFARI_FIELD,
		"shade": [Vector2(-27.0, 47.0), Vector2(-21.0, 41.5), Vector2(-15.0, 51.0)]},
	"rhino": {"file": W + "rhino.glb", "height": 1.7, "speed": 0.5, "run_speed": 1.2, "radius": 1.0,
		"sticker": "rhino", "likes": ["apple", "carrot", "grass"], "sound": "bear", "pitch": 0.9, "drinks": false, "area": SAFARI_FIELD, "shade": SAFARI_SHADE},
	"tiger": {"file": W + "tiger.glb", "height": 1.15, "speed": 0.7, "run_speed": 2.0, "radius": 0.6,
		"sticker": "tiger", "likes": [], "sound": "lion", "pitch": 1.15, "drinks": false, "area": SAFARI_FIELD, "shade": SAFARI_SHADE},
	# the treehouse camp in the wood (fox, wolf and raccoon come animated; the bear cub is rigged)
	"fox": {"file": W + "Fox.glb", "height": 0.62, "speed": 0.9, "run_speed": 2.4, "radius": 0.35,
		"sticker": "fox", "likes": ["apple"], "herd": "foxes", "sound": "fox", "drinks": false, "area": CAMP_FIELD, "shade": CAMP_SHADE},
	"wolf": {"file": W + "Wolf.glb", "height": 0.85, "speed": 0.9, "run_speed": 2.4, "radius": 0.45,
		"sticker": "wolf", "likes": ["apple"], "sound": "wolf", "drinks": false, "area": CAMP_FIELD, "shade": CAMP_SHADE},
	"raccoon": {"file": W + "Raccoon.glb", "height": 0.5, "speed": 0.7, "run_speed": 1.8, "radius": 0.3,
		"sticker": "raccoon", "likes": ["apple", "carrot"], "sound": "", "drinks": false, "area": CAMP_FIELD, "shade": CAMP_SHADE},
	"bear cub": {"file": W + "bearcub.glb", "height": 0.95, "speed": 0.55, "run_speed": 1.3, "radius": 0.5,
		"sticker": "bear", "likes": ["apple"], "sound": "bear", "pitch": 1.5, "drinks": false, "area": CAMP_FIELD, "shade": CAMP_SHADE},
	"alpaca": {"file": W + "Alpaca.glb", "height": 1.7, "speed": 0.7, "run_speed": 1.6, "radius": 0.55,
		"likes": ["apple", "carrot"], "sound": "", "sticker": "alpaca", "drinks": false, "area": VISITOR_FIELD},
	"stag": {"file": A + "deer.glb", "height": 2.0, "speed": 0.9, "run_speed": 2.0, "radius": 0.6,
		"likes": ["apple", "carrot"], "herd": "deer", "sound": "deer", "drinks": false, "area": WOOD},
	"dog": {"file": A + "dog.glb", "height": 0.75, "speed": 1.4, "run_speed": 3.0, "radius": 0.35,
		"likes": [], "companion": true, "sound": "dog", "drinks": false, "area": ANYWHERE, "home": Terrain.COTTAGE + Vector2(6.0, 0.0)},
}

var corner: Node3D
var paths := Paths.new()
var save := Save.new()
var interact: Node3D
var title: CanvasLayer
var jobs: Node3D
var day: Node
var stickers: CanvasLayer
var menu: CanvasLayer
var _said := {}  # when each animal's name was last spoken
var explorer: CharacterBody3D
var sound: Node
var fx: Node3D
var animals: Array = []
var places := {"water": [Vector2(2.6, -4.7), Vector2(2.6, -1.7)], "shade": [Vector2(1.8, -9.5), Vector2(-12.5, -5.8)]}
var seed_spots: Array = []     # [Vector2, time left]
var food_sources: Array = []   # [kind, Vector2, radius]
var _seed_mm: MultiMeshInstance3D
var _last_greet := -99.0
var _distant_t := 20.0
var _pickup_cool := 0.0
var _clock := 0.0


func build(c: Node3D, ex: CharacterBody3D) -> void:
	corner = c
	explorer = ex
	save.load_or_create()
	_volume_groups()
	interact = Interact.new()
	interact.explorer = ex
	add_child(interact)
	sound = SoundBank.new()
	add_child(sound)
	fx = Fx.new()
	add_child(fx)
	_food()
	paths.build(corner)
	paths.set_gate(Vector2(-1.6, 1.0), Vector2(1.6, 1.0), false)
	_spawn("cow", Vector2(-2.5, -3.0), 200.0)
	_spawn("cow", Vector2(0.2, -1.5), 160.0)
	_spawn("horse", Vector2(8.0, -2.5), 250.0)
	_spawn("donkey", Vector2(9.5, -4.5), 230.0)
	_spawn("pig", Vector2(-11.8, -2.2), 120.0)
	_spawn("hen", Vector2(6.0, -13.0), 20.0)
	_spawn("hen", Vector2(9.5, -13.5), 140.0)
	_spawn("hen", Vector2(8.6, -15.5), 300.0)
	_spawn("dog", Terrain.START + Vector2(2.0, 1.5), 180.0)
	_spawn("cat", Terrain.COTTAGE + Vector2(-1.4, -3.3), 180.0)
	_spawn("sheep", Terrain.ORCHARD + Vector2(-2.0, -1.5), 60.0)
	_spawn("sheep", Terrain.ORCHARD + Vector2(3.5, -2.5), 250.0)
	_spawn("stag", Terrain.OAK + Vector2(-6.0, -7.0), 200.0)
	_spawn("doe", Terrain.OAK + Vector2(-3.0, -11.0), 120.0)
	_spawn("fawn", Terrain.OAK + Vector2(-1.5, -10.0), 140.0)
	_spawn("lamb", Terrain.ORCHARD + Vector2(-1.0, -0.5), 60.0)
	_spawn("lamb", Terrain.ORCHARD + Vector2(4.5, -1.5), 200.0)
	_spawn("calf", Vector2(-1.0, -1.5), 180.0)
	_spawn("foal", Vector2(7.0, -3.0), 240.0)
	visitor_day(0)
	food_sources.append(["apple", Terrain.ORCHARD + Vector2(-7.5, 0.5), 0.6])
	food_sources.append(["apple", Terrain.ORCHARD + Vector2(2.5, 6.0), 0.7])
	food_sources.append(["carrot", Terrain.COTTAGE + Vector2(-5.5, -4.6), 2.2])
	_small_life()
	jobs = Jobs.new()
	add_child(jobs)
	jobs.build(self)
	day = Day.new()
	add_child(day)
	day.setup(corner, self)
	for m in Places.glows:
		day.add_glow(m)
	stickers = Stickers.new()
	add_child(stickers)
	stickers.setup(self)
	menu = ParentMenu.new()
	add_child(menu)
	menu.setup(self)
	prompt = Prompt.new()
	add_child(prompt)
	prompt.setup(self)
	day.session_minutes = float(save.setting("session_minutes", 15.0))
	var args := OS.get_cmdline_user_args()
	if not (args.has("--shots") or args.has("--bench") or args.has("--soak") or args.has("--trip") or args.has("--audit") or args.has("--moonshine-test") or args.has("--play-test") or args.has("--review") or args.has("--trip-full") or args.has("--quit-test") or args.has("--toy-test")):
		title = Title.new()
		add_child(title)


var visitor: Node3D
var trip: Node3D  # the trip to the Moon, set by the corner
var prompt: CanvasLayer  # what her button will do (ui/prompt.gd)
var play: Node    # toys, activities, the board (corner/play.gd)
var audio: Node   # footsteps, music box, the parent's voice (corner/audio_life.gd)
var visit_count := 0


## A different zoo animal stays in the visitor field each day (each new morning).
func visitor_day(n: int) -> void:
	visit_count = n
	if visitor:
		animals.erase(visitor)
		visitor.queue_free()
	var kinds := ["zebra", "alpaca"]
	_spawn(kinds[n % kinds.size()], Terrain.VISITOR, 180.0)
	visitor = animals[-1]


func mother_of(baby: Node) -> Node3D:
	var kind: String = baby.cfg["mother"]
	var best: Node3D = null
	for a in animals:
		if a != baby and a.get_meta("kind", "") == kind:
			if best == null or a.pos2().distance_to(baby.pos2()) < best.pos2().distance_to(baby.pos2()):
				best = a
	return best


func _spawn(kind: String, at: Vector2, yaw_deg: float) -> void:
	var cfg: Dictionary = SPECIES[kind]
	var a := Animal.new()
	add_child(a)
	a.name = kind.capitalize() + str(animals.size())
	a.position = Vector3(at.x, Terrain.height(at.x, at.y), at.y)
	a.yaw = deg_to_rad(yaw_deg)
	var holder := Models.spawn(a, cfg["file"], cfg["height"], 0.0)
	a.set_meta("kind", kind)
	a.setup(holder, cfg, self)
	var wanted := ""
	for f in cfg["likes"]:
		if f != "grass":
			wanted = f
			break
	if wanted != "":
		a.bubble = fx.want_bubble(_food_model(wanted, 0.22))
		a.add_child(a.bubble)
	animals.append(a)
	interact.register({"name": kind, "pos": func() -> Vector3: return a.global_position,
		"reach": float(cfg["radius"]) + 1.7, "act": func() -> String: return _press_animal(a), "sparkle": false,
		"label": func() -> String: return _animal_label(a), "icon": cfg["file"],
		"options": func() -> Array: return _animal_options(a),
		"when": func() -> bool: return is_instance_valid(a) and a.is_inside_tree()})


# --- food -----------------------------------------------------------------------------------

func _food() -> void:
	# hay bales by the barn doors, the seed sack by the coop; apples under the tree, carrots by the cart
	for h in [[Vector3(-3.6, 0, -5.4), 10.0], [Vector3(-4.5, 0, -6.1), -15.0], [Vector3(-4.0, 0.46, -5.75), 80.0]]:
		_hay_bale(h[0], h[1])
	corner.blocked.append([Vector2(-4.0, -5.8), 1.1])
	food_sources.append(["hay", Vector2(-4.0, -5.8), 1.2])
	var sack := Models.spawn(self, P + "Bag.gltf", 0.6, 20.0)
	sack.position = Vector3(4.6, Terrain.height(4.6, -7.4), -7.4)
	corner.blocked.append([Vector2(4.6, -7.4), 0.5])
	food_sources.append(["seed", Vector2(4.6, -7.4), 0.6])
	food_sources.append(["apple", Vector2(6.2, 8.9), 0.6])   # the apple crate
	food_sources.append(["apple", Vector2(9.4, 5.8), 0.7])   # the apple barrel
	food_sources.append(["carrot", Vector2(-4.4, 5.0), 0.6]) # the carrot crate
	# a mud patch for the pig
	var mud := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.7
	disc.bottom_radius = 1.7
	disc.height = 0.04
	disc.radial_segments = 24
	mud.mesh = disc
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.36, 0.25, 0.16)
	mm.roughness = 0.35
	mud.material_override = mm
	mud.position = Vector3(-11.8, Terrain.height(-11.8, -2.2) + 0.0, -2.2)
	add_child(mud)
	# scattered seed is drawn as little grains
	var grain := SphereMesh.new()
	grain.radius = 0.018
	grain.height = 0.03
	grain.radial_segments = 6
	grain.rings = 3
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.93, 0.8, 0.42)
	grain.material = gm
	_seed_mm = MultiMeshInstance3D.new()
	_seed_mm.multimesh = MultiMesh.new()
	_seed_mm.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_seed_mm.multimesh.mesh = grain
	add_child(_seed_mm)


func _hay_bale(at: Vector3, yaw_deg: float) -> void:
	var tex := NoiseTexture2D.new()
	var n := FastNoiseLite.new()
	n.frequency = 0.25
	n.fractal_octaves = 2
	tex.noise = n
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.78, 0.63, 0.30))
	ramp.set_color(1, Color(0.95, 0.83, 0.48))
	tex.color_ramp = ramp
	tex.width = 128
	tex.height = 32
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 1.0
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.46, 0.55)
	var m := MeshInstance3D.new()
	m.mesh = box
	m.material_override = mat
	m.position = Vector3(at.x, Terrain.height(at.x, at.z) + 0.23 + at.y, at.z)
	m.rotation_degrees.y = yaw_deg
	add_child(m)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = box.size
	shape.shape = bs
	body.add_child(shape)
	m.add_child(body)


## A small model of a food, for her hand or for a "wants" bubble.
func _food_model(kind: String, size: float) -> Node3D:
	var root := Node3D.new()
	add_child(root)  # models measure themselves while in the world; taken out again below
	match kind:
		"apple":
			var s := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = size * 0.5
			sm.height = size
			s.mesh = sm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.85, 0.13, 0.1)
			mat.roughness = 0.4
			s.material_override = mat
			root.add_child(s)
			var stem := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = size * 0.04
			cm.bottom_radius = size * 0.04
			cm.height = size * 0.35
			stem.mesh = cm
			var sm2 := StandardMaterial3D.new()
			sm2.albedo_color = Color(0.35, 0.22, 0.1)
			stem.material_override = sm2
			stem.position.y = size * 0.55
			root.add_child(stem)
		"carrot":
			var c := Models.spawn(root, P + "Carrot.gltf", size, 0.0)
			if c:
				c.rotation_degrees.z = 50.0
		"seed":
			Models.spawn(root, P + "Bag.gltf", size, 0.0)
		"hay":
			var h := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(size * 1.4, size * 0.7, size * 0.8)
			h.mesh = b
			var hm := StandardMaterial3D.new()
			hm.albedo_color = Color(0.9, 0.77, 0.4)
			h.material_override = hm
			root.add_child(h)
	remove_child(root)
	return root


func scatter_seed(at: Vector3) -> void:
	for i in 7:
		var a := randf() * TAU
		var r := randf_range(0.5, 1.6)
		seed_spots.append([Vector2(at.x + cos(a) * r, at.z + sin(a) * r), 14.0])
	_redraw_seed()
	for an in animals:
		if an.likes("seed") and an.state not in ["happy", "eat_hand"]:
			an._choose()


func nearest_seed(p: Vector2) -> Vector2:
	var best := Vector2.INF
	for s in seed_spots:
		if (s[0] as Vector2).distance_to(p) < best.distance_to(p):
			best = s[0]
	return best


func _redraw_seed() -> void:
	var mm := _seed_mm.multimesh
	mm.instance_count = seed_spots.size() * 6
	var i := 0
	for s in seed_spots:
		var c: Vector2 = s[0]
		for k in 6:
			var x := c.x + randf_range(-0.25, 0.25)
			var z := c.y + randf_range(-0.25, 0.25)
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, Terrain.height(x, z) + 0.01, z)))
			i += 1


# --- the world as animals see it ------------------------------------------------------------

func herd_centre(me: Node) -> Vector2:
	var herd: String = me.cfg.get("herd", "")
	if herd == "":
		return Vector2.INF
	var sum := Vector2.ZERO
	var n := 0
	for a in animals:
		if a != me and a.cfg.get("herd", "") == herd:
			sum += a.pos2()
			n += 1
	return sum / n if n > 0 else Vector2.INF


func clamp_to_area(p: Vector2, area: Rect2) -> Vector2:
	return Vector2(clampf(p.x, area.position.x, area.end.x), clampf(p.y, area.position.y, area.end.y))


func free_spot_near(p: Vector2, r: float, area: Rect2) -> Vector2:
	for i in 14:
		var q := clamp_to_area(p + Vector2(randf_range(-r, r), randf_range(-r, r)), area.grow(-0.7))
		if _clear(q, 0.6) and Terrain.height(q.x, q.y) > 0.3:
			return q
	return p


func _clear(q: Vector2, margin: float) -> bool:
	for b in corner.blocked:
		if q.distance_to(b[0]) < float(b[1]) + margin:
			return false
	return true


## Steering help: push away from things in the way and slide round them; keep apart from other animals.
func avoid(here: Vector2, r: float, me: Node, dir: Vector2) -> Vector2:
	var push := Vector2.ZERO
	for b in corner.blocked:
		var c: Vector2 = b[0]
		var d := here - c
		var dist := d.length()
		var reach := float(b[1]) + r + 0.7
		if dist < reach and dist > 0.001:
			var away := d / dist
			var side := away.orthogonal()
			if side.dot(dir) < 0.0:
				side = -side
			push += (away * 0.7 + side * 0.9) * ((reach - dist) / reach) * 2.0
	for a in animals:
		if a == me:
			continue
		var d2: Vector2 = here - a.pos2()
		var reach2: float = r + float(a.cfg["radius"]) + 0.35
		if d2.length() < reach2 and d2.length() > 0.001:
			push += d2.normalized() * (reach2 - d2.length()) / reach2 * 1.5
	var ex := Vector2(explorer.global_position.x, explorer.global_position.z)
	var d3 := here - ex
	if d3.length() < r + 0.6 and d3.length() > 0.001:
		push += d3.normalized() * 1.5
	return push


func can_greet() -> bool:
	return _clock - _last_greet > 4.0


func greeted() -> void:
	_last_greet = _clock


# --- her button and the parent's call ------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if trip and trip.active:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		if key.keycode == KEY_P:
			menu.toggle()
		elif menu.is_open():
			return
		elif key.keycode == KEY_TAB:
			stickers.toggle()
		elif key.keycode == KEY_C:
			parent_call()
		elif key.keycode == KEY_N:
			if audio:
				audio.cycle_style()
		elif not _parent_key(key.keycode):
			her_button()
		return
	var pad := event as InputEventJoypadButton
	if pad and pad.pressed:
		if pad.device == 0 and pad.button_index == JOY_BUTTON_START:
			menu.toggle()
		elif menu.is_open():
			return
		elif pad.device == 0 and pad.button_index == JOY_BUTTON_BACK:
			stickers.toggle()
		elif pad.device == 0 and pad.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			parent_call()
		elif pad.device == 0 and pad.button_index == JOY_BUTTON_MISC1:
			if audio:
				audio.cycle_style()
		elif pad.device != 0 or pad.button_index <= JOY_BUTTON_Y:
			her_button()


func _parent_key(k: Key) -> bool:
	return k in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SHIFT, KEY_Q, KEY_E,
		KEY_ESCAPE, KEY_TAB, KEY_ALT, KEY_CTRL, KEY_META, KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6,
		KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F11, KEY_F12, KEY_CAPSLOCK, KEY_P, KEY_C, KEY_H, KEY_M, KEY_T, KEY_N, KEY_1, KEY_2, KEY_3]


func her_button() -> String:
	if day.ended:
		day.new_morning()
		return "new morning"
	if stickers.is_open:
		stickers.press()
		return "sticker"
	if title and title.showing:
		return "title"
	if explorer.busy > 0.25:
		return "busy"
	if explorer.carrying == "ball":
		jobs.throw_ball()
		explorer.act("interact-right", 0.8)
		return "threw the ball"
	if explorer.carrying == "kite" and play:
		return play.drop_kite()
	if explorer.carrying == "seed":
		explorer.act("interact-left", 1.0)
		scatter_seed(explorer.global_position + explorer.forward() * 0.8)
		sound.play_flat(sound.pop, -10.0)
		return "scattered seed"
	var best: Dictionary = prompt.current() if prompt else {}
	if not best.is_empty() and (best["act"] as Callable).is_valid():
		explorer.face(best["pos"])
		var r: String = (best["act"] as Callable).call()
		if r != "":
			events_said(r)
			return r
	explorer.act("emote-yes", 1.0)
	fx.butterfly(explorer.global_position, explorer.facing)
	sound.play_flat(sound.chime, -8.0)
	return "butterfly"


## What her button will do with this animal, for the prompt.
func _animal_label(a: Node) -> String:
	var kind: String = a.get_meta("kind", "")
	var nice: String = {"hen": "hen", "calf": "calf", "foal": "foal", "lamb": "lamb", "fawn": "fawn", "stag": "deer", "doe": "deer"}.get(kind, kind)
	if explorer.carrying != "" and a.likes(explorer.carrying):
		return "Feed the %s" % nice
	var presses: Array = (a.get_meta("presses", []) as Array).filter(func(t: float) -> bool: return _clock - t < 25.0)
	if presses.size() >= 2:
		return "Ride the %s!" % nice if kind in ["horse", "donkey"] else "Give the %s a big hug!" % nice
	return "Stroke the %s" % nice


## What she can do with this animal: the choices on the cards.
func _animal_options(a: Node) -> Array:
	var kind: String = a.get_meta("kind", "")
	var nice: String = {"stag": "deer", "doe": "deer"}.get(kind, kind)
	var out: Array = []
	if explorer.carrying != "" and a.likes(explorer.carrying):
		out.append({"label": "Feed the %s" % nice, "icon": Prompt.FOOD.get(explorer.carrying, ""), "act": func() -> String: return _press_animal(a)})
	out.append({"label": "Stroke the %s" % nice, "act": func() -> String: return _stroke(a)})
	if kind in ["horse", "donkey"] and play:
		out.append({"label": "Ride the %s!" % nice, "act": func() -> String: return _special(a)})
	else:
		out.append({"label": "Big hug!", "act": func() -> String: return _special(a)})
	return out


func _stroke(a: Node) -> String:
	corner.follow.focus(a)
	a.stroke(explorer.global_position)
	_met(a)
	explorer.act("interact-right", 1.1)
	_rumble(0.35)
	sound.play_flat(sound.pop, -10.0)
	return "stroked " + a.cfg["sound"]


## Picks up a food from a food place (she swaps what she carries).
func take_food(kind: String) -> String:
	explorer.carry(kind, _food_model(kind, 0.2 if kind != "seed" else 0.28))
	sound.play_flat(sound.pop, -10.0)
	return "picked up " + kind


## Her button on an animal: feed it if she carries food it likes, otherwise stroke it.
func _press_animal(a: Node) -> String:
	corner.follow.focus(a)
	if explorer.carrying != "" and a.likes(explorer.carrying):
		a.feed(explorer.carrying, explorer.global_position)
		_met(a)
		explorer.act("interact-right", 1.3)
		explorer.drop()
		_rumble(0.5)
		return "fed " + a.cfg["sound"]
	# the third stroke in a row is special: a ride on the horse, a spin from the dog, a happy jump
	var presses: Array = a.get_meta("presses", [])
	presses = presses.filter(func(t: float) -> bool: return _clock - t < 25.0)
	presses.append(_clock)
	a.set_meta("presses", presses)
	if presses.size() >= 3:
		a.set_meta("presses", [])
		return _special(a)
	a.stroke(explorer.global_position)
	_met(a)
	explorer.act("interact-right", 1.1)
	_rumble(0.35)
	sound.play_flat(sound.pop, -10.0)
	return "stroked " + a.cfg["sound"]


func _special(a: Node) -> String:
	var kind: String = a.get_meta("kind", "")
	var node := a as Node3D
	fx.hearts(node.global_position + Vector3.UP * float(a.cfg["height"]) * 1.1, 14)
	sound.call_from(a.cfg["sound"], a.voice, true)
	_met(a)
	if kind in ["horse", "donkey"] and play and not play.riding:
		_ride(a)
		return "rode " + kind
	var tw := node.create_tween()
	if kind == "dog" or kind == "cat":
		tw.tween_property(node, "rotation:y", node.rotation.y + TAU, 0.8)
	else:
		var y := node.position.y
		tw.tween_property(node, "position:y", y + 0.4, 0.2).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "position:y", y, 0.2).set_ease(Tween.EASE_IN)
		tw.tween_property(node, "position:y", y + 0.25, 0.16).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "position:y", y, 0.16).set_ease(Tween.EASE_IN)
	stickers._say_later("I love you!", 1.0)
	return "loved " + kind


## A little ride round the yard on the horse (or donkey): she sits on its back.
func _ride(a: Node) -> void:
	var node := a as Node3D
	var start := node.global_position
	var to_yard := (Vector3(-1.5, start.y, -10.0) - start)
	to_yard.y = 0.0
	var centre := start + to_yard.normalized() * 2.4
	var a0 := atan2(start.z - centre.z, start.x - centre.x)
	var back := float(a.cfg["height"]) * 0.62
	a.set_process(false)
	a.set_physics_process(false)
	a._play("walk")
	var layer: int = a.body.collision_layer if a.body else 0
	if a.body:
		a.body.collision_layer = 0
	stickers._say_later("Giddy up!", 0.5)
	play.ride(9.0, func(k: float, _s: float) -> void:
		var ang := a0 + k * TAU
		var p := centre + Vector3(cos(ang) * 2.4, 0, sin(ang) * 2.4)
		p.y = Terrain.height(p.x, p.z)
		node.global_position = p
		var tangent := Vector3(-sin(ang), 0, cos(ang))
		node.rotation.y = atan2(tangent.x, tangent.z)
		play._place_her(p + Vector3.UP * back + Vector3(0, absf(sin(k * 40.0)) * 0.05, 0), atan2(tangent.x, tangent.z)),
		func() -> void:
			a.set_process(true)
			a.set_physics_process(true)
			if a.body:
				a.body.collision_layer = layer
			a.yaw = node.rotation.y
			var side := node.global_position + Vector3(1.2, 0, 0)
			explorer.global_position = Vector3(side.x, Terrain.height(side.x, side.z) + 0.1, side.z))


## Things listen for what just happened (adventures, souvenirs). Kept as one place to hook into.
signal happened(what: String)


func events_said(what: String) -> void:
	if corner and corner.has_method("note"):
		corner.note(what)
	happened.emit(what)


## Volume groups the parent menu can set separately.
func _volume_groups() -> void:
	for bus in ["Music", "Ambience", "Animals", "Voice"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	var vols: Dictionary = save.setting("volume", {})
	for bus in vols:
		var i := AudioServer.get_bus_index(bus)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, float(vols[bus]))


## A new sticker the first time; the animal's name spoken now and then after its sound.
func _met(a: Node) -> void:
	var kind: String = a.cfg.get("sticker", a.cfg["sound"])
	if kind == "":
		return
	if not stickers.earned.has(kind):
		stickers.earn(kind)
	elif _clock - float(_said.get(kind, -99.0)) > 25.0:
		stickers._say_later(stickers._name_of(kind), 1.3)
	_said[kind] = _clock


func _animal_in_reach() -> Node:
	var best: Node = null
	var best_score := INF
	var here := Vector2(explorer.global_position.x, explorer.global_position.z)
	var fwd := Vector2(explorer.forward().x, explorer.forward().z)
	for a in animals:
		var d: Vector2 = a.pos2() - here
		var gap: float = d.length() - float(a.cfg["radius"])
		if gap > 1.7:
			continue
		var ang := absf(fwd.angle_to(d))
		var score: float = gap + ang * 0.8 + (2.0 if ang > 1.3 and gap > 0.6 else 0.0)
		if score < best_score:
			best_score = score
			best = a
	return best


func parent_call() -> void:
	sound.play_flat(sound.chime, -14.0)
	for a in animals:
		if a.pos2().distance_to(Vector2(explorer.global_position.x, explorer.global_position.z)) < 26.0:
			a.called(explorer.global_position)


func _rumble(strength: float) -> void:
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, strength, strength * 0.5, 0.25)


# --- every frame ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	_place_sounds(delta)
	# seed is eaten up over time
	if not seed_spots.is_empty():
		var changed := false
		for s in seed_spots:
			s[1] -= delta
			if s[1] <= 0.0:
				changed = true
		if changed:
			seed_spots = seed_spots.filter(func(s): return s[1] > 0.0)
			_redraw_seed()
	_pickup_cool -= delta
	# now and then an animal calls from far away, so the parent can ask "where is it?"
	_distant_t -= delta
	if _distant_t <= 0.0:
		_distant_t = randf_range(25.0, 40.0)
		var ex := Vector2(explorer.global_position.x, explorer.global_position.z)
		var far := animals.filter(func(a): return a.pos2().distance_to(ex) > 14.0)
		if not far.is_empty():
			var a: Node = far.pick_random()
			sound.call_from(a.cfg["sound"], a.voice, false)


# --- small life and the sounds of each place -----------------------------------------

var _sea: AudioStreamPlayer
var _ripple_t := 0.0


func _small_life() -> void:
	# butterflies drift round the flowery places all day
	for anchor in [Terrain.ORCHARD, Terrain.COTTAGE, Terrain.HILL, Vector2(6, 9), Terrain.POND + Vector2(0, 12), Terrain.ORCHARD + Vector2(6, 6)]:
		fx.drifting_butterfly(Vector3(anchor.x, Terrain.height(anchor.x, anchor.y), anchor.y))
	# the sea, louder near the shore
	_sea = AudioStreamPlayer.new()
	_sea.stream = load("res://assets/sounds/sea.wav")
	_sea.volume_db = -40.0
	_sea.bus = "Ambience"
	_sea.autoplay = true
	add_child(_sea)


var _lod_t := 0.0


## Far animals stop animating and very far ones are not drawn: skinning is the costliest part of an animal.
func _animal_lod(delta: float) -> void:
	_lod_t -= delta
	if _lod_t > 0.0:
		return
	_lod_t = 0.4
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	for a in animals:
		var d := cp.distance_to((a as Node3D).global_position)
		if a.player:
			(a.player as AnimationMixer).active = d < 60.0
		for m in a.get_meta("meshes", []):
			(m as GeometryInstance3D).visible = d < 140.0


func _place_sounds(delta: float) -> void:
	_animal_lod(delta)
	var ex := Vector2(explorer.global_position.x, explorer.global_position.z)
	var from_shore := Terrain.shore_radius(ex.x, ex.y) - ex.distance_to(Terrain.CENTRE)
	var want := lerpf(-8.0, -36.0, clampf((from_shore - 4.0) / 30.0, 0.0, 1.0))
	_sea.volume_db = lerpf(_sea.volume_db, want, 1.0 - exp(-delta * 1.5))
	# fish make rings on the pond now and then
	_ripple_t -= delta
	if _ripple_t <= 0.0:
		_ripple_t = randf_range(1.5, 4.0)
		var a := randf() * TAU
		var r := randf_range(1.0, 6.0)
		fx.ripple(Vector3(Terrain.POND.x + cos(a) * r, 0.04, Terrain.POND.y + sin(a) * r))


# --- soak test --------------------------------------------------------------------------------

## Runs animal life fast with the explorer visiting animals, then reports anything wrong.
func soak(minutes: float) -> void:
	Engine.time_scale = 8.0
	Engine.max_physics_steps_per_frame = 24
	var steps := int(minutes * 60.0 / 2.0)
	var actions := {}
	for i in steps:
		await get_tree().create_timer(2.0, true, false, false).timeout
		if i % 50 == 0:
			print("[soak] step %d of %d" % [i, steps])
		if i % 6 == 0:
			# the explorer pops over to an animal and presses her button, sometimes with food
			var a: Node = animals.pick_random()
			var p: Vector2 = a.pos2() + Vector2(1.0, 0.6).normalized() * (float(a.cfg["radius"]) + 0.8)
			explorer.global_position = Vector3(p.x, Terrain.height(p.x, p.y) + 0.1, p.y)
			explorer.face(a.global_position)
			var liked: Array = (a.cfg["likes"] as Array).filter(func(f): return f != "grass")
			if not liked.is_empty() and randf() < 0.6:
				explorer.carry(liked[0], _food_model(liked[0], 0.2))
			else:
				explorer.drop()
			explorer.busy = 0.0
			var r := her_button()
			print("[soak] pressed: ", r, "  fps ", Engine.get_frames_per_second(), "  step ", i)
			actions[r.get_slice(" ", 0)] = int(actions.get(r.get_slice(" ", 0), 0)) + 1
		if i % 17 == 0:
			parent_call()
	Engine.time_scale = 1.0
	var problems := 0
	for a in animals:
		var p: Vector2 = a.pos2()
		var area: Rect2 = a.cfg["area"]
		var outside := not area.grow(0.3).has_point(p)
		var wet := Terrain.height(p.x, p.y) < 0.1
		var inside_thing: bool = not _clear(p, -0.3) and float(a.cfg["speed"]) > 0.0
		var stuck: int = a.used.get("stuck", 0)
		var seen := (a.used.keys() as Array).filter(func(k): return k != "stuck")
		seen.sort()
		print("[soak] %s: states %s, stuck %d, outside %s, in water %s, inside an object %s" % [a.name, ", ".join(seen), stuck, outside, wet, inside_thing])
		if outside or wet or inside_thing or stuck > 6:
			problems += 1
	print("[soak] explorer actions: %s" % str(actions))
	print("[soak] %d problem(s) in %d animals" % [problems, animals.size()])
	corner.quit_game()
