extends SceneTree
# M5-B 빙하 세로 슬라이스 회귀 검증:
#  1) 화로 3회 → 빙벽 골렘 → 5분 빙결 거상의 리듬 순서.
#  2) 빙하 화로 좌표가 실제 이동 가능 영역 안.
#  3) 화로는 모든 속성으로 해빙 가능하고 화염만 빠르며, 점화 뒤 온기 지대로 남는다.
#  4) 누적 냉기는 밖에서 상승·온기 안에서 하락하고 단계별 이동 압박을 준다.
#  5) 빙결 거상 예고 3패턴·70/35% 얼음 갑옷·속성별 파괴·5초 딜타임.
#  6) 슬롯별 빙하 전용 어픽스와 실제 런 효과 연결.

const MainScript = preload("res://Main.gd")
const BossScript = preload("res://Boss.gd")
const PlayerScript = preload("res://Player.gd")
const BrazierScript = preload("res://GlacierBrazier.gd")
const StageLayoutScript = preload("res://StageLayout.gd")
const GameConfigScript = preload("res://GameConfig.gd")

var failed := false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)


func _initialize() -> void:
	var game = MainScript.new()
	game.equipped = {"weapon": {}, "armor": {}, "trinket": {}}

	# 1) 세로 슬라이스 이벤트 순서.
	_expect(game.GLACIER_BRAZIER_TIMES.size() == game.GLACIER_BRAZIER_REQUIRED,
		"화로 시간표와 요구 개수가 다름")
	_expect(float(game.GLACIER_BRAZIER_TIMES[0]) < float(game.GLACIER_BRAZIER_TIMES[1])
		and float(game.GLACIER_BRAZIER_TIMES[1]) < game.GLACIER_MIDBOSS_TIME
		and game.GLACIER_MIDBOSS_TIME < float(game.GLACIER_BRAZIER_TIMES[2])
		and float(game.GLACIER_BRAZIER_TIMES[2]) < game.DUNGEON_BOSS_TIME,
		"화로→빙벽 골렘→빙결 거상 리듬 순서가 깨짐")

	# 2) 화로 좌표는 좁은 빙하 회랑에서도 반경 58의 전투 공간을 확보해야 한다.
	var layout = StageLayoutScript.make(game.GLACIER_STAGE,
		Color(GameConfigScript.stage_info(game.GLACIER_STAGE)["tint"]))
	_expect(layout.objective_positions.size() == game.GLACIER_BRAZIER_REQUIRED,
		"빙하 화로 좌표가 3개가 아님")
	for position in layout.objective_positions:
		_expect(layout.is_walkable(position, 58.0), "화로 좌표가 벽 안에 있음: %s" % position)

	# 3) 화염은 2.5배, 냉기는 느리지만 면역이 아니고, 물리는 정상 진행한다.
	var fire_brazier = BrazierScript.new()
	fire_brazier.configure(0, 180.0)
	fire_brazier.take_damage(10.0, false, false, "fire")
	_expect(is_equal_approx(fire_brazier.hp, 155.0), "화염 해빙 2.5배 오류: %.1f" % fire_brazier.hp)
	var phys_brazier = BrazierScript.new()
	phys_brazier.configure(0, 180.0)
	phys_brazier.take_damage(10.0, false, false, "phys")
	_expect(is_equal_approx(phys_brazier.hp, 170.0), "물리 해빙 진행 오류: %.1f" % phys_brazier.hp)
	var ice_brazier = BrazierScript.new()
	ice_brazier.configure(0, 180.0)
	ice_brazier.take_damage(10.0, false, false, "ice")
	_expect(ice_brazier.hp < ice_brazier.max_hp and ice_brazier.hp > 170.0,
		"냉기가 느리게나마 해빙하지 못함: %.1f" % ice_brazier.hp)
	phys_brazier.take_damage(999.0, false, false, "phys")
	_expect(phys_brazier.is_lit(), "비화염 빌드로 화로 점화 불가")
	_expect(phys_brazier.is_warming(Vector2.ZERO), "점화된 화로가 온기 지대로 남지 않음")

	# 4) 누적 냉기: 밖에서 상승 → 40 이상 이동 90% → 온기에서 빠른 감소·속도 복구.
	var chill_player = PlayerScript.new()
	game.player = chill_player
	game.glacier_chill = 0.0
	game._tick_glacier_chill(40.0, false)
	_expect(is_equal_approx(game.glacier_chill, 42.0), "기본 냉기 누적률 오류: %.1f" % game.glacier_chill)
	_expect(is_equal_approx(chill_player.environment_speed_mult, 0.90),
		"냉기 40 단계 이동 압박 미적용: %.2f" % chill_player.environment_speed_mult)
	game._tick_glacier_chill(1.0, true)
	_expect(is_equal_approx(game.glacier_chill, 18.0), "온기 냉기 해제율 오류: %.1f" % game.glacier_chill)
	_expect(is_equal_approx(chill_player.environment_speed_mult, 1.0),
		"온기 해제 뒤 이동속도 미복구: %.2f" % chill_player.environment_speed_mult)

	# 5) 예고 3패턴 + 얼음 갑옷 공식·속성 파쇄·5초 딜타임.
	var pattern_boss = BossScript.new()
	var pattern_player = PlayerScript.new()
	pattern_player.position = Vector2(300.0, 0.0)
	pattern_boss.configure_glacier_final(2)
	pattern_boss._start_next_glacier_attack(pattern_player)
	_expect(pattern_boss._glacier_state == pattern_boss.GlacierState.SHARD_WINDUP,
		"첫 패턴이 고드름 부채 예고가 아님")
	pattern_boss._start_next_glacier_attack(pattern_player)
	_expect(pattern_boss._glacier_state == pattern_boss.GlacierState.RING_WINDUP,
		"둘째 패턴이 빙결 파동 예고가 아님")
	pattern_boss._start_next_glacier_attack(pattern_player)
	_expect(pattern_boss._glacier_state == pattern_boss.GlacierState.ERUPT_WINDUP,
		"셋째 패턴이 지연 분출 예고가 아님")

	var boss = BossScript.new()
	boss.max_hp = 1000.0
	boss.hp = 1000.0
	boss.configure_glacier_final(0)
	boss.take_damage(300.0, false, "phys")
	_expect(is_equal_approx(boss.hp, 700.0) and boss.armor_hp > 0.0,
		"70%% 갑옷 게이트가 작동하지 않음: hp=%.1f armor=%.1f" % [boss.hp, boss.armor_hp])
	_expect(is_equal_approx(boss.armor_max, 250.0),
		"미점화 화로 3개 갑옷 강화 공식 오류: %.1f" % boss.armor_max)
	boss.take_damage(100.0, false, "fire")   # 화염 2.5배 = 갑옷 250 파쇄
	_expect(is_equal_approx(boss.armor_hp, 0.0)
		and is_equal_approx(boss.vulnerable_t, boss.GLACIER_VULNERABLE_TIME),
		"화염 갑옷 파쇄 뒤 5초 딜타임이 열리지 않음")
	boss.take_damage(100.0, false, "phys")
	_expect(is_equal_approx(boss.hp, 530.0), "빙하 딜타임 1.7배 피해 오류: %.1f" % boss.hp)
	_expect(is_equal_approx(boss.glacier_armor_element_multiplier("ice"), 0.55)
		and boss.glacier_armor_element_multiplier("phys") > 0.0,
		"냉기 저항 또는 비화염 진행 가능 규칙 오류")

	# 6) 슬롯별 전용 어픽스·상세·실제 배수/점화 보상 연결.
	var expected_specials := {
		"weapon": "thawbreaker", "armor": "winterward", "trinket": "hearth_echo",
	}
	for slot in expected_specials:
		var item: Dictionary = game._roll_glacier_gear(true, slot)
		_expect(str(item.get("dungeon_tag", "")) == "glacier", "%s 장비에 빙하 태그 없음" % slot)
		_expect(str(item.get("special", {}).get("key", "")) == expected_specials[slot],
			"%s 전용 효과 키 오류: %s" % [slot, item.get("special", {})])
		_expect(int(game.RARITY_ORDER.get(str(item.get("rarity", "")), 0)) >= 3, "확정 장비가 에픽 미만")
		_expect("[빙하 전용]" in game._gear_detail_text(item), "%s 전용 효과가 장비 상세에 안 보임" % slot)

	game.equipped = {"weapon": game._roll_glacier_gear(true, "weapon"), "armor": {}, "trinket": {}}
	_expect(is_equal_approx(game._glacier_objective_damage_multiplier(), 1.35),
		"해빙의 칼날 파괴 피해 +35% 미적용")
	game.equipped = {"weapon": {}, "armor": game._roll_glacier_gear(true, "armor"), "trinket": {}}
	_expect(is_equal_approx(game._glacier_chill_rate_multiplier(), 0.65)
		and is_equal_approx(game._glacier_incoming_damage_multiplier(), 0.74),
		"설원의 수호 냉기/보스 피해 감소 미적용")
	game.equipped = {"weapon": {}, "armor": {}, "trinket": game._roll_glacier_gear(true, "trinket")}
	game.glacier_chill = 80.0
	game.skill_e_cd = 5.0
	game._glacier_hearth_echo_on_light()
	_expect(is_equal_approx(game.glacier_chill, 50.0), "난롯불 메아리 냉기 추가 해제 오류: %.1f" % game.glacier_chill)
	_expect(is_equal_approx(game.skill_e_cd, 2.5), "난롯불 메아리 E 단축 오류: %.1f" % game.skill_e_cd)

	# 7) 선택 화면 설명과 전용 티어.
	_expect("화로" in str(GameConfigScript.stage_info(game.GLACIER_STAGE).get("rule", "")),
		"빙하 규칙에 화로 설명이 없음")
	var elite := GameConfigScript.glacier_elite_tier()
	var mid := GameConfigScript.glacier_midboss_tier()
	_expect(str(elite.get("key", "")) == "frost_sentry", "빙하 정예 키 오류")
	_expect(str(mid.get("key", "")) == "icewall_golem", "빙하 중간보스 키 오류")

	fire_brazier.free()
	phys_brazier.free()
	ice_brazier.free()
	chill_player.free()
	pattern_boss.free()
	pattern_player.free()
	boss.free()
	game.player = null
	game.free()
	if failed:
		quit(1)
		return
	print("GLACIER_SLICE_OK")
	quit(0)
