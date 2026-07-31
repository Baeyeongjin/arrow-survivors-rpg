extends Node2D

# M5-C 공허 던전의 위치 선정형 목표 — 공허 닻.
# 닻은 플레이어를 중심으로 끌어당긴다. 너무 가까운 핵이나 바깥이 아니라 안정 고리 안에서
# 누적 시간을 채워야 하므로, 단순 점령과 달리 이동 입력·회피 타이밍이 목표 수행의 일부다.

const ART_PATH := "res://assets/maps/void_altar/void_anchor.png"
const STABILIZE_DURATION := 8.0
const STABLE_INNER_RADIUS := 92.0
const STABLE_OUTER_RADIUS := 154.0
const PULL_RADIUS := 305.0
const PROGRESS_DECAY := 0.45

var encounter_index := 0
var duration := STABILIZE_DURATION
var progress := 0.0
var pull_strength := 104.0
var radius := 54.0

var _stabilized := false
var _fade_t := 0.75
var _anim_t := 0.0
var _in_stable_band := false
var _ring_bonus := 0.0
var _texture: Texture2D


func _ready() -> void:
	add_to_group("void_anchors")
	add_to_group("void_objectives")
	add_to_group("floor_runtime")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture = Assets.tex(ART_PATH)


func configure(index: int, stabilize_duration: float, gravity_strength: float) -> void:
	encounter_index = index
	duration = maxf(1.0, stabilize_duration)
	pull_strength = maxf(0.0, gravity_strength)
	progress = 0.0


func is_stabilized() -> bool:
	return _stabilized


# 콤보 보상: 닻 근처에서 상태를 터뜨리면 안정화가 당겨진다 (payoff 요구).
# 점령형 목표라 피해 배수 대신 시간을 준다.
func combo_boost(seconds: float) -> void:
	if not _stabilized:
		progress = minf(duration, progress + seconds)


func progress_ratio() -> float:
	return clampf(progress / maxf(0.001, duration), 0.0, 1.0)


func stability_band(ring_bonus: float = 0.0) -> Vector2:
	var bonus := clampf(ring_bonus, 0.0, 36.0)
	return Vector2(maxf(radius + 12.0, STABLE_INNER_RADIUS - bonus),
		STABLE_OUTER_RADIUS + bonus)


# 테스트와 런타임이 같은 규칙을 쓴다. 안정 고리 밖에서는 진행이 천천히 줄지만
# 즉시 초기화되지는 않아, 한 번의 밀림으로 누적 노력이 전부 사라지지 않는다.
func tick(delta: float, distance_to_anchor: float, ring_bonus: float = 0.0) -> void:
	if _stabilized:
		return
	var band := stability_band(ring_bonus)
	_in_stable_band = distance_to_anchor >= band.x and distance_to_anchor <= band.y
	if _in_stable_band:
		progress = minf(duration, progress + maxf(0.0, delta))
	else:
		progress = maxf(0.0, progress - maxf(0.0, delta) * PROGRESS_DECAY)
	if progress >= duration:
		_stabilize()


func _process(delta: float) -> void:
	_anim_t += delta
	if _stabilized:
		_fade_t -= delta
		if _fade_t <= 0.0:
			queue_free()
			return
		queue_redraw()
		return

	var pl := get_tree().get_first_node_in_group("player") as Player
	if pl:
		var main := get_parent()
		var ring_bonus := 0.0
		if main and main.has_method("_void_anchor_ring_bonus"):
			ring_bonus = float(main._void_anchor_ring_bonus())
		_ring_bonus = ring_bonus
		var distance := pl.position.distance_to(position)
		tick(delta, distance, ring_bonus)
		if not _stabilized and main and main.has_method("apply_void_pull"):
			main.apply_void_pull(position, PULL_RADIUS, pull_strength, delta)
	queue_redraw()


