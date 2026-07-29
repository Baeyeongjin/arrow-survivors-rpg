extends SceneTree
# M2: 능력치 포인트 소스가 레벨업 → 마일스톤(정예 처치)으로 이동했는지 검증.
#  1) _gain_xp 로 여러 레벨 올려도 stat_points 는 0 (레벨당 지급 폐지).
#  2) 정예 처치 지급 상수/헬퍼(_award_stat_points)가 실제로 포인트를 준다.
#  3) 음수·0 지급은 무시(불변식).

const MainScript = preload("res://Main.gd")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		quit(1)


func _initialize() -> void:
	var game = MainScript.new()
	# state 기본값 TITLE → _gain_xp 가 레벨업 UI를 열지 않아 bare 인스턴스에서 안전.
	game.xp_mult = 1.0
	game.level = 1
	game.xp = 0
	game.xp_to_next = 10
	game.stat_points = 0

	# 1) 레벨업으로는 포인트가 안 생겨야 한다.
	game._gain_xp(5000)
	_expect(game.level > 1, "테스트 전제: XP 투입으로 레벨이 올라야 함(level=%d)" % game.level)
	_expect(game.stat_points == 0,
		"레벨업이 아직 능력치 포인트를 지급함(=%d) — 레벨당 지급이 남아있음" % game.stat_points)

	# 2) 정예 처치 보상: 상수가 유효하고 헬퍼가 정확히 그만큼 준다.
	_expect(game.STAT_PT_ELITE >= 1, "STAT_PT_ELITE 는 1 이상이어야 함: %d" % game.STAT_PT_ELITE)
	game.stat_points = 0
	game._award_stat_points(game.STAT_PT_ELITE)
	_expect(game.stat_points == game.STAT_PT_ELITE,
		"정예 처치 지급이 STAT_PT_ELITE(%d)와 다름: %d" % [game.STAT_PT_ELITE, game.stat_points])

	# 3) 0/음수 지급은 무시.
	game._award_stat_points(0)
	game._award_stat_points(-5)
	_expect(game.stat_points == game.STAT_PT_ELITE,
		"0/음수 지급이 포인트를 바꿈: %d" % game.stat_points)

	game.free()
	print("STATPOINT_OK")
	quit(0)
