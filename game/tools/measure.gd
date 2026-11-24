extends SceneTree
## Prints each model's size in its own units (x, y, z) and its lowest point, for fitting pieces together.
const Models := preload("res://lib/models.gd")
func _init() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	for path in OS.get_cmdline_user_args():
		var inst: Node3D = (load(path) as PackedScene).instantiate()
		holder.add_child(inst)
		var b := Models.bounds(inst, holder)
		print("%s size=(%.2f, %.2f, %.2f) min_y=%.2f centre=(%.2f, %.2f)" % [path.get_file(), b.size.x, b.size.y, b.size.z, b.position.y, b.get_center().x, b.get_center().z])
		inst.queue_free()
	quit()
