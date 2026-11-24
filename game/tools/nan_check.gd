extends SceneTree
## Loads each rigged model and reports how many warnings each one makes.
const Models := preload("res://lib/models.gd")
func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	for f in ["new/lion", "new/elephant", "new/giraffe", "new/hippo", "new/rhino", "new/tiger", "new/bearcub", "wild/squirrel", "wild/grayrabbit"]:
		print("== ", f)
		var h := Models.spawn(root, "res://assets/animals/%s.glb" % f, 1.0, 0.0)
		await process_frame
	quit()
