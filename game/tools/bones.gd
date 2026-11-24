extends SceneTree
func _init():
	var inst: Node = (load("res://assets/characters/kenney/character-female-b.glb") as PackedScene).instantiate()
	for s in inst.find_children("*", "Skeleton3D", true, false):
		var names := []
		for i in (s as Skeleton3D).get_bone_count(): names.append((s as Skeleton3D).get_bone_name(i))
		print("bones: ", names)
	quit()
