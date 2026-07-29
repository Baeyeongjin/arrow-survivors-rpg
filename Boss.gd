class_name Boss
extends Node2D

const SPRITE := "res://assets/boss/boss.png"

var key := "boss_1"   # 스테이지별 보스 (boss_1 ~ boss_5)
var max_hp := 1000.0
var hp := 1000.0
var radius := 42.0
var move_speed := 95.0
# VS식 보스: 별도 탄막 없이 플레이어를 지속 추격하는 엘리트형 적.
# Main.gd의 옛 패턴 함수는 도전 모드용 참고 코드로만 남겨두고 호출하지 않는다.
var _anim_t := 0.0
var _atk_t := 0.0
var _atk_play := 0.0   # >0이면 공격 애니 재생 중
var is_reaper := false  # 사신 피날레 보스 (특별 연출)
var weak := ""          # 약점 속성 (×1.5). 던전 보스는 던전 테마 속성에 약함 (Phase 2에서 세팅)
var resist := ""        # 저항 속성 (×0.6)
# 텔레그래프: 특수공격 전 예비동작(경고). 이 시간 동안 정지+붉게 충전 후 발사.
const TELE_DUR := 0.85
var _tele_t := 0.0
var _dmg_accum := 0.0   # 지속피해 누적 (0 표시 방지)
var _dmg_flush := 0.0

# M3 지옥 최종 보스: 예고 공격 → 화염 갑옷 파괴 → 짧은 딜타임의 반복 구조.
const HELL_ARMOR_THRESHOLDS := [0.70, 0.35]
const HELL_VULNERABLE_TIME := 5.0
const HELL_SLAM_RADIUS := 178.0
enum HellState { CHASE, SLAM_WINDUP, CHARGE_WINDUP, CHARGE, VOLLEY_WINDUP, RECOVERY, STUNNED }

var hell_final := false
var hell_phase := 1
var armor_max := 0.0
var armor_hp := 0.0
var vulnerable_t := 0.0
var attack_damage := 28.0
var unsealed_fissures := 0

var _hell_state: int = HellState.CHASE
var _hell_t := 1.25
var _hell_attack_index := 0
var _hell_lock_dir := Vector2.DOWN
var _hell_charge_hit := false
var _hell_armor_index := 0

func _ready() -> void:
	add_to_group("boss")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func configure_hell_final(unsealed: int) -> void:
	hell_final = true
	unsealed_fissures = maxi(0, unsealed)
	weak = "ice"
	resist = "fire"
	hell_phase = 1
	armor_max = 0.0
	armor_hp = 0.0
	vulnerable_t = 0.0
	_hell_state = HellState.CHASE
	_hell_t = 2.45   # 등장 배너가 사라진 뒤 첫 패턴을 시작한다.
	_hell_attack_index = 0
	_hell_armor_index = 0


func uses_pattern_damage() -> bool:
	return hell_final


func hell_armor_element_multiplier(element: String) -> float:
	match element:
		"ice":
			return 2.5
		"fire":
			return 0.25
		"dark":
			return 0.80
	return 1.0


func _process(delta: float) -> void:
	_anim_t += delta
	var pl := get_tree().get_first_node_in_group("player") as Player
	if pl:
		if hell_final:
			_process_hell(delta, pl)
		else:
			var to: Vector2 = pl.position - position
			# 일반 보스는 기존 추격형 동작을 보존한다. 지옥 보스만 패턴 전투를 사용한다.
			if to.length() > 8.0:
				var main := get_parent()
				if main and main.has_method("stage_enemy_step"):
					position = main.stage_enemy_step(position, pl.position, move_speed * delta, radius)
				else:
					position += to.normalized() * move_speed * delta
				_atk_play = max(_atk_play, 0.5)   # 이동/접근 모션 유지
	if _atk_play > 0.0:
		_atk_play -= delta
		_atk_t += delta
	# 지속피해 누적 표시 (0.35초마다 합산 — 오라·회전검 딜 가시화, "0" 표시 방지)
	if _dmg_accum > 0.0:
		_dmg_flush += delta
		if _dmg_flush >= 0.35:
			var mm := get_parent()
			if mm and mm.has_method("_spawn_dmg_num") and _dmg_accum >= 1.0:
				mm._spawn_dmg_num(position + Vector2(0, -radius * 0.5), int(round(_dmg_accum)), true)
				_dmg_accum = 0.0
			_dmg_flush = 0.0
	queue_redraw()


