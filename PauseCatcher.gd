class_name PauseCatcher
extends Node
# 일시정지 중에도 키 입력을 받기 위한 노드.
# 타이틀/일시정지 화면은 get_tree().paused = true 라서 Main의 _unhandled_input이
# 호출되지 않는다 — ESC와 치트 키는 여기(PROCESS_MODE_ALWAYS)서 받아 시그널로 넘긴다.

signal esc_pressed
signal cheat_key(keycode: int)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			esc_pressed.emit()
		elif event.keycode == KEY_QUOTELEFT or event.keycode == KEY_F12 \
				or (event.keycode >= KEY_F1 and event.keycode <= KEY_F10):
			cheat_key.emit(event.keycode)
