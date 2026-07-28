class_name Gem
extends Node2D
# 경험치 젬: 자석 범위 안에 들어오면 플레이어에게 빨려감

# 젬 스프라이트 표시 크기 (등급 배수 _tier_scale이 여기에 곱해짐).
# 필드 아이템(Pickup)이 이 값에 크기를 맞춘다 — 바닥에 깔리는 것들끼리 통일.
const GEM_PX := 23.0   # 18 → 23 (+30%): 너무 작아 안 보였음

var value := 1
var radius := 7.0
var _pl: Player = null
var _t := 0.0
var _mag := 0.0   # 자석 흡입 램프 (0→1): 가속·발광 강도

func _ready() -> void:
	add_to_group("gems")
	_t = randf() * 6.28   # 젬마다 둥둥 위상 다르게 (군집이 물결처럼)

func _process(delta: float) -> void:
	_t += delta
	if _pl == null or not is_instance_valid(_pl):
		_pl = get_tree().get_first_node_in_group("player") as Player
	var pl := _pl
	if pl == null:
		return
	var to: Vector2 = pl.position - position
	var dist := to.length()
	if dist < 16.0:
		get_parent().collect_gem(value)
		queue_free()
		return
	if dist < pl.current_pickup_radius():
		# 자석: 시간이 갈수록 가속(진공청소기 흡입감)
		_mag = min(1.0, _mag + delta * 3.2)
		var spd: float = lerp(210.0, 760.0, _mag)
		position += to.normalized() * spd * delta
	else:
		_mag = max(0.0, _mag - delta * 2.5)
	queue_redraw()

# 뱀서식 XP 젬 등급: 값이 클수록 파랑<초록<빨강<금 — 멀리서도 "큰 젬!"이 보이게.
func _tier_color() -> Color:
	if value >= 30:
		return Color(1.0, 0.82, 0.30)   # 금 (대박 — 병합 젬/엘리트)
	elif value >= 12:
		return Color(1.0, 0.45, 0.45)   # 빨강 (큼)
	elif value >= 5:
		return Color(0.5, 1.0, 0.55)    # 초록 (중간)
	return Color(0.5, 0.9, 1.0)         # 파랑 (기본)

# 등급별 크기 배수 (상위 등급일수록 살짝 큼 → 시각적 도파민)
func _tier_scale() -> float:
	if value >= 30:
		return 1.5
	elif value >= 12:
		return 1.3
	elif value >= 5:
		return 1.14
	return 1.0

func _draw() -> void:
	# 흡입 중엔 둥둥 멈추고 발광, 대기 중엔 둥둥 + 좌우 흔들 + 맥동.
	# 위아래만 까딱이면 바닥에 박힌 것처럼 보여 좌우 성분을 섞음.
	var bob: float = sin(_t * 4.0) * 3.0 * (1.0 - _mag)
	var sway: float = sin(_t * 2.3) * 1.4 * (1.0 - _mag)
	var pulse: float = 0.88 + 0.12 * sin(_t * 6.0)
	var o := Vector2(sway, bob)
	var gc := _tier_color()
	var ts := _tier_scale()
	# 뒤 글로우 (흡입 시 확대·밝아짐, 등급 클수록 큼)
	var gr: float = (radius + 5.0) * pulse * ts * (1.0 + _mag * 0.6)
	draw_circle(o, gr, Color(gc.r, gc.g, gc.b, 0.16 + 0.28 * _mag))
	var s: float = ts * (1.0 + _mag * 0.35) * pulse
	var tex := Assets.tex("res://assets/items/gem.png")
	if tex:
		var w: float = GEM_PX * s
		# 텍스처를 등급 색으로 물들임 (흡입 시 하얗게 발광)
		var tint := gc.lerp(Color(1.7, 1.7, 2.0), _mag)
		draw_texture_rect(tex, Rect2(o + Vector2(-w / 2.0, -w / 2.0), Vector2(w, w)), false, tint)
		return
	# 작은 마름모 보석 (폴백)
	var r := radius * s
	var pts := PackedVector2Array([
		o + Vector2(0, -r), o + Vector2(r, 0), o + Vector2(0, r), o + Vector2(-r, 0)])
	draw_colored_polygon(pts, gc.lerp(Color(1, 1, 1), _mag * 0.5))
	draw_circle(o, 2.0, Color(1, 1, 1))