func _process_hell(delta: float, pl: Player) -> void:
	var main := get_parent()
	if _hell_state == HellState.STUNNED:
		vulnerable_t = maxf(0.0, vulnerable_t - delta)
		if vulnerable_t <= 0.0:
			_hell_state = HellState.CHASE
			_hell_t = maxf(0.72, 1.32 - hell_phase * 0.16)
		return

	_hell_t -= delta
	match _hell_state:
		HellState.CHASE:
			var desired_distance := 126.0
			if position.distance_to(pl.position) > desired_distance:
				if main and main.has_method("stage_enemy_step"):
					position = main.stage_enemy_step(position, pl.position,
						move_speed * (1.0 + (hell_phase - 1) * 0.10) * delta, radius)
				else:
					position = position.move_toward(pl.position, move_speed * delta)
				_atk_play = maxf(_atk_play, 0.35)
			if _hell_t <= 0.0:
				_start_next_hell_attack(pl)
		HellState.SLAM_WINDUP:
			_atk_play = maxf(_atk_play, 0.25)
			if _hell_t <= 0.0:
				if main and main.has_method("hell_boss_slam"):
					main.hell_boss_slam(position, HELL_SLAM_RADIUS + (hell_phase - 1) * 16.0,
						attack_damage * (1.0 + (hell_phase - 1) * 0.14))
				_hell_state = HellState.RECOVERY
				_hell_t = 0.62
				_atk_play = 0.55
				_atk_t = 0.0
		HellState.CHARGE_WINDUP:
			_atk_play = maxf(_atk_play, 0.25)
			if _hell_t <= 0.0:
				_hell_state = HellState.CHARGE
				_hell_t = 0.50
				_hell_charge_hit = false
		HellState.CHARGE:
			var charge_speed := 440.0 + (hell_phase - 1) * 55.0
			var target := position + _hell_lock_dir * 900.0
			if main and main.has_method("stage_enemy_step"):
				position = main.stage_enemy_step(position, target, charge_speed * delta, radius)
			else:
				position += _hell_lock_dir * charge_speed * delta
			_atk_play = maxf(_atk_play, 0.28)
			if not _hell_charge_hit and position.distance_to(pl.position) <= radius + pl.radius + 10.0:
				_hell_charge_hit = true
				if main and main.has_method("apply_hell_boss_damage"):
					main.apply_hell_boss_damage(attack_damage * 1.15, position)
			if _hell_t <= 0.0:
				_hell_state = HellState.RECOVERY
				_hell_t = 0.52
		HellState.VOLLEY_WINDUP:
			_atk_play = maxf(_atk_play, 0.25)
			if _hell_t <= 0.0:
				if main and main.has_method("spawn_hell_boss_volley"):
					main.spawn_hell_boss_volley(position, 10 + (hell_phase - 1) * 2,
						attack_damage * 0.62)
				_hell_state = HellState.RECOVERY
				_hell_t = 0.72
				_atk_play = 0.5
				_atk_t = 0.0
		HellState.RECOVERY:
			if _hell_t <= 0.0:
				_hell_state = HellState.CHASE
				_hell_t = maxf(0.72, 1.38 - hell_phase * 0.16)


func _start_next_hell_attack(pl: Player) -> void:
	var pattern := _hell_attack_index % 3
	_hell_attack_index += 1
	match pattern:
		0:
			_hell_state = HellState.SLAM_WINDUP
			_hell_t = maxf(0.64, 0.92 - (hell_phase - 1) * 0.08)
		1:
			_hell_lock_dir = (pl.position - position).normalized()
			if _hell_lock_dir == Vector2.ZERO:
				_hell_lock_dir = Vector2.DOWN
			_hell_state = HellState.CHARGE_WINDUP
			_hell_t = maxf(0.58, 0.82 - (hell_phase - 1) * 0.07)
		_:
			_hell_state = HellState.VOLLEY_WINDUP
			_hell_t = maxf(0.62, 0.86 - (hell_phase - 1) * 0.06)

