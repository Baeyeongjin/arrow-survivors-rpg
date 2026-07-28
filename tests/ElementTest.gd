extends SceneTree
# 속성 상성 곱 검증: 약점 ×1.5 / 저항 ×0.6 / 무관 ×1.0.
# Enemy는 부모 없이 생성 → take_damage에 element를 직접 넘겨 순수 곱만 확인한다.

const EnemyScript = preload("res://Enemy.gd")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		quit(1)


func _hp_after(element: String) -> float:
	var e = EnemyScript.new()
	e.hp = 100.0
	e.weak = "fire"
	e.resist = "ice"
	e.take_damage(10.0, false, false, element)
	var hp: float = e.hp
	e.free()
	return hp


func _initialize() -> void:
	_expect(is_equal_approx(_hp_after("fire"), 85.0), "약점(fire) 히트는 ×1.5 = 15 피해여야 함")
	_expect(is_equal_approx(_hp_after("ice"), 94.0), "저항(ice) 히트는 ×0.6 = 6 피해여야 함")
	_expect(is_equal_approx(_hp_after("holy"), 90.0), "무관 속성(holy)은 ×1.0 = 10 피해여야 함")
	_expect(is_equal_approx(_hp_after("phys"), 90.0), "물리는 상성 없음 ×1.0 = 10 피해여야 함")
	print("ELEMENT_OK")
	quit(0)
