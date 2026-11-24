extends SceneTree
func _init() -> void:
	for n in ["space", "moonshine", "twinkle"]:
		var w := AudioStreamWAV.load_from_file("user://music/%s.wav" % n)
		print(n, " format=", w.format, " stereo=", w.stereo, " rate=", w.mix_rate, " bytes=", w.data.size(), " loop=", w.loop_mode, " ", w.loop_begin, "-", w.loop_end, " len=", w.get_length())
	quit()
