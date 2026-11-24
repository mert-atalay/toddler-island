extends SceneTree
## Makes the desktop icon (256 x 256) from a square crop of one of the game's own pictures.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var img := Image.load_from_file(args[0])
	var side := mini(img.get_width(), img.get_height())
	var cx := int(args[2]) if args.size() > 2 else img.get_width() / 2
	var cy := int(args[3]) if args.size() > 3 else img.get_height() / 2
	var r := Rect2i(clampi(cx - side / 4, 0, img.get_width() - side / 2), clampi(cy - side / 4, 0, img.get_height() - side / 2), side / 2, side / 2)
	var crop := img.get_region(r)
	crop.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	crop.save_png(args[1])
	quit()
