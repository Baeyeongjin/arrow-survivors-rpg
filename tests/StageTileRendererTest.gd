extends SceneTree

const StageLayoutScript = preload("res://StageLayout.gd")
const StageTileRendererScript = preload("res://StageTileRenderer.gd")
# 실제 게임과 같은 월드 크기로 구워야 텍스처 크기·베이크 비용이 의미가 있다.
const WORLD := StageLayout.WORLD
const STAGE_DIRS := ["graveyard", "hell_bridge", "glacier", "void_altar", "demon_castle"]


func _check_outer_pack(stage_id: int, failures: Array[String]) -> void:
	var stage_dir: String = STAGE_DIRS[stage_id - 1]
	var expected_count := int(StageTileRendererScript.STAGE_OUTER_PACK.get(stage_dir, 0))
	var base := "res://assets/maps/%s/" % stage_dir
	for i in expected_count:
		var path := base + "outer/%02d.png" % i
		if not ResourceLoader.exists(path):
			failures.append("stage %d: missing PixelLab outer tile %s" % [stage_id, path])
			continue
		var texture := load(path) as Texture2D
		if texture == null or texture.get_size() != Vector2(128, 128):
			failures.append("stage %d: invalid 128px outer tile %s" % [stage_id, path])
	var variants: Array[Image] = StageTileRendererScript._load_outer_variants(base, stage_dir)
	if variants.size() != expected_count:
		failures.append(
			"stage %d: expected %d outer variants, loaded %d" % [
				stage_id, expected_count, variants.size()])
		return
	# 렌더 단계에서 64→128 nearest 확대가 적용됐으면 모든 2×2 블록은 같은 색이다.
	for variant_index in variants.size():
		var image: Image = variants[variant_index]
		for y in range(0, image.get_height(), 2):
			for x in range(0, image.get_width(), 2):
				var color := image.get_pixel(x, y)
				if image.get_pixel(x + 1, y) != color \
						or image.get_pixel(x, y + 1) != color \
						or image.get_pixel(x + 1, y + 1) != color:
					failures.append(
						"stage %d: outer variant %d lost integer pixel scaling" % [
							stage_id, variant_index])
					return
	print("STAGE_OUTER_PACK_OK stage=%d variants=%d logical=%d" % [
		stage_id, variants.size(), StageTileRendererScript.OUTER_LOGICAL_SIZE])


# 빌드된 맵에서 바닥 칸과 경계 칸의 평균 밝기를 직접 재서 대비를 계약으로 잠근다.
# 소스 아틀라스만 보면 실제 화면과 어긋난다(팩 감광·톤 보정·하이라이트 압축이 겹쳐서).
# 경계가 바닥보다 너무 밝으면 UI 선처럼 얹혀 보인다(빙하 흰 건반, 묘지 형광 테두리).
# 반대로 경계가 더 어두운 건 문제가 아니다 — 벽이 바닥보다 어두운 건 정상이고
# 지옥은 용암 바닥이 밝아 원래 그렇다(실측 -0.072). 그래서 상한만 좁게, 하한은 넉넉히 잡는다.
const EDGE_BRIGHTER_LIMIT := 0.14
const EDGE_DARKER_LIMIT := 0.20


func _floor_edge_brightness(texture: Texture2D, layout) -> Array:
	var image := texture.get_image()
	var cell := int(StageTileRendererScript.CELL)
	var columns := int(image.get_width() / float(cell))
	var rows := int(image.get_height() / float(cell))
	var half := int(cell * 0.5)
	var floor_sum := 0.0
	var floor_n := 0
	var edge_sum := 0.0
	var edge_n := 0
	var edge_peak := 0.0
	for row in rows:
		for column in columns:
			var origin := Vector2(column * cell, row * cell)
			var index := 0
			if layout.is_walkable(origin, 0.0):
				index += 8
			if layout.is_walkable(origin + Vector2(cell, 0), 0.0):
				index += 4
			if layout.is_walkable(origin + Vector2(0, cell), 0.0):
				index += 2
			if layout.is_walkable(origin + Vector2(cell, cell), 0.0):
				index += 1
			if index == 0:
				continue
			var color := image.get_pixel(column * cell + half, row * cell + half)
			var value: float = maxf(color.r, maxf(color.g, color.b))
			if index == StageTileRendererScript.FILL_INDEX:
				floor_sum += value
				floor_n += 1
			else:
				edge_sum += value
				edge_n += 1
				edge_peak = maxf(edge_peak, value)
	if floor_n == 0 or edge_n == 0:
		return []
	return [floor_sum / floor_n, edge_sum / edge_n, edge_peak]


func _pure_lower_color_count(texture: Texture2D, layout) -> int:
	var colors := {}
	var image := texture.get_image()
	var cell := int(StageTileRendererScript.CELL)
	var columns := int(image.get_width() / float(cell))
	var rows := int(image.get_height() / float(cell))
	var half_cell := int(cell * 0.5)
	for row in rows:
		for column in columns:
			var origin := Vector2(column * cell, row * cell)
			if layout.is_walkable(origin, 0.0) \
					or layout.is_walkable(origin + Vector2(cell, 0), 0.0) \
					or layout.is_walkable(origin + Vector2(0, cell), 0.0) \
					or layout.is_walkable(origin + Vector2(cell, cell), 0.0):
				continue
			colors[image.get_pixel(
				column * cell + half_cell,
				row * cell + half_cell).to_rgba32()] = true
	return colors.size()


