extends SceneTree
# 외부 스프라이트시트를 프로젝트 규격(assets/anim/<이름>/N.png 연번)으로 자른다.
#
# pimen 팩은 가로 스트립이 대부분이고(예: 336x48 = 48px 7프레임) 일부는 세로다.
# 프레임이 정사각이라는 가정으로 짧은 변을 프레임 크기로 삼고, 긴 변이 그 배수가
# 아니면 자르지 않고 건너뛴다(비정사각 프레임은 사람이 크기를 지정해야 한다).
#
# 실행:
#   godot --headless --path . --script res://tools/fx/SheetSlicer.gd -- \
#       --src=<시트png> --out=<출력폴더> [--frame=48]
#   godot --headless --path . --script res://tools/fx/SheetSlicer.gd -- --scan=<폴더>

func _initialize() -> void:
	var src := ""
	var out_dir := ""
	var scan := ""
	var frame := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--src="):
			src = arg.substr(6)
		elif arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg.begins_with("--scan="):
			scan = arg.substr(7)
		elif arg.begins_with("--frame="):
			frame = int(arg.substr(8))

	if scan != "":
		_scan(scan)
	elif src != "" and out_dir != "":
		var n := _slice(src, out_dir, frame)
		print("%d 프레임 저장 → %s" % [n, out_dir])
	else:
		print("--src=<png> --out=<폴더> 또는 --scan=<폴더> 가 필요하다")
		quit(1)
		return
	quit(0)


# 폴더를 훑어 자를 수 있는 시트와 못 자르는 시트를 분류해 보여준다.
func _scan(dir_path: String) -> void:
	print("%-46s %10s %8s %s" % ["파일", "크기", "프레임", "판정"])
	print("-".repeat(84))
	var ok := 0
	var skip := 0
	for path in _all_png(dir_path):
		var img := Image.load_from_file(path)
		if img == null or img.is_empty():
			continue
		var w := img.get_width()
		var h := img.get_height()
		var short: int = mini(w, h)
		var long: int = maxi(w, h)
		var name := path.get_file()
		if name.length() > 44:
			name = name.substr(0, 44)
		if short > 0 and long % short == 0 and long / short >= 2:
			print("%-46s %10s %8d %s" % [name, "%dx%d" % [w, h], long / short, "가로" if w > h else "세로"])
			ok += 1
		else:
			print("%-46s %10s %8s %s" % [name, "%dx%d" % [w, h], "-", "수동(비정사각 또는 단일)"])
			skip += 1
	print("-".repeat(84))
	print("자동 분할 가능 %d · 수동 필요 %d" % [ok, skip])


func _all_png(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return found
	for f in d.get_files():
		if f.to_lower().ends_with(".png"):
			found.append(dir_path.path_join(f))
	for sub in d.get_directories():
		found.append_array(_all_png(dir_path.path_join(sub)))
	return found


func _slice(src: String, out_dir: String, forced_frame: int) -> int:
	var img := Image.load_from_file(src)
	if img == null or img.is_empty():
		print("읽기 실패: %s" % src)
		return 0
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var horizontal := w >= h
	var frame: int = forced_frame if forced_frame > 0 else mini(w, h)
	var span: int = w if horizontal else h
	if frame <= 0 or span % frame != 0:
		print("프레임 크기를 정할 수 없다: %dx%d (frame=%d). --frame= 으로 지정하라." % [w, h, frame])
		return 0

	DirAccess.make_dir_recursive_absolute(out_dir)
	var count := span / frame
	var fw: int = frame
	var fh: int = h if horizontal else frame
	if not horizontal:
		fw = w
	for i in count:
		var cut := Image.create(fw, fh, false, Image.FORMAT_RGBA8)
		var origin := Vector2i(i * frame, 0) if horizontal else Vector2i(0, i * frame)
		cut.blit_rect(img, Rect2i(origin, Vector2i(fw, fh)), Vector2i.ZERO)
		cut.save_png(out_dir.path_join("%d.png" % i))
	return count
