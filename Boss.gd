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
# 텔레그래프: 특수공격 전 예비동작(경고). 이 시간 동안 정지+붉게 충전 후 발사.
const TELE_DUR := 0.85
var _tele_t := 0.0
var _dmg_accum := 0.0   # 지속피해 누적 (0 표시 방지)
var _dmg_flush := 0.0

func _ready() -> void:
	add_to_group("boss")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	_anim_t += delta
	var pl := get_tree().get_first_node_in_group("player") as Player
	if pl:
		var to: Vector2 = pl.position - position
		# 뱀서식: 패턴/포탄 없음 — 크고 단단한 추격자. 끈질기게 붙어 접촉으로 압박.
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

func take_damage(d: float, _crit: bool = true) -> void:
	var m := get_parent()
	var actual_damage := minf(maxf(0.0, hp), maxf(0.0, d))
	if m and m.has_method("record_damage_dealt"):
		m.record_damage_dealt(actual_damage)
	hp -= d
	if m and m.has_method("_spawn_dmg_num"):
		if d >= 1.0:
			m._spawn_dmg_num(position + Vector2(0, -radius * 0.5), max(1, int(round(d))), true)
		else:
			_dmg_accum += d   # 지속피해(오라·회전검 등)는 누적 후 주기 표시
	if hp <= 0:
		m.on_boss_killed()
		queue_free()

func _draw() -> void:
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
