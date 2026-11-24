extends RefCounted
## The storybook rocket, stacked from Kenney Space Kit parts: an engine base, fins, body sections,
## a window band and a nose cone. Used on the launch pad and for the whole trip to the Moon.

const Models := preload("res://lib/models.gd")
const K := "res://assets/kits/space/"


## Builds a rocket `height` metres tall under `parent`. Returns its root (feet at y = 0).
## Metas: "hatch_y" (where she climbs in), "flame" (a Node3D at the nozzle for effects).
static func build(parent: Node, height := 12.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Rocket"
	parent.add_child(root)
	var body := Node3D.new()
	root.add_child(body)
	# parts in file units, stacked from the ground up: [file, its height]
	var stack := [["rocket_baseA", 1.6], ["rocket_sidesA", 1.0], ["rocket_fuelA", 0.5], ["rocket_fuelA", 0.5],
		["rocket_sidesA", 1.0], ["rocket_fuelA", 0.5], ["rocket_topA", 0.8]]
	var y := 0.0
	for part in stack:
		var inst: Node3D = (load(K + part[0] + ".glb") as PackedScene).instantiate()
		body.add_child(inst)
		inst.position.y = y
		y += float(part[1])
	var fins: Node3D = (load(K + "rocket_finsA.glb") as PackedScene).instantiate()
	body.add_child(fins)
	fins.position.y = 1.55
	var s := height / y
	body.scale = Vector3.ONE * s
	# the kit parts are not centred on their origin; centre the stack over the nozzle
	var box := Models.bounds(body, root)
	body.position.x -= box.get_center().x
	body.position.z -= box.get_center().z
	for node in body.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.set_meta("hatch_y", 2.6 * s)
	root.set_meta("height", height)
	var flame := Node3D.new()
	flame.name = "Nozzle"
	flame.position.y = 0.15 * s
	root.add_child(flame)
	root.set_meta("flame", flame)
	return root


## Engine flames and smoke as particles under the nozzle. Returns [flame, smoke] emitters (off).
static func engine_effects(rocket: Node3D) -> Array:
	var nozzle: Node3D = rocket.get_meta("flame")
	var s: float = float(rocket.get_meta("height")) / 12.0
	var flame := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.DOWN
	pm.spread = 12.0
	pm.initial_velocity_min = 8.0 * s
	pm.initial_velocity_max = 12.0 * s
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	ramp.add_point(0.35, Color(1.0, 0.55, 0.15, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.6, 0.2, 0.1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	flame.process_material = pm
	flame.amount = 160
	flame.lifetime = 0.45
	var q := QuadMesh.new()
	q.size = Vector2(1.5, 1.5) * s
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.vertex_color_use_as_albedo = true
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.albedo_texture = _soft_dot()
	q.material = fm
	flame.draw_pass_1 = q
	flame.emitting = false
	flame.local_coords = true
	nozzle.add_child(flame)
	var smoke := GPUParticles3D.new()
	var sm := ParticleProcessMaterial.new()
	sm.direction = Vector3.DOWN
	sm.spread = 70.0
	sm.initial_velocity_min = 3.0 * s
	sm.initial_velocity_max = 6.0 * s
	sm.gravity = Vector3(0, 0.6, 0)
	sm.damping_min = 1.5
	sm.damping_max = 2.5
	sm.scale_min = 2.0
	sm.scale_max = 4.0
	var sr := Gradient.new()
	sr.set_color(0, Color(1, 1, 1, 0.7))
	sr.set_color(1, Color(0.85, 0.85, 0.85, 0.0))
	var st := GradientTexture1D.new()
	st.gradient = sr
	sm.color_ramp = st
	smoke.process_material = sm
	smoke.amount = 90
	smoke.lifetime = 3.5
	var q2 := QuadMesh.new()
	q2.size = Vector2(1.6, 1.6) * s
	var smm := StandardMaterial3D.new()
	smm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smm.vertex_color_use_as_albedo = true
	smm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smm.albedo_texture = _soft_dot()
	smm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q2.material = smm
	smoke.draw_pass_1 = q2
	smoke.emitting = false
	smoke.local_coords = false
	nozzle.add_child(smoke)
	return [flame, smoke]


static func _soft_dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t
