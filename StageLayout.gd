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
			# 묘지 — 중앙 광장 + 사방 납골당(십자 구조). 입문 던전이라 방이 크고
			# 복도가 넓어 길을 잃지 않는다. 광장에서 원을 그리며 호드를 흘릴 수 있고,
			# 봉인비는 각 납골당 안에 있어 "안전한 광장을 떠나는" 결정을 만든다.
			layout.shapes = [
				_rect(900, 900, 1000, 1000),                       # 중앙 광장
				_rect(1100, 180, 600, 540), _rect(1100, 2080, 600, 540),   # 북·남 납골당
				_rect(180, 1100, 540, 600), _rect(2080, 1100, 540, 600),   # 서·동 납골당
				_rect(1280, 680, 240, 260), _rect(1280, 1860, 240, 260),   # 북·남 복도
				_rect(680, 1280, 260, 240), _rect(1860, 1280, 260, 240),   # 서·동 복도
			]
			layout.blocked_rects = [
				Rect2(1040, 1040, 170, 140), Rect2(1590, 1040, 170, 140),
				Rect2(1040, 1620, 170, 140), Rect2(1590, 1620, 170, 140),
			]
			layout.item_positions = [Vector2(1550, 2350), Vector2(1000, 1400), Vector2(1800, 1400), Vector2(1400, 1000)]
			# M5-A 영혼 봉인비: 북·서·동 납골당 안. 광장을 벗어나야 점령할 수 있다.
			layout.objective_positions = [Vector2(1400, 450), Vector2(450, 1400), Vector2(2350, 1400)]
			layout.relic_position = Vector2(1250, 2350)
			layout.landmark_position = Vector2(1400, 1400)
		2:
			# 지옥 — 용암 다리 회랑 + 세 챔버. 가로 정체성은 유지하되 양끝이 아니라
			# 챔버로 이어져 목표 전투가 방 안에서 벌어진다. 회랑의 지그재그 병목이
			# 추격을 끊어 "다리 위에서 버틸지, 방으로 들어갈지"를 고르게 한다.
			layout.shapes = [
				_rect(120, 1150, 2560, 500),                        # 중앙 다리 회랑
				_rect(240, 600, 620, 590), _rect(1940, 600, 620, 590),      # 서·동 챔버
				_rect(1090, 1610, 620, 590),                        # 남 챔버
			]
			layout.blocked_rects = [
				Rect2(760, 1150, 110, 320), Rect2(1500, 1330, 110, 320),
				Rect2(2180, 1150, 110, 320),
			]
			layout.item_positions = [Vector2(200, 1400), Vector2(2600, 1400), Vector2(550, 700), Vector2(2250, 700)]
			# M3 용암 균열: 서 챔버 → 동 챔버 → 남 챔버 순으로 회랑을 왕복하게 한다.
			layout.objective_positions = [Vector2(550, 870), Vector2(2250, 870), Vector2(1400, 1900)]
			layout.relic_position = Vector2(1400, 2100)
			layout.landmark_position = Vector2(1400, 1400)
		3:
			# 빙하 — 외곽 순환 회랑 + 중앙 결정실(스포크 4개). 순환로가 있어 계속
			# 돌 수 있지만 폭이 좁아 방심하면 갇힌다. 중앙 결정실은 넓은 대신
			# 출구가 넷뿐이라 화로(온기)를 두면 "들어갈지 돌지"가 갈린다.
			layout.shapes = [
				_rect(240, 240, 2320, 230), _rect(240, 2330, 2320, 230),   # 북·남 회랑
				_rect(240, 240, 230, 2320), _rect(2330, 240, 230, 2320),   # 서·동 회랑
				_rect(1040, 1040, 720, 720),                        # 중앙 결정실
				_rect(1300, 430, 200, 650), _rect(1300, 1720, 200, 650),   # 북·남 스포크
				_rect(430, 1300, 650, 200), _rect(1720, 1300, 650, 200),   # 서·동 스포크
			]
			layout.blocked_rects = [
				Rect2(1130, 1130, 150, 150), Rect2(1520, 1130, 150, 150),
				Rect2(1130, 1520, 150, 150), Rect2(1520, 1520, 150, 150),
			]
			layout.item_positions = [Vector2(350, 350), Vector2(2450, 350), Vector2(350, 2450), Vector2(2450, 2450)]
			layout.relic_position = Vector2(1400, 350)
			layout.landmark_position = Vector2(1400, 1400)
		4:
			# 공허 — 부유 섬 다섯 + 다리. 섬 밖은 허공이라 물러설 곳이 없고,
			# 다리는 폭 180이라 한 번 물리면 빠져나오기 어렵다. 위치 선정이 곧 생존.
			layout.shapes = [
				_circle(1400, 1400, 520),                           # 중앙 대섬
				_circle(1400, 470, 330), _circle(1400, 2330, 330),          # 북·남 섬
				_circle(470, 1400, 330), _circle(2330, 1400, 330),          # 서·동 섬
				_rect(1310, 470, 180, 930), _rect(1310, 1400, 180, 930),    # 북·남 다리
				_rect(470, 1310, 930, 180), _rect(1400, 1310, 930, 180),    # 서·동 다리
			]
			layout.blocked_circles = [_circle(1150, 1150, 110), _circle(1650, 1650, 110)]
			layout.item_positions = [Vector2(1400, 470), Vector2(470, 1400), Vector2(2330, 1400), Vector2(1400, 2330)]
			layout.relic_position = Vector2(1400, 1180)
			layout.landmark_position = Vector2(1400, 1400)
		5:
			# 마왕성 — 전실 → 열주 대홀 → 왕좌실의 3단 관문. 성문을 통과할수록
			# 안쪽으로 좁아져 최종 빌드 검증장이 된다. 열주는 시야를 끊되 동선은 남긴다.
			layout.shapes = [
				_rect(560, 760, 1680, 1290),                        # 열주 대홀
				_rect(1140, 240, 520, 560),                         # 왕좌실 (대홀과 직접 접함)
				_rect(1000, 2120, 800, 520),                        # 전실
				_rect(1300, 2010, 200, 250),                        # 성문 복도
			]
			layout.blocked_rects = [
				Rect2(760, 900, 150, 150), Rect2(760, 1300, 150, 150), Rect2(760, 1700, 150, 150),
				Rect2(1940, 900, 150, 150), Rect2(1940, 1300, 150, 150), Rect2(1940, 1700, 150, 150),
			]
			layout.item_positions = [Vector2(1400, 2380), Vector2(700, 1000), Vector2(2150, 1000), Vector2(1200, 420)]
			layout.relic_position = Vector2(1600, 420)
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
