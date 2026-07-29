extends "res://tools/wfc/WFCModel.gd"
# OverlappingModel.cs 이식. 샘플 비트맵에서 NxN 패턴을 뽑아 가중치와 인접 규칙을 만든다.
# 원본은 PNG를 직접 읽지만 여기서는 색인 배열(sample)을 받는다. 우리 용도는
# "걸을 수 있음/벽"의 2색이라 색 변환 단계가 필요 없다.

var patterns: Array = []      # PackedByteArray(N*N), 값은 색인
var colors: PackedInt32Array = PackedInt32Array()


# sample: SX*SY 크기의 색인 배열. symmetry는 1(회전/반사 없음) ~ 8.
func setup(sample: PackedByteArray, sx: int, sy: int, color_count: int, pattern_size: int,
		width: int, height: int, periodic_input: bool, is_periodic: bool,
		symmetry: int, use_ground: bool, heuristic_mode: int) -> void:
	MX = width
	MY = height
	N = pattern_size
	periodic = is_periodic
	ground = use_ground
	heuristic = heuristic_mode

	colors.resize(color_count)
	for c in color_count:
		colors[c] = c

	patterns = []
	var pattern_indices := {}
	var weight_list := PackedFloat64Array()

	var xmax := sx if periodic_input else sx - N + 1
	var ymax := sy if periodic_input else sy - N + 1
	for y in ymax:
		for x in xmax:
			var ps: Array = []
			ps.resize(8)
			ps[0] = _extract(sample, sx, sy, x, y)
			ps[1] = _reflect(ps[0])
			ps[2] = _rotate(ps[0])
			ps[3] = _reflect(ps[2])
			ps[4] = _rotate(ps[2])
			ps[5] = _reflect(ps[4])
			ps[6] = _rotate(ps[4])
			ps[7] = _reflect(ps[6])

			for k in symmetry:
				var p: PackedByteArray = ps[k]
				var h := _hash(p, color_count)
				if pattern_indices.has(h):
					var index: int = pattern_indices[h]
					weight_list[index] = weight_list[index] + 1.0
				else:
					pattern_indices[h] = weight_list.size()
					weight_list.append(1.0)
					patterns.append(p)

	weights = weight_list
	T = weights.size()

	propagator = []
	propagator.resize(4)
	for d in 4:
		var per_tile: Array = []
		per_tile.resize(T)
		for t in T:
			var list := PackedInt32Array()
			for t2 in T:
				if _agrees(patterns[t], patterns[t2], DX[d], DY[d]):
					list.append(t2)
			per_tile[t] = list
		propagator[d] = per_tile


func _extract(sample: PackedByteArray, sx: int, sy: int, x: int, y: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(N * N)
	for dy in N:
		for dx in N:
			result[dx + dy * N] = sample[(x + dx) % sx + (y + dy) % sy * sx]
	return result


func _rotate(p: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(N * N)
	for y in N:
		for x in N:
			result[x + y * N] = p[N - 1 - y + x * N]
	return result


func _reflect(p: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(N * N)
	for y in N:
		for x in N:
			result[x + y * N] = p[N - 1 - x + y * N]
	return result


func _hash(p: PackedByteArray, c: int) -> int:
	var result := 0
	var power := 1
	for i in p.size():
		result += p[p.size() - 1 - i] * power
		power *= c
	return result


# 패턴 p1과 p2가 (dx, dy)만큼 어긋난 채 겹칠 때 겹치는 영역이 일치하는가.
func _agrees(p1: PackedByteArray, p2: PackedByteArray, dx: int, dy: int) -> bool:
	var xmin := 0 if dx < 0 else dx
	var xmax := dx + N if dx < 0 else N
	var ymin := 0 if dy < 0 else dy
	var ymax := dy + N if dy < 0 else N
	for y in range(ymin, ymax):
		for x in range(xmin, xmax):
			if p1[x + N * y] != p2[x - dx + N * (y - dy)]:
				return false
	return true


# 관측 결과를 MX*MY 색인 배열로. 미관측이면 비어 있는 배열.
func to_indices() -> PackedByteArray:
	var result := PackedByteArray()
	if observed.is_empty() or observed[0] < 0:
		return result
	result.resize(MX * MY)
	for y in MY:
		var dy := 0 if y < MY - N + 1 else N - 1
		for x in MX:
			var dx := 0 if x < MX - N + 1 else N - 1
			var p: PackedByteArray = patterns[observed[x - dx + (y - dy) * MX]]
			result[x + y * MX] = p[dx + dy * N]
	return result
