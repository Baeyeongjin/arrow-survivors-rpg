extends Node2D

# M5-A 묘지 던전의 점령형 목표 — 영혼 봉인비.
# 파괴가 아니라 "범위 안에 머무르며 점령"한다. 어떤 무기·속성도 진행을 막지 않는다
# (묘지는 입문 던전이라 정답 속성이 없다). 범위를 벗어나면 진행이 멈추되 초기화되지 않는다.

const SEAL_DURATION := 10.0

var radius := 138.0          # 점령 판정 반경
var duration := SEAL_DURATION
var progress := 0.0          # 누적 점령 시간(초)
var encounter_index := 0

var _completed := false
var _seal_fade := 0.6
var _anim_t := 0.0
var _in_range := false


func _ready() -> void:
	add_to_group("grave_seals")
	add_to_group("grave_objectives")
	add_to_group("floor_runtime")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func configure(index: int, seal_radius: float, seal_duration: float) -> void:
	encounter_index = index
	radius = maxf(24.0, seal_radius)
	duration = maxf(1.0, seal_duration)
	progress = 0.0


func is_completed() -> bool:
	return _completed


func progress_ratio() -> float:
	return clampf(progress / maxf(0.001, duration), 0.0, 1.0)


# 범위 안이면 진행, 밖이면 정지(초기화 아님). 완료 시 1회 콜백. 테스트가 직접 호출한다.
func tick(delta: float, in_range: bool) -> void:
	if _completed:
		return
	_in_range = in_range
	if in_range:
		progress = minf(duration, progress + delta)
		if progress >= duration:
			_complete()


func _process(delta: float) -> void:
	_anim_t += delta
	if _completed:
		_seal_fade -= delta
		if _seal_fade <= 0.0:
			queue_free()
			return
		queue_redraw()
		return
	tick(delta, _player_in_range())
	queue_redraw()


func _player_in_range() -> bool:
	var pl := get_tree().get_first_node_in_group("player")
	return pl != null and is_instance_valid(pl) and pl.position.distance_to(position) <= radius


# 보스 등장 시 미완료 봉인은 보상 없이 사라진다(보스 방패만 강화). 지옥 균열과 같은 규약.
func absorb_without_reward() -> void:
	if _completed:
		return
	_completed = true
	remove_from_group("grave_objectives")
	_seal_fade = 0.12


func _complete() -> void:
	_completed = true
	remove_from_group("grave_objectives")
	var main := get_parent()
	if main and main.has_method("on_grave_seal_completed"):
		main.on_grave_seal_completed(self)


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_anim_t * 5.0)
	if _completed:
		var fade := clampf(_seal_fade / 0.6, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius * (1.0 + (1.0 - fade) * 0.4),
			Color(0.60, 0.82, 1.0, 0.16 * fade))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.72, 0.92, 1.0, fade), 4.0)
		return

	# 점령 구역: 형태(원)로 위험/목표를 구분. 안에 있으면 밝게, 밖이면 어둡게.
	var ratio := progress_ratio()
	var zone_col := Color(0.45, 0.72, 1.0, 0.14 + pulse * 0.05) if _in_range \
		else Color(0.55, 0.55, 0.72, 0.10)
	draw_circle(Vector2.ZERO, radius, zone_col)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 44,
		Color(0.70, 0.88, 1.0, 0.50 + pulse * 0.25) if _in_range else Color(0.62, 0.64, 0.80, 0.5),
		2.5 + (pulse * 2.0 if _in_range else 0.0))

	# 봉인비 기둥(형태로도 읽히게): 중앙 오벨리스크.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, 30), Vector2(-9, -34), Vector2(0, -46),
		Vector2(9, -34), Vector2(13, 30),
	]), Color(0.30, 0.34, 0.46))
	draw_line(Vector2(0, -40), Vector2(0, 20), Color(0.62, 0.86, 1.0, 0.55 + pulse * 0.35), 3.0)

	# 점령 진행 링(형태) + 텍스트 대신 명확한 호 길이.
	var bar_y := -radius - 22.0
	if ratio > 0.0:
		draw_arc(Vector2.ZERO, radius - 8.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 40,
			Color(0.55, 0.95, 0.70), 6.0)
	var bar_width := 92.0
	draw_rect(Rect2(-bar_width * 0.5 - 1.0, bar_y - 1.0, bar_width + 2.0, 8.0),
		Color(0.04, 0.03, 0.06, 0.94))
	draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width * ratio, 6.0),
		Color(0.55, 0.95, 0.70) if _in_range else Color(0.50, 0.62, 0.80))
	# 점령 중 표식(삼각) — 색만이 아니라 형태로 상태를 알린다.
	if _in_range:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-6, bar_y - 8), Vector2(6, bar_y - 8), Vector2(0, bar_y - 16),
		]), Color(0.60, 1.0, 0.75, 0.95))
