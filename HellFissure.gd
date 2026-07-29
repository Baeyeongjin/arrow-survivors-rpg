extends Node2D

# M3 지옥 던전의 파괴 가능한 용암 균열.
# 방치하면 주기적으로 폭발하고, 냉기 피해로 빠르게 봉인할 수 있다.

const ART_PATH := "res://assets/maps/hell_bridge/lava_fissure.png"
const TELEGRAPH_TIME := 1.15
const PULSE_INTERVAL := 1.65
const ICE_DAMAGE_MULT := 2.5
const FIRE_DAMAGE_MULT := 0.30

var max_hp := 180.0
var hp := 180.0
var radius := 52.0
var pulse_damage := 18.0
var encounter_index := 0

var _telegraph_t := TELEGRAPH_TIME
var _pulse_t := PULSE_INTERVAL
var _sealed := false
var _sealed_t := 0.75
var _hit_t := 0.0
var _anim_t := 0.0
var _texture: Texture2D


func _ready() -> void:
	add_to_group("hell_fissures")
	add_to_group("hell_objectives")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture = Assets.tex(ART_PATH)


func configure(index: int, health: float, damage: float) -> void:
	encounter_index = index
	max_hp = maxf(1.0, health)
	hp = max_hp
	pulse_damage = maxf(1.0, damage)


func is_sealed() -> bool:
	return _sealed


func damage_multiplier_for(element: String) -> float:
	match element:
		"ice":
			return ICE_DAMAGE_MULT
		"fire":
			return FIRE_DAMAGE_MULT
	return 1.0


# Enemy.take_damage와 같은 호출 형태를 받아 기존 투사체·광역기·E 스킬에 바로 연결한다.
func take_damage(damage: float, crit: bool = false, _dot: bool = false, element: String = "") -> void:
	if _sealed or damage <= 0.0:
		return
	var main := get_parent()
	var resolved_element := element
	if resolved_element == "" and main and "attack_element" in main:
		resolved_element = str(main.attack_element)
	var dealt := damage * damage_multiplier_for(resolved_element)
	if main and main.has_method("_hell_objective_damage_multiplier"):
		dealt *= float(main._hell_objective_damage_multiplier())
	var actual := minf(hp, dealt)
	hp -= dealt
	_hit_t = 0.12
	if main and main.has_method("record_damage_dealt"):
		main.record_damage_dealt(actual)
	if main and main.has_method("_spawn_dmg_num"):
		var hit_kind := "weak" if resolved_element == "ice" else ("resist" if resolved_element == "fire" else "")
		main._spawn_dmg_num(position + Vector2(0, -radius), maxi(1, int(round(dealt))), crit,
			hit_kind, resolved_element)
	if hp <= 0.0:
		_seal()
	queue_redraw()


func apply_slow(_amount: float, _time: float) -> void:
	pass


func shove(_from: Vector2, _force: float) -> void:
	pass


func absorb_without_reward() -> void:
	if _sealed:
		return
	_sealed = true
	remove_from_group("hell_objectives")
	_sealed_t = 0.15
	queue_redraw()


func _seal() -> void:
	_sealed = true
	remove_from_group("hell_objectives")
	var main := get_parent()
	if main and main.has_method("on_hell_fissure_sealed"):
		main.on_hell_fissure_sealed(self)


func _process(delta: float) -> void:
	_anim_t += delta
	if _hit_t > 0.0:
		_hit_t -= delta
	if _sealed:
		_sealed_t -= delta
		if _sealed_t <= 0.0:
			queue_free()
			return
		queue_redraw()
		return
	if _telegraph_t > 0.0:
		_telegraph_t -= delta
		queue_redraw()
		return
	_pulse_t -= delta
	if _pulse_t <= 0.0:
		_pulse_t = PULSE_INTERVAL
		var main := get_parent()
		if main and main.has_method("apply_hell_hazard_damage"):
			main.apply_hell_hazard_damage(pulse_damage, position, radius + 34.0)
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_anim_t * 7.0)
	if _sealed:
		var fade := clampf(_sealed_t / 0.75, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius * (1.1 + (1.0 - fade) * 0.5),
			Color(0.35, 0.82, 1.0, 0.18 * fade))
		draw_arc(Vector2.ZERO, radius * 1.25, 0.0, TAU, 32,
			Color(0.65, 0.92, 1.0, fade), 4.0)
		return

	var active := _telegraph_t <= 0.0
	var danger_radius := radius + 34.0
	if active:
		draw_circle(Vector2.ZERO, danger_radius, Color(1.0, 0.18, 0.04, 0.10 + pulse * 0.05))
		draw_arc(Vector2.ZERO, danger_radius, 0.0, TAU, 36,
			Color(1.0, 0.36, 0.08, 0.58 + pulse * 0.25), 3.0 + pulse * 2.0)
	else:
		var progress := clampf(1.0 - _telegraph_t / TELEGRAPH_TIME, 0.0, 1.0)
		var closing := lerpf(danger_radius * 1.65, danger_radius, progress)
		draw_circle(Vector2.ZERO, danger_radius, Color(1.0, 0.24, 0.06, 0.06 + progress * 0.08))
		draw_arc(Vector2.ZERO, closing, 0.0, TAU, 36,
			Color(1.0, 0.72, 0.18, 0.45 + progress * 0.45), 3.0 + progress * 2.0)

	# 아트는 정수배로만 확대한다. 소수배로 줄이면 도트가 뭉개져 바닥 타일보다
	# 고화질처럼 보인다(64px 아트 → 2배 = 128 월드px).
	var art_size := radius * 2.15
	if _texture:
		art_size = float(_texture.get_width()) * maxf(1.0, round(art_size / float(_texture.get_width())))
	var tint := Color(2.1, 2.1, 2.2) if _hit_t > 0.0 else Color(1.0, 0.90 + pulse * 0.10, 0.84)
	if _texture:
		draw_texture_rect(_texture,
			Rect2(Vector2(-art_size * 0.5, -art_size * 0.64), Vector2(art_size, art_size)),
			false, tint)
	else:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-radius, radius * 0.45), Vector2(-radius * 0.35, -radius * 0.7),
			Vector2(radius * 0.45, -radius * 0.65), Vector2(radius, radius * 0.45),
		]), Color(0.34, 0.13, 0.09))
		draw_line(Vector2(0, -radius * 0.45), Vector2(0, radius * 0.55),
			Color(1.0, 0.28, 0.04), 7.0)

	var bar_width := 96.0
	var ratio := clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	var bar_y := -radius - 25.0
	draw_rect(Rect2(-bar_width * 0.5 - 1.0, bar_y - 1.0, bar_width + 2.0, 8.0),
		Color(0.04, 0.03, 0.05, 0.94))
	draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width * ratio, 6.0),
		Color(0.40, 0.86, 1.0))
	# 냉기 약점을 말 없이 읽게 하는 푸른 파쇄 마커.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, bar_y - 8), Vector2(0, bar_y - 15),
		Vector2(6, bar_y - 8), Vector2(0, bar_y - 1),
	]), Color(0.58, 0.90, 1.0, 0.92))
