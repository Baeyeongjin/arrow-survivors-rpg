class_name Breakable
extends Node2D
# 파괴 가능한 맵 오브젝트 (뱀서식 촛대/항아리/상자). 부수면 전리품 분출.

var hp := 30.0
var radius := 16.0
var kind := "barrel"   # barrel / crate / torch / pot
var _flash := 0.0
var _t := 0.0
var _dead := false   # 파괴 처리 1회 보장 (같은 프레임 다중 피격 → 중복 드랍 방지)

func _ready() -> void:
	add_to_group("breakables")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_t = randf() * TAU

func take_damage(d: float, _crit: bool = false) -> void:
	if _dead:
		return
	hp -= d
	_flash = 0.09
	if hp <= 0.0:
		_dead = true
		remove_from_group("breakables")   # 즉시 그룹 제외 → 잔여 화살이 다시 못 때림
		var m := get_parent()
		if m and m.has_method("on_breakable_destroyed"):
			m.on_breakable_destroyed(self)
		queue_free()
		return
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()
	elif kind == "torch" or kind == "coffin":
		queue_redraw()   # 불꽃 일렁임 / 관 반짝임

func _draw() -> void:
	var tex := Assets.tex("res://assets/items/obj_%s.png" % kind)
	if tex:
		if kind == "coffin":
			# 세로로 긴 석관(64×96) — 비율 유지해서 찌그러짐 방지
			var cw := radius * 2.1
			var chh := cw * 1.5
			draw_texture_rect(tex, Rect2(Vector2(-cw / 2.0, -chh * 0.62), Vector2(cw, chh)), false)
		else:
			var w := radius * 2.4
			draw_texture_rect(tex, Rect2(Vector2(-w / 2.0, -w * 0.6), Vector2(w, w)), false)
	else:
		_draw_fallback()
	if _flash > 0.0:
		draw_circle(Vector2(0, -radius * 0.3), radius * 1.1, Color(1, 1, 1, 0.5))

func _draw_fallback() -> void:
	match kind:
		"crate":
			var wood := Color(0.5, 0.35, 0.18)
			draw_rect(Rect2(Vector2(-radius, -radius), Vector2(radius * 2, radius * 2)), wood)
			draw_rect(Rect2(Vector2(-radius, -radius), Vector2(radius * 2, radius * 2)), Color(0.3, 0.2, 0.1), false, 2.0)
			draw_line(Vector2(-radius, -radius), Vector2(radius, radius), Color(0.3, 0.2, 0.1), 2.0)
			draw_line(Vector2(radius, -radius), Vector2(-radius, radius), Color(0.3, 0.2, 0.1), 2.0)
		"pot":
			var clay := Color(0.62, 0.42, 0.3)
			draw_circle(Vector2(0, 0), radius, clay)
			draw_rect(Rect2(Vector2(-radius * 0.6, -radius), Vector2(radius * 1.2, radius * 0.4)), Color(0.45, 0.3, 0.2))
		"torch":
			draw_rect(Rect2(Vector2(-3, -4), Vector2(6, radius + 6)), Color(0.35, 0.24, 0.14))
			var fl := 1.0 + sin(_t * 12.0) * 0.15
			draw_circle(Vector2(0, -radius * 0.5), radius * 0.5 * fl, Color(1.0, 0.55, 0.15, 0.9))
			draw_circle(Vector2(0, -radius * 0.6), radius * 0.28 * fl, Color(1.0, 0.9, 0.4))
		"coffin":
			# 어두운 석관 + 금빛 십자가 (은은한 반짝임 → 눈에 띔)
			var stone := Color(0.32, 0.3, 0.36)
			draw_rect(Rect2(Vector2(-radius * 0.7, -radius), Vector2(radius * 1.4, radius * 2)), stone)
			draw_rect(Rect2(Vector2(-radius * 0.7, -radius), Vector2(radius * 1.4, radius * 2)), Color(0.15, 0.14, 0.18), false, 2.0)
			var glow := 0.6 + sin(_t * 3.0) * 0.4
			var gold := Color(1.0, 0.85, 0.4, glow)
			draw_line(Vector2(0, -radius * 0.5), Vector2(0, radius * 0.55), gold, 3.0)
			draw_line(Vector2(-radius * 0.35, -radius * 0.15), Vector2(radius * 0.35, -radius * 0.15), gold, 3.0)
		_:   # barrel
			var br := Color(0.5, 0.33, 0.17)
			draw_rect(Rect2(Vector2(-radius * 0.85, -radius), Vector2(radius * 1.7, radius * 2)), br)
			draw_rect(Rect2(Vector2(-radius * 0.85, -radius * 0.5), Vector2(radius * 1.7, 3)), Color(0.7, 0.5, 0.25))
			draw_rect(Rect2(Vector2(-radius * 0.85, radius * 0.4), Vector2(radius * 1.7, 3)), Color(0.7, 0.5, 0.25))
