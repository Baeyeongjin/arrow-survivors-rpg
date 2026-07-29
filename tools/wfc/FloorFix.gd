extends SceneTree
# 기존 바닥 팩을 실측된 두 결함만 겨냥해 고친다. 새로 그리지 않고 있는 아트를 손본다.
#
# 실측된 결함
#   1) 테두리 격자선 — 12/12장이 테두리가 안쪽보다 어둡다(0.0465 vs 0.0690).
#      이 대비(0.0224)가 12장 전체의 밝기범위(0.022)보다 커서, 변형을 아무리 늘려도
#      화면에는 32px 격자가 가장 먼저 보인다.
#   2) 톤 범위 없음 — 팔레트가 9색이고 5색이 98.8%다. 전부 거의 검정이라
#      변형끼리 구분이 안 되고(군집수 1) 넓은 바닥이 평평하다.
#
# 처리
#   1) 테두리 링을 안쪽 평균 밝기에 맞춰 곱셈 보정. 링 고유의 무늬는 남기고
#      "체계적으로 어둡다"만 없앤다.
#   2) 팩 전체를 하나로 묶어 밝기 백분위 → 목표 팔레트 매핑. 팩 단위로 해야
#      타일 사이의 밝기 차이가 유지된다(타일별로 하면 전부 같은 히스토그램이 된다).
#
# 실행:
#   godot --headless --path . --script res://tools/wfc/FloorFix.gd -- --stage=graveyard [--apply]
#   --apply 없이는 미리보기만 만들고 원본을 건드리지 않는다.

const OUT_DIR := "user://wfc_probe"
const CELL := 32

# 목표 밝기 곡선. 백분위 p를 LO..HI 구간에 p^GAMMA로 대응시킨다.
# GAMMA > 1이면 어두운 쪽이 넓어져 기존 팩의 어두운 성격을 유지하면서 위쪽 톤만 열린다.
#
# 고정 팔레트를 쓰지 않는 이유: 던전마다 색 정체성이 다르다(실측 지배색 — 지옥 #380800
# 순수 빨강, 빙하 #182050 파랑, 공허 #080818 보라, 묘지 #201008 올리브).
# 하나의 팔레트로 밀면 네 던전의 색이 뭉개진다. 그래서 픽셀의 색조는 그대로 두고
# 밝기만 재배치한다.
# LO/HI는 팩마다 자기 평균 밝기에서 유도한다. 고정값을 쓰면 원래 밝은 팩(빙하 0.155)이
# 끌려 내려가고 어두운 팩(지옥 0.037)은 과하게 밝아진다.
#   LO = m*0.25, HI = LO + m*2.0  →  출력 평균 = LO + (HI-LO)/(GAMMA+1) ≈ 1.02*m
# 즉 팩의 밝기 정체성은 그대로 두고 퍼짐만 넓힌다.
#   LO = m*LO_RATIO,  HI = LO + (GAMMA+1)*(m - LO)  →  출력 평균 = m (보존)
# 평균을 고정한 채 퍼짐을 넓히려면 감마를 올려야 한다. 감마가 크면 대부분의 픽셀이
# 어두운 쪽에 몰리므로 같은 평균에서 위쪽 톤을 더 열 수 있다.
# HI_CAP은 바닥이 캐릭터보다 밝아지는 것을 막는 상한이다.
const LO_RATIO := 0.10
const GAMMA := 2.2
const HI_CAP := 0.42

# 원본 팩의 색은 전부 8의 배수다(#080000, #182050 …). 결과도 같은 격자에 맞춰
# 픽셀아트다운 제한 팔레트를 유지한다.
const QUANT := 8


