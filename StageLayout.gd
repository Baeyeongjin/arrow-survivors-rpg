class_name StageLayout
extends RefCounted

# 독립 맵의 이동 가능 영역/고정 아이템/유물 슬롯 데이터.
# 장판 아트가 준비되기 전에도 플레이 동선과 충돌을 먼저 검증할 수 있게 한다.
const WORLD := Vector2(3840, 3840)

var stage_id := 1
var tint := Color(0.70, 0.70, 0.78)
var rooms: Array[Rect2] = []          # 생성된 방(장식·스폰이 방 기준으로 배치되도록 공개)
var shapes: Array[Dictionary] = []
var blocked_circles: Array[Dictionary] = []
var blocked_rects: Array[Rect2] = []
var item_positions: Array[Vector2] = []
var objective_positions: Array[Vector2] = []
var relic_position := Vector2.ZERO
var landmark_position := Vector2(1400, 1220)

# 경로찾기 핫패스용 평탄화 캐시.
# 적 한 마리가 매 프레임 steer_toward를 2회(추격 + 분리) 부르고, 그 안에서 is_walkable이
# 다시 호출된다. 원래 구현은 호출마다 shapes를 9번(중심 1 + 발자국 8) 훑고 도형마다
# str(shape["kind"]) 문자열 match를 했다. 실측 결과 is_walkable 한 번이 10~22us,
# 300마리 × 2회 환산 시 빙하에서 프레임당 18.5ms로 60fps 예산(16.7ms)을 넘겼다.
# 그래서 도형을 최초 사용 시 한 번만 타입 배열로 굽고, 핫패스에서는 문자열을 만지지 않는다.
var _baked := false
var _rects: Array[Rect2] = []
var _circle_center := PackedVector2Array()
var _circle_radius := PackedFloat32Array()
var _ring_center := PackedVector2Array()
var _ring_inner := PackedFloat32Array()
var _ring_outer := PackedFloat32Array()
var _block_center := PackedVector2Array()
var _block_radius := PackedFloat32Array()


# ── 상위 그리드 WFC 던전 생성 ────────────────────────────────────────────
# 방 슬롯 격자(WFC_GRID x WFC_GRID)에 WFC를 돌려 배치를 만든다. 타일은
# 빈칸 / 방 / 가로복도 / 세로복도 / 교차로 다섯 가지고, 인접 제약은 하나다:
#   "복도의 열린 끝이 암반(빈칸)으로 이어지면 안 된다."
# 이 제약은 실제로 가지치기를 한다. tools/wfc 검증에서 코너 Wang 16장이 백색소음을
# 낸 이유는 제약이 0이었기 때문이고(어떤 타일 옆에도 항상 4장이 맞았다), 여기서는
# 복도가 방·교차로로만 이어질 수 있어 방과 통로가 있는 배치가 나온다.
#
# WFC는 연결성을 보장하지 못한다(실측: 최대 연결요소 12.9~85.1%). 그래서 풀이 뒤에
# 중앙에서 BFS로 도달 검사를 하고, 못 닿는 칸은 빈칸으로 지운다. 그러고도 방이
# 모자라면 다른 시드로 다시 뽑고, 전부 실패하면 결정적 폴백으로 내려간다.
# 자세한 실측은 tools/wfc/README.md.
const WFCModelScript = preload("res://tools/wfc/WFCModel.gd")

enum { SLOT_EMPTY, SLOT_ROOM, SLOT_HALL_H, SLOT_HALL_V, SLOT_CROSS }
const SLOT_COUNT := 5
const SOCKET_WALL := 0
const SOCKET_OPEN := 1
const SOCKET_FLEX := 2   # 방의 벽 — 이웃이 열려 있으면 그쪽에 문이 난다
# 방향 순서는 WFCModel과 같다: 0=좌, 1=하, 2=우, 3=상
const SLOT_SOCKETS := [
	[SOCKET_WALL, SOCKET_WALL, SOCKET_WALL, SOCKET_WALL],
	[SOCKET_FLEX, SOCKET_FLEX, SOCKET_FLEX, SOCKET_FLEX],
	[SOCKET_OPEN, SOCKET_WALL, SOCKET_OPEN, SOCKET_WALL],
	[SOCKET_WALL, SOCKET_OPEN, SOCKET_WALL, SOCKET_OPEN],
	[SOCKET_OPEN, SOCKET_OPEN, SOCKET_OPEN, SOCKET_OPEN],
]
const WFC_GRID := 5
const WFC_TRIES := 24
const MIN_ROOMS := 5     # 목표 3 + 유물 1 + 여유 1 (슬라이스 계약)

