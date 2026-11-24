extends SceneTree
const Models := preload("res://lib/models.gd")
func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	for f in ["Tree_1_A", "Tree_2_A", "Tree_3_A", "Tree_4_A", "Tree_Bare_1_A", "Bush_1_A", "Bush_2_A", "Bush_3_A", "Bush_4_A", "Grass_1_A", "Grass_2_A", "Rock_1_A", "Rock_2_A", "Rock_3_A"]:
		var h := Models.spawn(root, "res://assets/kaykit/%s_Color1.gltf" % f, 1.0)
		var s: Vector3 = h.get_meta("size")
		var tris := 0
		for mi in h.find_children("*", "MeshInstance3D", true, false):
			var m: Mesh = (mi as MeshInstance3D).mesh
			for k in m.get_surface_count():
				tris += m.surface_get_array_index_len(k) / 3
		print("%-14s native h %.2f  w/h %.2f  tris %d" % [f, h.get_meta("native"), s.x, tris])
	quit()