func take_damage(d: float, _crit: bool = true, element: String = "") -> void:
	var m := get_parent()
	# 상성: 공격 속성 미지정이면 플레이어 공격 속성 사용. 약점 ×1.5 / 저항 ×0.6.
	var elem := element
	if elem == "" and m and "attack_element" in m:
		elem = str(m.attack_element)
	# 화염 군주의 갑옷은 체력과 별도다. 냉기는 빠르게 파괴하고 화염은 거의 통하지 않는다.
	# 전용 무기 어픽스는 이 파괴량에만 적용해 일반 DPS 영구 누적을 만들지 않는다.
	if hell_final and armor_hp > 0.0:
		var armor_damage := d * hell_armor_element_multiplier(elem)
		if m and m.has_method("_hell_objective_damage_multiplier"):
			armor_damage *= float(m._hell_objective_damage_multiplier())
		var actual_armor_damage := minf(armor_hp, maxf(0.0, armor_damage))
		armor_hp -= armor_damage
		if m and m.has_method("record_damage_dealt"):
			m.record_damage_dealt(actual_armor_damage)
		if m and m.has_method("_spawn_dmg_num"):
			var armor_kind := "weak" if elem == "ice" else ("resist" if elem == "fire" else "")
			m._spawn_dmg_num(position + Vector2(0, -radius * 0.5),
				maxi(1, int(round(armor_damage))), _crit, armor_kind, elem)
		if armor_hp <= 0.0:
			_break_hell_armor()
		queue_redraw()
		return
	var hit_kind := ""
	if elem != "" and elem != "phys":
		if elem == weak:
			d *= 1.5
			hit_kind = "weak"
		elif elem == resist:
			d *= 0.6
			hit_kind = "resist"
	if hell_final and vulnerable_t > 0.0:
		d *= 1.70

	# 70%와 35%에서 체력을 정확히 멈춰 갑옷 파괴 국면을 건너뛰는 원샷을 막는다.
	if hell_final and _hell_armor_index < HELL_ARMOR_THRESHOLDS.size():
		var threshold_hp := max_hp * float(HELL_ARMOR_THRESHOLDS[_hell_armor_index])
		if hp > threshold_hp and hp - d <= threshold_hp:
			d = maxf(0.0, hp - threshold_hp)
	var actual_damage := minf(maxf(0.0, hp), maxf(0.0, d))
	if m and m.has_method("record_damage_dealt"):
		m.record_damage_dealt(actual_damage)
	hp -= d
	if m and m.has_method("_spawn_dmg_num"):
		if d >= 1.0:
			m._spawn_dmg_num(position + Vector2(0, -radius * 0.5), max(1, int(round(d))), true, hit_kind, elem)
		else:
			_dmg_accum += d   # 지속피해(오라·회전검 등)는 누적 후 주기 표시
	if hell_final and _hell_armor_index < HELL_ARMOR_THRESHOLDS.size():
		var reached_threshold := max_hp * float(HELL_ARMOR_THRESHOLDS[_hell_armor_index])
		if hp <= reached_threshold + 0.01:
			hp = reached_threshold
			_start_hell_armor()
			queue_redraw()
			return
	if hp <= 0:
		if m and m.has_method("on_boss_killed"):
			m.on_boss_killed()
		queue_free()


func _start_hell_armor() -> void:
	_hell_armor_index += 1
	hell_phase = _hell_armor_index + 1
	var cycle_bonus := float(_hell_armor_index - 1) * 0.04
	armor_max = max_hp * (0.15 + cycle_bonus + float(unsealed_fissures) * 0.035)
	armor_hp = armor_max
	vulnerable_t = 0.0
	_hell_state = HellState.CHASE
	_hell_t = 2.30   # 갑옷 안내 배너 아래에서 즉시 공격하지 않는다.
	var main := get_parent()
	if main and main.has_method("on_hell_boss_armor_started"):
		main.on_hell_boss_armor_started(_hell_armor_index, armor_max)


func _break_hell_armor() -> void:
	armor_hp = 0.0
	vulnerable_t = HELL_VULNERABLE_TIME
	_hell_state = HellState.STUNNED
	_hell_t = vulnerable_t
	var main := get_parent()
	if main and main.has_method("on_hell_boss_armor_broken"):
		main.on_hell_boss_armor_broken(vulnerable_t)

