extends SceneTree
## Lays the comparison pictures into one labelled sheet.
func _init() -> void:
	var d := OS.get_cmdline_user_args()[0]
	var rows := [["valley-valley-above", "valley-river-bend"], ["valley-lake", "valley-forest-edge"], ["valley-windmill-hill", "valley-meadow"]]
	var sheet := Image.create(1920, 1620, false, Image.FORMAT_RGB8)
	for r in rows.size():
		for c in 2:
			var im := Image.load_from_file(d.path_join(rows[r][c] + ".png"))
			im.resize(960, 540)
			sheet.blit_rect(im, Rect2i(0, 0, 960, 540), Vector2i(c * 960, r * 540))
	sheet.save_png(d.path_join("valley-second-look.png"))
	quit()
