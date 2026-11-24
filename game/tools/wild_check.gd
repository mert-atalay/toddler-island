extends SceneTree
## Prints size and animations of the wildlife models.
const Models := preload("res://lib/models.gd")
func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	for f in DirAccess.get_files_at("res://assets/animals/wild"):
		if not f.ends_with(".glb"):
			continue
		var h := Models.spawn(root, "res://assets/animals/wild/" + f, 1.0)
		var anims: Array = []
		for p in h.find_children("*", "AnimationPlayer", true, false):
			anims.append_array((p as AnimationPlayer).get_animation_list())
		print(f, " native h=", h.get_meta("native"), " size@1m=", h.get_meta("size"), " anims=", anims)
	var c := Models.spawn(root, "res://assets/characters/kenney/character-female-b.glb", 1.0)
	for p in c.find_children("*", "AnimationPlayer", true, false):
		print("girl anims: ", (p as AnimationPlayer).get_animation_list())
	quit()
