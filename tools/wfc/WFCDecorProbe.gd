extends SceneTree
# 타일·조형물 배치를 WFC로 재설계할 수 있는가에 대한 실측.
# 맵 크기는 건드리지 않는다. 관심사는 두 개다:
#   (A) 바닥 변형 타일 팩에 WFC가 쓸 만한 인접 제약이 뽑히는가
#   (B) 조형물(scatter) 자산이 지금 얼마나 쓰이고 있는가
#
# 실행:
#   godot --headless --path . --script res://tools/wfc/WFCDecorProbe.gd
#
# (A)가 중요한 이유: 앞선 실측에서 코너 Wang 16장은 "어떤 타일 옆에도 항상 호환 타일이
# 있는" 완전 무제약 집합이라 WFC가 백색소음을 뱉었다. 바닥 팩도 서로 완전 교체 가능하면
# 똑같은 결과가 나온다. 지금 코드가 이미 균등 랜덤(rng.randi_range)으로 고르고 있으므로,
# 제약이 없다면 WFC를 붙여도 결과가 달라지지 않는다.

const CELL := 32
const STAGE_DIRS := {
	1: "graveyard", 2: "hell_bridge", 3: "glacier", 4: "void_altar", 5: "demon_castle",
}
const STAGE_NAMES := {1: "묘지", 2: "지옥", 3: "빙하", 4: "공허", 5: "마왕성"}
const OUT_DIR := "user://wfc_probe"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	print("=".repeat(78))
	print("타일·조형물 WFC 재설계 가능성 실측 (맵 크기 불변)")
	print("=".repeat(78))
	_probe_floor_packs()
	_probe_arrangement_matters()
	_probe_scatter()
	_save_contact_sheets()
	print("\n출력 폴더: %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit(0)


# ---------------------------------------------------------------- (A) 바닥 팩

func _probe_floor_packs() -> void:
	print("\n[A] 바닥 변형 타일 팩 — WFC가 쓸 인접 제약이 있는가")
	print("%-8s %6s %10s %10s %12s %10s" % ["던전", "장수", "밝기범위", "이음새평균", "이음새최소", "군집수"])
	for stage in range(1, 6):
		var dir_name: String = STAGE_DIRS[stage]
		var images := _load_pack(dir_name)
		if images.is_empty():
			print("%-8s %6s" % [STAGE_NAMES[stage], "없음"])
			continue

		# 1) 밝기 분포 — 변형끼리 시각적으로 구분되는가 (군집 가능성)
		var brightness: PackedFloat64Array = PackedFloat64Array()
		for img in images:
			brightness.append(_mean_luma(img))
		var b_min := brightness[0]
		var b_max := brightness[0]
		for v in brightness:
			b_min = minf(b_min, v)
			b_max = maxf(b_max, v)

		# 2) 이음새 거리 — A의 오른쪽 끝 열과 B의 왼쪽 끝 열이 얼마나 맞는가.
		#    작을수록 "이어 붙여도 티가 안 남" = 제약 없음.
		var seam_sum := 0.0
		var seam_min := INF
		var seam_max := 0.0
		var pairs := 0
		for a in images.size():
			for b in images.size():
				var d := _seam_distance(images[a], images[b])
				seam_sum += d
				seam_min = minf(seam_min, d)
				seam_max = maxf(seam_max, d)
				pairs += 1
		var seam_avg := seam_sum / float(pairs)

		# 3) 밝기 기준 단순 군집 — 변형을 "지형 종류"로 묶을 수 있는가.
		var clusters := _count_clusters(brightness, 0.04)

		print("%-8s %6d %9.3f %10.4f %12.4f %10d" % [
			STAGE_NAMES[stage], images.size(), b_max - b_min, seam_avg, seam_min, clusters])

	print("\n  이음새 거리는 0~1 정규화값이다. 값이 작고 편차가 없으면 어떤 타일이든")
	print("  아무 데나 붙일 수 있다는 뜻 = 인접 제약 없음 = WFC를 붙여도 균등 랜덤과 같다.")


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


func _mean_luma(img: Image) -> float:
	var total := 0.0
	var count := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			count += 1
	return total / maxf(1.0, float(count))


# a의 오른쪽 끝 열과 b의 왼쪽 끝 열의 평균 색 거리.
func _seam_distance(a: Image, b: Image) -> float:
	var h: int = mini(a.get_height(), b.get_height())
	var ax := a.get_width() - 1
	var total := 0.0
	for y in h:
		var ca := a.get_pixel(ax, y)
		var cb := b.get_pixel(0, y)
		total += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
	return total / (3.0 * maxf(1.0, float(h)))


# 밝기값을 정렬해 간격이 tolerance보다 벌어지는 지점에서 끊는다.
func _count_clusters(values: PackedFloat64Array, tolerance: float) -> int:
	var sorted := Array(values)
	sorted.sort()
	if sorted.is_empty():
		return 0
	var clusters := 1
	for i in range(1, sorted.size()):
		if sorted[i] - sorted[i - 1] > tolerance:
			clusters += 1
	return clusters


# ------------------------------------------------ (A-2) 배치가 결과를 바꾸는가

# 결정적 실험. 같은 타일 팩으로 두 장을 만든다.
#   uniform : 지금 StageTileRenderer가 하는 균등 랜덤
#   patches : 큰 덩어리로 뭉친 배치 (WFC가 낼 수 있는 응집력의 상한)
# 두 장이 육안으로 같아 보이면, 배치 알고리즘을 아무리 바꿔도 화면은 안 변한다.
func _probe_arrangement_matters() -> void:
	print("\n[A-2] 배치를 바꾸면 화면이 달라지는가 — 균등 랜덤 vs 최대 응집 배치")
	for stage in [1, 3, 5]:
		var dir_name: String = STAGE_DIRS[stage]
		var images := _load_pack(dir_name)
		if images.is_empty():
			continue
		var size := 24
		var rng := RandomNumberGenerator.new()

		rng.seed = hash(dir_name)
		var uniform := PackedInt32Array()
		for i in size * size:
			uniform.append(rng.randi_range(0, images.size() - 1))

		# 보로노이 씨앗 6개로 큰 덩어리를 만든다. WFC보다 응집력이 강한 상한값이다.
		rng.seed = hash(dir_name)
		var seeds: Array[Vector2i] = []
		var seed_variant := PackedInt32Array()
		for s in 6:
			seeds.append(Vector2i(rng.randi_range(0, size - 1), rng.randi_range(0, size - 1)))
			seed_variant.append(rng.randi_range(0, images.size() - 1))
		var patches := PackedInt32Array()
		for y in size:
			for x in size:
				var best := 0
				var best_d := 1 << 30
				for s in seeds.size():
					var d: int = (seeds[s].x - x) * (seeds[s].x - x) + (seeds[s].y - y) * (seeds[s].y - y)
					if d < best_d:
						best_d = d
						best = s
				patches.append(seed_variant[best])

		_render_floor(images, uniform, size, "floor_%s_uniform.png" % dir_name)
		_render_floor(images, patches, size, "floor_%s_patches.png" % dir_name)

		# 두 결과의 평균 픽셀 차이. 0에 가까우면 배치를 바꿔도 화면이 같다는 뜻이다.
		var diff := _image_diff(images, uniform, patches, size)
		print("  %-6s 변형 %2d장 — 균등 vs 최대응집 평균 픽셀차 %.4f (0~1)" % [
			STAGE_NAMES[stage], images.size(), diff])
	print("  → 이 값이 타일 팩 자체의 밝기범위(위 표)보다 크게 나올 수 없다.")
	print("     즉 변형끼리 비슷하면 배치를 어떻게 바꿔도 화면 차이는 그 범위에 갇힌다.")


func _render_floor(images: Array, indices: PackedInt32Array, size: int, filename: String) -> void:
	var out := Image.create(size * CELL, size * CELL, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var img: Image = images[indices[x + y * size]]
			out.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(x * CELL, y * CELL))
	out.save_png(OUT_DIR + "/" + filename)


func _image_diff(images: Array, a: PackedInt32Array, b: PackedInt32Array, size: int) -> float:
	var total := 0.0
	var count := 0
	for i in size * size:
		var ia: Image = images[a[i]]
		var ib: Image = images[b[i]]
		for y in range(0, CELL, 4):
			for x in range(0, CELL, 4):
				var ca := ia.get_pixel(x, y)
				var cb := ib.get_pixel(x, y)
				total += (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) / 3.0
				count += 1
	return total / maxf(1.0, float(count))


# ---------------------------------------------------------------- (B) 조형물

# Main.gd::_add_decor_patterns가 실제로 쓰는 스캐터 인덱스 (STAGE_PILLAR_IDX + 하드코딩된 3번)
const USED_SCATTER := {1: [0, 3], 2: [1], 3: [0, 3], 4: [3], 5: [3, 5]}


func _probe_scatter() -> void:
	print("\n[B] 조형물(scatter) 자산 활용률 — Main.gd::_add_decor_patterns 기준")
	print("%-8s %8s %8s %10s %s" % ["던전", "보유", "사용", "활용률", "배치 방식"])
	var patterns := {
		1: "원형1 + 열주1", 2: "열주2", 3: "원형1 + 열주1", 4: "열주2", 5: "열주3",
	}
	var total_have := 0
	var total_used := 0
	for stage in range(1, 6):
		var dir_name: String = STAGE_DIRS[stage]
		var have := 0
		for i in 16:
			if FileAccess.file_exists("res://assets/maps/%s/scatter/%02d.png" % [dir_name, i]):
				have += 1
		var used: int = (USED_SCATTER[stage] as Array).size()
		total_have += have
		total_used += used
		print("%-8s %8d %8d %9.0f%% %s" % [
			STAGE_NAMES[stage], have, used, 100.0 * used / maxf(1.0, float(have)), patterns[stage]])
	print("  합계: %d장 중 %d장 사용 (%.0f%%)" % [
		total_have, total_used, 100.0 * total_used / maxf(1.0, float(total_have))])
	print("\n  조형물은 순수 시각 요소다(decorations 배열은 충돌 판정에 쓰이지 않는다).")
	print("  현재 배치는 _decor_line/_decor_ring 두 가지 패턴뿐이고 스테이지당 2~3줄이 전부다.")


# 무엇을 가지고 작업하는지 눈으로 보게 한다. 묘지 기준.
func _save_contact_sheets() -> void:
	var dir_name := "graveyard"
	var floors := _load_pack(dir_name)
	if not floors.is_empty():
		var zoom := 4
		var cols := 6
		var rows := int(ceil(floors.size() / float(cols)))
		var sheet := Image.create(cols * CELL * zoom, rows * CELL * zoom, false, Image.FORMAT_RGBA8)
		for i in floors.size():
			var big := (floors[i] as Image).duplicate() as Image
			big.resize(CELL * zoom, CELL * zoom, Image.INTERPOLATE_NEAREST)
			sheet.blit_rect(big, Rect2i(0, 0, CELL * zoom, CELL * zoom),
				Vector2i((i % cols) * CELL * zoom, (i / cols) * CELL * zoom))
		sheet.save_png(OUT_DIR + "/sheet_floor_graveyard.png")

	var props: Array = []
	for i in 16:
		var path := "res://assets/maps/%s/scatter/%02d.png" % [dir_name, i]
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		var img := tex.get_image()
		if img == null or img.is_empty():
			continue
		img.convert(Image.FORMAT_RGBA8)
		props.append(img)
	if props.is_empty():
		return
	var cell_px := 128
	var pcols := 5
	var prows := int(ceil(props.size() / float(pcols)))
	var psheet := Image.create(pcols * cell_px, prows * cell_px, false, Image.FORMAT_RGBA8)
	psheet.fill(Color(0.12, 0.12, 0.15))
	for i in props.size():
		var img2: Image = props[i]
		var zoom2: int = maxi(1, int(floor(cell_px / float(maxi(img2.get_width(), img2.get_height())))))
		var scaled := img2.duplicate() as Image
		scaled.resize(img2.get_width() * zoom2, img2.get_height() * zoom2, Image.INTERPOLATE_NEAREST)
		var ox := (i % pcols) * cell_px + (cell_px - scaled.get_width()) / 2
		var oy := (i / pcols) * cell_px + (cell_px - scaled.get_height()) / 2
		psheet.blend_rect(scaled, Rect2i(0, 0, scaled.get_width(), scaled.get_height()), Vector2i(ox, oy))
	psheet.save_png(OUT_DIR + "/sheet_scatter_graveyard.png")
	print("\n  묘지 바닥 %d장 / 조형물 %d장 컨택트 시트를 출력 폴더에 저장했다." % [floors.size(), props.size()])
