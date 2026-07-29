extends RefCounted
# WFC 코어 — mxgmn/WaveFunctionCollapse의 Model.cs를 GDScript로 이식.
#   원본: https://github.com/mxgmn/WaveFunctionCollapse  (MIT, (C) 2016 Maxim Gumin)
#
# 관측(Observe)-전파(Propagate) 루프와 엔트로피 휴리스틱은 원본과 동일하다.
# 바꾼 것은 자료구조뿐이다: 원본의 bool[][] / int[][][] 를 GDScript에서 그대로 쓰면
# 중첩 Array 인덱싱 비용이 지배적이라, 전부 1차원 Packed 배열로 평탄화했다.
#   wave[i][t]          -> wave[i * T + t]
#   compatible[i][t][d] -> compatible[(i * T + t) * 4 + d]
#
# 이 파일은 게임 런타임이 아니라 tools/ 검증용이다. class_name을 붙이지 않는다.

const HEURISTIC_ENTROPY := 0
const HEURISTIC_MRV := 1
const HEURISTIC_SCANLINE := 2

const DX := [-1, 0, 1, 0]
const DY := [0, 1, 0, -1]
const OPPOSITE := [2, 3, 0, 1]

var MX := 0
var MY := 0
var T := 0
var N := 1
var periodic := false
var ground := false
var heuristic := HEURISTIC_ENTROPY

# 서브클래스가 setup에서 채운다.
var weights := PackedFloat64Array()
var propagator: Array = []            # [4][T] -> PackedInt32Array

var wave := PackedByteArray()         # MX*MY*T
var compatible := PackedInt32Array()  # MX*MY*T*4
var observed := PackedInt32Array()    # MX*MY

var sums_of_ones := PackedInt32Array()

var _stack := PackedInt32Array()      # (i, t) 쌍을 평탄화
var _stacksize := 0
var _observed_so_far := 0

var _weight_log_weights := PackedFloat64Array()
var _distribution := PackedFloat64Array()
var _sum_of_weights := 0.0
var _sum_of_weight_log_weights := 0.0
var _starting_entropy := 0.0

var _sums_of_weights := PackedFloat64Array()
var _sums_of_weight_log_weights := PackedFloat64Array()
var _entropies := PackedFloat64Array()

var _rng := RandomNumberGenerator.new()


func _init_arrays() -> void:
	var cells := MX * MY
	wave.resize(cells * T)
	compatible.resize(cells * T * 4)
	observed.resize(cells)
	_distribution.resize(T)
	_weight_log_weights.resize(T)

	_sum_of_weights = 0.0
	_sum_of_weight_log_weights = 0.0
	for t in T:
		var w := weights[t]
		_weight_log_weights[t] = w * log(w)
		_sum_of_weights += w
		_sum_of_weight_log_weights += _weight_log_weights[t]
	_starting_entropy = log(_sum_of_weights) - _sum_of_weight_log_weights / _sum_of_weights

	sums_of_ones.resize(cells)
	_sums_of_weights.resize(cells)
	_sums_of_weight_log_weights.resize(cells)
	_entropies.resize(cells)
	# 원본은 wave.Length * T 크기로 잡는다. 같은 (i,t)는 한 번만 Ban되므로 넘치지 않는다.
	_stack.resize(cells * T * 2)
	_stacksize = 0


# 성공하면 true, 모순(contradiction)에 빠지면 false.
func run(seed_value: int, limit: int) -> bool:
	if wave.is_empty():
		_init_arrays()
	_rng.seed = seed_value
	_clear()

	var l := 0
	while limit < 0 or l < limit:
		var node := _next_unobserved_node()
		if node >= 0:
			_observe(node)
			if not _propagate():
				return false
		else:
			for i in MX * MY:
				var base := i * T
				for t in T:
					if wave[base + t] != 0:
						observed[i] = t
						break
			return true
		l += 1
	return true


func _next_unobserved_node() -> int:
	if heuristic == HEURISTIC_SCANLINE:
		for i in range(_observed_so_far, MX * MY):
			if not periodic and (i % MX + N > MX or i / MX + N > MY):
				continue
			if sums_of_ones[i] > 1:
				_observed_so_far = i + 1
				return i
		return -1

	var min_value := 1e4
	var argmin := -1
	for i in MX * MY:
		if not periodic and (i % MX + N > MX or i / MX + N > MY):
			continue
		var remaining := sums_of_ones[i]
		if remaining <= 1:
			continue
		var entropy := _entropies[i] if heuristic == HEURISTIC_ENTROPY else float(remaining)
		if entropy <= min_value:
			var noise := 1e-6 * _rng.randf()
			if entropy + noise < min_value:
				min_value = entropy + noise
				argmin = i
	return argmin


