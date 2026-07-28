class_name SkyStrike
extends Node2D
# 하늘에서 떨어져 착탄하는 투사체 (메테오 / 화살비)
# 착탄 지점 마커를 먼저 보여주고, 낙하 후 폭발 피해

var target := Vector2.ZERO
var fall_time := 0.4
var dmg := 20.0
var radius := 45.0
var col := Color(1.0, 0.6, 0.2)
var sprite_path := ""     # 있으면 회전된 스프라이트로 낙하
var big := false          # true면 착탄 시 화면 흔들림
var fx_name := "fx_explosion"   # 착탄 이펙트 애니 이름
# 번개(연쇄뇌전)처럼 착탄 애니만 원하면 false — 경고 링/버스트/원 테두리를 끈다.
# 별똥별·천벌은 낙하가 길어 경고 링이 예고 기능을 하므로 기본 true 유지.
var show_ring := true
# 착탄 시 코드 지그재그 낙뢰를 그림 (번개 계열 전용).
# fx_lightning/fx_thunder 아트가 번개가 아니라 '회색 기둥'으로 보여 폐기하고 코드로 대체.
var bolt_fx := false
# 착탄 시 스폰할 코드 이펙트 kind (예: "moonbeam" — 월광 달빛 기둥). 빈 문자열이면 없음.
var impact_kind := ""
# 낙하체(점·선)를 그리지 않음 — 월광처럼 '하늘에서 빛이 내리쬐는' 연출용.
var hide_fall := false
# 낙하 전 착탄 예고 원만 끔 (착탄 버스트/링은 유지) — 별똥별·천벌 (사장님 결정: 예고 원 제거)
var show_warn := true
var _t := 0.0
var _start := Vector2.ZERO
var _done := false

var _vis := 1.0   # 무기 성장 시각 배율 (착탄이 비동기라 생성 시점에 캡처)

func _ready() -> void:
	_start = target + Vector2(70, -300)
	position = _start
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var p := get_parent()
	if p and "wfx_boost" in p:
		_vis = clampf(float(p.wfx_boost), 1.0, 1.8)

func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var k: float = min(1.0, _t / fall_time)
	position = _start.lerp(target, k * k)   # 가속 낙하
	if _t >= fall_time:
		_done = true
		var main = get_parent()
		if main and main.has_method("_explode"):
			main._explode(target, radius, dmg, null)
			if main.has_method("spawn_fx"):
				main.spawn_fx(fx_name, target, radius * 2.2 * _vis)
			if impact_kind != "":
				var ik := Effect.new()
				ik.kind = impact_kind
				ik.position = target
				ik.rad = radius
				ik.col = col
				ik.life = 0.6    # 부드러운 인/아웃 이징이 보이게 넉넉히
				ik.max_life = 0.6
				main.add_child(ik)
			if bolt_fx:
				var bolt := Effect.new()
				bolt.kind = "bolt"
				bolt.position = target
				bolt.from_global = target + Vector2(40, -340)   # 화면 위에서 내리꽂힘
				bolt.col = col
				bolt.life = 0.22
				bolt.max_life = 0.22
				main.add_child(bolt)
			if show_ring:
				var fx := Effect.new()
				fx.kind = "burst"
				fx.position = target
				fx.col = col
				fx.life = 0.35
				fx.max_life = 0.35
				main.add_child(fx)
				var ring := Effect.new()
				ring.kind = "ring"
				ring.position = target
				ring.rad = radius
				ring.col = col
				ring.life = 0.3
				ring.max_life = 0.3
				main.add_child(ring)
			if big:
				main.shake_t = max(main.shake_t, 0.15)
				main.play_sfx("ult", -14.0, 0.1)
			else:
				main.play_sfx("hit", -14.0, 0.05)
		queue_free()
	queue_redraw()

func _draw() -> void:
	if hide_fall:
		return   # 월광 등: 낙하체 없이 착탄 이펙트(impact_kind)만
	# 착탄 지점 마커 (경고 링) — show_ring=false(번개)·show_warn=false(별똥별·천벌)는 생략
	if show_ring and show_warn:
		var to_target := target - position
		draw_arc(to_target, radius * 0.9, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.5), 2.0)
		draw_circle(to_target, 3.0, Color(col.r, col.g, col.b, 0.7))
	# 낙하체
	var dir := (target - _start).normalized()
	var tex := Assets.tex(sprite_path)
	if tex:
		draw_set_transform(Vector2.ZERO, dir.angle() + PI / 2.0, Vector2.ONE)
		var w := 26.0 if not big else 40.0
		draw_texture_rect(tex, Rect2(Vector2(-w / 2.0, -w / 2.0), Vector2(w, w)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var r := 10.0 if big else 5.0
		draw_circle(Vector2.ZERO, r, col)
		draw_line(Vector2.ZERO, -dir * (26.0 if big else 14.0), Color(col.r, col.g, col.b, 0.6), 3.0)
