extends SceneTree
# 아이콘 폴더를 번호 붙은 대조 시트 한 장으로. 어떤 그림인지 눈으로 고르기 위한 도구다.
#
# PixelLab 에서 받은 장비 아이콘은 파일명이 전부 unknown.png 라 이름으로는 무엇인지
# 알 수 없다. 번호를 매겨 깔고, 사장님이 번호로 지목하면 그 번호를 슬롯에 배정한다.
#
# 실행:
#   godot --headless --path . --script res://tools/fx/IconSheet.gd -- --dir=res://assets/items/_incoming

const OUT_DIR := "user://wfc_probe"
const CELL := 72     # 32px 아이콘을 2배로 키우고 여백
const ZOOM := 2
const COLS := 11


func _initialize() -> void:
	var dir_path := "res://assets/items/_incoming"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			dir_path = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var names: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		print("폴더를 열 수 없다: %s" % dir_path)
		quit(1)
		return
	for f in d.get_files():
		if f.to_lower().ends_with(".png"):
			names.append(f)
	names.sort()
	if names.is_empty():
		print("png 가 없다: %s" % dir_path)
		quit(1)
		return

	var rows := int(ceil(names.size() / float(COLS)))
	var sheet := Image.create(COLS * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	# 아이콘이 대체로 어두워서 중간 회색 배경에 깔아야 윤곽이 보인다.
	sheet.fill(Color(0.18, 0.18, 0.21))

	for i in names.size():
		var tex := load(dir_path.path_join(names[i])) as Texture2D
		if tex == null:
			continue
		var img := tex.get_image()
		if img == null or img.is_empty():
			continue
		img.convert(Image.FORMAT_RGBA8)
		var big := img.duplicate() as Image
		big.resize(img.get_width() * ZOOM, img.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
		var ox := (i % COLS) * CELL + (CELL - big.get_width()) / 2
		var oy := (i / COLS) * CELL + (CELL - big.get_height()) / 2
		sheet.blend_rect(big, Rect2i(0, 0, big.get_width(), big.get_height()), Vector2i(ox, oy))

	sheet.save_png(OUT_DIR + "/icon_sheet.png")
	print("아이콘 %d개 · %d열 x %d행" % [names.size(), COLS, rows])
	print("좌상단이 0번, 오른쪽으로 %d개마다 줄바꿈." % COLS)
	print("시트: %s/icon_sheet.png" % ProjectSettings.globalize_path(OUT_DIR))
	quit(0)
