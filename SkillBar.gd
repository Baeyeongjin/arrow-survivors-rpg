class_name SkillBar
extends Control

# Q/E/R/F 스킬바. 아이콘 + 쿨다운을 한눈에 보여 준다.
#
# 텍스트 한 줄로는 전투 중에 "지금 뭘 쓸 수 있나"가 안 읽힌다(사장님 요청).
# 슬롯은 항상 같은 자리에 4칸 고정이다 — 빈 칸도 자리를 지킨다. 위치가 흔들리면
# 눈으로 못 찾는다.
#
# 쿨다운은 두 가지로 동시에 보여 준다:
#   1) 아래에서 차오르는 어두운 덮개 — 곁눈질로 "얼마나 남았나"
#   2) 남은 초 숫자 — 정확히 언제 쓸 수 있나
# 색만으로 알리지 않는다.

const SLOT := 46.0
const GAP := 8.0
const ICON_PAD := 5.0

# Main이 매 프레임 채운다. [{key, name, icon, cd, cd_max, ready}]
var slots: Array = []
# 회피는 스킬은 아니지만 같은 리듬으로 쓰는 자원이라 끝에 붙인다.
var dodge_cd := 0.0
var dodge_max := 1.0

var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func bar_width() -> float:
	return float(slots.size() + 1) * (SLOT + GAP) - GAP


func _draw() -> void:
	var x := 0.0
	for entry in slots:
		_draw_slot(x, entry as Dictionary)
		x += SLOT + GAP
	_draw_dodge(x)


func _draw_slot(x: float, entry: Dictionary) -> void:
	var rect := Rect2(x, 0.0, SLOT, SLOT)
	var filled := str(entry.get("name", "")) != ""
	# 바탕: 빈 칸은 더 어둡게 해 "아직 안 배웠다"가 바로 읽히게 한다.
	draw_rect(rect, Color(0.06, 0.05, 0.09, 0.86 if filled else 0.55))
	if not filled:
		draw_rect(rect, Color(0.30, 0.28, 0.36, 0.7), false, 1.0)
		_key_label(x, str(entry.get("key", "")), Color(0.45, 0.43, 0.52))
		return

	var icon: Texture2D = entry.get("icon", null)
	if icon:
		# 원본 크기 그대로 가운데에. 아이콘은 32px로 만들어 뒀고 슬롯은 46px이라
		# 여백이 남는데, 슬롯에 맞춰 늘리면 정수배가 아니라 픽셀이 어긋난다.
		var isz := icon.get_size()
		draw_texture(icon, Vector2(x + (SLOT - isz.x) * 0.5, (SLOT - isz.y) * 0.5))

	var cd := float(entry.get("cd", 0.0))
	var cd_max := maxf(0.001, float(entry.get("cd_max", 1.0)))
	if cd > 0.0:
		# 아래에서 차오르는 덮개. 남은 비율만큼 가린다.
		var ratio := clampf(cd / cd_max, 0.0, 1.0)
		draw_rect(Rect2(x, SLOT * (1.0 - ratio), SLOT, SLOT * ratio),
			Color(0.02, 0.02, 0.05, 0.72))
		var secs := "%.1f" % cd if cd < 10.0 else "%d" % int(ceil(cd))
		var w := _font.get_string_size(secs, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(_font, Vector2(x + (SLOT - w) * 0.5, SLOT * 0.62), secs,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.94, 0.72))
	elif bool(entry.get("primed", false)):
		# 터뜨릴 대상이 사거리 안에 있다. 준비됨보다 한 단계 더 밝게 + 두껍게 —
		# 이 신호가 없으면 플레이어가 콤보의 존재 자체를 모른 채 쿨마다 누르게 된다.
		draw_rect(rect, Color(1.0, 0.42, 0.30, 0.30))
		draw_rect(rect, Color(1.0, 0.55, 0.35, 1.0), false, 3.0)
	else:
		# 준비됨: 테두리를 밝혀 알린다.
		draw_rect(rect, Color(0.95, 0.86, 0.48, 0.85), false, 2.0)

	_key_label(x, str(entry.get("key", "")), Color(0.95, 0.93, 1.0))


func _key_label(x: float, key: String, col: Color) -> void:
	if key == "":
		return
	draw_rect(Rect2(x, 0.0, 15.0, 14.0), Color(0.04, 0.03, 0.07, 0.9))
	draw_string(_font, Vector2(x + 3.0, 11.0), key,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


func _draw_dodge(x: float) -> void:
	var rect := Rect2(x, 0.0, SLOT, SLOT)
	draw_rect(rect, Color(0.06, 0.05, 0.09, 0.86))
	if dodge_cd > 0.0:
		var ratio := clampf(dodge_cd / maxf(0.001, dodge_max), 0.0, 1.0)
		draw_rect(Rect2(x, SLOT * (1.0 - ratio), SLOT, SLOT * ratio),
			Color(0.02, 0.02, 0.05, 0.72))
	else:
		draw_rect(rect, Color(0.45, 0.85, 1.0, 0.8), false, 2.0)
	# 회피는 아이콘 대신 화살표 두 개로 "치고 빠진다"를 그린다.
	var cx := x + SLOT * 0.5
	var cy := SLOT * 0.56
	var col := Color(0.62, 0.92, 1.0) if dodge_cd <= 0.0 else Color(0.38, 0.52, 0.62)
	for i in 2:
		var ox := cx - 9.0 + float(i) * 9.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(ox - 4.0, cy - 6.0), Vector2(ox + 4.0, cy), Vector2(ox - 4.0, cy + 6.0),
		]), col)
	_key_label(x, "SPC", Color(0.72, 0.92, 1.0))
