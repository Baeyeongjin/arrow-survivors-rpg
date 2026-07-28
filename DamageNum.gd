class_name DamageNum
extends Node2D
# 위로 떠오르며 사라지는 데미지 숫자

var amount := 0
var crit := false
var kind := ""            # ""=기본 / "weak"=약점 / "resist"=저항
var tint := Color(1, 1, 1)  # 상성 히트 색 (weak=속성색, resist=회색)
var life := 0.7
var _vx := 0.0
static var _font: Font = null

func _ready() -> void:
	_vx = randf_range(-18.0, 18.0)
	if _font == null:
		_font = load("res://assets/fonts/pixel.ttf")
		if _font == null:
			_font = ThemeDB.fallback_font

func _process(delta: float) -> void:
	position.y -= 48.0 * delta
	position.x += _vx * delta
	life -= delta
	if life <= 0.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var t: float = clamp(life / 0.7, 0.0, 1.0)
	var a: float = clamp(t * 1.7, 0.0, 1.0)
	# 뱀서식 가독성: 일반=밝은 노랑, 크릿=주황. 흰색은 밝은 배경에 묻혀서 폐기.
	var col := Color(1.0, 0.55, 0.12, a) if crit else Color(1.0, 0.92, 0.35, a)
	var fs := 26 if crit else 19
	# 상성 히트: 약점은 속성색으로 더 크게(짜릿함), 저항은 회색으로 작게(먹힌 느낌).
	if kind == "weak":
		col = Color(tint.r, tint.g, tint.b, a)
		fs = 32 if crit else 25
	elif kind == "resist":
		col = Color(tint.r, tint.g, tint.b, a)
		fs = 22 if crit else 15
	var s := str(amount)
	# 등장 순간 팝 스케일 (t≈1일 때 1.35배 → 빠르게 1.0) — 뱀서처럼 툭 튀어나옴
	var pop: float = 1.0 + 0.35 * clamp((t - 0.75) / 0.25, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(pop, pop))
	# 8방향 두꺼운 검은 외곽선 → 어떤 배경에서도 선명
	var oc := Color(0, 0, 0, a * 0.95)
	for ox in [-2, 0, 2]:
		for oy in [-2, 0, 2]:
			if ox != 0 or oy != 0:
				draw_string(_font, Vector2(-22 + ox, oy), s, HORIZONTAL_ALIGNMENT_CENTER, 44, fs, oc)
	draw_string(_font, Vector2(-22, 0), s, HORIZONTAL_ALIGNMENT_CENTER, 44, fs, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
