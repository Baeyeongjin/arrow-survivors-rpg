extends Node2D

# M5-B 빙하 던전의 해빙형 목표 — 얼어붙은 화로.
# 어떤 속성으로도 녹일 수 있고 화염만 빠른 해결책이다. 점화 뒤에는 사라지지 않고
# 온기 지대로 남아 플레이어의 누적 냉기를 해제한다.

const ART_PATH := "res://assets/maps/glacier/brazier.png"
const FIRE_DAMAGE_MULT := 2.5
const ICE_DAMAGE_MULT := 0.55

var max_hp := 180.0
var hp := 180.0
var radius := 54.0
var warmth_radius := 184.0
var encounter_index := 0

var _lit := false
var _hit_t := 0.0
var _anim_t := 0.0
var _texture: Texture2D


func _ready() -> void:
	add_to_group("glacier_braziers")
	add_to_group("glacier_objectives")
	add_to_group("floor_runtime")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture = Assets.tex(ART_PATH)


func configure(index: int, health: float) -> void:
	encounter_index = index
	max_hp = maxf(1.0, health)
	hp = max_hp


func is_lit() -> bool:
	return _lit


func thaw_ratio() -> float:
	return clampf(1.0 - hp / maxf(1.0, max_hp), 0.0, 1.0)


func is_warming(point: Vector2) -> bool:
	return _lit and point.distance_to(position) <= warmth_radius


func damage_multiplier_for(element: String) -> float:
	match element:
		"fire":
			return FIRE_DAMAGE_MULT
		"ice":
			return ICE_DAMAGE_MULT
	return 1.0


# Enemy.take_damage와 같은 호출 형태를 받아 투사체·범위기·E·궁극기에 그대로 연결한다.

# 원소 상태(콤보). Enemy와 같은 계약이라 스킬 코드가 목표물을 구분하지 않는다.
var status := ""
var status_t := 0.0
var status_col := Color(1, 1, 1)


func mark_status(kind: String, time: float, col: Color) -> void:
	if kind == "":
		return
	status = kind
	status_t = maxf(status_t, time)
	status_col = col
	self_modulate = Color(1, 1, 1).lerp(col, 0.45)


func consume_status() -> String:
	var k := status
	status = ""
	status_t = 0.0
	self_modulate = Color(1, 1, 1)
	return k


func tick_status(delta: float) -> void:
	if status_t <= 0.0:
		return
	status_t -= delta
	if status_t <= 0.0:
		status = ""
		self_modulate = Color(1, 1, 1)


func take_damage(damage: float, crit: bool = false, _dot: bool = false, element: String = "") -> void:
	# 화로 점화 가속: 원소 상태가 걸려 있으면 2배로 달아오른다 (setup 보상).
	# 지옥 균열은 벌(30%)로 요구하고 여기는 상(200%)으로 권한다 — 같은 문법, 다른 압력.
	if status != "":
		damage *= 2.0
	if _lit or damage <= 0.0:
		return
	var main := get_parent()
	var resolved_element := element
	if resolved_element == "" and main and "attack_element" in main:
		resolved_element = str(main.attack_element)
	var dealt := damage * damage_multiplier_for(resolved_element)
	if main and main.has_method("_glacier_objective_damage_multiplier"):
		dealt *= float(main._glacier_objective_damage_multiplier())
	var actual := minf(hp, maxf(0.0, dealt))
	hp -= dealt
	_hit_t = 0.12
	if main and main.has_method("record_damage_dealt"):
		main.record_damage_dealt(actual)
	if main and main.has_method("_spawn_dmg_num"):
		var hit_kind := "weak" if resolved_element == "fire" else ("resist" if resolved_element == "ice" else "")
		main._spawn_dmg_num(position + Vector2(0, -radius), maxi(1, int(round(dealt))), crit,
			hit_kind, resolved_element)
	if hp <= 0.0:
		_light(true)
	queue_redraw()


func apply_slow(_amount: float, _time: float) -> void:
	pass


func shove(_from: Vector2, _force: float) -> void:
	pass


# 자동 렌더 검수에서 점화 상태를 만들되 실제 보상 콜백은 발생시키지 않는다.
func light_for_preview() -> void:
	_light(false)