func _draw() -> void:
	if hell_final:
		_draw_hell_warning()
	var tex: Texture2D = null
	if _atk_play > 0.0:
		var fa: Array = Assets.frames("res://assets/anim/%s_attack" % key)
		if fa.size() > 0:
			tex = fa[int(_atk_t * 11.0) % fa.size()]
	if tex == null:
		var fw: Array = Assets.frames("res://assets/anim/%s_walk" % key)
		if fw.is_empty():
			fw = Assets.frames("res://assets/anim/boss_walk")
		if fw.size() > 0:
			tex = fw[int(_anim_t * 9.0) % fw.size()]
	if tex == null:
		tex = Assets.tex("res://assets/boss/%s.png" % key)
	if tex == null:
		tex = Assets.tex(SPRITE)
	# 텔레그래프 경고: 특수공격 예비동작 동안 붉은 링이 수축하며 조준 완성 (플레이어에게 회피 시간)
	if _tele_t > 0.0:
		var p: float = clamp(1.0 - _tele_t / TELE_DUR, 0.0, 1.0)   # 0→1 충전
		var pulse: float = 0.5 + 0.5 * sin(_tele_t * 34.0)
		# 바닥 경고 원(옅게 채움) — 위험 범위 암시
		draw_circle(Vector2.ZERO, radius * 3.0, Color(1.0, 0.2, 0.15, 0.08 + 0.14 * p))
		# 수축하는 조준 링
		var rr: float = radius * (3.2 - 1.8 * p)
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 44, Color(1.0, 0.3, 0.22, 0.4 + 0.45 * p), 4.0 + 4.0 * p)
		# 완성 직전 번쩍이는 내측 링
		if p > 0.55:
			draw_arc(Vector2.ZERO, radius * 1.15, 0.0, TAU, 40, Color(1.0, 0.85, 0.4, 0.5 * pulse), 3.0)
	if tex:
		var w := radius * 2.6
		var tint := Color(0.55, 0.5, 0.7) if is_reaper else Color(1, 1, 1)   # 사신: 어둡게
		if hell_final and armor_hp > 0.0:
			tint = Color(1.35, 0.72, 0.34)
		elif hell_final and vulnerable_t > 0.0:
			tint = Color(0.62, 0.88, 1.18)
		# 충전 중엔 붉게 달아오름 (맥동)
		if _tele_t > 0.0:
			var tp: float = clamp(1.0 - _tele_t / TELE_DUR, 0.0, 1.0)
			var glow: float = 0.5 + 0.5 * sin(_tele_t * 34.0)
			tint = tint.lerp(Color(1.9, 0.55, 0.4), 0.35 + 0.35 * tp * glow)
		draw_texture_rect(tex, Rect2(Vector2(-w / 2.0, -w / 2.0), Vector2(w, w)), false, tint)
	elif is_reaper:
		# 사신 폴백: 검은 후드 형상 + 붉은 눈 + 낫
		draw_circle(Vector2(0, 4), radius, Color(0.08, 0.06, 0.12))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-radius * 0.9, radius), Vector2(0, -radius * 1.2), Vector2(radius * 0.9, radius)]),
			Color(0.05, 0.04, 0.09))
		draw_circle(Vector2(-radius * 0.28, -radius * 0.1), 6, Color(1.0, 0.15, 0.15))
		draw_circle(Vector2(radius * 0.28, -radius * 0.1), 6, Color(1.0, 0.15, 0.15))
		draw_line(Vector2(radius * 0.7, -radius), Vector2(radius * 1.1, radius), Color(0.7, 0.7, 0.75), 4.0)
		draw_arc(Vector2(radius * 1.0, -radius), radius * 0.5, -1.2, 0.6, 12, Color(0.85, 0.85, 0.9), 4.0)
	else:
		draw_circle(Vector2.ZERO, radius, Color(0.8, 0.2, 0.35))
		draw_circle(Vector2.ZERO, radius * 0.7, Color(0.95, 0.4, 0.5))
		draw_circle(Vector2(-20, -10), 7, Color.BLACK)
		draw_circle(Vector2(20, -10), 7, Color.BLACK)

	var w2 := 120.0
	var ratio: float = clamp(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(Vector2(-w2 / 2.0, -radius - 22), Vector2(w2, 9)), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(Vector2(-w2 / 2.0, -radius - 22), Vector2(w2 * ratio, 9)), Color(1.0, 0.3, 0.3))
	if hell_final and armor_max > 0.0 and armor_hp > 0.0:
		var armor_ratio := clampf(armor_hp / armor_max, 0.0, 1.0)
		draw_rect(Rect2(Vector2(-w2 / 2.0, -radius - 34), Vector2(w2, 7)),
			Color(0.08, 0.05, 0.04, 0.94))
		draw_rect(Rect2(Vector2(-w2 / 2.0, -radius - 34), Vector2(w2 * armor_ratio, 7)),
			Color(1.0, 0.56, 0.12))
		# 갑옷 바 왼쪽의 냉기 파쇄 표식.
		draw_colored_polygon(PackedVector2Array([
			Vector2(-w2 * 0.5 - 12.0, -radius - 31.0),
			Vector2(-w2 * 0.5 - 6.0, -radius - 38.0),
			Vector2(-w2 * 0.5, -radius - 31.0),
			Vector2(-w2 * 0.5 - 6.0, -radius - 24.0),
		]), Color(0.55, 0.90, 1.0))


