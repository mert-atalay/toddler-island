extends SceneTree
## Prints every mesh in a model with its bounds, to find odd parts (headless).
## godot --headless --path game --script res://tools/inspect.gd -- res://path/model.fbx

func _init() -> void:
	for path in OS.get_cmdline_user_args():
		var inst: Node3D = (load(path) as PackedScene).instantiate()
		root.add_child(inst)
		print("== ", path)
		for n in inst.find_children("*", "", true, false):
			var line := "  %s (%s)" % [inst.get_path_to(n), n.get_class()]
			if n is Node3D:
				line += " scale=%s pos=%s" % [str((n as Node3D).scale), str((n as Node3D).position)]
			if n is MeshInstance3D and (n as MeshInstance3D).mesh:
				var mi := n as MeshInstance3D
				line += " aabb=%s global=%s skin=%s" % [str(mi.get_aabb()), str(mi.global_transform * mi.get_aabb()), str(mi.skin != null)]
			if n is AnimationPlayer:
				line += " anims=%s" % str((n as AnimationPlayer).get_animation_list())
			print(line)
		inst.queue_free()
	quit()
