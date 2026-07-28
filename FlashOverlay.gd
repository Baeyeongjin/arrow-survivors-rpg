class_name FlashOverlay
extends Control
# 전체 화면 플래시 (레벨업·진화 순간 연출). 스스로 페이드 — 일시정지 중에도 동작.

var _col := Color(1, 1, 1, 0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200


func flash(c: Color) -> void:
	_col = c
	queue_redraw()


func _process(delta: float) -> void:
	if _col.a > 0.0:
		_col.a = max(0.0, _col.a - delta * 3.2)
		queue_redraw()


func _draw() -> void:
	if _col.a > 0.0:
		var vs: Vector2 = size if size != Vector2.ZERO else get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, vs), _col)