# 던전 성격 프로필. 배치는 매 판 달라지되 던전마다 손맛은 유지하는 손잡이.
#   room_min/max: 방 한 변(격자 칸 안으로 클램프), corridor: 복도 폭,
#   room_w: 방 가중치(높으면 방이 많은 던전), cross_w: 교차로 가중치(높으면 순환로가 많다),
#   round: 방을 원형으로 낼지(공허의 부유 섬), pillars: 방 안 기둥 수
const DUNGEON_PROFILES := {
	1: {"room_min": 360, "room_max": 520, "corridor": 260, "room_w": 2.6, "cross_w": 0.8, "round": false, "pillars": 1},
	2: {"room_min": 330, "room_max": 480, "corridor": 220, "room_w": 2.0, "cross_w": 0.5, "round": false, "pillars": 1},
	3: {"room_min": 320, "room_max": 470, "corridor": 200, "room_w": 2.4, "cross_w": 1.1, "round": false, "pillars": 1},
	4: {"room_min": 330, "room_max": 480, "corridor": 190, "room_w": 2.2, "cross_w": 0.6, "round": true, "pillars": 0},
	5: {"room_min": 360, "room_max": 540, "corridor": 240, "room_w": 2.5, "cross_w": 0.9, "round": false, "pillars": 2},
}


# layout_seed 0 = 스테이지별 고정 시드(테스트·개발 캡처 재현용).
# 실제 런은 Main이 층마다 난수를 넘겨 매번 다른 던전이 나온다.
static func make(stage: int, stage_tint: Color, layout_seed: int = 0) -> StageLayout:
	var layout := StageLayout.new()
	layout.stage_id = clampi(stage, 1, 5)
	layout.tint = stage_tint
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("arrow-stage-%d" % layout.stage_id) if layout_seed == 0 else layout_seed
	layout._generate(rng, DUNGEON_PROFILES[layout.stage_id])
	layout._bake()
	return layout


func _generate(rng: RandomNumberGenerator, profile: Dictionary) -> void:
	var slots := _solve_slots(rng, profile)
	if slots.is_empty():
		slots = _fallback_slots()
	_build_geometry(rng, profile, slots)
	_assign_points()


# WFC를 돌려 슬롯 격자를 얻는다. 실패하면 빈 배열.
func _solve_slots(rng: RandomNumberGenerator, profile: Dictionary) -> PackedInt32Array:
	var model = WFCModelScript.new()
	model.MX = WFC_GRID
	model.MY = WFC_GRID
	model.T = SLOT_COUNT
	model.N = 1
	model.heuristic = WFCModelScript.HEURISTIC_ENTROPY
	model.weights = PackedFloat64Array([
		1.0, float(profile["room_w"]), 1.5, 1.5, float(profile["cross_w"])])
	model.propagator = _build_propagator()
	for _attempt in WFC_TRIES:
		if not model.run(rng.randi(), -1):
			continue   # 모순 — 다른 시드로
		var slots := PackedInt32Array(model.observed)
		# 중앙은 항상 방. 런 시작·층 전환이 그 자리라 반드시 걸을 수 있어야 한다.
		# 방 소켓은 FLEX라 어떤 이웃과도 맞으므로 이 덮어쓰기가 제약을 깨지 않는다.
		slots[_center_slot()] = SLOT_ROOM
		_prune_unreachable(slots)
		if _count_rooms(slots) >= MIN_ROOMS:
			return slots
	return PackedInt32Array()


static func _build_propagator() -> Array:
	var propagator: Array = []
	for d in 4:
		var per_tile: Array = []
		for t in SLOT_COUNT:
			var allowed := PackedInt32Array()
			for t2 in SLOT_COUNT:
				var a: int = SLOT_SOCKETS[t][d]
				var b: int = SLOT_SOCKETS[t2][WFCModelScript.OPPOSITE[d]]
				# 열린 끝이 벽을 만나는 조합만 금지한다.
				var clash := (a == SOCKET_OPEN and b == SOCKET_WALL) or (a == SOCKET_WALL and b == SOCKET_OPEN)
				if not clash:
					allowed.append(t2)
			per_tile.append(allowed)
		propagator.append(per_tile)
	return propagator


