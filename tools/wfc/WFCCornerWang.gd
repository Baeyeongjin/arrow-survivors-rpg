extends "res://tools/wfc/WFCModel.gd"
# SimpleTiledModel 계열 — 우리 프로젝트가 실제로 쓰는 16장 코너 Wang 타일셋을
# 그대로 WFC 타일로 삼는다. StageTileRenderer와 동일한 인덱스 규약을 쓴다:
#   index = NW*8 + NE*4 + SW*2 + SE   (1 = 바닥, 0 = 벽)
#
# 인접 규칙은 원본 XML 대신 코너 일치에서 자동으로 유도한다.
# 오른쪽 이웃이면 내 NE/SE 가 상대의 NW/SW 와 같아야 한다.
#
# 이 모델을 돌려보는 목적은 "지금 가진 타일셋만으로 WFC가 구조를 만들 수 있는가"를
# 실측하기 위해서다. 결과 해석은 tools/wfc/README.md 참고.

const NW := 3   # 비트 위치
const NE := 2
const SW := 1
const SE := 0


func _bit(t: int, which: int) -> int:
	return (t >> which) & 1


func setup(width: int, height: int, is_periodic: bool, heuristic_mode: int,
		tile_weights := PackedFloat64Array()) -> void:
	MX = width
	MY = height
	N = 1
	periodic = is_periodic
	heuristic = heuristic_mode
	T = 16

	if tile_weights.size() == 16:
		weights = tile_weights
	else:
		weights = PackedFloat64Array()
		weights.resize(16)
		weights.fill(1.0)

	propagator = []
	propagator.resize(4)
	for d in 4:
		var per_tile: Array = []
		per_tile.resize(T)
		for t in T:
			var list := PackedInt32Array()
			for t2 in T:
				if _compatible_pair(t, t2, d):
					list.append(t2)
			per_tile[t] = list
		propagator[d] = per_tile


# t2가 t의 방향 d 이웃으로 올 수 있는가. DX/DY는 코어와 동일한 규약.
func _compatible_pair(t: int, t2: int, d: int) -> bool:
	match d:
		2:   # 오른쪽 이웃
			return _bit(t, NE) == _bit(t2, NW) and _bit(t, SE) == _bit(t2, SW)
		0:   # 왼쪽 이웃
			return _bit(t2, NE) == _bit(t, NW) and _bit(t2, SE) == _bit(t, SW)
		1:   # 아래 이웃 (y 증가 = 화면 아래)
			return _bit(t, SW) == _bit(t2, NW) and _bit(t, SE) == _bit(t2, NE)
		3:   # 위 이웃
			return _bit(t2, SW) == _bit(t, NW) and _bit(t2, SE) == _bit(t, NE)
	return false


# 각 방향에서 타일 하나당 몇 개가 호환되는지. 16이면 완전 무제약, 1이면 강한 제약.
func compatibility_profile() -> Dictionary:
	var per_direction := PackedInt32Array()
	for d in 4:
		var total := 0
		for t in T:
			total += (propagator[d][t] as PackedInt32Array).size()
		per_direction.append(total / T)
	return {"avg_compatible_per_direction": per_direction, "tile_count": T}


# 관측 결과를 걸을 수 있음(1)/벽(0) 격자로. 타일 하나가 코너 4개를 갖고 있으므로
# 셀 중심의 통행 가능 여부는 "네 코너가 모두 바닥인가"로 본다.
func to_walkable() -> PackedByteArray:
	var result := PackedByteArray()
	if observed.is_empty() or observed[0] < 0:
		return result
	result.resize(MX * MY)
	for i in MX * MY:
		var t := observed[i]
		result[i] = 1 if t == 15 else 0
	return result
