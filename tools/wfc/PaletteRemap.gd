extends SceneTree
# 생성된 텍스처를 우리 팔레트로 강제 변환한다.
#
# 왜 후처리인가: 프롬프트로 색을 지시하는 건 이미 5회 실패했고(StageTileRenderer 주석),
# 팔레트를 어둡게 가중해 강제했더니 이번엔 모델이 통째로 검정을 뱉었다(실측 밝기 0.0000).
# 생성 단계에서 색까지 통제하려 하면 구조가 망가진다.
# 그래서 구조는 모델에 맡기고, 색은 여기서 결정적으로 맞춘다.
#
# 방식: 밝기 백분위 매핑. 원본 픽셀을 밝기 순으로 줄 세운 뒤 백분위를 목표 팔레트의
# 누적 가중치 구간에 대응시킨다. 무늬(어디가 밝고 어두운지)는 그대로 남고 색 분포만
# 목표대로 바뀐다. 최근접색 양자화와 달리 원본이 전체적으로 밝아도 결과가 뭉치지 않는다.
#
# 실행:
#   godot --headless --path . --script res://tools/wfc/PaletteRemap.gd -- \
#       --src=<png절대경로> --out=<png절대경로>

# 목표 팔레트 (어두운 순) + 가중치. 기존 묘지 팩의 색 계열은 유지하되
# 톤 범위를 넓혀 넓은 바닥이 평평해 보이지 않게 한다.
const TARGET := [
	["0d0d08", 8],
	["141410", 16],
	["1a1a12", 20],
	["201a12", 16],
	["242418", 14],
	["2a2a1e", 10],
	["322a1c", 6],
	["2e3a24", 4],
	["383826", 4],
	["443a24", 2],
]


func _initialize() -> void:
	var src := ""
	var out_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--src="):
			src = arg.substr(6)
		elif arg.begins_with("--out="):
			out_path = arg.substr(6)
	if src == "" or out_path == "":
		print("--src=<png> --out=<png> 가 필요하다")
		quit(1)
		return

	var img := Image.load_from_file(src)
	if img == null or img.is_empty():
		print("원본을 읽을 수 없다: %s" % src)
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)

	var w := img.get_width()
	var h := img.get_height()

	# 1) 밝기 수집
	var lumas := PackedFloat64Array()
	lumas.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			lumas[x + y * w] = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

	# 2) 백분위 계산용 정렬본
	var sorted_luma := lumas.duplicate()
	sorted_luma.sort()

	# 3) 목표 팔레트의 누적 경계
	var colors: Array[Color] = []
	var bounds := PackedFloat64Array()
	var total_weight := 0.0
	for entry in TARGET:
		total_weight += float(entry[1])
	var acc := 0.0
	for entry in TARGET:
		colors.append(Color(str(entry[0])))
		acc += float(entry[1])
		bounds.append(acc / total_weight)

	# 4) 매핑
	var before_mean := 0.0
	for v in lumas:
		before_mean += v
	before_mean /= maxf(1.0, float(lumas.size()))

	for y in h:
		for x in w:
			var luma := lumas[x + y * w]
			var rank := _percentile(sorted_luma, luma)
			var pick := colors.size() - 1
			for i in bounds.size():
				if rank <= bounds[i]:
					pick = i
					break
			var src_alpha := img.get_pixel(x, y).a
			var c := colors[pick]
			img.set_pixel(x, y, Color(c.r, c.g, c.b, src_alpha))

	var after_mean := 0.0
	var after_values := PackedFloat64Array()
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			after_values.append(l)
			after_mean += l
	after_mean /= maxf(1.0, float(after_values.size()))
	var variance := 0.0
	for v in after_values:
		variance += (v - after_mean) * (v - after_mean)
	variance /= maxf(1.0, float(after_values.size()))

	img.save_png(out_path)
	print("리매핑 완료: %dx%d" % [w, h])
	print("  평균 밝기 %.4f → %.4f (목표 팔레트 %d색)" % [before_mean, after_mean, colors.size()])
	print("  결과 대비(표준편차) %.4f  [기존 팩 평균 0.0465]" % sqrt(variance))
	print("  출력: %s" % out_path)
	quit(0)


# 이진 탐색으로 value의 백분위(0~1)를 구한다.
func _percentile(sorted_values: PackedFloat64Array, value: float) -> float:
	var lo := 0
	var hi := sorted_values.size()
	while lo < hi:
		var mid := (lo + hi) / 2
		if sorted_values[mid] < value:
			lo = mid + 1
		else:
			hi = mid
	return float(lo) / maxf(1.0, float(sorted_values.size() - 1))
