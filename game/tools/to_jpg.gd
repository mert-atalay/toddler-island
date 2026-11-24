extends SceneTree
## Converts pictures to JPG for the project page: to_jpg.gd -- <out dir> <in1.png> <in2.png> ...
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	for i in range(1, a.size()):
		var img := Image.load_from_file(a[i])
		if img.get_width() > 1600:
			img.resize(1600, int(1600.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
		img.save_jpg(a[0].path_join(a[i].get_file().get_basename() + ".jpg"), 0.86)
	quit()
