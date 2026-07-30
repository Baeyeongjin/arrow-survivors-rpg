extends SceneTree

const MainScript = preload("res://Main.gd")
const Rules = preload("res://ExpeditionRules.gd")

var failed := false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)


func _gear(id: String, rarity: String, slot: String = "trinket") -> Dictionary:
	return {
		"slot": slot,
		"rarity": rarity,
		"name": "%s 시험 장비" % rarity,
		"gear_id": id,
		"lvl": 0,
		"affixes": [{
			"stat": "regen", "name": "재생", "value": 0.3,
			"base_value": 0.3, "pct": false,
		}],
		"_found": true,
	}


func _initialize() -> void:
	# 1) 두 번의 분기마다 캠프·상인·이벤트와 서로 다른 다음 전장이 제공된다.
	for floor_no in [1, 2]:
		var options: Array = Rules.route_options(2, floor_no)
		_expect(options.size() == 3, "원정 경로 카드가 3개가 아님: %s" % str(options))
		var node_keys := {}
		var stages := {}
		for option in options:
			node_keys[str(option["key"])] = true
			stages[int(option["target_stage"])] = true
		_expect(node_keys.size() == 3 and stages.size() == 3,
			"경로 노드/다음 전장이 중복됨: %s" % str(options))
	_expect(Rules.route_options(2, 3).is_empty(), "최종층 뒤에 경로가 다시 열림")

	# 2) 3층, 클리어 2개 추출, 사망 1개 보험이라는 원정 계약.
	_expect(Rules.FLOOR_COUNT == 3, "원정 층 수가 3이 아님")
	_expect(Rules.extraction_limit(true) == 2, "클리어 추출 한도가 2가 아님")
	_expect(Rules.extraction_limit(false) == 1, "사망 보험 한도가 1이 아님")
	_expect(Rules.floor_pressure(1) < Rules.floor_pressure(2)
		and Rules.floor_pressure(2) < Rules.floor_pressure(3),
		"층별 적 압박이 상승하지 않음")
	_expect(is_equal_approx(Rules.floor_pressure(1), 1.0)
		and Rules.floor_pressure(2) >= 1.30
		and Rules.floor_pressure(3) >= 1.68,
		"2·3층 체력 압박 목표가 적용되지 않음")
	_expect(Rules.floor_damage_pressure(1) < Rules.floor_damage_pressure(2)
		and Rules.floor_damage_pressure(2) < Rules.floor_damage_pressure(3),
		"층별 공격력 압박이 상승하지 않음")
	_expect(Rules.floor_speed_pressure(1) < Rules.floor_speed_pressure(2)
		and Rules.floor_speed_pressure(2) < Rules.floor_speed_pressure(3),
		"층별 이동 속도 압박이 상승하지 않음")
	_expect(Rules.floor_spawn_pressure(1) < Rules.floor_spawn_pressure(2)
		and Rules.floor_spawn_pressure(2) < Rules.floor_spawn_pressure(3),
		"층별 출현 밀도 압박이 상승하지 않음")
	_expect(Rules.floor_elite_bonus(1) == 0.0
		and Rules.floor_elite_bonus(2) > 0.0
		and Rules.floor_elite_bonus(3) > Rules.floor_elite_bonus(2),
		"층별 정예 확률 보너스가 상승하지 않음")

	var game = MainScript.new()
	game.expedition_active = true
	game.expedition_floor_started_at = 300.0
	game.time_survived = 599.0
	_expect(is_equal_approx(game._dungeon_elapsed(), 299.0),
		"총 원정 시간과 현재 층 시간이 분리되지 않음")
	game.kills = 18
	game.run_damage_dealt = 420.0
	game.run_damage_taken = 35.0
	game.run_floor_start_kills = 7
	game.run_floor_start_damage = 120.0
	game.run_floor_start_taken = 10.0
	game._record_current_floor(false)
	_expect(game.run_floor_stats.size() == 1
		and str(game.run_floor_stats[0]["outcome"]) == "death"
		and int(game.run_floor_stats[0]["kills"]) == 11
		and is_equal_approx(float(game.run_floor_stats[0]["damage_dealt"]), 300.0)
		and is_equal_approx(float(game.run_floor_stats[0]["damage_taken"]), 25.0),
		"사망 층의 증분 전투 기록 오류: %s" % str(game.run_floor_stats))
	game._record_current_floor(true)
	_expect(game.run_floor_stats.size() == 1, "같은 층 결과가 중복 기록됨")

	# 3) 선택한 두 장비만 추출 표식이 붙고 나머지는 자동 분해된다.
	game.inventory = [
		_gear("keep-epic", "epic"),
		_gear("keep-rare", "rare", "armor"),
		_gear("salvage-common", "common", "weapon"),
	]
	game.run_gold = 0
	game._resolve_expedition_loot({"keep-epic": true, "keep-rare": true}, true)
	_expect(bool(game.inventory[0].get("_extract_keep", false))
		and bool(game.inventory[1].get("_extract_keep", false)),
		"선택 장비에 추출 표식이 붙지 않음")
	_expect(not bool(game.inventory[2].get("_extract_keep", false)),
		"미선택 장비가 추출 대상으로 남음")
	_expect(game.auto_salvage_gold == int(game.FORGE_SALVAGE_BASE["common"]),
		"자동 분해 골드 계산 오류: %d" % game.auto_salvage_gold)
	var resolved_gold: int = int(game.run_gold)
	game._resolve_expedition_loot({"keep-epic": true}, true)
	_expect(game.run_gold == resolved_gold, "추출 확정 재호출로 자동 분해 골드가 중복 지급됨")

	# 4) 사망 보험은 희귀도가 가장 높은 장비를 자동 선택한다.
	var death_game = MainScript.new()
	death_game.expedition_active = true
	death_game.inventory = [
		_gear("common", "common"),
		_gear("legendary", "legendary"),
		_gear("rare", "rare"),
	]
	death_game._resolve_expedition_loot({}, false)
	_expect(bool(death_game.inventory[1].get("_extract_keep", false)),
		"사망 보험이 최고 희귀도 장비를 보존하지 않음")
	_expect(death_game.extracted_gear_count == 1, "사망 보험 보존 수가 1이 아님")

	# 5) 보스 파편은 중간층 1개, 최종층 3개이며 제작 비용이 유효하다.
	_expect(Rules.fragment_reward(1) == 1 and Rules.fragment_reward(3) == 3,
		"보스 파편 층별 보상 오류")
	_expect(Rules.BOSS_CRAFT_COST > Rules.fragment_reward(1),
		"중간보스 한 번으로 즉시 제작되어 원정 누적 의미가 없음")
	var fragment := Rules.boss_fragment(2)
	_expect(str(fragment["key"]) == "inferno" and "화염핵" in str(fragment["name"]),
		"지옥 보스 파편 정체성 오류: %s" % fragment)
	game.meta["boss_fragments"] = {"inferno": 3, "glacier": 2}
	_expect(game._consume_boss_fragments(Rules.BOSS_CRAFT_COST),
		"서로 다른 지역 보스 파편을 합쳐 제작 비용을 지불하지 못함")
	_expect(game._total_boss_fragments(game.meta["boss_fragments"]) == 0,
		"파편 제작 비용 차감 오류: %s" % game.meta["boss_fragments"])

	game.free()
	death_game.free()
	if failed:
		quit(1)
		return
	print("EXPEDITION_OK")
	quit(0)