static func _center_slot() -> int:
	return (WFC_GRID / 2) + (WFC_GRID / 2) * WFC_GRID


# 두 이웃 칸이 실제로 통하는가 (양쪽 소켓이 모두 벽이 아니면 통한다).
static func _slots_linked(slots: PackedInt32Array, index: int, d: int) -> bool:
	var x := index % WFC_GRID
	var y := index / WFC_GRID
	var nx: int = x + WFCModelScript.DX[d]
	var ny: int = y + WFCModelScript.DY[d]
	if nx < 0 or ny < 0 or nx >= WFC_GRID or ny >= WFC_GRID:
		return false
	var here: int = slots[index]
	var there: int = slots[nx + ny * WFC_GRID]
	if here == SLOT_EMPTY or there == SLOT_EMPTY:
		return false
	var a: int = SLOT_SOCKETS[here][d]
	var b: int = SLOT_SOCKETS[there][WFCModelScript.OPPOSITE[d]]
	return a != SOCKET_WALL and b != SOCKET_WALL


# 중앙에서 못 닿는 칸을 빈칸으로 지운다. WFC가 보장하지 못하는 연결성을 여기서 확정한다.
func _prune_unreachable(slots: PackedInt32Array) -> void:
	var seen := {}
	var queue: Array[int] = [_center_slot()]
	seen[_center_slot()] = true
	while not queue.is_empty():
		var index: int = queue.pop_back()
		for d in 4:
			if not _slots_linked(slots, index, d):
				continue
			var nx: int = index % WFC_GRID + WFCModelScript.DX[d]
			var ny: int = index / WFC_GRID + WFCModelScript.DY[d]
			var next_index: int = nx + ny * WFC_GRID
			if not seen.has(next_index):
				seen[next_index] = true
				queue.append(next_index)
	for i in slots.size():
		if not seen.has(i):
			slots[i] = SLOT_EMPTY


static func _count_rooms(slots: PackedInt32Array) -> int:
	var total := 0
	for i in slots.size():
		if slots[i] == SLOT_ROOM:
			total += 1
	return total


# WFC가 24번 다 실패했을 때의 결정적 배치. make()가 절대 실패하지 않게 하는 안전망.
static func _fallback_slots() -> PackedInt32Array:
	var slots := PackedInt32Array()
	slots.resize(WFC_GRID * WFC_GRID)
	slots.fill(SLOT_EMPTY)
	var mid := WFC_GRID / 2
	slots[mid + mid * WFC_GRID] = SLOT_CROSS
	for step in range(1, mid + 1):
		var kind: int = SLOT_ROOM if step == mid else SLOT_HALL_H
		slots[(mid - step) + mid * WFC_GRID] = kind
		slots[(mid + step) + mid * WFC_GRID] = kind
		kind = SLOT_ROOM if step == mid else SLOT_HALL_V
		slots[mid + (mid - step) * WFC_GRID] = kind
		slots[mid + (mid + step) * WFC_GRID] = kind
	slots[_center_slot()] = SLOT_ROOM
	return slots


