extends SceneTree
# 던전별 몬스터 로스터 계약 (사장님 요청 "던전별로 등장하는 몬스터가 다른지 체크"):
#  1) 5개 던전 모두 6종이고, 모든 키가 실제 티어에 존재한다.
#  2) 어떤 몹도 3개 던전 이상에 등장하지 않는다 — 정체성이 뭉개진다.
#  3) 최종 던전 마왕성은 전용 몹을 4종 이상 갖는다.
#  4) 지옥의 화염 태그 4종이 유지된다(상성이 걸려 있어 빠지면 목표 난도가 흔들린다).
#  5) 냉기 던전에 독 계열이 없고, 22종을 전부 사용한다.
#  6) wave_for_minute(분, 스테이지)가 실제로 그 던전 로스터만 뽑는다.

const GameConfigScript = preload("res://GameConfig.gd")
const DUNGEON_COUNT := 5
const FIRE_MOBS := ["fire_imp", "lava_toad", "hellhound", "demon"]

var failed := false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)


func _initialize() -> void:
	var all_keys := {}
	for tier in GameConfigScript.enemy_tiers():
		all_keys[str(tier["key"])] = true

	var usage := {}
	var rosters := []
	for stage in range(1, DUNGEON_COUNT + 1):
		var roster: Array = GameConfigScript.stage_roster(stage)
		rosters.append(roster)
		_expect(roster.size() == 6, "%d번 던전 로스터가 6종이 아님: %d" % [stage, roster.size()])
		var seen_in_stage := {}
		for key in roster:
			var mob := str(key)
			_expect(all_keys.has(mob), "%d번 던전에 존재하지 않는 몹 키: %s" % [stage, mob])
			_expect(not seen_in_stage.has(mob),
				"%d번 던전 로스터에 같은 몹이 두 번: %s" % [stage, mob])
			seen_in_stage[mob] = true
			usage[mob] = int(usage.get(mob, 0)) + 1

	# 2) 3개 던전 이상 등장 금지.
	for mob in usage:
		_expect(int(usage[mob]) <= 2,
			"%s가 %d개 던전에 등장함 (최대 2)" % [mob, int(usage[mob])])

	# 3) 마왕성 전용 4종 이상.
	var castle: Array = rosters[4]
	var castle_exclusive := 0
	for key in castle:
		if int(usage[str(key)]) == 1:
			castle_exclusive += 1
	_expect(castle_exclusive >= 4,
		"마왕성 전용 몹이 %d종뿐 — 최종 던전이 이미 본 얼굴로 채워짐" % castle_exclusive)

	# 4) 지옥 화염 4종 유지.
	var hell: Array = rosters[1]
	for fire_mob in FIRE_MOBS:
		_expect(hell.has(fire_mob), "지옥 로스터에서 화염 몹 %s가 빠짐" % fire_mob)

	# 5) 빙하에 독 계열 없음 + 22종 전부 사용.
	var glacier: Array = rosters[2]
	_expect(not glacier.has("mushroom"), "냉기 던전에 독버섯이 남아 있음")
	_expect(usage.size() == all_keys.size(),
		"사용되지 않는 몹이 있음: %d/%d종" % [usage.size(), all_keys.size()])

	# 6) 실제 스폰이 참조하는 경로가 로스터를 지킨다. 5분 층은 분 0~4를 지나므로
	#    그 구간의 primary/secondary가 모두 해당 던전 로스터 안에 있어야 한다.
	for stage in range(1, DUNGEON_COUNT + 1):
		var roster: Array = rosters[stage - 1]
		for minute in 5:
			var wave: Dictionary = GameConfigScript.wave_for_minute(minute, stage)
			for slot in ["primary", "secondary"]:
				var mob := str(wave.get(slot, ""))
				_expect(roster.has(mob),
					"%d번 던전 %d분 %s가 로스터 밖: %s" % [stage, minute, slot, mob])
		# 5분 층 안에서 6종이 모두 등장해야 로스터를 다 보여 준다.
		var appeared := {}
		for minute in 5:
			var wave: Dictionary = GameConfigScript.wave_for_minute(minute, stage)
			appeared[str(wave.get("primary", ""))] = true
			appeared[str(wave.get("secondary", ""))] = true
		_expect(appeared.size() == roster.size(),
			"%d번 던전 5분 안에 %d/%d종만 등장" % [stage, appeared.size(), roster.size()])

	if failed:
		quit(1)
		return
	print("STAGE_ROSTER_OK dungeons=%d mobs=%d" % [DUNGEON_COUNT, usage.size()])
	quit(0)