func _draw_hell_warning() -> void:
	var danger := Color(1.0, 0.18, 0.06)
	match _hell_state:
		HellState.SLAM_WINDUP:
			var duration := maxf(0.64, 0.92 - (hell_phase - 1) * 0.08)
			var progress := clampf(1.0 - _hell_t / duration, 0.0, 1.0)
			var rr := HELL_SLAM_RADIUS + (hell_phase - 1) * 16.0
			draw_circle(Vector2.ZERO, rr, Color(danger.r, danger.g, danger.b, 0.06 + progress * 0.10))
			draw_arc(Vector2.ZERO, lerpf(rr * 1.35, rr, progress), 0.0, TAU, 48,
				Color(1.0, 0.58, 0.16, 0.42 + progress * 0.48), 4.0 + progress * 2.0)
		HellState.CHARGE_WINDUP:
			var duration := maxf(0.58, 0.82 - (hell_phase - 1) * 0.07)
			var progress := clampf(1.0 - _hell_t / duration, 0.0, 1.0)
			var length := 360.0
			var side := _hell_lock_dir.orthogonal() * (radius + 14.0)
			var end := _hell_lock_dir * length
			var lane := PackedVector2Array([-side, side, end + side, end - side])
			draw_colored_polygon(lane, Color(danger.r, danger.g, danger.b, 0.06 + progress * 0.12))
			draw_line(-side, end - side, Color(1.0, 0.42, 0.10, 0.50 + progress * 0.40), 3.0)
			draw_line(side, end + side, Color(1.0, 0.42, 0.10, 0.50 + progress * 0.40), 3.0)
		HellState.VOLLEY_WINDUP:
			var duration := maxf(0.62, 0.86 - (hell_phase - 1) * 0.06)
			var progress := clampf(1.0 - _hell_t / duration, 0.0, 1.0)
			var count := 10 + (hell_phase - 1) * 2
			for i in count:
				var dir := Vector2.from_angle(TAU * float(i) / float(count))
				draw_line(dir * (radius + 6.0), dir * (94.0 + progress * 38.0),
					Color(1.0, 0.55, 0.14, 0.25 + progress * 0.55), 2.0)
	if armor_hp > 0.0:
		var pulse := 0.5 + 0.5 * sin(_anim_t * 8.0)
		draw_circle(Vector2.ZERO, radius * 1.48, Color(1.0, 0.30, 0.04, 0.08 + pulse * 0.06))
		draw_arc(Vector2.ZERO, radius * 1.48, 0.0, TAU, 44,
			Color(1.0, 0.58, 0.12, 0.60 + pulse * 0.26), 4.0)
	elif vulnerable_t > 0.0:
		var pulse := 0.5 + 0.5 * sin(_anim_t * 10.0)
		draw_arc(Vector2.ZERO, radius * (1.30 + pulse * 0.10), 0.0, TAU, 40,
			Color(0.55, 0.92, 1.0, 0.70), 4.0)
		for i in 6:
			var a := TAU * float(i) / 6.0 + _anim_t * 0.35
			draw_line(Vector2.from_angle(a) * radius * 0.72,
				Vector2.from_angle(a + 0.15) * radius * 1.15,
				Color(0.78, 0.96, 1.0, 0.82), 2.0)