# 최종 보스 등장 시 미완료 닻은 보상 없이 붕괴한다. 이미 안정화된 개수만 보스 핵에 반영한다.
func absorb_without_reward() -> void:
	if _stabilized:
		return
	_stabilized = true
	remove_from_group("void_objectives")
	_fade_t = 0.12


func _stabilize() -> void:
	if _stabilized:
		return
	_stabilized = true
	remove_from_group("void_objectives")
	var main := get_parent()
	if main and main.has_method("on_void_anchor_stabilized"):
		main.on_void_anchor_stabilized(self)


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_anim_t * 6.0)
	if _stabilized:
		var fade := clampf(_fade_t / 0.75, 0.0, 1.0)
		draw_arc(Vector2.ZERO, STABLE_OUTER_RADIUS * (1.0 + (1.0 - fade) * 0.22),
			0.0, TAU, 52, Color(0.72, 0.54, 1.0, fade), 5.0)
		draw_circle(Vector2.ZERO, radius * (1.0 + (1.0 - fade) * 0.65),
			Color(0.66, 0.42, 1.0, 0.18 * fade))
		return

	var band := stability_band(_ring_bonus)
	# 바깥 중력 범위와 실제 안정 고리를 서로 다른 형태로 표시한다.
	draw_circle(Vector2.ZERO, PULL_RADIUS, Color(0.28, 0.10, 0.46, 0.035 + pulse * 0.018))
	draw_arc(Vector2.ZERO, PULL_RADIUS, 0.0, TAU, 64,
		Color(0.52, 0.30, 0.78, 0.24 + pulse * 0.10), 2.0)
	draw_circle(Vector2.ZERO, band.y, Color(0.58, 0.34, 0.92, 0.08 + pulse * 0.025))
	draw_circle(Vector2.ZERO, band.x, Color(0.03, 0.02, 0.07, 0.28))
	draw_arc(Vector2.ZERO, band.x, 0.0, TAU, 48,
		Color(0.82, 0.64, 1.0, 0.44 + pulse * 0.20), 3.0)
	draw_arc(Vector2.ZERO, band.y, 0.0, TAU, 56,
		Color(0.82, 0.64, 1.0, 0.54 + pulse * 0.22), 4.0 if _in_stable_band else 2.5)

	# 안쪽을 향하는 쐐기 8개로 색을 보지 않아도 중력 방향을 읽을 수 있다.
	for i in 8:
		var angle := TAU * float(i) / 8.0 + _anim_t * 0.18
		var direction := Vector2.from_angle(angle)
		var side := direction.orthogonal() * 5.0
		var tip := direction * (band.x + 5.0)
		var tail := direction * (band.x + 23.0)
		draw_colored_polygon(PackedVector2Array([tip, tail + side, tail - side]),
			Color(0.74, 0.52, 1.0, 0.52 + pulse * 0.22))

	var art_size := 128.0
	if _texture:
		art_size = float(_texture.get_width()) * 2.0
		draw_texture_rect(_texture,
			Rect2(Vector2(-art_size * 0.5, -art_size * 0.68), Vector2(art_size, art_size)),
			false, Color(1.45, 1.10, 1.75) if _in_stable_band else Color(0.88, 0.74, 1.12))
	else:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-18, 34), Vector2(-10, -30), Vector2(0, -46),
			Vector2(10, -30), Vector2(18, 34),
		]), Color(0.34, 0.18, 0.52))

	var ratio := progress_ratio()
	var bar_width := 102.0
	var bar_y := -radius - 34.0
	draw_rect(Rect2(-bar_width * 0.5 - 1.0, bar_y - 1.0, bar_width + 2.0, 8.0),
		Color(0.03, 0.02, 0.06, 0.96))
	draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width * ratio, 6.0),
		Color(0.72, 0.48, 1.0) if _in_stable_band else Color(0.40, 0.30, 0.55))
	if _in_stable_band:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-7, bar_y - 8), Vector2(7, bar_y - 8), Vector2(0, bar_y - 18),
		]), Color(0.88, 0.72, 1.0))