func _observe(node: int) -> void:
	var base := node * T
	for t in T:
		_distribution[t] = weights[t] if wave[base + t] != 0 else 0.0
	var r := _weighted_pick(_rng.randf())
	for t in T:
		if (wave[base + t] != 0) != (t == r):
			_ban(node, t)


# 원본 Helper.Random의 누적분포 샘플링을 그대로 옮긴다.
func _weighted_pick(r: float) -> int:
	var total := 0.0
	for t in T:
		total += _distribution[t]
	var threshold := r * total
	var partial := 0.0
	for t in T:
		partial += _distribution[t]
		if partial >= threshold:
			return t
	return 0


func _propagate() -> bool:
	while _stacksize > 0:
		_stacksize -= 1
		var i1 := _stack[_stacksize * 2]
		var t1 := _stack[_stacksize * 2 + 1]
		var x1 := i1 % MX
		var y1 := i1 / MX

		for d in 4:
			var x2: int = x1 + DX[d]
			var y2: int = y1 + DY[d]
			if not periodic and (x2 < 0 or y2 < 0 or x2 + N > MX or y2 + N > MY):
				continue
			if x2 < 0:
				x2 += MX
			elif x2 >= MX:
				x2 -= MX
			if y2 < 0:
				y2 += MY
			elif y2 >= MY:
				y2 -= MY

			var i2 := x2 + y2 * MX
			var p: PackedInt32Array = propagator[d][t1]
			for t2 in p:
				var ci := (i2 * T + t2) * 4 + d
				compatible[ci] -= 1
				if compatible[ci] == 0:
					_ban(i2, t2)

	return sums_of_ones[0] > 0


func _ban(i: int, t: int) -> void:
	wave[i * T + t] = 0
	var cbase := (i * T + t) * 4
	for d in 4:
		compatible[cbase + d] = 0
	_stack[_stacksize * 2] = i
	_stack[_stacksize * 2 + 1] = t
	_stacksize += 1

	sums_of_ones[i] -= 1
	_sums_of_weights[i] -= weights[t]
	_sums_of_weight_log_weights[i] -= _weight_log_weights[t]

	var s := _sums_of_weights[i]
	# 원본은 s=0에서 -inf/NaN이 나오지만 sums_of_ones==0인 칸은 선택되지 않아 무해하다.
	# GDScript에서도 같은 값이 나오므로 NaN 전파만 막고 의미는 유지한다.
	_entropies[i] = (log(s) - _sums_of_weight_log_weights[i] / s) if s > 0.0 else 0.0


func _clear() -> void:
	var cells := MX * MY
	for i in cells:
		for t in T:
			wave[i * T + t] = 1
			var cbase := (i * T + t) * 4
			for d in 4:
				compatible[cbase + d] = (propagator[OPPOSITE[d]][t] as PackedInt32Array).size()
		sums_of_ones[i] = T
		_sums_of_weights[i] = _sum_of_weights
		_sums_of_weight_log_weights[i] = _sum_of_weight_log_weights
		_entropies[i] = _starting_entropy
		observed[i] = -1
	_observed_so_far = 0
	_stacksize = 0

	for y in MY:
		for x in MX:
			if not periodic and (x + N > MX or y + N > MY):
				continue
			var i := x + y * MX
			for t in T:
				var no_right: bool = (periodic or x < MX - N) and (propagator[2][t] as PackedInt32Array).is_empty()
				var no_top: bool = (periodic or y > 0) and (propagator[3][t] as PackedInt32Array).is_empty()
				var no_left: bool = (periodic or x > 0) and (propagator[0][t] as PackedInt32Array).is_empty()
				var no_bottom: bool = (periodic or y < MY - N) and (propagator[1][t] as PackedInt32Array).is_empty()
				if no_right or no_top or no_left or no_bottom:
					_ban(i, t)

	if ground:
		for x in MX:
			var bottom := x + (MY - 1) * MX
			for t in T - 1:
				if wave[bottom * T + t] != 0:
					_ban(bottom, t)
			for y in MY - 1:
				var i := x + y * MX
				if wave[i * T + T - 1] != 0:
					_ban(i, T - 1)

	if _stacksize > 0:
		_propagate()
