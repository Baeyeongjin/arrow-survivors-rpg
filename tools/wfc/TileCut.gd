extends SceneTree
# 큰 텍스처 한 장에서 32px 바닥 타일을 잘라낸다.
#
# 개별 타일을 직접 생성하면 모델이 "타일"을 그리려고 테두리를 붙인다(실측: 테두리차
# 0.0452로 기존 팩 0.0224보다 나빴다). 큰 텍스처의 안쪽을 잘라내면 테두리가 원천적으로
# 없고, 한 장에서 나왔으니 팔레트와 화풍도 자동으로 일치한다.
#
# 실행:
#   godot --headless --path . --script res://tools/wfc/TileCut.gd -- \
#       --src=<원본png절대경로> --out=<출력폴더절대경로> --count=12

const CELL := 32
const INSET := 8       # 바깥 테두리 링은 버린다
const STRIDE := 8      # 후보 크롭 간격
const PREVIEW_DIR := "user://wfc_probe"


func _initialize() -> void:
	var src := ""
	var out_dir := ""
	var want := 12
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--src="):
			src = arg.substr(6)
		elif arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg.begins_with("--count="):
			want = int(arg.substr(8))
	if src == "" or out_dir == "":
		print("--src=<png> --out=<폴더> 가 필요하다")
		quit(1)
		return

	var source := Image.load_from_file(src)
	if source == null or source.is_empty():
		print("원본을 읽을 수 없다: %s" % src)
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.make_dir_recursive_absolute(PREVIEW_DIR)

	# 1) 안쪽 영역에서 후보 크롭을 모은다.
	var candidates: Array = []
	var max_x := source.get_width() - INSET - CELL
	var max_y := source.get_height() - INSET - CELL
	var x := INSET
	while x <= max_x:
		var y := INSET
		while y <= max_y:
			var crop := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
			crop.blit_rect(source, Rect2i(x, y, CELL, CELL), Vector2i.ZERO)
			candidates.append({"image": crop, "x": x, "y": y, "contrast": _contrast(crop)})
			y += STRIDE
		x += STRIDE

	if candidates.is_empty():
		print("후보를 만들 수 없다. 원본이 너무 작다 (%dx%d)" % [source.get_width(), source.get_height()])
		quit(1)
		return
	print("후보 크롭 %d개 (원본 %dx%d, 안쪽 %d px 제외)" % [
		candidates.size(), source.get_width(), source.get_height(), INSET])

	# 2) 대비가 가장 높은 것을 씨앗으로, 이후 기존 선택들과 가장 다른 것을 차례로 고른다.
	#    같은 텍스처에서 잘라내므로 서로 최대한 다른 크롭을 골라야 반복감이 줄어든다.
	candidates.sort_custom(func(a, b): return a["contrast"] > b["contrast"])
	var chosen: Array = [candidates[0]]
	while chosen.size() < want and chosen.size() < candidates.size():
		var best := -1
		var best_score := -1.0
		for i in candidates.size():
			if _already_chosen(chosen, candidates[i]):
				continue
			var nearest := INF
			for c in chosen:
				nearest = minf(nearest, _distance(candidates[i]["image"], c["image"]))
			# 서로 다른 것을 우선하되 대비도 약간 반영한다.
			var score: float = nearest + 0.25 * float(candidates[i]["contrast"])
			if score > best_score:
				best_score = score
				best = i
		if best < 0:
			break
		chosen.append(candidates[best])

	# 3) 저장 + 계측
	print("\n%-6s %8s %10s %12s %10s" % ["번호", "위치", "내부대비", "자기이음새", "평균밝기"])
	for i in chosen.size():
		var img: Image = chosen[i]["image"]
		img.save_png(out_dir.path_join("%02d.png" % i))
		print("%-6d %4d,%-4d %10.4f %12.4f %10.4f" % [
			i, chosen[i]["x"], chosen[i]["y"], _contrast(img), _self_seam(img), _luma(img)])

	# 4) 실제 렌더처럼 균등 랜덤으로 넓은 바닥을 깔아 격자감을 눈으로 확인한다.
	_save_field(chosen, 24, "cut_field.png")
	print("\n넓은 바닥 미리보기: %s/cut_field.png" % ProjectSettings.globalize_path(PREVIEW_DIR))
	print("출력 타일: %s" % out_dir)
	quit(0)


func _already_chosen(chosen: Array, candidate: Dictionary) -> bool:
	for c in chosen:
		if c["x"] == candidate["x"] and c["y"] == candidate["y"]:
			return true
	return false


func _distance(a: Image, b: Image) -> float:
	var total := 0.0
	var n := 0
	for y in range(0, CELL, 2):
		for x in range(0, CELL, 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			n += 1
	return total / (3.0 * maxf(1.0, float(n)))


func _contrast(img: Image) -> float:
	var values: PackedFloat64Array = PackedFloat64Array()
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			values.append(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b)
	var mean := 0.0
	for v in values:
		mean += v
	mean /= maxf(1.0, float(values.size()))
	var variance := 0.0
	for v in values:
		variance += (v - mean) * (v - mean)
	return sqrt(variance / maxf(1.0, float(values.size())))


func _self_seam(img: Image) -> float:
	var h := img.get_height()
	var total := 0.0
	for y in h:
		var ca := img.get_pixel(img.get_width() - 1, y)
		var cb := img.get_pixel(0, y)
		total += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
	return total / (3.0 * maxf(1.0, float(h)))


func _luma(img: Image) -> float:
	var total := 0.0
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
	return total / maxf(1.0, float(n))


# StageTileRenderer와 같은 방식(균등 랜덤)으로 깐다. 실제 화면과 같은 조건이어야
# 격자감이 사라졌는지 판단할 수 있다.
func _save_field(chosen: Array, size: int, filename: String) -> void:
	var out := Image.create(size * CELL, size * CELL, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("graveyard")
	for y in size:
		for x in size:
			var img: Image = chosen[rng.randi_range(0, chosen.size() - 1)]["image"]
			out.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(x * CELL, y * CELL))
	out.save_png(PREVIEW_DIR + "/" + filename)
