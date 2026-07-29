class_name StageLayout
extends RefCounted

# 독립 맵의 이동 가능 영역/고정 아이템/유물 슬롯 데이터.
# 장판 아트가 준비되기 전에도 플레이 동선과 충돌을 먼저 검증할 수 있게 한다.
const WORLD := Vector2(2800, 2800)

var stage_id := 1
var tint := Color(0.70, 0.70, 0.78)
var shapes: Array[Dictionary] = []
var blocked_circles: Array[Dictionary] = []
var blocked_rects: Array[Rect2] = []
var item_positions: Array[Vector2] = []
var objective_positions: Array[Vector2] = []
var relic_position := Vector2.ZERO
var landmark_position := Vector2(1400, 1220)


static func make(stage: int, stage_tint: Color) -> StageLayout:
	var layout := StageLayout.new()
	layout.stage_id = clampi(stage, 1, 5)
	layout.tint = stage_tint
	match layout.stage_id:
		1:
			# 묘지 — 완전 개활. 사방이 트여 원을 그리며 도망칠 수 있는 입문 전장.
			# 장애물은 작게 흩뿌려 시야만 끊고 동선은 막지 않는다.
			layout.shapes = [_rect(0, 0, 2800, 2800)]
			layout.blocked_rects = [
				Rect2(520, 620, 240, 200), Rect2(1960, 520, 260, 220),
				Rect2(880, 1980, 240, 200), Rect2(2120, 1880, 260, 220),
				Rect2(1500, 1160, 220, 190), Rect2(300, 1500, 300, 260),
			]
			layout.item_positions = [Vector2(1400, 400), Vector2(2400, 1400), Vector2(1400, 2400), Vector2(400, 1000)]
			# M5-A 영혼 봉인비: 개활지 세 모서리로 흩어 점령 동선을 만든다(장애물과 겹치지 않게).
			layout.objective_positions = [Vector2(950, 950), Vector2(2050, 950), Vector2(1400, 2050)]
			layout.relic_position = Vector2(300, 2400)
			layout.landmark_position = Vector2(1400, 1400)
		2:
			# 지옥 — 가로 회랑. 위아래가 용암으로 막혀 좌우로만 도망칠 수 있다.
			# 균열 슬래브가 회랑을 좁혀 병목을 만들고, 위아래 벽감이 숨돌릴 틈을 준다.
			layout.shapes = [
				_rect(0, 760, 2800, 1280),
				_rect(700, 300, 420, 520), _rect(1680, 1980, 420, 520),
			]
			layout.blocked_rects = [
				Rect2(600, 900, 140, 420), Rect2(1180, 1400, 140, 500),
				Rect2(1780, 880, 140, 440), Rect2(2320, 1420, 140, 460),
			]
			layout.item_positions = [Vector2(200, 1400), Vector2(900, 500), Vector2(1890, 2300), Vector2(2650, 1400)]
			# M3 용암 균열: 중앙 회랑 → 위 벽감 → 아래 벽감 순으로 탐험 동선을 꺾는다.
			layout.objective_positions = [Vector2(420, 1400), Vector2(900, 580), Vector2(1900, 2240)]
			layout.relic_position = Vector2(2650, 900)
			layout.landmark_position = Vector2(1450, 1000)
		3:
			# 빙하 — 3x3 미로. 얼음 폐허 벽이 방을 나누고 통로는 300px 병목뿐이다.
			# 개활지처럼 원을 그리며 도망칠 수 없어 통로 관리가 곧 생존이다.
			layout.shapes = [_rect(0, 0, 2800, 2800)]
			layout.blocked_rects = [
				Rect2(0, 880, 700, 90), Rect2(1000, 880, 800, 90), Rect2(2100, 880, 700, 90),
				Rect2(0, 1830, 700, 90), Rect2(1000, 1830, 800, 90), Rect2(2100, 1830, 700, 90),
				Rect2(880, 0, 90, 700), Rect2(880, 1000, 90, 760), Rect2(880, 1920, 90, 880),
				Rect2(1830, 0, 90, 700), Rect2(1830, 1000, 90, 760), Rect2(1830, 1920, 90, 880),
			]
			layout.item_positions = [Vector2(440, 440), Vector2(2360, 440), Vector2(440, 2360), Vector2(2360, 2360)]
			layout.relic_position = Vector2(1400, 440)
			layout.landmark_position = Vector2(1400, 1400)
		4:
			# 공허 — 세로 탑. 폭 1160의 좁고 긴 회랑이라 옆으로 빠질 곳이 없다.
			# 좌우 성소 두 곳만이 유일한 대피처다.
			layout.shapes = [
				_rect(820, 0, 1160, 2800),
				_rect(300, 1100, 580, 600), _rect(1920, 1100, 580, 600),
			]
			layout.blocked_circles = [_circle(1400, 700, 170), _circle(1400, 2100, 170)]
			layout.item_positions = [Vector2(1400, 300), Vector2(560, 1400), Vector2(2240, 1400), Vector2(1400, 2500)]
			layout.relic_position = Vector2(1400, 1050)
			layout.landmark_position = Vector2(1400, 1400)
		5:
			# 마왕성 — 열주 대홀. 좌우 대칭 기둥 8개가 세로 회랑을 만드는 성채.
			# 기둥 사이를 꿰며 싸우게 되고, 좌우 벽실은 몰리면 빠져나오기 어려운 구석이다.
			layout.shapes = [_rect(0, 0, 2800, 2800)]
			layout.blocked_rects = [
				Rect2(760, 560, 160, 160), Rect2(760, 1080, 160, 160),
				Rect2(760, 1600, 160, 160), Rect2(760, 2120, 160, 160),
				Rect2(1880, 560, 160, 160), Rect2(1880, 1080, 160, 160),
				Rect2(1880, 1600, 160, 160), Rect2(1880, 2120, 160, 160),
				Rect2(180, 1200, 360, 400), Rect2(2260, 1200, 360, 400),
			]
			layout.item_positions = [Vector2(1400, 380), Vector2(2400, 700), Vector2(1400, 2420), Vector2(400, 700)]
			layout.relic_position = Vector2(1400, 200)
			layout.landmark_position = Vector2(1400, 1400)
	return layout


