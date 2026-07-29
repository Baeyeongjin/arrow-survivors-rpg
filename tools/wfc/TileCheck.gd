extends SceneTree
# 생성한 바닥 타일 후보를 기존 팩 기준으로 검수한다.
#
# 합격 기준은 앞선 실측에서 나온 세 가지 실패 원인을 그대로 뒤집은 것이다.
#   1) 테두리 어두움 — 기존 팩은 12/12장이 테두리가 어두워 32px 격자선을 그렸다.
#      새 타일은 이 값이 0 근처여야 한다.
#   2) 내부 대비 — 기존 팩은 변형 간 밝기범위가 0.022로 사실상 구분이 안 됐다.
#      타일 내부 표준편차가 커야 넓은 바닥이 평평해 보이지 않는다.
#   3) 자기 이음새 — 한 장이 자기 자신과 이어 붙었을 때 티가 나면 반복이 드러난다.
#
# 실행:
#   godot --headless --path . --script res://tools/wfc/TileCheck.gd -- --dir=<절대경로>

const OUT_DIR := "user://wfc_probe"
const CELL := 32


func _initialize() -> void:
	var dir_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			dir_path = arg.substr(6)
	if dir_path == "":
		print("--dir=<후보 폴더 절대경로> 가 필요하다")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var candidates := _load_dir(dir_path)
	var baseline := _load_pack("graveyard")
	if candidates.is_empty():
		print("후보 없음: %s" % dir_path)
		quit(1)
		return

	print("=".repeat(76))
	print("바닥 타일 후보 검수 — 후보 %d장 / 기존 팩 %d장" % [candidates.size(), baseline.size()])
	print("=".repeat(76))
	print("%-14s %12s %10s %12s %10s" % ["대상", "테두리차", "내부대비", "자기이음새", "평균밝기"])

	var base_edge := 0.0
	var base_contrast := 0.0
	var base_seam := 0.0
	var base_luma := 0.0
	for img: Image in baseline:
		var m := _measure(img)
		base_edge += m["edge_gap"]
		base_contrast += m["contrast"]
		base_seam += m["self_seam"]
		base_luma += m["luma"]
	var bn := maxf(1.0, float(baseline.size()))
	print("%-14s %12.4f %10.4f %12.4f %10.4f" % [
		"기존 팩 평균", base_edge / bn, base_contrast / bn, base_seam / bn, base_luma / bn])
	print("-".repeat(76))

	for i in candidates.size():
		var m := _measure(candidates[i]["image"])
		print("%-14s %12.4f %10.4f %12.4f %10.4f" % [
			candidates[i]["name"], m["edge_gap"], m["contrast"], m["self_seam"], m["luma"]])

	print("\n  테두리차 = 안쪽밝기 - 테두리밝기. 양수가 크면 격자선이 그려진 것이다(나쁨).")
	print("  내부대비 = 타일 안 밝기 표준편차. 클수록 넓은 바닥이 덜 평평하다(좋음).")
	print("  자기이음새 = 자기 오른쪽 끝과 왼쪽 끝의 색차. 작을수록 이어 붙여도 티가 안 난다(좋음).")

	# 반복이 눈에 보이는지 직접 확인할 수 있게 한 장을 8x8로 깐다.
	for i in candidates.size():
		_save_tiled(candidates[i]["image"], 8, "tiled_%s.png" % candidates[i]["name"])
	if not baseline.is_empty():
		_save_tiled(baseline[0], 8, "tiled_baseline_00.png")
	print("\n  8x8 반복 미리보기를 출력 폴더에 저장했다.")
	print("  출력: %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit(0)


func _measure(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var edge_sum := 0.0
	var edge_n := 0
	var inner_sum := 0.0
	var inner_n := 0
	var all_luma: PackedFloat64Array = PackedFloat64Array()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var luma := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			all_luma.append(luma)
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				edge_sum += luma
				edge_n += 1
			else:
				inner_sum += luma
				inner_n += 1

	var mean := 0.0
	for v in all_luma:
		mean += v
	mean /= maxf(1.0, float(all_luma.size()))
	var variance := 0.0
	for v in all_luma:
		variance += (v - mean) * (v - mean)
	variance /= maxf(1.0, float(all_luma.size()))

	var seam := 0.0
	for y in h:
		var ca := img.get_pixel(w - 1, y)
		var cb := img.get_pixel(0, y)
		seam += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
	seam /= (3.0 * maxf(1.0, float(h)))

	return {
		"edge_gap": inner_sum / maxf(1.0, float(inner_n)) - edge_sum / maxf(1.0, float(edge_n)),
		"contrast": sqrt(variance),
		"self_seam": seam,
		"luma": mean,
	}


func _load_dir(dir_path: String) -> Array:
	var result: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return result
	var names: Array[String] = []
	for f in d.get_files():
		if f.ends_with(".png"):
			names.append(f)
	names.sort()
	for f in names:
		var img := Image.load_from_file(dir_path.path_join(f))
		if img == null or img.is_empty():
			continue
		img.convert(Image.FORMAT_RGBA8)
		result.append({"name": f.get_basename(), "image": img})
	return result


func _load_pack(dir_name: String) -> Array:
	var images: Array = []
	for i in 24:
		var path := "res://assets/maps/%s/floor/%02d.png" % [dir_name, i]
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		var img := tex.get_image()
		if img == null or img.is_empty():
			continue
		img.convert(Image.FORMAT_RGBA8)
		images.append(img)
	return images


func _save_tiled(img: Image, times: int, filename: String) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create(w * times, h * times, false, Image.FORMAT_RGBA8)
	for y in times:
		for x in times:
			out.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(x * w, y * h))
	# 실제 화면에서 보이는 크기에 가깝게 3배 확대.
	out.resize(out.get_width() * 3, out.get_height() * 3, Image.INTERPOLATE_NEAREST)
	out.save_png(OUT_DIR + "/" + filename)
