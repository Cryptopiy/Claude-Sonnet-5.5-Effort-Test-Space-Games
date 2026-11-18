extends SceneTree
## Developer tool: synthesises every sound (or the ones named in `names=a,b,c`) and writes 16-bit WAV files to <project>/.previews/audio/
## plus a stats table, so the sounds can be analysed offline (spectrograms / levels) without a sound card.
##   powershell -NoProfile -File tools/godot.ps1 -Project "<sandbox>" -Mode run -Script res://tests/audio_dump.gd -TimeoutSec 240 -GodotArgs "-- names=ui_click,notify"
## Run with no `names=` to dump everything.

func _initialize() -> void:
	var only := PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("names="):
			only = String(a).substr(6).split(",", false)
	var list: PackedStringArray = only if only.size() > 0 else AudioRecipes.build_order()
	var dir := ProjectSettings.globalize_path("res://.previews/audio")
	DirAccess.make_dir_recursive_absolute(dir)
	var total_ms := 0
	var rows: Array = []
	for n in list:
		var t0 := Time.get_ticks_msec()
		var d: Dictionary = AudioRecipes.build(n)
		var ms := Time.get_ticks_msec() - t0
		total_ms += ms
		if d.is_empty():
			print("[dump] MISSING recipe for ", n)
			continue
		var buf: PackedFloat32Array = d["buf"]
		var right: PackedFloat32Array = d["right"]
		var sr: int = d["sr"]
		var st := AudioDSP.to_stream(buf, sr, d["loop"], right)
		st.save_to_wav(dir + "/" + n + ".wav")
		rows.append("%-20s %6.2fs sr=%5d %s peak=%.2f rms=%.3f build=%dms" % [n, float(buf.size()) / sr, sr, "L" if d["loop"] else "-", AudioDSP.peak(buf), AudioDSP.rms(buf), ms])
	for r in rows:
		print(r)
	print("[dump] total build ms = ", total_ms, "  sounds = ", rows.size())
	quit()
