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
	if failed:
		quit(1)
		return
	print("COMBO_OK")
	quit(0)
