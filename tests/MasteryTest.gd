extends SceneTree
# 숙련 갈림길 검증 (원소 기반).
#
# 예전엔 주무기 레벨(Lv4·Lv6)로 열렸다. 무기가 스탯으로 내려가면서 그 축이 사라져
# 캐릭터 원소 9종 × 2단계로 옮기고 플레이어 레벨(Lv5·Lv12)로 연다.
#
#  1) 패시브 슬롯 상한.
#  2) 원소 9종 전부가 갈림길 2단계 × a/b(name·desc·eff)를 완비 — 하나라도 빠지면
#     그 캐릭터만 성장 분기가 통째로 없는 채로 조용히 굴러간다.
#  3) 각 갈림길이 해당 레벨부터 뜨고, 고르면 잠기고 재제시되지 않는다.
#  4) 잘못된 레벨/중복 선택은 무시.

const MainScript = preload("res://Main.gd")
const SkillDefsScript = preload("res://SkillDefs.gd")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		quit(1)


func _initialize() -> void:
	var game = MainScript.new()

	# 1) 슬롯 상한
	_expect(game.MAX_PASSIVES == 4, "MAX_PASSIVES 는 4여야 함: %d" % game.MAX_PASSIVES)

	# 2) 갈림길 완비: 원소마다 2단계, 각 a/b(name/desc/eff)
	var fork_table: Dictionary = game.MASTERY_FORK
	var levels: Array = game.MASTERY_FORK_LEVELS
	for elem in SkillDefsScript.ELEMENT_TRAITS.keys():
		_expect(fork_table.has(elem), "MASTERY_FORK 에 원소 %s 없음(그 캐릭터는 분기가 통째로 없다)" % elem)
		var tiers: Array = fork_table[elem]
		_expect(tiers.size() == levels.size(),
			"%s 갈림길 단계 수(%d)가 MASTERY_FORK_LEVELS(%d)와 다름" % [elem, tiers.size(), levels.size()])
		for tier in tiers:
			for bkey in ["a", "b"]:
				var b: Dictionary = (tier as Dictionary).get(bkey, {})
				_expect(b.has("name") and b.has("desc") and b.has("eff"),
					"%s 어떤 단계의 %s 분기에 name/desc/eff 누락" % [elem, bkey])
	# 캐릭터 9명이 전부 갈림길이 있는 원소를 쓰는가 (원소 표와 로스터가 어긋나면 여기서 걸린다)
	for c in GameConfig.characters():
		var ce := SkillDefsScript.element_of(str(c.get("key", "")))
		_expect(fork_table.has(ce), "캐릭터 %s 의 원소 %s 에 갈림길 없음" % [c.get("key", ""), ce])

	game.sel_char = {"key": "mordek"}   # phys
	_expect(game._player_element() == "phys", "테스트 캐릭터 원소가 phys 여야 함")

	# 3a) 1단계는 Lv5부터
	game.level = levels[0] - 1
	game.mastery_picks = {}
	_expect(game._pending_mastery_fork().is_empty(), "Lv%d 에서는 갈림길이 떠선 안 됨" % (levels[0] - 1))
	game.level = levels[0]
	_expect(game._pending_mastery_fork().size() == 2, "Lv%d 에 갈림길 2장이 떠야 함" % levels[0])

	# 확정 → 잠금 + 재제시 없음
	game._take_mastery_branch(levels[0], "a")
	_expect(str(game.mastery_picks.get(levels[0], "")) == "a", "1단계 잠금값 틀림: %s" % str(game.mastery_picks))
	_expect(game._pending_mastery_fork().is_empty(), "1단계 선택 후 갈림길이 재제시됨")

	# 4) 중복 선택 무시
	game._take_mastery_branch(levels[0], "b")
	_expect(str(game.mastery_picks.get(levels[0], "")) == "a", "이미 고른 1단계가 덮어써짐")

	# 3b) 2단계는 Lv12부터
	game.level = levels[1] - 1
	_expect(game._pending_mastery_fork().is_empty(), "Lv%d 에서 2단계가 떠선 안 됨" % (levels[1] - 1))
	game.level = levels[1]
	_expect(game._pending_mastery_fork().size() == 2, "Lv%d 에 2단계 갈림길이 떠야 함" % levels[1])
	game._take_mastery_branch(levels[1], "b")
	_expect(str(game.mastery_picks.get(levels[1], "")) == "b", "2단계 잠금값 틀림: %s" % str(game.mastery_picks))
	_expect(game._pending_mastery_fork().is_empty(), "모든 갈림길 선택 후에도 재제시됨")

	game.free()
	print("MASTERY_OK")
	quit(0)
