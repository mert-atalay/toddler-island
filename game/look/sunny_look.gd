extends RefCounted
## The game's look: warm late-morning sun, light from the sky, soft contact shadows where things
## meet the ground, light bounced off grass and walls, and blue haze with distance.
## Shared by the step 1 lineup now and by the island later.


static func apply(parent: Node, sun_elevation := 38.0, sun_azimuth := -35.0) -> DirectionalLight3D:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.58, 0.88)
	sky_mat.sky_horizon_color = Color(0.74, 0.85, 0.94)
	sky_mat.ground_bottom_color = Color(0.36, 0.45, 0.32)
	sky_mat.ground_horizon_color = Color(0.74, 0.85, 0.94)
	sky_mat.sun_angle_max = 30.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	# grounding: soft shade where objects meet the ground and each other
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.8
	env.ssao_power = 1.6
	# bounced light from grass and walls
	env.ssil_enabled = false
	env.ssil_radius = 3.0
	env.ssil_intensity = 0.8
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	# layers: haze with distance so far things read as far
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.87, 0.96)
	env.fog_density = 0.0018
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08

	parent.set_meta("env", env)
	parent.set_meta("sky", sky_mat)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.3
	sun.light_angular_distance = 0.6
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 65.0
	sun.shadow_blur = 1.0
	sun.rotation_degrees = Vector3(-sun_elevation, sun_azimuth, 0.0)
	parent.add_child(sun)
	return sun