# 슬롯 격자를 실제 지형으로 펼친다. 방은 칸 안 지터 사각(칸 중심을 반드시 포함),
# 복도는 통하는 이웃 칸 중심끼리 이은 직선. 그래서 그래프 연결성이 곧 기하 연결성이다.
func _build_geometry(rng: RandomNumberGenerator, profile: Dictionary, slots: PackedInt32Array) -> void:
	var corridor := float(profile["corridor"])
	var margin := corridor * 0.5 + 70.0
	var cell := (WORLD - Vector2(margin, margin) * 2.0) / float(WFC_GRID)
	var room_cap := Vector2(cell.x - corridor * 0.6, cell.y - corridor * 0.6)
	var is_round: bool = bool(profile["round"])

	var room_of_slot := {}
	for i in slots.size():
		if slots[i] != SLOT_ROOM:
			continue
		var slot_center := _slot_center(i, margin, cell)
		var size := Vector2(
			clampf(rng.randf_range(float(profile["room_min"]), float(profile["room_max"])), 120.0, room_cap.x),
			clampf(rng.randf_range(float(profile["room_min"]), float(profile["room_max"])), 120.0, room_cap.y))
		# 지터를 주되 칸 중심을 항상 품게 한다 — 복도가 칸 중심으로 들어오기 때문.
		var jitter := Vector2(
			rng.randf_range(-1.0, 1.0) * maxf(0.0, size.x * 0.5 - corridor * 0.5),
			rng.randf_range(-1.0, 1.0) * maxf(0.0, size.y * 0.5 - corridor * 0.5))
		var room := Rect2(slot_center + jitter - size * 0.5, size)
		rooms.append(room)
		room_of_slot[i] = rooms.size() - 1
		if is_round and i != _center_slot():
			var c := room.get_center()
			shapes.append(_circle(c.x, c.y, minf(size.x, size.y) * 0.5))
		else:
			shapes.append(_rect(room.position.x, room.position.y, size.x, size.y))

	# 통하는 이웃끼리 복도를 뚫는다. d를 우/하만 돌려 같은 복도를 두 번 파지 않는다.
	for i in slots.size():
		if slots[i] == SLOT_EMPTY:
			continue
		for d in [1, 2]:
			if not _slots_linked(slots, i, d):
				continue
			var nx: int = i % WFC_GRID + WFCModelScript.DX[d]
			var ny: int = i / WFC_GRID + WFCModelScript.DY[d]
			_carve(_slot_center(i, margin, cell),
				_slot_center(nx + ny * WFC_GRID, margin, cell), corridor * 0.5)

	# 방 안 기둥. 시야를 끊되 방 중앙(목표·아이템 자리)은 비워 둔다.
	for index in room_of_slot.keys():
		if index == _center_slot():
			continue   # 시작 방은 비워 둔다
		var room: Rect2 = rooms[room_of_slot[index]]
		for _p in int(profile["pillars"]):
			var pillar := Vector2(rng.randf_range(90.0, 150.0), rng.randf_range(90.0, 150.0))
			if room.size.x < pillar.x + 300.0 or room.size.y < pillar.y + 300.0:
				continue
			var slot := Rect2(Vector2(
				rng.randf_range(room.position.x + 40.0, room.end.x - 40.0 - pillar.x),
				rng.randf_range(room.position.y + 40.0, room.end.y - 40.0 - pillar.y)), pillar)
			if slot.grow(130.0).has_point(room.get_center()):
				continue
			blocked_rects.append(slot)


static func _slot_center(index: int, margin: float, cell: Vector2) -> Vector2:
	return Vector2(margin, margin) + (Vector2(index % WFC_GRID, index / WFC_GRID) + Vector2(0.5, 0.5)) * cell


func _carve(a: Vector2, b: Vector2, half: float) -> void:
	var origin := Vector2(minf(a.x, b.x) - half, minf(a.y, b.y) - half)
	var size := Vector2(absf(b.x - a.x) + half * 2.0, absf(b.y - a.y) + half * 2.0)
	shapes.append(_rect(origin.x, origin.y, size.x, size.y))


# 시작 방에서 먼 방부터 목표·유물을 배치해 탐험 동선을 만든다.
# 목표 3개 / 아이템 4개는 던전 슬라이스와 테스트의 계약이라 개수를 반드시 지킨다.
func _assign_points() -> void:
	var start: Vector2 = rooms[0].get_center() if not rooms.is_empty() else WORLD * 0.5
	# 시작 방은 중앙 슬롯 방이다. rooms 순서는 슬롯 인덱스순이라 중앙을 직접 찾는다.
	for room in rooms:
		if room.has_point(WORLD * 0.5):
			start = room.get_center()
			break
	landmark_position = start
	var order: Array[int] = []
	for i in rooms.size():
		if rooms[i].get_center() != start:
			order.append(i)
	var room_list := rooms
	order.sort_custom(func(a: int, b: int) -> bool:
		return (room_list[a].get_center().distance_squared_to(start)
			> room_list[b].get_center().distance_squared_to(start)))

	var used := {}
	for i in mini(3, order.size()):
		objective_positions.append(rooms[order[i]].get_center())
		used[order[i]] = true
	relic_position = start
	for i in order.size():
		if not used.has(order[i]):
			relic_position = rooms[order[i]].get_center()
			used[order[i]] = true
			break
	# 고정 아이템은 가까운 방부터 — 초반 탐험이 곧 빌드 확장이 되게.
	for i in range(order.size() - 1, -1, -1):
		if item_positions.size() >= 4:
			break
		if used.has(order[i]):
			continue
		item_positions.append(rooms[order[i]].get_center())
		used[order[i]] = true
	# 방이 모자라면 시작 방 안쪽으로 채워 4개 계약을 지킨다.
	var fill := 0
	while item_positions.size() < 4:
		var reach := 120.0
		if not rooms.is_empty():
			reach = minf(rooms[0].size.x, rooms[0].size.y) * 0.26
		item_positions.append(start + Vector2.from_angle(TAU * float(fill) / 4.0) * reach)
		fill += 1
	while objective_positions.size() < 3:
		objective_positions.append(start)


