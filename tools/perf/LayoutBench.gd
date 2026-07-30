extends SceneTree
# 이동 경로찾기 비용 실측. 게임 코드가 아니라 진단 드라이버다.
#
# 랙 후보를 좁히기 위한 것: 적 한 마리는 매 프레임 _move_on_stage를 2회(추격 + 분리)
# 호출하고, 각 호출은 StageLayout.steer_toward로 간다. steer_toward는 직진이 뚫려 있으면
# is_walkable 1회로 끝나지만(빠른 경로), 막히면 10개 각도 × resolve_move(8회) = 80회를
# 부른다. is_walkable은 다시 shape 목록을 9번(중심 1 + 발자국 8) 순회한다.
#
# 실행:
#   godot --headless --path . --script res://tools/perf/LayoutBench.gd

const StageLayoutScript = preload("res://StageLayout.gd")
const GameConfigScript = preload("res://GameConfig.gd")

const SAMPLES := 4000
const ENEMY_RADIUS := 18.0
const STEP_DIST := 2.0        # 프레임당 이동 거리 정도
const ENEMIES := 300          # MAX_ENEMIES
const CALLS_PER_ENEMY := 2    # 추격 + 분리


func _initialize() -> void:
	print("stage           shapes  blk  is_walkable(us)  steer(us)  fast%%   300마리2회(ms/frame)")
	var total_worst := 0.0
	for stage in range(1, 6):
		var info := GameConfigScript.stage_info(stage)
		var stage_name := str(info.get("name", stage))
		var layout = StageLayoutScript.make(stage, Color(info["tint"]))
		var shape_count: int = layout.shapes.size()
		var blocker_count: int = layout.blocked_rects.size() + layout.blocked_circles.size()

		# 실제 적이 서 있을 만한 지점을 표본으로 뽑는다(걸을 수 있는 칸).
		var points: Array[Vector2] = []
		var seed_rng := RandomNumberGenerator.new()
		seed_rng.seed = 12345
		while points.size() < SAMPLES:
			var candidate := Vector2(
				seed_rng.randf_range(0.0, StageLayoutScript.WORLD.x),
				seed_rng.randf_range(0.0, StageLayoutScript.WORLD.y))
			if layout.is_walkable(candidate, ENEMY_RADIUS):
				points.append(candidate)

		# 1) is_walkable 단가
		var t0 := Time.get_ticks_usec()
		for p in points:
			layout.is_walkable(p, ENEMY_RADIUS)
		var walk_us := float(Time.get_ticks_usec() - t0) / float(points.size())

		# 2) steer_toward 단가 + 빠른 경로 적중률
		#    적은 플레이어(맵 중앙)를 향해 움직인다고 가정한다.
		var target: Vector2 = StageLayoutScript.WORLD * 0.5
		var fast_hits := 0
		for p in points:
			var direct := target - p
			if direct.length_squared() >= 0.01:
				if layout.is_walkable(p + direct.normalized() * STEP_DIST, ENEMY_RADIUS):
					fast_hits += 1
		var t1 := Time.get_ticks_usec()
		for p in points:
			layout.steer_toward(p, target, STEP_DIST, ENEMY_RADIUS)
		var steer_us := float(Time.get_ticks_usec() - t1) / float(points.size())
		var fast_pct := 100.0 * float(fast_hits) / float(points.size())

		# 3) 300마리 × 2호출을 이 단가로 환산한 프레임 비용
		var frame_ms := steer_us * float(ENEMIES * CALLS_PER_ENEMY) / 1000.0
		total_worst = maxf(total_worst, frame_ms)

		print("%-14s %5d  %3d  %13.2f  %9.2f  %5.1f  %18.1f" % [
			stage_name, shape_count, blocker_count, walk_us, steer_us, fast_pct, frame_ms])

	print("")
	print("최악 스테이지 경로찾기만으로 프레임당 %.1f ms (60fps 예산 16.7ms)" % total_worst)
	quit(0)
