extends SceneTree
# 던전 지형(StageLayout) 회귀 검증. RPG형 방+복도 구조로 바꾸면서 조용히 깨지기
# 쉬운 두 가지를 잡는다:
#  1) 주요 좌표(시작점·랜드마크·유물·아이템·목표)가 실제 이동 가능 영역 안에 있는가.
#  2) 모든 방이 시작점에서 걸어서 도달 가능한가 (복도 연결 누락 = 고립된 방).
# 연결성은 40px 격자 BFS로 검사한다. 격자를 벗어난 미세 통로는 못 잡지만,
# 방 하나가 통째로 끊긴 치명적 실패는 확실히 잡는다.

const StageLayoutScript = preload("res://StageLayout.gd")
const GameConfigScript = preload("res://GameConfig.gd")

const STEP := 40.0        # BFS 격자 간격
const AGENT := 20.0       # 통로 통과 판정 반경 (일반 몹 기준)
const REACH := 90.0       # 주요 좌표가 이 거리 안의 격자에 닿으면 도달로 본다

var failed := false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)


# 시작점에서 걸어갈 수 있는 격자 점 집합.
func _reachable(layout) -> Dictionary:
	var start: Vector2 = layout.nearest_walkable(StageLayoutScript.WORLD * 0.5, AGENT)
	var start_key := Vector2i(int(round(start.x / STEP)), int(round(start.y / STEP)))
	var seen := {start_key: true}
	var queue: Array[Vector2i] = [start_key]
	var limit := int(StageLayoutScript.WORLD.x / STEP) + 2
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + offset
			if seen.has(next) or next.x < 0 or next.y < 0 or next.x > limit or next.y > limit:
				continue
			if not layout.is_walkable(Vector2(next.x * STEP, next.y * STEP), AGENT):
				continue
			seen[next] = true
			queue.append(next)
	return seen


func _is_reached(seen: Dictionary, point: Vector2) -> bool:
	var span := int(ceil(REACH / STEP))
	var base := Vector2i(int(round(point.x / STEP)), int(round(point.y / STEP)))
	for dx in range(-span, span + 1):
		for dy in range(-span, span + 1):
			var cell := base + Vector2i(dx, dy)
			if seen.has(cell) and Vector2(cell.x * STEP, cell.y * STEP).distance_to(point) <= REACH:
				return true
	return false


func _initialize() -> void:
	for stage in range(1, 6):
		var info := GameConfigScript.stage_info(stage)
		var name := str(info.get("name", stage))
		var layout = StageLayoutScript.make(stage, Color(info["tint"]))

		# 런 시작·층 전환은 맵 중앙에서 시작한다. 중앙이 막히면 nearest_walkable이
		# 엉뚱한 구석으로 보내므로 중앙 자체가 걸을 수 있어야 한다.
		_expect(layout.is_walkable(StageLayoutScript.WORLD * 0.5, 34.0),
			"[%s] 맵 중앙(시작 지점)이 이동 불가" % name)

		var seen := _reachable(layout)
		_expect(seen.size() > 200, "[%s] 이동 가능 영역이 지나치게 좁음: %d칸" % [name, seen.size()])

		var checks: Array = [
			{"label": "랜드마크", "point": layout.landmark_position, "radius": 34.0},
			{"label": "유물", "point": layout.relic_position, "radius": 34.0},
		]
		for i in layout.item_positions.size():
			checks.append({"label": "아이템%d" % i, "point": layout.item_positions[i], "radius": 34.0})
		# 목표(균열·봉인비)는 반경 58로 스폰되므로 더 넓은 여유가 필요하다.
		for i in layout.objective_positions.size():
			checks.append({"label": "목표%d" % i, "point": layout.objective_positions[i], "radius": 58.0})

		for check in checks:
			var point: Vector2 = check["point"]
			_expect(layout.is_walkable(point, float(check["radius"])),
				"[%s] %s 좌표가 벽 안에 있음: %s" % [name, check["label"], point])
			_expect(_is_reached(seen, point),
				"[%s] %s 좌표가 시작점에서 도달 불가(방이 고립됨): %s" % [name, check["label"], point])

		# 방이 나뉜 구조라면 4개 아이템이 서로 다른 구역에 흩어져 있어야 탐험이 된다.
		_expect(layout.item_positions.size() == 4, "[%s] 고정 아이템 좌표가 4개가 아님" % name)

	if failed:
		quit(1)
		return
	print("STAGE_LAYOUT_OK")
	quit(0)
