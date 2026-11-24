extends SceneTree
func _init() -> void:
	for p in OS.get_cmdline_user_args():
		var inst: Node = (load(p) as PackedScene).instantiate()
		for ap in inst.find_children("*", "AnimationPlayer", true, false):
			print(p.get_file(), ": ", (ap as AnimationPlayer).get_animation_list())
		inst.free()
	quit()