func is_walkable(point: Vector2, radius := 0.0) -> bool:
	if point.x < radius or point.y < radius or point.x > WORLD.x - radius or point.y > WORLD.y - radius:
		return false
	# Shapes form one continuous walkable union.  Shrinking each rectangle on its
	# own creates invisible gaps at joins, so test the player footprint against
	# the union instead.
	if not _is_in_shape_union(point):
		return false
	if radius > 0.0:
		for direction_index in 8:
			var angle := TAU * float(direction_index) / 8.0
			var footprint := point + Vector2.from_angle(angle) * radius
			if not _is_in_shape_union(footprint):
				return false
	for block in blocked_circles:
		if point.distance_to(block["center"]) < float(block["radius"]) + radius:
			return false
	for rect in blocked_rects:
		if rect.grow(radius).has_point(point):
			return false
	return true


func _is_in_shape_union(point: Vector2) -> bool:
	for shape in shapes:
		if _contains(shape, point, 0.0):
			return true
	return false


func resolve_move(from: Vector2, desired: Vector2, radius := 0.0) -> Vector2:
	if is_walkable(desired, radius):
		return desired
	var safe := from
	var blocked := desired
	for _i in 7:
		var mid := safe.lerp(blocked, 0.5)
		if is_walkable(mid, radius):
			safe = mid
		else:
			blocked = mid
	return safe


