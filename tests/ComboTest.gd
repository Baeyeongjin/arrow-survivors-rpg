extends SceneTree
# 콤보(원소 상태 × 스킬 역할) 검증.
#
# 스킬 7종이 전부 "때리기"라 뭘 골라도 결과가 같던 문제를 setup/payoff 로 갈랐다.
# 여기서 지키는 것:
#  1) 표 드리프트 — 아키타입마다 역할이, 원소 효과마다 색이 있어야 한다.
#     하나라도 빠지면 그 스킬만 조용히 콤보에서 빠지거나 상태가 안 보인다.
#  2) 상태 태그의 수명 — 바르면 남고, 소비하면 한 번만 먹히고, 시간이 지나면 풀린다.
#     "소비하면 한 번만"이 깨지면 payoff 한 방으로 무한 콤보가 된다.
#  3) 몸 색 — 상태가 걸리면 몸이 물들고 풀리면 돌아온다(도형 오버레이 대신 쓰는 유일한 신호).

const SkillDefsScript = preload("res://SkillDefs.gd")
const EnemyScript = preload("res://Enemy.gd")

var failed := false


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failed = true
		push_error(msg)


func _initialize() -> void:
	# 1) 표 드리프트
	for arch in SkillDefsScript.ARCHETYPES.keys():
		_expect(SkillDefsScript.ROLE.has(arch), "아키타입 %s 에 역할 없음(콤보에서 조용히 빠진다)" % arch)
		var role := SkillDefsScript.role_of(str(arch))
		_expect(role in ["setup", "payoff", "guard"], "%s 역할값 이상: %s" % [arch, role])
	var payoffs := 0
	var setups := 0
	for arch in SkillDefsScript.ROLE.keys():
		if SkillDefsScript.ROLE[arch] == "payoff":
			payoffs += 1
		elif SkillDefsScript.ROLE[arch] == "setup":
			setups += 1
	_expect(payoffs >= 1 and setups >= 1, "setup/payoff 가 한쪽이라도 0이면 콤보가 성립하지 않는다")

	for elem in SkillDefsScript.ELEMENT_TRAITS.keys():
		var eff := str(SkillDefsScript.ELEMENT_TRAITS[elem]["effect"])
		_expect(SkillDefsScript.EFFECT_COL.has(eff), "원소 효과 %s 에 색 없음(상태가 안 보인다)" % eff)
		_expect(SkillDefsScript.EFFECT_NAME.has(eff), "원소 효과 %s 에 이름 없음" % eff)

	# 기본 공격은 반드시 setup 이어야 한다. 제일 자주 맞히는 게 상태를 발라야 콤보가 돈다.
	for elem in SkillDefsScript.BASIC_BY_ELEMENT.keys():
		var basic := SkillDefsScript.basic_archetype(str(elem))
		_expect(SkillDefsScript.role_of(basic) == "setup",
			"%s 의 기본 공격 %s 가 setup 이 아니다" % [elem, basic])

	# 1-b) 숙련 표 — 아키타입마다 Lv4 규칙이 있어야 한다.
	# 문구가 없으면 "레벨업이 숫자만 오른다"로 돌아가고, 문구만 있고 실행부가 없으면
	# 카드가 거짓말을 한다. 여기서는 문구 존재와 build() 반영만 지킨다.
	for arch in SkillDefsScript.ARCHETYPES.keys():
		_expect(str(SkillDefsScript.UPGRADE.get(arch, "")) != "",
			"아키타입 %s 에 숙련 효과가 없다(레벨업이 숫자만 오른다)" % arch)
	var below := SkillDefsScript.build("burst", "fire", SkillDefsScript.MASTERY_LEVEL - 1)
	var at := SkillDefsScript.build("burst", "fire", SkillDefsScript.MASTERY_LEVEL)
	_expect(not bool(below.get("mastered", true)), "숙련 미만인데 mastered 가 켜져 있다")
	_expect(bool(at.get("mastered", false)), "숙련 레벨인데 mastered 가 안 켜졌다")
	_expect(str(below.get("upgrade", "")).contains("Lv%d" % SkillDefsScript.MASTERY_LEVEL),
		"숙련 전에는 목표로 보여 줘야 한다: %s" % str(below.get("upgrade", "")))
	_expect(str(at.get("upgrade", "")).begins_with("[숙련]"),
		"숙련 후에는 획득한 효과로 보여 줘야 한다: %s" % str(at.get("upgrade", "")))

	# 2) 상태 태그 수명
	var e = EnemyScript.new()
	_expect(e.status == "", "초기 상태는 비어 있어야 함")
	_expect(e.consume_status() == "", "빈 상태를 소비하면 \"\" 여야 함")

	e.mark_status("burn", SkillDefsScript.PRIME_TIME, SkillDefsScript.EFFECT_COL["burn"])
	_expect(e.status == "burn", "상태가 안 발렸다")
	_expect(e.self_modulate != Color(1, 1, 1), "상태가 걸렸는데 몸 색이 그대로다")

	_expect(e.consume_status() == "burn", "소비가 상태를 못 돌려줬다")
	_expect(e.status == "", "소비 후에도 상태가 남아 있다(무한 콤보가 된다)")
	_expect(e.consume_status() == "", "같은 상태가 두 번 소비됐다")
	_expect(e.self_modulate == Color(1, 1, 1), "소비 후 몸 색이 안 돌아왔다")

	# 빈 상태를 바르는 건 무시 (guard 스킬이 실수로 지우지 않게)
	e.mark_status("", 4.0, Color(1, 1, 1))
	_expect(e.status == "", "빈 상태가 발렸다")

	# 시간이 지나면 풀린다
	e.mark_status("chill", 0.2, SkillDefsScript.EFFECT_COL["chill"])
	e.tick_status(0.5)
	_expect(e.status == "", "시간이 지났는데 상태가 안 풀렸다")
	_expect(e.self_modulate == Color(1, 1, 1), "상태가 풀렸는데 몸 색이 남았다")

	e.free()

	# 3) 콤보를 요구하는 몹. 조건을 못 맞추면 거의 안 아파야 압력이 된다.
	var w = EnemyScript.new()
	w.combo_trait = "warded"
	_expect(w._combo_damage_mult() < 0.5, "경화 몹이 상태 없이도 제대로 아프다(압력이 없다)")
	w.mark_status("burn", 4.0, SkillDefsScript.EFFECT_COL["burn"])
	_expect(is_equal_approx(w._combo_damage_mult(), 1.0), "상태를 발랐는데 경화가 안 풀렸다")
	w.tick_status(5.0)
	_expect(w._combo_damage_mult() < 0.5, "상태가 풀렸는데 경화가 안 돌아왔다")
	w.free()

	var s = EnemyScript.new()
	s.combo_trait = "shell"
	_expect(s._combo_damage_mult() < 0.5, "껍질 몹이 처음부터 제대로 아프다")
	s.mark_status("stun", 4.0, SkillDefsScript.EFFECT_COL["stun"])
	_expect(s._combo_damage_mult() < 0.5, "껍질은 상태만 발라서는 안 열려야 한다(터뜨려야 한다)")
	s.consume_status()
	_expect(is_equal_approx(s._combo_damage_mult(), 1.0), "터뜨렸는데 껍질이 안 열렸다")
	s.tick_status(EnemyScript.SHELL_OPEN_TIME + 0.1)
	_expect(s._combo_damage_mult() < 0.5, "껍질이 영구히 열린 채로 남았다")
	s.free()

	# 특성이 없는 평범한 몹은 아무 영향이 없어야 한다
	var n = EnemyScript.new()
	_expect(is_equal_approx(n._combo_damage_mult(), 1.0), "특성 없는 몹이 피해 배수를 받는다")
	n.free()

	if failed:
		quit(1)
		return
	print("COMBO_OK")
	quit(0)
