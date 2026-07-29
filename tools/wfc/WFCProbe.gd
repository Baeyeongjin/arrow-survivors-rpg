extends SceneTree
# WFC 실사용 가능성 실측. 게임 코드는 건드리지 않고 tools/에서만 돌린다.
#
# 실행:
#   godot --headless --path . --script res://tools/wfc/WFCProbe.gd -- --mode=all
#   모드: profile | wang | overlap | stats | all
#
# 측정 항목
#   1) 현재 수제 맵의 기준값 (걸을 수 있는 비율, 연결 요소 수, 목표 배치 가능 칸)
#   2) 코너 Wang 타일셋으로 WFC를 돌렸을 때의 인접 제약 강도와 결과
#   3) OverlappingModel(N=3)로 수제 맵을 학습해 더 큰 맵을 생성했을 때의 결과
#   4) 여러 시드에서의 모순률·연결성·소요 시간

const StageLayoutScript = preload("res://StageLayout.gd")
const OverlappingScript = preload("res://tools/wfc/WFCOverlapping.gd")
const CornerWangScript = preload("res://tools/wfc/WFCCornerWang.gd")

const CELL := 32                      # StageTileRenderer.CELL 과 동일
const SRC_GRID := 88                  # ceil(2800 / 32) — 현재 맵
const DST_GRID := 123                 # ceil(3920 / 32) — 1순위 확대 목표(1.4배)
const OUT_DIR := "user://wfc_probe"
const STAGE_NAMES := {1: "묘지", 2: "지옥", 3: "빙하", 4: "공허", 5: "마왕성"}

# 목표(봉인비·화로 등)는 반경 58로 스폰된다. 32px 격자에서 여유 2칸(=5x5)을 요구한다.
const OBJECTIVE_CLEARANCE := 2

