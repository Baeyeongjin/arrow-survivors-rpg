extends SceneTree
# M5-A 묘지 세로 슬라이스 회귀 검증:
#  1) 봉인비 3회 → 무덤 기사 → 5분 묘지 수호자의 리듬 순서.
#  2) 묘지 레이아웃의 봉인비 좌표가 실제 이동 가능 영역 안.
#  3) 영혼 봉인비 점령: 범위 안 진행 / 범위 밖 정지(초기화 아님) / 완료.
#  4) 묘지 수호자 방패 핵 수 = max(1, 4-봉인) · 예고 3패턴 · 핵 파괴 후 딜타임.
#  5) 슬롯별 묘지 전용 어픽스와 실제 런 효과 연결(장송/수의/혼령).
#  6) GameConfig 묘지 이름·규칙·전용 티어.

const MainScript = preload("res://Main.gd")
const BossScript = preload("res://Boss.gd")
const PlayerScript = preload("res://Player.gd")
const SealScript = preload("res://GraveSeal.gd")
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

	# 1) 세로 슬라이스 이벤트 순서.
	_expect(game.GRAVE_SEAL_TIMES.size() == game.GRAVE_SEAL_REQUIRED, "봉인 시간표와 요구 개수가 다름")
	_expect(float(game.GRAVE_SEAL_TIMES[0]) < float(game.GRAVE_SEAL_TIMES[1])
		and float(game.GRAVE_SEAL_TIMES[1]) < float(game.GRAVE_SEAL_TIMES[2])
		and float(game.GRAVE_SEAL_TIMES[2]) < game.GRAVE_MIDBOSS_TIME
		and game.GRAVE_MIDBOSS_TIME < game.DUNGEON_BOSS_TIME,
		"봉인→무덤 기사→묘지 수호자 리듬 순서가 깨짐")

	# 2) 봉인비 좌표는 묘지 개활지 안에서 실제 전투 가능해야 한다.
	var layout = StageLayoutScript.make(game.GRAVE_STAGE,
		Color(GameConfigScript.stage_info(game.GRAVE_STAGE)["tint"]))
	_expect(layout.objective_positions.size() == game.GRAVE_SEAL_REQUIRED, "묘지 봉인 좌표가 3개가 아님")
	for position in layout.objective_positions:
		_expect(layout.is_walkable(position, 58.0), "봉인 좌표가 벽 안에 있음: %s" % position)

	# 3) 점령: 범위 안 진행 / 범위 밖 정지(초기화 아님) / 완료.
	var seal = SealScript.new()
	seal.configure(0, 138.0, 10.0)
	seal.tick(4.0, true)
	_expect(is_equal_approx(seal.progress, 4.0), "범위 안 점령 진행 오류: %.1f" % seal.progress)
	seal.tick(3.0, false)
	_expect(is_equal_approx(seal.progress, 4.0), "범위 밖에서 진행이 멈추지 않거나 초기화됨: %.1f" % seal.progress)
	_expect(not seal.is_completed(), "미완료 봉인이 완료로 표시됨")
	seal.tick(7.0, true)
	_expect(seal.is_completed(), "10초 누적 점령이 완료되지 않음")

	# 4) 방패 핵 수 공식 + 예고 3패턴 + 딜타임.
	var b0 = BossScript.new()
	b0.configure_grave_final(0)
	_expect(b0.grave_shield_core_max == 4, "봉인 0 → 핵 4개여야 함: %d" % b0.grave_shield_core_max)
	var b2 = BossScript.new()
	b2.configure_grave_final(2)
	_expect(b2.grave_shield_core_max == 2, "봉인 2 → 핵 2개여야 함: %d" % b2.grave_shield_core_max)
	var b4 = BossScript.new()
	b4.configure_grave_final(4)
	_expect(b4.grave_shield_core_max == 1, "봉인 4 → 핵 최소 1개여야 함: %d" % b4.grave_shield_core_max)

	var pattern_boss = BossScript.new()
	var pattern_player = PlayerScript.new()
	pattern_player.position = Vector2(300.0, 0.0)
	pattern_boss.configure_grave_final(0)
	pattern_boss._start_next_grave_attack(pattern_player)
	_expect(pattern_boss._grave_state == pattern_boss.GraveState.FAN_WINDUP, "첫 패턴이 부채꼴 뼈파동 예고가 아님")
	pattern_boss._start_next_grave_attack(pattern_player)
	_expect(pattern_boss._grave_state == pattern_boss.GraveState.EXPLODE_WINDUP, "둘째 패턴이 지연 폭발 예고가 아님")
	pattern_boss._start_next_grave_attack(pattern_player)
	_expect(pattern_boss._grave_state == pattern_boss.GraveState.CHARGE_WINDUP, "셋째 패턴이 직선 돌진 예고가 아님")

	# 60% 방패 게이트 → 핵 전부 파괴 → 5초 딜타임 → 취약 1.7배.
	var boss = BossScript.new()
	boss.max_hp = 1000.0
	boss.hp = 1000.0
	boss.configure_grave_final(0)   # 핵 4개
	boss.take_damage(400.0, false, "phys")
	_expect(is_equal_approx(boss.hp, 600.0), "60%% 방패 게이트가 멈추지 않음: %.1f" % boss.hp)
	_expect(boss.grave_shield_active and boss.grave_shield_cores == 4, "영혼 방패/핵 4개가 시작되지 않음")
	var core_hp: float = boss.grave_core_hp_max
	for i in 4:
		boss.take_damage(core_hp, false, "phys")   # 속성 무관 파괴
	_expect(not boss.grave_shield_active and is_equal_approx(boss.vulnerable_t, boss.GRAVE_VULNERABLE_TIME),
		"핵 전부 파괴 후 5초 딜타임이 열리지 않음: active=%s vuln=%.1f" % [boss.grave_shield_active, boss.vulnerable_t])
	boss.take_damage(100.0, false, "phys")
	_expect(is_equal_approx(boss.hp, 430.0), "딜타임 1.7배 피해가 반영되지 않음: %.1f" % boss.hp)

	# 5) 슬롯별 전용 어픽스와 상세/실제 효과 연결.
	var expected_specials := {
		"weapon": "requiem_interrupt", "armor": "burial_shroud", "trinket": "grave_echo",
	}
	for slot in expected_specials:
		var item: Dictionary = game._roll_graveyard_gear(true, slot)
		_expect(str(item.get("dungeon_tag", "")) == "graveyard", "%s 장비에 묘지 태그 없음" % slot)
		_expect(str(item.get("special", {}).get("key", "")) == expected_specials[slot],
			"%s 전용 효과 키 오류: %s" % [slot, item.get("special", {})])
		_expect(int(game.RARITY_ORDER.get(str(item.get("rarity", "")), 0)) >= 3, "확정 장비가 에픽 미만")
		_expect("[묘지 전용]" in game._gear_detail_text(item), "%s 전용 효과가 장비 상세에 안 보임" % slot)

	# 혼령의 메아리: 정예 처치 시 E 재사용 단축.
	game.equipped = {"weapon": {}, "armor": {}, "trinket": game._roll_graveyard_gear(true, "trinket")}
	game.skill_cds["e"] = 5.0
	_expect(game._has_gear_special("grave_echo"), "혼령의 메아리 장착 판정 미연결")
	# 감소량이 1.5 -> 2.0으로 바뀌었다(_reduce_skill_cds(2.0)). 5.0 - 2.0 = 3.0.
	game._grave_echo_on_elite()
	_expect(is_equal_approx(float(game.skill_cds["e"]), 3.0), "정예 처치 E 재사용 단축 미적용: %.2f" % float(game.skill_cds["e"]))

	# 수의의 가호: 층마다 처음 치명 피해 1회 방어.
	game.equipped = {"weapon": {}, "armor": game._roll_graveyard_gear(true, "armor"), "trinket": {}}
	var guard_player = PlayerScript.new()
	guard_player.max_hp = 100.0
	guard_player.hp = 30.0
	game.player = guard_player
	game.grave_shroud_used = false
	_expect(game._grave_try_death_guard(), "수의의 가호 첫 발동 실패")
	_expect(is_equal_approx(guard_player.hp, 1.0), "수의의 가호가 1 HP로 버티지 못함: %.1f" % guard_player.hp)
	_expect(not game._grave_try_death_guard(), "수의의 가호가 층에서 두 번 발동됨")
	game.player = null

	# 장송의 무기: 전조 보스 공격 취소 + 8초 쿨다운.
	game.equipped = {"weapon": game._roll_graveyard_gear(true, "weapon"), "armor": {}, "trinket": {}}
	game.grave_requiem_cd = 0.0
	var target_boss = BossScript.new()
	target_boss.configure_grave_final(0)
	target_boss._grave_state = target_boss.GraveState.FAN_WINDUP
	_expect(game._grave_try_requiem_interrupt(target_boss), "장송의 무기 전조 취소 실패")
	_expect(is_equal_approx(game.grave_requiem_cd, 8.0), "장송의 무기 쿨다운이 8초가 아님: %.1f" % game.grave_requiem_cd)
	_expect(not game._grave_try_requiem_interrupt(target_boss), "장송의 무기가 쿨다운 중 재발동됨")

	# 6) 던전 선택 화면·전용 티어.
	_expect(str(GameConfigScript.stage_info(game.GRAVE_STAGE).get("name", "")) == "묘지", "1층 이름이 묘지가 아님")
	_expect("봉인" in str(GameConfigScript.stage_info(game.GRAVE_STAGE).get("rule", "")), "묘지 규칙에 봉인 설명이 없음")
	var elite := GameConfigScript.graveyard_elite_tier()
	var mid := GameConfigScript.graveyard_midboss_tier()
	_expect(str(elite.get("key", "")) == "grave_warden", "묘지 정예 키 오류")
	_expect(str(mid.get("key", "")) == "tomb_knight", "묘지 중간보스 키 오류")
	_expect(str(elite.get("key", "")) != str(mid.get("key", "")), "정예와 중간보스가 같은 엔티티")

	seal.free()
	b0.free()
	b2.free()
	b4.free()
	pattern_boss.free()
	pattern_player.free()
	boss.free()
	guard_player.free()
	target_boss.free()
	game.free()
	if failed:
		quit(1)
		return
	print("GRAVEYARD_SLICE_OK")
	quit(0)
