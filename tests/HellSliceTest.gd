extends SceneTree
# M3 지옥 세로 슬라이스 회귀 검증:
#  1) 균열 3회 → 중간보스 → 5분 최종보스의 리듬 순서.
#  2) 지옥 레이아웃의 균열 위치가 실제 이동 가능 영역 안에 있음.
#  3) 냉기/화염의 균열 파괴 배수.
#  4) 화염 군주 70%·35% 갑옷 게이트와 파괴 후 딜타임.
#  5) 슬롯별 지옥 전용 어픽스와 실제 런 효과 연결.

const MainScript = preload("res://Main.gd")
const BossScript = preload("res://Boss.gd")
const PlayerScript = preload("res://Player.gd")
const FissureScript = preload("res://HellFissure.gd")
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

	# 1) 4~6분 세로 슬라이스의 이벤트 순서.
	_expect(game.HELL_FISSURE_TIMES.size() == game.HELL_FISSURE_REQUIRED,
		"균열 시간표와 요구 개수가 다름")
	_expect(float(game.HELL_FISSURE_TIMES[0]) < float(game.HELL_FISSURE_TIMES[1])
		and float(game.HELL_FISSURE_TIMES[1]) < game.HELL_MIDBOSS_TIME
		and game.HELL_MIDBOSS_TIME < float(game.HELL_FISSURE_TIMES[2])
		and float(game.HELL_FISSURE_TIMES[2]) < game.DUNGEON_BOSS_TIME,
		"균열→중간보스→최종보스 리듬 순서가 깨짐")
	_expect(game.DUNGEON_BOSS_TIME >= 240.0 and game.DUNGEON_BOSS_TIME <= 360.0,
		"최종보스가 4~6분 창 밖에 있음")

	# 2) 균열 좌표는 지옥 회랑 안에서 실제 전투가 가능해야 한다.
	var layout = StageLayoutScript.make(game.HELL_STAGE,
		Color(GameConfigScript.stage_info(game.HELL_STAGE)["tint"]))
	_expect(layout.objective_positions.size() == game.HELL_FISSURE_REQUIRED,
		"지옥 균열 좌표가 3개가 아님")
	for position in layout.objective_positions:
		_expect(layout.is_walkable(position, 58.0), "균열 좌표가 벽/용암 안에 있음: %s" % position)

	# 3) 냉기는 파괴 특효, 화염은 저항. 어떤 빌드도 완전 면역에는 막히지 않는다.
	var fissure = FissureScript.new()
	fissure.configure(0, 100.0, 10.0)
	fissure.take_damage(10.0, false, false, "phys")
	_expect(is_equal_approx(fissure.hp, 90.0), "물리 균열 피해 기준값 오류: %.1f" % fissure.hp)
	fissure.hp = 100.0
	fissure.take_damage(10.0, false, false, "ice")
	_expect(is_equal_approx(fissure.hp, 75.0), "냉기 균열 파괴 배수 오류: %.1f" % fissure.hp)
	fissure.hp = 100.0
	fissure.take_damage(10.0, false, false, "fire")
	_expect(is_equal_approx(fissure.hp, 97.0), "화염 균열 저항 배수 오류: %.1f" % fissure.hp)

	# 4) 보스 체력 게이트 → 갑옷 → 냉기 파괴 → 5초 딜타임 → 두 번째 게이트.
	var boss = BossScript.new()
	boss.max_hp = 1000.0
	boss.hp = 1000.0
	boss.configure_hell_final(0)
	_expect(boss._hell_t >= 2.2, "보스 등장 배너가 사라지기 전에 첫 패턴이 시작됨")
	boss.take_damage(400.0, false, "phys")
	_expect(is_equal_approx(boss.hp, 700.0), "첫 갑옷 게이트가 70%%에 멈추지 않음: %.1f" % boss.hp)
	_expect(boss.armor_hp > 0.0 and boss.hell_phase == 2,
		"첫 화염 갑옷/2페이즈가 시작되지 않음")
	_expect(boss._hell_t >= 2.2, "갑옷 안내 배너가 사라지기 전에 다음 패턴이 시작됨")
	boss.take_damage(60.0, false, "ice")
	_expect(boss.armor_hp <= 0.0 and is_equal_approx(boss.vulnerable_t, boss.HELL_VULNERABLE_TIME),
		"냉기로 갑옷 파괴 후 딜타임이 열리지 않음")
	boss.take_damage(100.0, false, "phys")
	_expect(is_equal_approx(boss.hp, 530.0), "딜타임 1.7배 피해가 체력에 반영되지 않음: %.1f" % boss.hp)
	boss.take_damage(300.0, false, "phys")
	_expect(is_equal_approx(boss.hp, 350.0) and boss.armor_hp > 0.0 and boss.hell_phase == 3,
		"두 번째 35%% 갑옷 게이트가 작동하지 않음")

	# 미봉인 균열은 보스 갑옷만 강화한다.
	var empowered = BossScript.new()
	empowered.max_hp = 1000.0
	empowered.hp = 1000.0
	empowered.configure_hell_final(3)
	empowered.take_damage(400.0, false, "phys")
	_expect(empowered.armor_max > boss.max_hp * 0.20,
		"미봉인 균열이 화염 갑옷을 강화하지 않음: %.1f" % empowered.armor_max)
	var pattern_boss = BossScript.new()
	var pattern_player = PlayerScript.new()
	pattern_player.position = Vector2(300.0, 0.0)
	pattern_boss.configure_hell_final(0)
	pattern_boss._start_next_hell_attack(pattern_player)
	_expect(pattern_boss._hell_state == pattern_boss.HellState.SLAM_WINDUP,
		"보스 첫 패턴이 회피 가능한 원형 강타가 아님")
	pattern_boss._start_next_hell_attack(pattern_player)
	_expect(pattern_boss._hell_state == pattern_boss.HellState.CHARGE_WINDUP,
		"보스 두 번째 패턴이 경로 예고 돌진이 아님")
	pattern_boss._start_next_hell_attack(pattern_player)
	_expect(pattern_boss._hell_state == pattern_boss.HellState.VOLLEY_WINDUP,
		"보스 세 번째 패턴이 방사 탄막 예고가 아님")

	# 5) 슬롯별 전용 어픽스와 UI/실제 효과 연결.
	var expected_specials := {
		"weapon": "riftbreaker", "armor": "cinderward", "trinket": "sealkeeper",
	}
	for slot in expected_specials:
		var item: Dictionary = game._roll_hell_gear(true, slot)
		_expect(str(item.get("dungeon_tag", "")) == "hell", "%s 장비에 지옥 태그 없음" % slot)
		_expect(str(item.get("special", {}).get("key", "")) == expected_specials[slot],
			"%s 전용 효과 키 오류: %s" % [slot, item.get("special", {})])
		_expect(int(game.RARITY_ORDER.get(str(item.get("rarity", "")), 0)) >= 3,
			"중간/최종보스 확정 장비가 에픽 미만")
		_expect("[지옥 전용]" in game._gear_detail_text(item), "%s 전용 효과가 장비 상세에 안 보임" % slot)
		game.equipped[slot] = item
	_expect(is_equal_approx(game._hell_objective_damage_multiplier(), 1.35),
		"균열 파쇄 실제 배수 미연결")
	_expect(is_equal_approx(game._hell_incoming_damage_multiplier(), 0.72),
		"잿불 수호 실제 배수 미연결")
	_expect(game._has_gear_special("sealkeeper"), "봉인의 메아리 실제 장착 판정 미연결")

	var hell_rule := str(GameConfigScript.stage_info(game.HELL_STAGE).get("rule", ""))
	_expect("용암 균열" in hell_rule and "화염 갑옷" in hell_rule,
		"던전 선택 화면에 지옥 고유 규칙이 설명되지 않음")
	var midboss_tier: Dictionary = GameConfigScript.hell_midboss_tier()
	var elite_tier: Dictionary = GameConfigScript.hell_elite_tier()
	_expect(str(elite_tier.get("key", "")) == "ember_stalker"
		and str(elite_tier.get("behavior", "")) == "charge"
		and str(elite_tier.get("weak", "")) == "ice",
		"지옥 고유 정예 잿불 추적자 규칙 오류")
	_expect(str(midboss_tier.get("behavior", "")) == "charge"
		and str(midboss_tier.get("weak", "")) == "ice"
		and str(midboss_tier.get("resist", "")) == "fire",
		"용암 집행자 돌진/속성 규칙 오류")
	_expect(str(elite_tier.get("key", "")) != str(midboss_tier.get("key", "")),
		"고유 정예와 중간보스가 같은 엔티티로 합쳐짐")

	fissure.free()
	boss.free()
	empowered.free()
	pattern_boss.free()
	pattern_player.free()
	game.free()
	if failed:
		quit(1)
		return
	print("HELL_SLICE_OK")
	quit(0)