func is_walkable(point: Vector2, radius := 0.0) -> bool:
	if point.x < radius or point.y < radius or point.x > WORLD.x - radius or point.y > WORLD.y - radius:
		return false
	if not _baked:
		_bake()
	# 빠른 경로: 점이 도형 하나를 radius만큼 줄인 영역 안에 있으면 반지름 radius의 발자국
	# 원이 전부 그 도형 안이다. 따라서 합집합 조건이 자동으로 성립하고 발자국 8방향 검사를
	# 건너뛸 수 있다(근사가 아니라 동치). 개활 바닥에 서 있는 대다수 몹이 여기서 끝난다.
	if not _inside_single_shape(point, radius):
		# 도형 이음새 근처. 각 사각형을 따로 줄이면 이음새에 없는 벽이 생기므로,
		# 원래대로 합집합에 대해 중심 + 발자국 8방향을 확인한다.
		if not _in_shape_union(point):
			return false
		if radius > 0.0:
			for direction_index in 8:
				var angle := TAU * float(direction_index) / 8.0
				if not _in_shape_union(point + Vector2.from_angle(angle) * radius):
					return false
	for i in _block_center.size():
		var reach := _block_radius[i] + radius
		if point.distance_squared_to(_block_center[i]) < reach * reach:
			return false
	for rect in blocked_rects:
		if rect.grow(radius).has_point(point):
			return false
	return true


# 도형을 문자열 키 딕셔너리에서 타입 배열로 굽는다(핫패스에서 str()·match 제거).
func _bake() -> void:
	_baked = true
	_rects.clear()
	_circle_center = PackedVector2Array()
	_circle_radius = PackedFloat32Array()
	_ring_center = PackedVector2Array()
	_ring_inner = PackedFloat32Array()
	_ring_outer = PackedFloat32Array()
	for shape in shapes:
		match str(shape["kind"]):
			"rect":
				_rects.append(shape["rect"])
			"circle":
				_circle_center.append(shape["center"])
				_circle_radius.append(float(shape["radius"]))
			"ring":
				_ring_center.append(shape["center"])
				_ring_inner.append(float(shape["inner"]))
				_ring_outer.append(float(shape["outer"]))
	_block_center = PackedVector2Array()
	_block_radius = PackedFloat32Array()
	for block in blocked_circles:
		_block_center.append(block["center"])
		_block_radius.append(float(block["radius"]))


# 점이 도형 하나만으로 radius 여유를 확보하는가 (발자국 검사 생략 조건).
func _inside_single_shape(point: Vector2, radius: float) -> bool:
	for rect in _rects:
		if rect.grow(-radius).has_point(point):
			return true
	for i in _circle_center.size():
		var inner := _circle_radius[i] - radius
		if inner > 0.0 and point.distance_squared_to(_circle_center[i]) <= inner * inner:
			return true
	for i in _ring_center.size():
		var distance := point.distance_to(_ring_center[i])
		if distance >= _ring_inner[i] + radius and distance <= _ring_outer[i] - radius:
			return true
	return false


# 점이 걷기 영역 합집합에 속하는가 (여유 없이 경계 포함).
func _in_shape_union(point: Vector2) -> bool:
	for rect in _rects:
		if rect.has_point(point):
			return true
	for i in _circle_center.size():
		if point.distance_squared_to(_circle_center[i]) <= _circle_radius[i] * _circle_radius[i]:
			return true
	for i in _ring_center.size():
		var distance := point.distance_to(_ring_center[i])
		if distance >= _ring_inner[i] and distance <= _ring_outer[i]:
			return true
	return false


func _is_in_shape_union(point: Vector2) -> bool:
	if not _baked:
		_bake()
	return _in_shape_union(point)


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
