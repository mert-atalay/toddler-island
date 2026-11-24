extends RefCounted
## Gives a still animal model (one mesh, no bones) a skeleton and its own animations, so lions,
## elephants and the rest walk, graze and wag like the animated farm animals.
##
## The model is measured: the long side is the body, the end standing higher is the head. Vertices
## below the belly near the four leg columns become the legs; the part in front of the shoulders
## becomes the head (an elephant's lower front becomes the trunk); the part behind the hips the tail.
## Each part gets a bone, every vertex a smooth weight, and an AnimationPlayer gets the clips
## "Idle", "Walk", "Gallop", "Eating", "Idle_Headlow" and "Idle_2" (a happy hop), the same names the
## farm pack uses, so corner/animal.gd plays them without knowing the difference.
##
## Options: "flip" (the head is at the other end), "trunk" (an elephant), "tail" (0..1 how much the
## tail wags), "neck" (0..1, more nodding, for the giraffe), "hop" (rabbits: the legs hop together),
## "climber" (squirrels: the tail stands up and curls).

static func rig(model: Node3D, opts := {}) -> Node3D:
	# gather every mesh into one list of surfaces, in the model's own space
	var surfaces: Array = []   # [arrays, material]
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != model and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms = arr[Mesh.ARRAY_NORMAL]
			for i in verts.size():
				verts[i] = xf * verts[i]
			arr[Mesh.ARRAY_VERTEX] = verts
			if norms != null:
				var nn: PackedVector3Array = norms
				for i in nn.size():
					nn[i] = (xf.basis * nn[i]).normalized()
				arr[Mesh.ARRAY_NORMAL] = nn
			var mat: Material = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			if mi.material_override:
				mat = mi.material_override
			surfaces.append([arr, mat])
	if surfaces.is_empty():
		return model
	# the bounds, and which way the animal faces
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for sf in surfaces:
		for v in (sf[0][Mesh.ARRAY_VERTEX] as PackedVector3Array):
			lo = lo.min(v)
			hi = hi.max(v)
	var size := hi - lo
	var mid := (lo + hi) * 0.5
	var along_x := size.x > size.z
	# canonical frame: head towards +Z, feet at y = 0, centred
	var basis := Basis.IDENTITY
	if along_x:
		basis = Basis(Vector3.UP, -PI / 2)   # +X becomes +Z
	var to_c := Transform3D(basis, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -Vector3(mid.x, lo.y, mid.z))
	var pts: Array[PackedVector3Array] = []
	for sf in surfaces:
		var vs: PackedVector3Array = (sf[0][Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
		for i in vs.size():
			vs[i] = to_c * vs[i]
		pts.append(vs)
	var length := size.x if along_x else size.z
	var height := size.y
	var half := length * 0.5
	# the head end is the end that stands higher
	var top_front := -INF
	var top_back := -INF
	for vs in pts:
		for v in vs:
			if v.z > half * 0.45:
				top_front = maxf(top_front, v.y)
			elif v.z < -half * 0.45:
				top_back = maxf(top_back, v.y)
	var flip := top_back > top_front
	if opts.get("flip", false):
		flip = not flip
	if flip:
		var r := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
		to_c = r * to_c
		for vs in pts:
			for i in vs.size():
				vs[i] = r * vs[i]
	# the belly: the lowest point under the middle of the body
	var belly := height
	var width := size.z if along_x else size.x
	for vs in pts:
		for v in vs:
			if absf(v.z) < length * 0.12 and absf(v.x) < width * 0.3:
				belly = minf(belly, v.y)
	belly = clampf(belly, height * 0.12, height * 0.62)
	# the legs: low vertices, split front and back by the middle of their spread
	var leg_z: Array[float] = []
	for vs in pts:
		for v in vs:
			if v.y < belly * 0.55:
				leg_z.append(v.z)
	leg_z.sort()
	var split := leg_z[leg_z.size() / 2] if not leg_z.is_empty() else 0.0
	var zf := 0.0
	var zb := 0.0
	var nf := 0
	var nb := 0
	var xl := 0.0
	var nl := 0
	for vs in pts:
		for v in vs:
			if v.y < belly * 0.55:
				if v.z > split:
					zf += v.z
					nf += 1
				else:
					zb += v.z
					nb += 1
				xl += absf(v.x)
				nl += 1
	zf = zf / maxf(nf, 1) if nf > 0 else half * 0.5
	zb = zb / maxf(nb, 1) if nb > 0 else -half * 0.5
	xl = xl / maxf(nl, 1) if nl > 0 else width * 0.25
	var leg_r := maxf((zf - zb) * 0.32, length * 0.08)
	var hop: bool = opts.get("hop", false)
	# the top of the back over the shoulders and over the hips
	var sh_top := belly
	var hip_top := belly
	for vs in pts:
		for v in vs:
			if absf(v.z - zf) < leg_r:
				sh_top = maxf(sh_top, v.y)
			if absf(v.z - zb) < leg_r:
				hip_top = maxf(hip_top, v.y)
	var trunk: bool = opts.get("trunk", false)
	# bones: root, body, four legs, head (and trunk), tail
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	var names := ["root", "body", "leg_fl", "leg_fr", "leg_bl", "leg_br", "head", "tail", "trunk"]
	var body_at := Vector3(0, belly + (sh_top - belly) * 0.4, (zf + zb) * 0.5)
	var head_at := Vector3(0, belly + (sh_top - belly) * 0.65, zf + leg_r * 0.2)
	var tail_at := Vector3(0, belly + (hip_top - belly) * 0.75, zb - leg_r * 0.6)
	var front_end := half
	var trunk_at := Vector3(0, belly + (sh_top - belly) * 0.5, front_end - (front_end - zf) * 0.45)
	var heads := {"root": Vector3.ZERO, "body": body_at,
		"leg_fl": Vector3(xl, belly, zf), "leg_fr": Vector3(-xl, belly, zf),
		"leg_bl": Vector3(xl, belly, zb), "leg_br": Vector3(-xl, belly, zb),
		"head": head_at, "tail": tail_at, "trunk": trunk_at}
	var parents := {"root": -1, "body": 0, "leg_fl": 1, "leg_fr": 1, "leg_bl": 1, "leg_br": 1, "head": 1, "tail": 1, "trunk": 6}
	for nm in names:
		skel.add_bone(nm)
	for i in names.size():
		var nm: String = names[i]
		skel.set_bone_parent(i, parents[nm])
		var par: int = parents[nm]
		var rel: Vector3 = heads[nm] - (heads[names[par]] if par >= 0 else Vector3.ZERO)
		skel.set_bone_rest(i, Transform3D(Basis.IDENTITY, rel))
		skel.set_bone_pose_position(i, rel)
	# weights
	var mesh := ArrayMesh.new()
	for si in surfaces.size():
		var arr: Array = surfaces[si][0]
		var vs: PackedVector3Array = pts[si]
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		bones.resize(vs.size() * 4)
		weights.resize(vs.size() * 4)
		for i in vs.size():
			var v := vs[i]
			var w := {}
			# legs
			var low := 1.0 - _ss(belly * 0.7, belly * 1.08, v.y)
			if low > 0.0:
				var front := absf(v.z - zf) < leg_r * 1.25 and v.z > split - leg_r * 0.2
				var back := absf(v.z - zb) < leg_r * 1.25 and v.z <= split + leg_r * 0.2
				if front or back:
					var side := "l" if v.x >= 0.0 else "r"
					var leg := ("leg_f" if front else "leg_b") + side
					w[leg] = low
			# head (and the neck in front of the shoulders)
			var hd := _ss(zf - leg_r * 0.3, zf + (front_end - zf) * 0.35, v.z) * _ss(belly * 0.6, belly * 1.1, v.y)
			if trunk:
				var tk := _ss(trunk_at.z - (front_end - zf) * 0.1, trunk_at.z + (front_end - zf) * 0.25, v.z) * (1.0 - _ss(trunk_at.y, trunk_at.y + (sh_top - belly) * 0.5, v.y))
				if tk > 0.0:
					w["trunk"] = tk
					hd = maxf(hd, 0.0) * (1.0 - tk)
			if hd > 0.0 and not w.has("leg_fl") and not w.has("leg_fr"):
				w["head"] = hd
			# tail
			var tl := _ss(zb - leg_r * 0.5, zb - leg_r * 1.4, v.z) * _ss(belly * 0.5, belly * 1.0, v.y)
			if tl > 0.0 and not w.has("leg_bl") and not w.has("leg_br"):
				w["tail"] = tl
			var total := 0.0
			for k in w:
				total += float(w[k])
			if total < 1.0:
				w["body"] = 1.0 - total
			else:
				for k in w:
					w[k] = float(w[k]) / total
			var keys: Array = w.keys()
			keys.sort_custom(func(a: String, b: String) -> bool: return float(w[a]) > float(w[b]))
			for j in 4:
				if j < keys.size():
					bones[i * 4 + j] = names.find(keys[j])
					weights[i * 4 + j] = float(w[keys[j]])
				else:
					bones[i * 4 + j] = 0
					weights[i * 4 + j] = 0.0
		var out := arr.duplicate()
		out[Mesh.ARRAY_VERTEX] = vs
		if arr[Mesh.ARRAY_NORMAL] != null:
			var nn: PackedVector3Array = (arr[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
			for i in nn.size():
				nn[i] = (to_c.basis * nn[i]).normalized()
			out[Mesh.ARRAY_NORMAL] = nn
		out[Mesh.ARRAY_TANGENT] = null
		out[Mesh.ARRAY_BONES] = bones
		out[Mesh.ARRAY_WEIGHTS] = weights
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
		var smat: Material = surfaces[si][1]
		if smat and float(opts.get("bright", 1.0)) != 1.0 and smat is BaseMaterial3D:
			# grey animals read dark blue in the valley's sky light: lift them a little
			smat = smat.duplicate()
			(smat as BaseMaterial3D).albedo_color = (smat as BaseMaterial3D).albedo_color * float(opts["bright"])
		if smat:
			mesh.surface_set_material(mesh.get_surface_count() - 1, smat)
	var skin := Skin.new()
	for i in names.size():
		skin.add_named_bind(names[i], skel.get_bone_global_rest(i).affine_inverse())
	var root := Node3D.new()
	root.name = "Rigged"
	root.add_child(skel)
	var mi2 := MeshInstance3D.new()
	mi2.name = "Body"
	mi2.mesh = mesh
	mi2.skin = skin
	skel.add_child(mi2)
	mi2.skeleton = NodePath("..")
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	var lib := AnimationLibrary.new()
	var dims := {"belly": belly, "height": height, "length": length, "neck": float(opts.get("neck", 0.0)),
		"tail": float(opts.get("tail", 1.0)), "trunk": trunk, "hop": hop, "climber": opts.get("climber", false),
		"rest": heads}
	for clip in ["Idle", "Walk", "Gallop", "Eating", "Idle_Headlow", "Idle_2"]:
		lib.add_animation(clip, _clip(clip, dims))
	ap.add_animation_library("", lib)
	model.free()
	return root


## Settings for the still models that get rigged (by file name).
const OPTIONS := {
	"lion": {"tail": 1.0}, "tiger": {"tail": 1.0}, "elephant": {"trunk": true, "tail": 0.6, "flip": true, "bright": 1.45},
	"giraffe": {"neck": 1.0, "tail": 0.8}, "hippo": {"tail": 0.4, "flip": true, "bright": 1.3}, "rhino": {"tail": 0.5, "flip": true, "bright": 1.15},
	"bearcub": {"tail": 0.0}, "squirrel": {"climber": true, "tail": 1.4, "flip": true}, "grayrabbit": {"hop": true, "tail": 0.3},
}


## The options for a model file, or null if it should not be rigged.
static func options_for(path: String):
	var stem := path.get_file().get_basename()
	return OPTIONS.get(stem)


static func _ss(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## One clip, made from a few sine curves per bone. Angles in degrees; +X tips a part forward/down.
static func _clip(name: String, d: Dictionary) -> Animation:
	var a := Animation.new()
	var len := {"Idle": 4.0, "Walk": 1.0, "Gallop": 0.55, "Eating": 2.4, "Idle_Headlow": 5.0, "Idle_2": 1.2}[name] as float
	a.length = len
	a.loop_mode = Animation.LOOP_NONE if name == "Idle_2" else Animation.LOOP_LINEAR
	var rest: Dictionary = d["rest"]
	var h: float = d["height"]
	var neck: float = d["neck"]
	var tailw: float = d["tail"]
	var hop: bool = d["hop"]
	var climber: bool = d["climber"]
	var steps := 24
	var rot := {}   # bone -> track index
	for b in ["body", "leg_fl", "leg_fr", "leg_bl", "leg_br", "head", "tail", "trunk"]:
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath("Skeleton3D:" + b))
		rot[b] = t
	var pos_t := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(pos_t, NodePath("Skeleton3D:body"))
	var body_rest: Vector3 = rest["body"] - rest["root"]
	for k in steps + 1:
		var t := len * k / steps
		var ph := TAU * t / len
		var legs := {"leg_fl": 0.0, "leg_fr": 0.0, "leg_bl": 0.0, "leg_br": 0.0}
		var head := Vector3.ZERO   # pitch, yaw, roll in degrees
		var tail := Vector3.ZERO
		var trunk := Vector3.ZERO
		var body := Vector3.ZERO
		var bob := 0.0
		match name:
			"Idle":
				head = Vector3(4.0 * sin(ph * 0.5) - 3.0 * neck, 18.0 * sin(ph * 0.25), 0)
				tail = Vector3(10.0, 18.0 * sin(ph * 1.5) * tailw, 0)
				trunk = Vector3(12.0 + 10.0 * sin(ph), 10.0 * sin(ph * 0.5), 0)
				bob = 0.006 * h * sin(ph * 2.0)
			"Walk":
				var sw := 20.0 if not hop else 0.0
				legs = {"leg_fl": sw * sin(ph), "leg_br": sw * sin(ph), "leg_fr": -sw * sin(ph), "leg_bl": -sw * sin(ph)}
				if hop:
					var hp := maxf(0.0, sin(ph))
					legs = {"leg_fl": -25.0 * hp, "leg_fr": -25.0 * hp, "leg_bl": 30.0 * hp, "leg_br": 30.0 * hp}
					bob = 0.25 * h * hp
					body.x = -12.0 * cos(ph)
				else:
					bob = 0.02 * h * absf(sin(ph * 2.0 + 0.5)) - 0.01 * h
					body.z = 2.0 * sin(ph)
				head = Vector3(5.0 * sin(ph * 2.0) + 4.0 * neck * sin(ph * 2.0), 3.0 * sin(ph), 0)
				tail = Vector3(14.0, 14.0 * sin(ph) * tailw, 0)
				trunk = Vector3(10.0 + 8.0 * sin(ph * 2.0), 12.0 * sin(ph), 0)
			"Gallop":
				var g := 34.0
				legs = {"leg_fl": g * sin(ph), "leg_fr": g * sin(ph + 0.5), "leg_bl": -g * sin(ph + 0.3), "leg_br": -g * sin(ph + 0.8)}
				if hop:
					var hp2 := maxf(0.0, sin(ph))
					legs = {"leg_fl": -30.0 * hp2, "leg_fr": -30.0 * hp2, "leg_bl": 40.0 * hp2, "leg_br": 40.0 * hp2}
				bob = 0.06 * h * maxf(0.0, sin(ph)) if not hop else 0.35 * h * maxf(0.0, sin(ph))
				body.x = 6.0 * sin(ph + 1.2)
				head = Vector3(8.0 * sin(ph + 0.6), 0, 0)
				tail = Vector3(30.0 * tailw, 8.0 * sin(ph * 2.0) * tailw, 0)
				trunk = Vector3(-20.0 + 10.0 * sin(ph), 0, 0)
			"Eating":
				var nib := 4.0 * sin(ph * 3.0)
				head = Vector3(48.0 + 20.0 * neck + nib, 6.0 * sin(ph * 0.5), 0)
				tail = Vector3(8.0, 20.0 * sin(ph * 1.5) * tailw, 0)
				trunk = Vector3(30.0 + 25.0 * maxf(0.0, sin(ph)), 0, 0)
				body.x = 4.0
			"Idle_Headlow":
				head = Vector3(26.0 + 10.0 * neck + 2.0 * sin(ph * 0.5), 6.0 * sin(ph * 0.25), 0)
				tail = Vector3(4.0, 6.0 * sin(ph * 0.5) * tailw, 0)
				trunk = Vector3(35.0, 0, 0)
				bob = -0.04 * h + 0.004 * h * sin(ph)
				legs = {"leg_fl": -6.0, "leg_fr": -6.0, "leg_bl": 6.0, "leg_br": 6.0}
			"Idle_2":
				var up := sin(clampf(t / len, 0.0, 1.0) * PI)
				bob = 0.12 * h * up
				legs = {"leg_fl": -18.0 * up, "leg_fr": -18.0 * up, "leg_bl": 16.0 * up, "leg_br": 16.0 * up}
				head = Vector3(-18.0 * up, 14.0 * sin(ph * 2.0) * up, 0)
				tail = Vector3(30.0 * up, 35.0 * sin(ph * 4.0) * tailw, 0)
				trunk = Vector3(-75.0 * up, 0, 0)   # an elephant lifts its trunk high
				body.x = -8.0 * up
		if climber:
			tail.x += 35.0   # a squirrel's tail stands up behind it
		_key(a, rot["body"], t, body)
		for leg in legs:
			_key(a, rot[leg], t, Vector3(float(legs[leg]), 0, 0))
		_key(a, rot["head"], t, head)
		_key(a, rot["tail"], t, Vector3(tail.x, tail.y, 0))
		_key(a, rot["trunk"], t, trunk)
		a.position_track_insert_key(pos_t, t, body_rest + Vector3(0, bob, 0))
	return a


static func _key(a: Animation, track: int, t: float, deg: Vector3) -> void:
	var q := Quaternion.from_euler(Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z)))
	a.rotation_track_insert_key(track, t, q)
