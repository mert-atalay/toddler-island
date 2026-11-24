extends RefCounted
const AutoRig := preload("res://lib/autorig.gd")
## Loading models at their real size. Every model file comes in its own scale (the first version
## used plants 2 to 5 times too big), so everything placed in the world goes through here.


## Loads a model under a new holder node, turns it, scales it to `height` metres, centres it and
## stands it on the ground. The holder gets metas "size" (Vector3) and "native" (file height).
static func spawn(parent: Node, path: String, height: float, yaw_deg := 0.0) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("[models] missing " + path)
		return null
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	# still animal models get a skeleton and animations made for them (lib/autorig.gd)
	var rig_opts = AutoRig.options_for(path)
	if rig_opts != null and inst.find_children("*", "AnimationPlayer", true, false).is_empty():
		inst = AutoRig.rig(inst, rig_opts)
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.add_child(inst)
	inst.rotation_degrees.y = yaw_deg
	var box := bounds(inst, holder)
	holder.set_meta("native", box.size.y)
	inst.scale *= height / maxf(box.size.y, 0.0001)
	box = bounds(inst, holder)
	inst.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	holder.set_meta("size", bounds(inst, holder).size)
	# small things cast no shadow: it costs a draw per shadow split and barely shows
	var shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if height > 0.6 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for node in inst.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = shadow
	return holder


static func bounds(root: Node3D, space: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var to_space := space.global_transform.affine_inverse()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := node as MeshInstance3D
		if mesh_inst.mesh == null:
			continue
		var b := mesh_bounds(mesh_inst, to_space)
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out


## Bounds of a mesh as it is drawn. A skinned mesh is placed by its skeleton, so its raw mesh
## bounds can be far off (the farm-pack sheep came out a tenth of its size); those vertices are
## skinned on the CPU here, in the rest pose.
static func mesh_bounds(mi: MeshInstance3D, to_space: Transform3D) -> AABB:
	var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	if skel == null or mi.skin == null:
		return (to_space * mi.global_transform) * mi.get_aabb()
	var skin := mi.skin
	var bind_xf: Array[Transform3D] = []
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		if bone < 0:
			bone = skel.find_bone(skin.get_bind_name(b))
		var pose := skel.get_bone_global_pose(bone) if bone >= 0 else Transform3D.IDENTITY
		bind_xf.append(to_space * skel.global_transform * pose * skin.get_bind_pose(b))
	var out := AABB()
	var first := true
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if arr[Mesh.ARRAY_BONES] == null or arr[Mesh.ARRAY_WEIGHTS] == null or verts.is_empty():
			continue
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / verts.size()
		var stride := maxi(1, verts.size() / 4000)
		for i in range(0, verts.size(), stride):
			var p := Vector3.ZERO
			var wsum := 0.0
			for j in per:
				var w := weights[i * per + j]
				if w <= 0.0:
					continue
				p += (bind_xf[bones[i * per + j]] * verts[i]) * w
				wsum += w
			if wsum <= 0.0:
				continue
			p /= wsum
			if first:
				out = AABB(p, Vector3.ZERO)
				first = false
			else:
				out = out.expand(p)
	if first:
		return (to_space * mi.global_transform) * mi.get_aabb()
	return out


## The single mesh inside a static model file (a plant, a rock), with its own transform and its
## height in file units, for drawing many copies at once.
static func mesh_of(path: String) -> Dictionary:
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	var found := {}
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != inst and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var box := xf * mi.get_aabb()
		found = {"mesh": mi.mesh, "xf": xf, "height": box.size.y, "bottom": box.position.y}
		break
	inst.free()
	return found