# 경계 타일 하이라이트 압축 규칙. 이게 풀리면 빙하 흰 건반·묘지 형광 테두리가 돌아온다.
func _check_edge_rolloff(failures: Array[String]) -> void:
	for stage_dir in STAGE_DIRS:
		if not StageTileRendererScript.STAGE_EDGE_ROLLOFF.has(stage_dir):
			failures.append("%s: 경계 하이라이트 압축 설정이 없음" % stage_dir)
			continue
		var rolloff: Dictionary = StageTileRendererScript.STAGE_EDGE_ROLLOFF[stage_dir]
		var knee := float(rolloff["knee"])
		var cap := float(rolloff["cap"])
		if not (knee > 0.0 and knee < cap and cap < 1.0):
			failures.append("%s: knee/cap 범위 오류 (knee=%.2f cap=%.2f)" % [stage_dir, knee, cap])
			continue
		# knee 이하는 손대지 않는다 — 어두운 묘사가 뭉개지면 형태를 잃는다.
		if not is_equal_approx(StageTileRendererScript.compress_value(knee, knee, cap), knee):
			failures.append("%s: knee 이하 픽셀이 변형됨" % stage_dir)
		if not is_equal_approx(StageTileRendererScript.compress_value(knee * 0.5, knee, cap), knee * 0.5):
			failures.append("%s: knee 아래 어두운 픽셀이 변형됨" % stage_dir)
		# 순백(1.0)이 정확히 cap으로 떨어져야 상한이 보장된다.
		if not is_equal_approx(StageTileRendererScript.compress_value(1.0, knee, cap), cap):
			failures.append("%s: 순백이 cap으로 떨어지지 않음 (%.3f)" % [
				stage_dir, StageTileRendererScript.compress_value(1.0, knee, cap)])
		# 단조 증가여야 밝기 순서가 뒤집히지 않는다.
		var previous := -1.0
		for step in 21:
			var v := float(step) / 20.0
			var out: float = StageTileRendererScript.compress_value(v, knee, cap)
			if out < previous - 0.0001:
				failures.append("%s: 압축이 단조 증가가 아님 (v=%.2f)" % [stage_dir, v])
				break
			if out > cap + 0.0001:
				failures.append("%s: 압축 결과가 cap을 넘음 (v=%.2f -> %.3f)" % [stage_dir, v, out])
				break
			previous = out
	print("STAGE_EDGE_ROLLOFF_OK themes=%d" % StageTileRendererScript.STAGE_EDGE_ROLLOFF.size())


func _initialize() -> void:
	var failures: Array[String] = []
	_check_edge_rolloff(failures)
	for stage_id in range(1, 6):
		_check_outer_pack(stage_id, failures)
		var layout = StageLayoutScript.make(stage_id, Color.WHITE)
		var texture := StageTileRendererScript.build(layout, stage_id, WORLD)
		if texture == null:
			failures.append("stage %d: texture build failed" % stage_id)
			continue
		# 32px 격자로 올림한 크기. WORLD가 바뀌어도 따라간다.
		var cell := float(StageTileRendererScript.CELL)
		var expected := Vector2i(
			int(ceil(WORLD.x / cell) * cell), int(ceil(WORLD.y / cell) * cell))
		if texture.get_size() != Vector2(expected):
			failures.append(
				"stage %d: expected %s, got %s" % [stage_id, expected, texture.get_size()]
			)
		else:
			print("STAGE_TILE_OK stage=%d size=%s" % [stage_id, texture.get_size()])
			var lower_color_count := _pure_lower_color_count(texture, layout)
			if lower_color_count < 3:
				failures.append(
					"stage %d: lower field is still a flat/repeating tile (%d sampled colors)" % [
						stage_id, lower_color_count])
			else:
				print("STAGE_LOWER_FIELD_OK stage=%d colors=%d" % [
					stage_id, lower_color_count])
				var brightness := _floor_edge_brightness(texture, layout)
				if brightness.is_empty():
					failures.append("stage %d: 바닥·경계 칸 표본을 못 모았다" % stage_id)
				else:
					var floor_v: float = brightness[0]
					var edge_v: float = brightness[1]
					var edge_max: float = brightness[2]
					print("STAGE_EDGE_TONE stage=%d floor=%.3f edge=%.3f peak=%.3f gap=%+.3f" % [
						stage_id, floor_v, edge_v, edge_max, edge_v - floor_v])
					if edge_v - floor_v > EDGE_BRIGHTER_LIMIT:
						failures.append(
							"stage %d: 경계가 바닥보다 %+.3f 밝다 (허용 %+.2f) — UI 선처럼 얹혀 보인다" % [
								stage_id, edge_v - floor_v, EDGE_BRIGHTER_LIMIT])
					if floor_v - edge_v > EDGE_DARKER_LIMIT:
						failures.append(
							"stage %d: 경계가 바닥보다 %.3f 어두워 형태가 안 보인다" % [
								stage_id, floor_v - edge_v])
			if "--render-stage-previews" in OS.get_cmdline_user_args():
				var preview_path := OS.get_temp_dir().path_join("arrow_stage_%d.png" % stage_id)
				var save_error := texture.get_image().save_png(preview_path)
				if save_error != OK:
					failures.append("stage %d: preview save failed (%d)" % [stage_id, save_error])
				else:
					print("STAGE_TILE_PREVIEW %s" % preview_path)
			if "--write-map-card-previews" in OS.get_cmdline_user_args():
				var card_image := texture.get_image()
				card_image.resize(192, 192, Image.INTERPOLATE_NEAREST)
				var card_path := "res://assets/maps/%s/preview.png" % STAGE_DIRS[stage_id - 1]
				var card_error := card_image.save_png(card_path)
				if card_error != OK:
					failures.append("stage %d: card preview save failed (%d)" % [stage_id, card_error])
				else:
					print("STAGE_CARD_PREVIEW %s" % card_path)
	if failures.is_empty():
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