func _initialize() -> void:
	var stage_dir := "graveyard"
	var apply := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			stage_dir = arg.split("=")[1]
		elif arg == "--apply":
			apply = true
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var paths := _pack_paths(stage_dir)
	if paths.is_empty():
		print("팩 없음: %s" % stage_dir)
		quit(1)
		return
	var images: Array[Image] = []
	for p in paths:
		var tex := load(p) as Texture2D
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		images.append(img)

	print("=".repeat(70))
	print("바닥 팩 보정: %s (%d장)%s" % [stage_dir, images.size(), "" if apply else "  [미리보기 전용]"])
	print("=".repeat(70))

	_report_ring_profile(images)
	var before := _pack_stats(images)

	_flatten_and_remap(images)

	var after := _pack_stats(images)
	print("\n%-16s %12s %12s" % ["지표", "보정 전", "보정 후"])
	print("%-16s %12.4f %12.4f" % ["테두리차", before["edge_gap"], after["edge_gap"]])
	print("%-16s %12.4f %12.4f" % ["타일내 대비", before["contrast"], after["contrast"]])
	print("%-16s %12.4f %12.4f" % ["타일간 밝기범위", before["luma_range"], after["luma_range"]])
	print("%-16s %12.4f %12.4f" % ["평균 밝기", before["luma"], after["luma"]])

	_save_field(images, 24, "fixed_field_%s.png" % stage_dir)
	_save_sheet(images, "fixed_sheet_%s.png" % stage_dir)

	if apply:
		for i in images.size():
			var abs_path := ProjectSettings.globalize_path(paths[i])
			images[i].save_png(abs_path)
		print("\n원본 %d장을 덮어썼다." % images.size())
	else:
		print("\n원본은 건드리지 않았다. 적용하려면 --apply 를 붙인다.")
	print("미리보기: %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit(0)


func _pack_paths(dir_name: String) -> Array[String]:
	var paths: Array[String] = []
	for i in 24:
		var path := "res://assets/maps/%s/floor/%02d.png" % [dir_name, i]
		if ResourceLoader.exists(path):
			paths.append(path)
	return paths


# 가장자리에서 안쪽으로 들어가며 링별 평균 밝기. 격자선이 몇 픽셀 두께인지 본다.
func _report_ring_profile(images: Array[Image]) -> void:
	print("\n링별 평균 밝기 (가장자리 → 안쪽)")
	var line := "  "
	for depth in 4:
		var total := 0.0
		var count := 0
		for img in images:
			var w := img.get_width()
			var h := img.get_height()
			for y in h:
				for x in w:
					var d: int = mini(mini(x, y), mini(w - 1 - x, h - 1 - y))
					if d != depth:
						continue
					var c := img.get_pixel(x, y)
					total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
					count += 1
		line += "d%d=%.4f  " % [depth, total / maxf(1.0, float(count))]
	print(line)


# 타일 가장자리의 베벨을 평탄화한다.
# 실측 링 프로파일이 d0=0.0465(어두운 테두리) / d1=0.0770(밝은 하이라이트) /
# d2~d3≈0.066(안쪽)으로, 바깥 두 링이 입체 테두리를 이룬다. 이게 32px 격자의 정체다.
# 두 링을 각각 안쪽(d>=2) 평균에 맞춰 곱셈 보정한다. 링 안의 무늬는 그대로 남는다.
const FLATTEN_RINGS := 2


# 베벨 평탄화와 팔레트 매핑을 한 번에 한다.
#
# 곱셈으로 밝기를 맞춘 뒤 백분위 매핑을 하면 어긋난다(실측: 테두리차가 +0.0224에서
# -0.0182로 뒤집혔다). 최종 색은 밝기가 아니라 '순위'로 결정되는데, 곱셈은 순위 분포를
# 균등하게 옮겨주지 않기 때문이다. 링을 밝히면 분포가 가운데로 좁아지고, 목표 팔레트가
# 어두운 쪽에 가중돼 있어 안쪽만 더 어두워진다.
#
# 그래서 보정을 순위 공간에서 한다. 링별 평균 순위를 안쪽 평균 순위에 맞춰 평행이동한
# 뒤 팔레트로 보낸다. 최종 색이 순위의 함수이므로 평균 순위를 맞추면 평균 색이 맞는다.
func _flatten_and_remap(images: Array[Image]) -> void:
	var all_luma := PackedFloat64Array()
	for img in images:
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				all_luma.append(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b)
	var sorted_luma := all_luma.duplicate()
	sorted_luma.sort()

	# 픽셀별 순위와 링 등급을 한 번만 계산해 둔다(등급 2 = 안쪽).
	var pcts := PackedFloat64Array()
	var ring_class := PackedByteArray()
	for img in images:
		var w := img.get_width()
		var h := img.get_height()
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				pcts.append(_percentile(sorted_luma, 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b))
				var d: int = mini(mini(x, y), mini(w - 1 - x, h - 1 - y))
				ring_class.append(mini(d, FLATTEN_RINGS))

	# 완전한 검정 픽셀은 색조 정보가 없다(묘지는 28%가 #000000). 팩 평균 색에서
	# 색조 방향을 뽑아 그 픽셀들에 쓴다. 그래야 지옥은 붉게, 빙하는 푸르게 밝아진다.
	var sum_rgb := Vector3.ZERO
	var sum_luma := 0.0
	for img in images:
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				sum_rgb += Vector3(c.r, c.g, c.b)
				sum_luma += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	var tint_dir := Vector3(1, 1, 1)
	if sum_luma > 0.0001:
		tint_dir = sum_rgb / sum_luma

	var pack_mean := sum_luma / maxf(1.0, float(all_luma.size()))
	var lo := pack_mean * LO_RATIO
	var hi := minf(lo + (GAMMA + 1.0) * (pack_mean - lo), HI_CAP)
	print("팩 색조 방향: (%.2f, %.2f, %.2f) · 평균 %.4f → 목표 구간 %.4f~%.4f" % [
		tint_dir.x, tint_dir.y, tint_dir.z, pack_mean, lo, hi])

	# 링 보정량을 출력 밝기 기준으로 반복 수렴시킨다.
	# 순위 공간에서 한 번에 맞추면 감마에 따라 결과가 달라진다(감마 1.6에서는 테두리차
	# 0.0030, 2.2에서는 0.0175). 최종 밝기를 직접 보고 조정하면 감마와 무관해진다.
	var offsets := PackedFloat64Array()
	offsets.resize(FLATTEN_RINGS)
	for _iter in 8:
		var ring_out := PackedFloat64Array()
		var ring_cnt := PackedInt32Array()
		ring_out.resize(FLATTEN_RINGS)
		ring_cnt.resize(FLATTEN_RINGS)
		var deep_out := 0.0
		var deep_cnt := 0
		for i in pcts.size():
			var rc := ring_class[i]
			var p := pcts[i]
			if rc < FLATTEN_RINGS:
				p = clampf(p + offsets[rc], 0.0, 1.0)
			var out_luma := lo + (hi - lo) * pow(p, GAMMA)
			if rc < FLATTEN_RINGS:
				ring_out[rc] += out_luma
				ring_cnt[rc] += 1
			else:
				deep_out += out_luma
				deep_cnt += 1
		var deep_mean_out := deep_out / maxf(1.0, float(deep_cnt))
		var converged := true
		for d in FLATTEN_RINGS:
			var mean_out := ring_out[d] / maxf(1.0, float(ring_cnt[d]))
			var gap := deep_mean_out - mean_out
			if absf(gap) > 0.0004:
				converged = false
			# 목표 곡선의 기울기로 밝기 오차를 순위 보정량으로 환산한다.
			var p_here := clampf(0.5 + offsets[d], 0.02, 0.98)
			var slope := maxf((hi - lo) * GAMMA * pow(p_here, GAMMA - 1.0), 0.02)
			offsets[d] = clampf(offsets[d] + gap / slope, -0.8, 0.8)
		if converged:
			break
	print("링 보정량(순위): " + " ".join(Array(offsets).map(func(v): return "%+.4f" % v)))

	var index := 0
	for img in images:
		var w := img.get_width()
		var h := img.get_height()
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				var luma := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
				var pct := pcts[index]
				var rc := ring_class[index]
				index += 1
				if rc < FLATTEN_RINGS:
					pct = clampf(pct + offsets[rc], 0.0, 1.0)
				var target := lo + (hi - lo) * pow(pct, GAMMA)
				var rgb: Vector3
				if luma > 0.004:
					# 자기 색조를 그대로 두고 밝기만 맞춘다.
					rgb = Vector3(c.r, c.g, c.b) * (target / luma)
				else:
					rgb = tint_dir * target
				img.set_pixel(x, y, Color(
					_quant(rgb.x), _quant(rgb.y), _quant(rgb.z), c.a))

	# 8단위 양자화가 어두운 색에서 아래로 치우쳐 팩 평균이 내려간다(실측 0.0663 → 0.0507).
	# 곡선을 다시 손대는 대신 결과를 직접 재서 이득을 맞춘다.
	for _iter in 4:
		var current := _mean_luma_of(images)
		if current <= 0.0001 or absf(current - pack_mean) / pack_mean < 0.02:
			break
		var gain := pack_mean / current
		for img in images:
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					img.set_pixel(x, y, Color(
						_quant(c.r * gain), _quant(c.g * gain), _quant(c.b * gain), c.a))


func _mean_luma_of(images: Array[Image]) -> float:
	var total := 0.0
	var n := 0
	for img in images:
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
				n += 1
	return total / maxf(1.0, float(n))


func _quant(value: float) -> float:
	var v := int(round(clampf(value, 0.0, 1.0) * 255.0 / float(QUANT))) * QUANT
	return clampf(float(v) / 255.0, 0.0, 1.0)


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


func _pack_stats(images: Array[Image]) -> Dictionary:
	var edge_gap := 0.0
	var contrast := 0.0
	var luma := 0.0
	var per_tile_luma := PackedFloat64Array()
	for img in images:
		var w := img.get_width()
		var h := img.get_height()
		var edge_sum := 0.0
		var edge_n := 0
		var inner_sum := 0.0
		var inner_n := 0
		var values := PackedFloat64Array()
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
				values.append(l)
				if x == 0 or y == 0 or x == w - 1 or y == h - 1:
					edge_sum += l
					edge_n += 1
				else:
					inner_sum += l
					inner_n += 1
		var mean := 0.0
		for v in values:
			mean += v
		mean /= maxf(1.0, float(values.size()))
		var variance := 0.0
		for v in values:
			variance += (v - mean) * (v - mean)
		contrast += sqrt(variance / maxf(1.0, float(values.size())))
		edge_gap += inner_sum / maxf(1.0, float(inner_n)) - edge_sum / maxf(1.0, float(edge_n))
		luma += mean
		per_tile_luma.append(mean)
	var n := maxf(1.0, float(images.size()))
	var lo := per_tile_luma[0]
	var hi := per_tile_luma[0]
	for v in per_tile_luma:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return {
		"edge_gap": edge_gap / n, "contrast": contrast / n,
		"luma": luma / n, "luma_range": hi - lo,
	}


func _save_field(images: Array[Image], size: int, filename: String) -> void:
	var out := Image.create(size * CELL, size * CELL, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("graveyard")
	for y in size:
		for x in size:
			out.blit_rect(images[rng.randi_range(0, images.size() - 1)],
				Rect2i(0, 0, CELL, CELL), Vector2i(x * CELL, y * CELL))
	out.save_png(OUT_DIR + "/" + filename)


func _save_sheet(images: Array[Image], filename: String) -> void:
	var zoom := 4
	var cols := 6
	var rows := int(ceil(images.size() / float(cols)))
	var sheet := Image.create(cols * CELL * zoom, rows * CELL * zoom, false, Image.FORMAT_RGBA8)
	for i in images.size():
		var big := images[i].duplicate() as Image
		big.resize(CELL * zoom, CELL * zoom, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(big, Rect2i(0, 0, CELL * zoom, CELL * zoom),
			Vector2i((i % cols) * CELL * zoom, (i / cols) * CELL * zoom))
	sheet.save_png(OUT_DIR + "/" + filename)