const NEIGHBORS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _initialize() -> void:
	var mode := "all"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.split("=")[1]
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	print("=".repeat(72))
	print("WFC 실사용 가능성 실측  (mode=%s)" % mode)
	print("격자: 현재 %dx%d (WORLD 2800) → 목표 %dx%d (WORLD 3920)" % [SRC_GRID, SRC_GRID, DST_GRID, DST_GRID])
	print("=".repeat(72))

	if mode == "all" or mode == "profile":
		_report_baseline()
		_report_wang_profile()
	if mode == "all" or mode == "wang":
		_run_wang()
	if mode == "all" or mode == "overlap":
		_run_overlap()
	if mode == "all" or mode == "stats":
		_run_stats()

	print("\n출력 폴더: %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit(0)


# ---------------------------------------------------------------- 기준값

func _report_baseline() -> void:
	print("\n[1] 현재 수제 맵 기준값 — 이 수치를 WFC 결과가 따라와야 한다")
	print("%-8s %8s %8s %10s %12s" % ["던전", "바닥%", "연결요소", "최대요소%", "목표배치칸"])
	for stage in range(1, 6):
		var grid := _rasterize(stage)
		var stats := _analyze(grid, SRC_GRID)
		print("%-8s %7.1f%% %8d %9.1f%% %12d" % [
			STAGE_NAMES[stage], stats["floor_pct"], stats["components"],
			stats["largest_pct"], stats["objective_sites"]])
	var g := _rasterize(1)
	_save_png(g, SRC_GRID, "baseline_graveyard.png")


func _report_wang_profile() -> void:
	print("\n[2] 코너 Wang 타일셋의 인접 제약 강도")
	var model = CornerWangScript.new()
	model.setup(8, 8, false, model.HEURISTIC_SCANLINE)
	var profile: Dictionary = model.compatibility_profile()
	var avg: PackedInt32Array = profile["avg_compatible_per_direction"]
	print("  타일 %d장, 방향별 평균 호환 타일 수: 좌%d 하%d 우%d 상%d (전체 %d장 중)" % [
		profile["tile_count"], avg[0], avg[1], avg[2], avg[3], profile["tile_count"]])
	print("  → 어떤 타일 옆에도 항상 호환 타일이 존재한다. 즉 모순이 원천적으로 불가능하고,")
	print("     유효한 타일링 집합 = 임의의 이진 코너 격자 전체다. WFC가 가지치기할 것이 없다.")


# ---------------------------------------------------------------- 실험

func _run_wang() -> void:
	print("\n[3] 코너 Wang 타일셋으로 WFC 생성 (%dx%d)" % [DST_GRID, DST_GRID])
	var model = CornerWangScript.new()
	model.setup(DST_GRID, DST_GRID, false, model.HEURISTIC_SCANLINE)
	var t0 := Time.get_ticks_msec()
	var ok: bool = model.run(1234, -1)
	var elapsed := Time.get_ticks_msec() - t0
	if not ok:
		print("  모순 발생 (%d ms)" % elapsed)
		return
	var grid: PackedByteArray = model.to_walkable()
	var stats := _analyze(grid, DST_GRID)
	print("  성공 %d ms — 바닥 %.1f%%, 연결요소 %d개, 최대요소 %.1f%%, 목표배치칸 %d" % [
		elapsed, stats["floor_pct"], stats["components"], stats["largest_pct"], stats["objective_sites"]])
	_save_png(grid, DST_GRID, "wang_output.png")


func _run_overlap() -> void:
	print("\n[4] OverlappingModel(N=3) — 수제 묘지 맵을 학습해 %dx%d 생성" % [DST_GRID, DST_GRID])
	var sample := _rasterize(1)
	var model = OverlappingScript.new()
	var t0 := Time.get_ticks_msec()
	model.setup(sample, SRC_GRID, SRC_GRID, 2, 3, DST_GRID, DST_GRID, false, false, 8, false, model.HEURISTIC_SCANLINE)
	var setup_ms := Time.get_ticks_msec() - t0
	print("  학습 완료 %d ms — 서로 다른 3x3 패턴 %d개" % [setup_ms, model.T])

	for seed_value in [1, 2, 3]:
		t0 = Time.get_ticks_msec()
		var ok: bool = model.run(seed_value, -1)
		var elapsed := Time.get_ticks_msec() - t0
		if not ok:
			print("  seed %d: 모순 (%d ms)" % [seed_value, elapsed])
			continue
		var grid: PackedByteArray = model.to_indices()
		var stats := _analyze(grid, DST_GRID)
		print("  seed %d: 성공 %d ms — 바닥 %.1f%%, 연결요소 %d개, 최대요소 %.1f%%, 목표배치칸 %d" % [
			seed_value, elapsed, stats["floor_pct"], stats["components"],
			stats["largest_pct"], stats["objective_sites"]])
		_save_png(grid, DST_GRID, "overlap_seed%d.png" % seed_value)

		# 연결성 보장 패스: 최대 요소만 남기고 나머지는 벽으로 채운다.
		var pruned := _keep_largest(grid, DST_GRID)
		var pstats := _analyze(pruned, DST_GRID)
		print("      └ 최대요소만 남긴 뒤: 바닥 %.1f%% (손실 %.1f%%p), 목표배치칸 %d" % [
			pstats["floor_pct"], stats["floor_pct"] - pstats["floor_pct"], pstats["objective_sites"]])
		_save_png(pruned, DST_GRID, "overlap_seed%d_pruned.png" % seed_value)


func _run_stats() -> void:
	print("\n[5] 시드 12회 반복 — 모순률과 연결성 분포 (OverlappingModel, 엔트로피 휴리스틱)")
	var sample := _rasterize(1)
	var model = OverlappingScript.new()
	# 엔트로피 휴리스틱은 매 관측마다 전체 칸을 훑어 O(칸^2)다. 실행 시간을 보려고
	# 목표 크기가 아닌 현재 크기(88x88)로 돌린다.
	model.setup(sample, SRC_GRID, SRC_GRID, 2, 3, SRC_GRID, SRC_GRID, false, false, 8, false, model.HEURISTIC_ENTROPY)
	var fails := 0
	var total_ms := 0
	var largest_values: Array = []
	for seed_value in range(1, 13):
		var t0 := Time.get_ticks_msec()
		var ok: bool = model.run(seed_value * 7919, -1)
		total_ms += Time.get_ticks_msec() - t0
		if not ok:
			fails += 1
			continue
		var stats := _analyze(model.to_indices(), SRC_GRID)
		largest_values.append(stats["largest_pct"])
	print("  12회 중 모순 %d회 (%.0f%%), 평균 %d ms/회 (엔트로피 휴리스틱, %dx%d)" % [
		fails, 100.0 * fails / 12.0, total_ms / 12, SRC_GRID, SRC_GRID])
	if not largest_values.is_empty():
		var sum := 0.0
		var worst := 100.0
		for v in largest_values:
			sum += v
			worst = minf(worst, v)
		print("  최대 연결요소가 전체 바닥에서 차지하는 비율: 평균 %.1f%%, 최악 %.1f%%" % [
			sum / largest_values.size(), worst])
		print("  → 100%가 아니면 그만큼이 도달 불가능한 고립 구역이다.")


# ---------------------------------------------------------------- 유틸

# 수제 StageLayout을 32px 격자 이진 비트맵으로. 1 = 걸을 수 있음.
func _rasterize(stage: int) -> PackedByteArray:
	var layout = StageLayoutScript.make(stage, Color.WHITE)
	var grid := PackedByteArray()
	grid.resize(SRC_GRID * SRC_GRID)
	for y in SRC_GRID:
		for x in SRC_GRID:
			var point := Vector2(x * CELL + CELL * 0.5, y * CELL + CELL * 0.5)
			grid[x + y * SRC_GRID] = 1 if layout.is_walkable(point, 0.0) else 0
	return grid


# 4방향 연결 요소 분석 + 목표 배치 가능 칸 수.
func _analyze(grid: PackedByteArray, size: int) -> Dictionary:
	if grid.is_empty():
		return {"floor_pct": 0.0, "components": 0, "largest_pct": 0.0, "objective_sites": 0}
	var floor_count := 0
	for v in grid:
		if v != 0:
			floor_count += 1

	var seen := PackedByteArray()
	seen.resize(size * size)
	var components := 0
	var largest := 0
	for start in size * size:
		if grid[start] == 0 or seen[start] != 0:
			continue
		components += 1
		var count := 0
		var queue := PackedInt32Array([start])
		seen[start] = 1
		while not queue.is_empty():
			var cell := queue[queue.size() - 1]
			queue.remove_at(queue.size() - 1)
			count += 1
			var cx := cell % size
			var cy := cell / size
			for offset in NEIGHBORS:
				var nx := cx + offset.x
				var ny := cy + offset.y
				if nx < 0 or ny < 0 or nx >= size or ny >= size:
					continue
				var ni := nx + ny * size
				if grid[ni] == 0 or seen[ni] != 0:
					continue
				seen[ni] = 1
				queue.append(ni)
		largest = maxi(largest, count)

	var sites := 0
	for y in size:
		for x in size:
			if _clearance_ok(grid, size, x, y, OBJECTIVE_CLEARANCE):
				sites += 1

	return {
		"floor_pct": 100.0 * floor_count / float(size * size),
		"components": components,
		"largest_pct": (100.0 * largest / float(floor_count)) if floor_count > 0 else 0.0,
		"objective_sites": sites,
	}


func _clearance_ok(grid: PackedByteArray, size: int, x: int, y: int, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or ny < 0 or nx >= size or ny >= size:
				return false
			if grid[nx + ny * size] == 0:
				return false
	return true


# 최대 연결 요소만 남기고 나머지 바닥은 벽으로 채운다 (연결성 보장 패스).
func _keep_largest(grid: PackedByteArray, size: int) -> PackedByteArray:
	var label := PackedInt32Array()
	label.resize(size * size)
	label.fill(-1)
	var sizes: Array[int] = []
	for start in size * size:
		if grid[start] == 0 or label[start] >= 0:
			continue
		var id := sizes.size()
		var count := 0
		var queue := PackedInt32Array([start])
		label[start] = id
		while not queue.is_empty():
			var cell := queue[queue.size() - 1]
			queue.remove_at(queue.size() - 1)
			count += 1
			var cx := cell % size
			var cy := cell / size
			for offset in NEIGHBORS:
				var nx := cx + offset.x
				var ny := cy + offset.y
				if nx < 0 or ny < 0 or nx >= size or ny >= size:
					continue
				var ni := nx + ny * size
				if grid[ni] == 0 or label[ni] >= 0:
					continue
				label[ni] = id
				queue.append(ni)
		sizes.append(count)

	var best := -1
	var best_size := -1
	for i in sizes.size():
		if sizes[i] > best_size:
			best_size = sizes[i]
			best = i

	var result := grid.duplicate()
	for i in size * size:
		if grid[i] != 0 and label[i] != best:
			result[i] = 0
	return result


func _save_png(grid: PackedByteArray, size: int, filename: String) -> void:
	if grid.is_empty():
		return
	var scale := 4
	var image := Image.create(size * scale, size * scale, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var color := Color(0.82, 0.80, 0.74) if grid[x + y * size] != 0 else Color(0.10, 0.09, 0.13)
			image.fill_rect(Rect2i(x * scale, y * scale, scale, scale), color)
	image.save_png(OUT_DIR + "/" + filename)
