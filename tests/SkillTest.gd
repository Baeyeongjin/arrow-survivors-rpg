extends SceneTree
# 캐릭터별 고유 스킬 매핑 완전성 검증:
# 모든 캐릭터가 CHAR_SKILLS에 있고, 배정된 궁극기가 ULT_NAME/디스패치에 존재해야 한다.

const MainScript = preload("res://Main.gd")
const KNOWN_ULTS = ["blast", "meteor", "blizzard", "judgment", "reap"]


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		quit(1)


func _initialize() -> void:
	var game = MainScript.new()
	var skills: Dictionary = game.CHAR_SKILLS
	var ult_names: Dictionary = game.ULT_NAME
	for c in GameConfig.characters():
		var key := str(c["key"])
		_expect(skills.has(key), "캐릭터 %s 가 CHAR_SKILLS에 없음 (기본값 fallback)" % key)
		var ult := str((skills[key] as Dictionary).get("ult", ""))
		_expect(ult in KNOWN_ULTS, "캐릭터 %s 의 궁극기 %s 가 디스패치에 없음" % [key, ult])
		_expect(ult_names.has(ult), "궁극기 %s 의 표시 이름이 ULT_NAME에 없음" % ult)
	# 헬퍼가 미등록 캐릭터엔 기본값을 주는지
	game.sel_char = {"key": "__none__"}
	_expect(game._char_ult() == "blast", "미등록 캐릭터는 blast로 폴백해야 함")
	_expect(game._char_skill_element() == "phys", "미등록 캐릭터 스킬 속성은 phys 폴백")
	game.free()
	print("SKILL_OK")
	quit(0)
