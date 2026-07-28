class_name Pickup
extends Node2D
# 맵에 숨겨진 아이템: 상자/하트/자석/폭탄

var kind := "chest"
var radius := 11.0   # 젬(Gem.GEM_PX)과 겉보기 크기를 맞춤 — 바닥 아이템끼리 통일
var icon_path := ""  # 패시브 랜드마크처럼 kind와 파일명이 다를 때 지정
var item := {}       # kind=="gear"일 때 장비 데이터(slot/rarity/affixes)를 싣는다
var gear_col := Color(1, 1, 1)   # 장비 등급색 (겉보기)
var _t := 0.0
var _taken := false   # 획득 1회 보장 (일시정지 타이밍에 중복 발동 방지)

func _ready() -> void:
	if kind.begins_with("passive:"):
		add_to_group("landmarks")
		radius = 16.0
	else:
		add_to_group("pickups")

func _process(delta: float) -> void:
	_t += delta
	if _taken:
		return
	var pl := get_tree().get_first_node_in_group("player") as Player
	if pl and pl.position.distance_to(position) < radius + pl.radius:
		_taken = true
		if is_in_group("landmarks"):
			remove_from_group("landmarks")
		else:
			remove_from_group("pickups")
		if kind == "gear":
			get_parent()._pickup_gear(item)
		else:
			get_parent().on_pickup(kind)
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	# 멀리서도 보이게 은은한 글로우 + 둥둥 + 좌우 흔들 + 맥동 (젬과 같은 움직임 문법).
	# 위아래만 까딱이면 바닥에 박힌 것처럼 보여 좌우·크기 성분을 섞음.
	var bob := sin(_t * 3.0) * 3.0
	var sway := sin(_t * 1.9) * 1.6
	var pulse: float = 0.93 + 0.07 * sin(_t * 5.0)
	var o := Vector2(sway, bob)
	var gcol := _glow_color()
	draw_circle(o, (radius + 2.0) * pulse, Color(gcol.r, gcol.g, gcol.b, 0.14))

	# 장비: 등급색 다이아몬드 + 흰 테두리 (아이콘 없이 코드로)
	if kind == "gear":
		var d := radius * pulse
		var pts := PackedVector2Array([o + Vector2(0, -d), o + Vector2(d, 0), o + Vector2(0, d), o + Vector2(-d, 0)])
		draw_colored_polygon(pts, gear_col)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(1, 1, 1, 0.9), 1.5)
		return
	var tex := Assets.tex(icon_path if icon_path != "" else "res://assets/items/%s.png" % kind)
	if tex:
		var w: float = Gem.GEM_PX * pulse   # 젬과 같은 크기 기준
		draw_texture_rect(tex, Rect2(o + Vector2(-w / 2.0, -w / 2.0), Vector2(w, w)), false)
		return
	match kind:
		"heart":
			draw_circle(o + Vector2(-5, -3), 6, Color(1, 0.3, 0.4))
			draw_circle(o + Vector2(5, -3), 6, Color(1, 0.3, 0.4))
			draw_colored_polygon(PackedVector2Array([
				o + Vector2(-10, 0), o + Vector2(10, 0), o + Vector2(0, 11)]), Color(1, 0.3, 0.4))
		"chicken":
			# 통닭(로스트 치킨): 노릇한 몸통 + 두 다리 (뱀서 전체회복 상징)
			var meat := Color(0.80, 0.52, 0.24)
			var meat_lt := Color(0.92, 0.66, 0.34)
			draw_circle(o + Vector2(0, 2), 9.5, meat)
			draw_circle(o + Vector2(-2, 0), 5.5, meat_lt)
			# 두 다리(북 스틱)
			for sgn in [-1.0, 1.0]:
				var hip := o + Vector2(sgn * 5.0, -3.0)
				draw_line(hip, hip + Vector2(sgn * 5.0, -7.0), meat, 4.0)
				draw_circle(hip + Vector2(sgn * 5.5, -8.0), 2.8, Color(0.96, 0.92, 0.82))
		"magnet":
			draw_arc(o, 9, PI, TAU, 16, Color(0.7, 0.5, 1.0), 5.0)
			draw_rect(Rect2(o + Vector2(-9, -2), Vector2(4, 8)), Color(0.7, 0.5, 1.0))
			draw_rect(Rect2(o + Vector2(5, -2), Vector2(4, 8)), Color(0.7, 0.5, 1.0))
		"bomb":
			draw_circle(o, 11, Color(0.1, 0.1, 0.12))
			draw_line(o + Vector2(0, -11), o + Vector2(5, -16), Color(1, 0.7, 0.2), 2.0)
		"rosary":
			# 황금 십자가 + 구슬
			var gold := Color(1.0, 0.9, 0.45)
			draw_line(o + Vector2(0, -12), o + Vector2(0, 10), gold, 3.5)
			draw_line(o + Vector2(-7, -4), o + Vector2(7, -4), gold, 3.5)
			draw_circle(o + Vector2(0, 13), 3.0, gold)
		"clock":
			# 오롤로기온: 시안 시계 (테두리 + 바늘)
			var cy := Color(0.6, 0.9, 1.0)
			draw_arc(o, 11, 0.0, TAU, 20, cy, 2.5)
			draw_line(o, o + Vector2(0, -8), cy, 2.0)
			draw_line(o, o + Vector2(6, 2), cy, 2.0)
			draw_circle(o, 2.0, cy)
		_:
			# chest
			draw_rect(Rect2(o + Vector2(-12, -8), Vector2(24, 16)), Color(0.55, 0.35, 0.15))
			draw_rect(Rect2(o + Vector2(-12, -8), Vector2(24, 5)), Color(0.85, 0.65, 0.2))
			draw_rect(Rect2(o + Vector2(-2, -3), Vector2(4, 6)), Color(1, 0.9, 0.4))

func _glow_color() -> Color:
	if kind == "gear":
		return gear_col
	if kind.begins_with("passive:"):
		return Color(0.45, 0.88, 1.0)
	match kind:
		"heart":
			return Color(1, 0.3, 0.4)
		"chicken":
			return Color(1.0, 0.6, 0.35)
		"magnet":
			return Color(0.7, 0.5, 1.0)
		"bomb":
			return Color(1, 0.6, 0.2)
		"rosary":
			return Color(1.0, 0.95, 0.6)
		"clock":
			return Color(0.6, 0.9, 1.0)
		_:
			return Color(1, 0.85, 0.3)