func _light(notify_main: bool) -> void:
	if _lit:
		return
	_lit = true
	hp = 0.0
	remove_from_group("glacier_objectives")
	if notify_main:
		var main := get_parent()
		if main and main.has_method("on_glacier_brazier_lit"):
			main.on_glacier_brazier_lit(self)


func _process(delta: float) -> void:
	tick_status(delta)
	_anim_t += delta
	if _hit_t > 0.0:
		_hit_t -= delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_anim_t * (5.0 if _lit else 3.2))
	var art_size := 128.0
	if _texture:
		art_size = float(_texture.get_width()) * 2.0

	if _lit:
		# 온기 지대는 채움+이중 링으로 냉기 지형 위에서도 범위를 읽을 수 있게 한다.
		draw_circle(Vector2.ZERO, warmth_radius, Color(1.0, 0.42, 0.10, 0.07 + pulse * 0.035))
		draw_arc(Vector2.ZERO, warmth_radius, 0.0, TAU, 56,
			Color(1.0, 0.62, 0.18, 0.52 + pulse * 0.22), 3.0 + pulse * 1.5)
		draw_arc(Vector2.ZERO, warmth_radius - 10.0, 0.0, TAU, 56,
			Color(1.0, 0.86, 0.38, 0.20 + pulse * 0.12), 2.0)
		if _texture:
			draw_texture_rect(_texture,
				Rect2(Vector2(-art_size * 0.5, -art_size * 0.68), Vector2(art_size, art_size)),
				false, Color(1.12 + pulse * 0.10, 1.02 + pulse * 0.05, 0.90))
		else:
			draw_circle(Vector2(0, -12), 22.0 + pulse * 4.0, Color(1.0, 0.42, 0.08))
		# 점화 완료 표식은 색뿐 아니라 위로 열린 갈매기 형태로도 구분한다.
		draw_polyline(PackedVector2Array([
			Vector2(-10, -radius - 19), Vector2(0, -radius - 9), Vector2(14, -radius - 27),
		]), Color(1.0, 0.90, 0.44), 4.0)
		return

	# 얼어붙은 화로: 푸른 안전선과 결정 조각을 겹쳐 불이 꺼진 상태를 형태로 표시한다.
	draw_circle(Vector2.ZERO, radius + 22.0, Color(0.35, 0.72, 1.0, 0.07 + pulse * 0.03))
	draw_arc(Vector2.ZERO, radius + 22.0, 0.0, TAU, 40,
		Color(0.58, 0.86, 1.0, 0.48 + pulse * 0.16), 2.5)
	if _texture:
		var tint := Color(1.8, 2.0, 2.2) if _hit_t > 0.0 else Color(0.48, 0.72, 0.92)
		draw_texture_rect(_texture,
			Rect2(Vector2(-art_size * 0.5, -art_size * 0.68), Vector2(art_size, art_size)),
			false, tint)
	else:
		draw_circle(Vector2.ZERO, radius * 0.65, Color(0.35, 0.58, 0.78))
	for i in 5:
		var angle := TAU * float(i) / 5.0 - PI * 0.5
		var center := Vector2.from_angle(angle) * (radius * 0.70)
		var side := Vector2.from_angle(angle + PI * 0.5) * 5.0
		draw_colored_polygon(PackedVector2Array([
			center + Vector2.from_angle(angle) * 12.0,
			center - Vector2.from_angle(angle) * 8.0 + side,
			center - Vector2.from_angle(angle) * 8.0 - side,
		]), Color(0.70, 0.92, 1.0, 0.78))

	var bar_width := 96.0
	var ratio := clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	var bar_y := -radius - 28.0
	draw_rect(Rect2(-bar_width * 0.5 - 1.0, bar_y - 1.0, bar_width + 2.0, 8.0),
		Color(0.04, 0.04, 0.08, 0.94))
	draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width * ratio, 6.0),
		Color(0.46, 0.78, 1.0))
	# 화염 특효를 작은 불꽃형 마커로 표시하되 다른 속성도 피해를 줄 수 있다.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, bar_y - 4), Vector2(-2, bar_y - 16), Vector2(2, bar_y - 9),
		Vector2(6, bar_y - 18), Vector2(8, bar_y - 5), Vector2(2, bar_y + 1),
	]), Color(1.0, 0.56, 0.16, 0.94))
