extends SceneTree
# 이펙트 대조 시트. assets/anim 아래 fx_* / proj_* 를 전부 한 장에 깔아
# "어느 것이 겉도는가"를 눈으로 고를 수 있게 한다.
#
# 이미지에는 이름을 못 넣는다(Image에 글자를 그릴 수단이 없다). 대신 콘솔에
# 번호↔이름 표를 찍는다. 시트에서 번호를 세어 지목하면 된다.
#
# 실행:
#   godot --headless --path . --script res://tools/fx/FxSheet.gd

const OUT_DIR := "user://wfc_probe"
const CELL := 96      # 칸 크기
const COLS := 8


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var names := _effect_names()
	if names.is_empty():
		print("assets/anim 에서 fx_/proj_ 폴더를 찾지 못했다")
		quit(1)
		return

	var rows := int(ceil(names.size() / float(COLS)))
	var sheet := Image.create(COLS * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	# 밝은 이펙트와 어두운 이펙트를 함께 보려면 중간 회색 배경이 낫다.
	sheet.fill(Color(0.16, 0.16, 0.19))

	print("=".repeat(70))
	print("이펙트 대조 시트 — %d종 (%d열 x %d행)" % [names.size(), COLS, rows])
	print("=".repeat(70))
	print("%-5s %-24s %6s %10s" % ["번호", "이름", "프레임", "크기"])

	for i in names.size():
		var frames := _frames_of(names[i])
		var info := "없음"
		if not frames.is_empty():
			# 대표 프레임: 이펙트는 중간이 가장 잘 보인다(시작·끝은 투명한 경우가 많다).
			var mid: Image = frames[frames.size() / 2]
			info = "%dx%d" % [mid.get_width(), mid.get_height()]
			_blit_fit(sheet, mid, (i % COLS) * CELL, (i / COLS) * CELL)
		print("%-5d %-24s %6d %10s" % [i, names[i], frames.size(), info])

	sheet.save_png(OUT_DIR + "/fx_sheet.png")
	print("\n시트: %s/fx_sheet.png" % ProjectSettings.globalize_path(OUT_DIR))
	print("좌상단이 0번, 오른쪽으로 세어 %d개마다 줄바꿈이다." % COLS)
	quit(0)


func _effect_names() -> Array[String]:
	var names: Array[String] = []
	var d := DirAccess.open("res://assets/anim")
	if d == null:
		return names
	for dir_name in d.get_directories():
		# vfx_* 는 스킬이 형태 x 원소 매트릭스로 고르는 자산군이다(FxMatrix).
		# fx_* 와 별개 계열이라 예전에는 시트에 안 잡혔는데, 어긋난 조합을 찾으려면
		# 이쪽을 봐야 한다(화염만 cast/zone/ward 세 군데에서 문제가 나왔다).
		if dir_name.begins_with("fx_") or dir_name.begins_with("proj_") \
				or dir_name.begins_with("vfx_"):
			names.append(dir_name)
	names.sort()
	return names


func _frames_of(dir_name: String) -> Array:
	var frames: Array = []
	for i in 24:
		var path := "res://assets/anim/%s/%d.png" % [dir_name, i]
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		var img := tex.get_image()
		if img == null or img.is_empty():
			continue
		img.convert(Image.FORMAT_RGBA8)
		frames.append(img)
	return frames


# 칸에 맞춰 정수배로 키우거나 줄여 넣는다. 도트가 뭉개지지 않게 최근접만 쓴다.
func _blit_fit(sheet: Image, img: Image, ox: int, oy: int) -> void:
	var longest: int = maxi(img.get_width(), img.get_height())
	var scaled := img.duplicate() as Image
	if longest > CELL - 8:
		var ratio := float(CELL - 8) / float(longest)
		scaled.resize(maxi(1, int(img.get_width() * ratio)), maxi(1, int(img.get_height() * ratio)),
			Image.INTERPOLATE_NEAREST)
	elif longest > 0:
		var zoom: int = maxi(1, int(floor((CELL - 8) / float(longest))))
		if zoom > 1:
			scaled.resize(img.get_width() * zoom, img.get_height() * zoom, Image.INTERPOLATE_NEAREST)
	var px := ox + (CELL - scaled.get_width()) / 2
	var py := oy + (CELL - scaled.get_height()) / 2
	sheet.blend_rect(scaled, Rect2i(0, 0, scaled.get_width(), scaled.get_height()), Vector2i(px, py))