func steer_toward(from: Vector2, target: Vector2, distance: float, radius := 0.0) -> Vector2:
	var direct := target - from
	if direct.length_squared() < 0.01:
		return from
	var base := direct.normalized()
	# 직진이 뚫려 있으면 즉시 반환. 아래 탐색은 몹 한 마리당 매 프레임
	# is_walkable을 80회 부르는데, 대부분의 프레임은 그냥 직진이면 된다.
	# 각도 0 후보는 우회 페널티가 없어 어차피 항상 최저 점수라 결과도 같다.
	var straight := from + base * distance
	if is_walkable(straight, radius):
		return straight
	var angles := [0.0, 0.38, -0.38, 0.76, -0.76, 1.14, -1.14, 1.52, -1.52, PI]
	var best := from
	var best_score := INF
	for angle in angles:
		var candidate := resolve_move(from, from + base.rotated(angle) * distance, radius)
		if candidate.distance_squared_to(from) < 0.01:
			continue
		var score := candidate.distance_to(target) + absf(angle) * 18.0
		if score < best_score:
			best_score = score
			best = candidate
	return best


func nearest_walkable(point: Vector2, radius := 0.0) -> Vector2:
	if is_walkable(point, radius):
		return point
	# 원형 호수/균열처럼 유효 영역 안의 막힌 지형에 들어갔을 때,
	# 맵 중앙으로 순간이동하지 않고 가장 가까운 가장자리로 복귀한다.
	for distance in range(16, 641, 16):
		for direction_index in 16:
			var angle := TAU * float(direction_index) / 16.0
			var nearby := point + Vector2.from_angle(angle) * float(distance)
			if is_walkable(nearby, radius):
				return nearby
	var best := Vector2(WORLD.x * 0.5, WORLD.y * 0.5)
	var best_dist := INF
	for shape in shapes:
		var candidate := _nearest_in_shape(shape, point, radius)
		if is_walkable(candidate, radius) and candidate.distance_squared_to(point) < best_dist:
			best = candidate
			best_dist = candidate.distance_squared_to(point)
	return best


func random_walkable(radius := 0.0) -> Vector2:
	for _try in 96:
		var candidate := Vector2(randf_range(radius, WORLD.x - radius), randf_range(radius, WORLD.y - radius))
		if is_walkable(candidate, radius):
			return candidate
	return nearest_walkable(WORLD * 0.5, radius)


static func _rect(x: float, y: float, w: float, h: float) -> Dictionary:
	return {"kind": "rect", "rect": Rect2(x, y, w, h)}


static func _circle(x: float, y: float, radius: float) -> Dictionary:
	return {"kind": "circle", "center": Vector2(x, y), "radius": radius}


static func _ring(x: float, y: float, inner: float, outer: float) -> Dictionary:
	return {"kind": "ring", "center": Vector2(x, y), "inner": inner, "outer": outer}


func _contains(shape: Dictionary, point: Vector2, radius: float) -> bool:
	match str(shape["kind"]):
		"rect":
			var rect: Rect2 = shape["rect"]
			return Rect2(rect.position + Vector2(radius, radius), rect.size - Vector2(radius * 2.0, radius * 2.0)).has_point(point)
		"circle":
			return point.distance_to(shape["center"]) <= float(shape["radius"]) - radius
		"ring":
			var d := point.distance_to(shape["center"])
			return d >= float(shape["inner"]) + radius and d <= float(shape["outer"]) - radius
	return false


func _nearest_in_shape(shape: Dictionary, point: Vector2, radius: float) -> Vector2:
	match str(shape["kind"]):
		"rect":
			var rect: Rect2 = shape["rect"]
			return Vector2(clampf(point.x, rect.position.x + radius, rect.end.x - radius), clampf(point.y, rect.position.y + radius, rect.end.y - radius))
		"circle", "ring":
			var center: Vector2 = shape["center"]
			var dir := (point - center).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			var target_radius := float(shape.get("outer", shape.get("radius", 0.0))) - radius
			return center + dir * target_radius
	return WORLD * 0.5
