extends SceneTree
# 뱀서식 돌발 대형 대신 RPG형 지역 위협만 유지하는 회귀 테스트.

const GameConfigScript = preload("res://GameConfig.gd")
const EnemyScript = preload("res://Enemy.gd")
const MainScript = preload("res://Main.gd")

var failed := false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)


func _initialize() -> void:
	_check_schedule_contract()
	_check_threat_definitions()
	_check_enemy_buff_lifecycle()
	_check_main_integration_contract()

	if failed:
		quit(1)
		return
	print("MONSTER_THREAT_OK types=%d stages=5" % GameConfigScript.MONSTER_THREAT_EVENTS.size())
	quit(0)


func _check_schedule_contract() -> void:
	for minute in GameConfigScript.WAVE_SCHEDULE.size():
		var wave: Dictionary = GameConfigScript.WAVE_SCHEDULE[minute]
		_expect(wave.has("threat"), "웨이브 %d에 threat 키가 없음" % minute)
		_expect(not wave.has("event"), "웨이브 %d에 구 돌발 event 키가 남음" % minute)
		var threat_id := int(wave["threat"])
		_expect(threat_id >= -1 and threat_id < GameConfigScript.MONSTER_THREAT_EVENTS.size(),
			"웨이브 %d의 threat id가 범위를 벗어남: %d" % [minute, threat_id])

	for stage in range(1, 6):
		var profile: Dictionary = GameConfigScript.stage_spawn_profile(stage)
		_expect(profile.has("threats"), "스테이지 %d에 위협 순환표가 없음" % stage)
		_expect(not profile.has("events"), "스테이지 %d에 구 이벤트 순환표가 남음" % stage)
		var cycle: Array = profile.get("threats", [])
		_expect(not cycle.is_empty(), "스테이지 %d의 위협 순환표가 비어 있음" % stage)
		for threat_id in cycle:
			_expect(int(threat_id) >= 0
				and int(threat_id) < GameConfigScript.MONSTER_THREAT_EVENTS.size(),
				"스테이지 %d의 위협 id가 범위를 벗어남: %s" % [stage, threat_id])


func _check_threat_definitions() -> void:
	_expect(GameConfigScript.MONSTER_THREAT_EVENTS.size() == 6,
		"지역 위협은 기존 시간표와 호환되는 6종이어야 함")
	var forbidden_terms := ["무리 출현", "원진", "포위망", "양방향 협공", "벽이 밀려"]
	for threat_id in GameConfigScript.MONSTER_THREAT_EVENTS.size():
		var threat: Dictionary = GameConfigScript.monster_threat(threat_id, 3)
		for required_key in [
			"name", "display_name", "duration", "attack_mult",
			"speed_mult", "damage_taken_mult", "desc", "color",
		]:
			_expect(threat.has(required_key),
				"위협 %d에 %s 값이 없음" % [threat_id, required_key])
		_expect(float(threat["duration"]) >= 10.0 and float(threat["duration"]) <= 15.0,
			"위협 %d 지속 시간이 짧은 RPG 교전 범위를 벗어남" % threat_id)
		var raises_danger := (float(threat["attack_mult"]) > 1.0
			or float(threat["speed_mult"]) > 1.0
			or float(threat["damage_taken_mult"]) < 1.0)
		_expect(raises_danger, "위협 %d이 몬스터를 실제로 강화하지 않음" % threat_id)
		var copy := "%s %s" % [str(threat["name"]), str(threat["desc"])]
		for forbidden in forbidden_terms:
			_expect(not forbidden in copy,
				"위협 문구에 삭제한 대형 이벤트 표현이 남음: %s" % forbidden)
	_expect("빙설의 기운" in str(GameConfigScript.monster_threat(0, 3)["display_name"]),
		"위협 이름에 지역 정체성이 반영되지 않음")


func _check_enemy_buff_lifecycle() -> void:
	var enemy = EnemyScript.new()
	enemy.hp = 100.0
	enemy.max_hp = 100.0
	enemy.speed = 80.0
	enemy.touch_damage = 10.0

	var armor_threat: Dictionary = GameConfigScript.monster_threat(0, 1)
	enemy.apply_threat_buff(armor_threat, 5.0)
	_expect(enemy.is_threatened(), "적에게 지역 위협 상태가 적용되지 않음")
	_expect(is_equal_approx(enemy.threat_timer, 5.0), "남은 위협 시간이 전달되지 않음")
	var expected_damage := 20.0 * float(armor_threat["damage_taken_mult"])
	enemy.take_damage(20.0, false, false, "phys")
	_expect(is_equal_approx(enemy.hp, 100.0 - expected_damage),
		"위협의 받는 피해 배수가 실제 피해에 반영되지 않음")

	var speed_threat: Dictionary = GameConfigScript.monster_threat(2, 1)
	enemy.apply_threat_buff(speed_threat, 4.0)
	_expect(is_equal_approx(enemy.speed, 80.0 * float(speed_threat["speed_mult"])),
		"겹친 위협이 원래 속도에서 다시 계산되지 않음")
	_expect(is_equal_approx(enemy.touch_damage, 10.0 * float(speed_threat["attack_mult"])),
		"위협 공격력 배수가 적용되지 않음")
	enemy.clear_threat_buff()
	_expect(not enemy.is_threatened()
		and is_equal_approx(enemy.speed, 80.0)
		and is_equal_approx(enemy.touch_damage, 10.0)
		and is_equal_approx(enemy.threat_damage_taken_mult, 1.0),
		"위협 종료 후 적 능력치가 원래 값으로 복구되지 않음")
	enemy.free()


func _check_main_integration_contract() -> void:
	var game = MainScript.new()
	var newborn = EnemyScript.new()
	newborn.speed = 50.0
	newborn.touch_damage = 12.0
	game._monster_threat_def = GameConfigScript.monster_threat(3, 2)
	game._monster_threat_t = 7.0
	game._apply_active_monster_threat(newborn)
	_expect(newborn.is_threatened() and is_equal_approx(newborn.threat_timer, 7.0),
		"위협 중 새로 생성된 적이 남은 강화 시간을 이어받지 못함")
	var midboss = EnemyScript.new()
	midboss.midboss = true
	game._apply_active_monster_threat(midboss)
	_expect(not midboss.is_threatened(), "수제 중간보스 수치에 일반 지역 위협이 중첩됨")

	for old_method in [
		"_spawn_event", "_spawn_horde", "_event_static_ring",
		"_event_pincer", "_event_wall", "_event_encircle", "_event_elite_pack",
	]:
		_expect(not game.has_method(old_method), "삭제한 대형 이벤트 함수가 남음: %s" % old_method)

	# 저장소가 CRLF로 정규화되면 "\n\n" 검색이 통째로 실패해 이 검사가 조용히 무력화된다.
	# 줄바꿈을 LF로 통일한 뒤 찾는다.
	var source := FileAccess.get_file_as_string("res://Main.gd").replace("\r\n", "\n")
	var start := source.find("func _start_monster_threat")
	var finish := source.find("\n\nfunc _apply_active_monster_threat", start)
	_expect(start >= 0 and finish > start, "지역 위협 시작 함수 범위를 찾지 못함")
	if start >= 0 and finish > start:
		var threat_block := source.substr(start, finish - start)
		_expect(not "_make_enemy(" in threat_block,
			"지역 위협이 몬스터를 추가 소환함")

	newborn.free()
	midboss.free()
	game.free()
