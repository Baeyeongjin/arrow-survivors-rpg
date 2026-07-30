extends SceneTree
# is_walkable 최적화의 동치성 검증.
#
# 경로찾기 핫패스를 (1) 도형을 타입 배열로 굽고 (2) "점이 도형 하나를 radius만큼 줄인
# 영역 안이면 발자국 8방향 검사를 건너뛴다"는 빠른 경로로 재작성했다. (2)는 근사가 아니라
# 동치라는 주장이므로, 원래 알고리즘을 참조 구현으로 직접 돌려 결과가 한 점도 다르지
# 않은지 확인한다. 이 검사가 깨지면 몹이 벽을 통과하거나 통로가 막힌다.
#
# 참조 구현은 최적화 대상이 아닌 _contains(shapes 딕셔너리 순회)를 쓰므로
# 굽힌 배열과 독립적이다.

const StageLayoutScript = preload("res://StageLayout.gd")
const GameConfigScript = preload("res://GameConfig.gd")

const GRID_STEP := 37.0            # 격자에 정렬되지 않은 간격으로 경계도 훑는다
const RADII := [0.0, 4.0, 18.0, 26.0, 34.0, 42.0, 58.0]

var failed := false


# 최적화 이전 알고리즘 그대로.
func _reference_walkable(layout, point: Vector2, radius: float) -> bool:
	var world: Vector2 = StageLayoutScript.WORLD
	if point.x < radius or point.y < radius or point.x > world.x - radius or point.y > world.y - radius:
		return false
	if not _reference_union(layout, point):
		return false
	if radius > 0.0:
		for direction_index in 8:
			var angle := TAU * float(direction_index) / 8.0
			if not _reference_union(layout, point + Vector2.from_angle(angle) * radius):
				return false
	for block in layout.blocked_circles:
		if point.distance_to(block["center"]) < float(block["radius"]) + radius:
			return false
	for rect in layout.blocked_rects:
		if rect.grow(radius).has_point(point):
			return false
	return true


func _reference_union(layout, point: Vector2) -> bool:
	for shape in layout.shapes:
		if layout._contains(shape, point, 0.0):
			return true
	return false


func _initialize() -> void:
	var checked := 0
	for stage in range(1, 6):
		var info := GameConfigScript.stage_info(stage)
		var stage_name := str(info.get("name", stage))
		var layout = StageLayoutScript.make(stage, Color(info["tint"]))
		var mismatches := 0
		var first_bad := ""
		var world: Vector2 = StageLayoutScript.WORLD
		var y := 0.0
		while y <= world.y:
			var x := 0.0
			while x <= world.x:
				var point := Vector2(x, y)
				for radius in RADII:
					var expected := _reference_walkable(layout, point, float(radius))
					var actual: bool = layout.is_walkable(point, float(radius))
					checked += 1
					if expected != actual:
						mismatches += 1
						if first_bad == "":
							first_bad = "%s r=%.0f 기대=%s 실제=%s" % [point, radius, expected, actual]
				x += GRID_STEP
			y += GRID_STEP
		if mismatches > 0:
			failed = true
			push_error("[%s] is_walkable 결과가 참조 구현과 다름 %d곳 — 첫 사례: %s" % [
				stage_name, mismatches, first_bad])

	if failed:
		quit(1)
		return
	print("WALKABLE_EQUIV_OK checked=%d" % checked)
	quit(0)
