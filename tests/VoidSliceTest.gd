extends SceneTree
# M5-C 공허 세로 슬라이스 회귀 검증:
#  1) 공허 닻 3회 → 심연의 눈 → 5분 공허 감시자 리듬.
#  2) 닻 좌표가 실제 이동 가능 영역 안.
#  3) 안정 고리 누적/이탈 감쇠/완료 및 전용 장신구의 고리 확장.
#  4) 중력 끌어당김·회피 저항·전용 방어구 저항.
#  5) 감시자 3패턴·55% 분신 게이트·닻별 핵 수·5초 취약.
#  6) 슬롯별 공허 전용 어픽스·전용 티어·투사체 피해 출처.

const MainScript = preload("res://Main.gd")
const BossScript = preload("res://Boss.gd")
const PlayerScript = preload("res://Player.gd")
const AnchorScript = preload("res://VoidAnchor.gd")
const GravityFieldScript = preload("res://VoidGravityField.gd")
const StageLayoutScript = preload("res://StageLayout.gd")
const GameConfigScript = preload("res://GameConfig.gd")
const LAYOUT_SEEDS := [0, 1, 7, 23, 101, 4242, 90001]

var failed := false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)


func _initialize() -> void:
	var game = MainScript.new()
	game.equipped = {"weapon": {}, "armor": {}, "trinket": {}}

	# 1) 닻 둘 → 중간보스 → 마지막 닻 → 최종보스 순서.
	_expect(game.VOID_ANCHOR_TIMES.size() == game.VOID_ANCHOR_REQUIRED,
		"공허 닻 시간표와 요구 개수가 다름")
	_expect(float(game.VOID_ANCHOR_TIMES[0]) < float(game.VOID_ANCHOR_TIMES[1])
		and float(game.VOID_ANCHOR_TIMES[1]) < game.VOID_MIDBOSS_TIME
		and game.VOID_MIDBOSS_TIME < float(game.VOID_ANCHOR_TIMES[2])
		and float(game.VOID_ANCHOR_TIMES[2]) < game.DUNGEON_BOSS_TIME,
		"닻→심연의 눈→공허 감시자 리듬 순서가 깨짐")

	# 2) 공허 탑 지형에서도 닻 주변 반경 58의 전투 공간을 확보한다.
	for layout_seed in LAYOUT_SEEDS:
		var layout = StageLayoutScript.make(game.VOID_STAGE,
			Color(GameConfigScript.stage_info(game.VOID_STAGE)["tint"]), layout_seed)
		_expect(layout.objective_positions.size() == game.VOID_ANCHOR_REQUIRED,
			"공허 닻 좌표가 3개가 아님 (seed=%d)" % layout_seed)
		for position in layout.objective_positions:
			var objective_position: Vector2 = position
			_expect(layout.is_walkable(objective_position, 58.0),
				"공허 닻 좌표가 벽 안에 있음: %s (seed=%d)" % [
					objective_position, layout_seed])
			var walkable_band_points := 0
			for sample in 24:
				var band_point: Vector2 = objective_position \
					+ Vector2.from_angle(TAU * float(sample) / 24.0) * 123.0
				if layout.is_walkable(band_point, 16.0):
					walkable_band_points += 1
			_expect(walkable_band_points >= 6,
				"공허 닻 안정 고리의 이동 가능 구간이 부족함: %s (%d/24 seed=%d)" % [
					objective_position, walkable_band_points, layout_seed])

	# 3) 고리 안에서는 누적, 밖에서는 느리게 감쇠하며 즉시 초기화되지 않는다.
	var anchor = AnchorScript.new()
	anchor.configure(0, 8.0, 104.0)
	var band := anchor.stability_band()
	var stable_distance := (band.x + band.y) * 0.5
	anchor.tick(4.0, stable_distance)
	_expect(is_equal_approx(anchor.progress, 4.0), "안정 고리 누적 오류: %.2f" % anchor.progress)
	anchor.tick(2.0, band.y + 20.0)
	_expect(is_equal_approx(anchor.progress, 3.1), "고리 이탈 감쇠 오류: %.2f" % anchor.progress)
	anchor.tick(5.0, stable_distance)
	_expect(anchor.is_stabilized(), "8초 누적 뒤 닻이 안정화되지 않음")

	game.equipped = {"weapon": {}, "armor": {}, "trinket": game._roll_void_gear(true, "trinket")}
	var expanded := AnchorScript.new()
	expanded.configure(0, 8.0, 104.0)
	var expanded_band := expanded.stability_band(game._void_anchor_ring_bonus())
	_expect(is_equal_approx(expanded_band.x, band.x - 24.0)
		and is_equal_approx(expanded_band.y, band.y + 24.0),
		"닻의 메아리 고리 확장 +24가 적용되지 않음: %s" % expanded_band)

	# 4) 중력은 플레이어를 중심으로 끌고, 회피 중에는 완전히 저항한다.
	var pull_player = PlayerScript.new()
	game.player = pull_player
	pull_player.position = Vector2.ZERO
	game.equipped = {"weapon": {}, "armor": {}, "trinket": {}}
	_expect(game.apply_void_pull(Vector2(100, 0), 200.0, 100.0, 1.0),
		"기본 공허 끌어당김이 발동하지 않음")
	_expect(is_equal_approx(pull_player.position.x, 50.0),
		"기본 공허 끌어당김 거리 오류: %.2f" % pull_player.position.x)
	pull_player.position = Vector2.ZERO
	game.equipped = {"weapon": {}, "armor": game._roll_void_gear(true, "armor"), "trinket": {}}
	game.apply_void_pull(Vector2(100, 0), 200.0, 100.0, 1.0)
	_expect(is_equal_approx(pull_player.position.x, 27.5),
		"중력 수호 -45%% 저항 오류: %.2f" % pull_player.position.x)
	pull_player.position = Vector2.ZERO
	pull_player.dodge_t = 0.2
	_expect(not game.apply_void_pull(Vector2(100, 0), 200.0, 100.0, 1.0)
		and pull_player.position == Vector2.ZERO, "회피 중 공허 중력 저항 실패")

	# 5) 닻 수에 따른 핵 공식, 3개 예고 패턴, 55% 게이트와 취약 배율.
	var b0 = BossScript.new()
	b0.configure_void_final(0)
	_expect(b0.void_echo_core_max == 4, "닻 0 → 분신 핵 4개여야 함")
	var b2 = BossScript.new()
	b2.configure_void_final(2)
	_expect(b2.void_echo_core_max == 2, "닻 2 → 분신 핵 2개여야 함")
	var b3 = BossScript.new()
	b3.configure_void_final(3)
	_expect(b3.void_echo_core_max == 1, "닻 3 → 분신 핵 최소 1개여야 함")

	var pattern_boss = BossScript.new()
	var pattern_player = PlayerScript.new()
	pattern_player.position = Vector2(300.0, 0.0)
	pattern_boss.configure_void_final(1)
	pattern_boss._start_next_void_attack(pattern_player)
	_expect(pattern_boss._void_state == pattern_boss.VoidState.GAZE_WINDUP,
		"첫 패턴이 시선 원뿔 예고가 아님")
	pattern_boss._start_next_void_attack(pattern_player)
	_expect(pattern_boss._void_state == pattern_boss.VoidState.LASER_WINDUP,
		"둘째 패턴이 회전 광선 예고가 아님")
	pattern_boss._start_next_void_attack(pattern_player)
	_expect(pattern_boss._void_state == pattern_boss.VoidState.WELL_WINDUP,
		"셋째 패턴이 중력 붕괴 예고가 아님")

	var boss = BossScript.new()
	boss.max_hp = 1000.0
	boss.hp = 1000.0
	boss.configure_void_final(0)
	boss.take_damage(450.0, false, "phys")
	_expect(is_equal_approx(boss.hp, 550.0) and boss.void_echo_active
		and boss.void_echo_cores == 4, "55%% 분신 게이트 또는 핵 4개 시작 실패")
	var core_hp: float = boss.void_core_hp_max
	for i in 4:
		boss.take_damage(core_hp, false, "phys")
	_expect(not boss.void_echo_active
		and is_equal_approx(boss.vulnerable_t, boss.VOID_VULNERABLE_TIME),
		"분신 핵 전부 파괴 뒤 5초 취약이 열리지 않음")
	boss.take_damage(100.0, false, "phys")
	_expect(is_equal_approx(boss.hp, 375.0), "공허 취약 1.75배 피해 오류: %.1f" % boss.hp)

	# 6) 슬롯별 전용 장비와 실제 배수, 전용 티어의 애니메이션/피해 출처 연결.
	var expected_specials := {
		"weapon": "corebreaker", "armor": "gravity_ward", "trinket": "anchor_echo",
	}
	for slot in expected_specials:
		var item: Dictionary = game._roll_void_gear(true, slot)
		_expect(str(item.get("dungeon_tag", "")) == "void", "%s 장비에 공허 태그 없음" % slot)
		_expect(str(item.get("special", {}).get("key", "")) == expected_specials[slot],
			"%s 전용 효과 키 오류: %s" % [slot, item.get("special", {})])
		_expect(int(game.RARITY_ORDER.get(str(item.get("rarity", "")), 0)) >= 3,
			"확정 공허 장비가 에픽 미만")
		_expect("[공허 전용]" in game._gear_detail_text(item),
			"%s 전용 효과가 장비 상세에 안 보임" % slot)
	game.equipped = {"weapon": game._roll_void_gear(true, "weapon"), "armor": {}, "trinket": {}}
	_expect(is_equal_approx(game._void_core_damage_multiplier(), 1.35),
		"분신 파쇄 핵 피해 +35% 미적용")
	game.equipped = {"weapon": {}, "armor": game._roll_void_gear(true, "armor"), "trinket": {}}
	_expect(is_equal_approx(game._void_pull_multiplier(), 0.55)
		and is_equal_approx(game._void_incoming_damage_multiplier(), 0.75),
		"중력 수호 끌어당김/패턴 피해 감소 미적용")

	var elite := GameConfigScript.void_elite_tier()
	var mid := GameConfigScript.void_midboss_tier()
	_expect(str(elite.get("key", "")) == "rift_stalker", "공허 정예 키 오류")
	_expect(str(mid.get("key", "")) == "abyss_oracle", "공허 중간보스 키 오류")
	_expect(str(mid.get("damage_source", "")) == "void_boss",
		"심연의 눈 투사체가 공허 방어구 피해 감소를 사용하지 않음")
	_expect("닻" in str(GameConfigScript.stage_info(game.VOID_STAGE).get("rule", "")),
		"공허 규칙에 닻 설명이 없음")

	var field = GravityFieldScript.new()
	field.configure(224.0, 142.0, 4.2, 18.0)
	_expect(is_equal_approx(field.radius, 224.0) and is_equal_approx(field.pull_strength, 142.0)
		and is_equal_approx(field.life, 4.2), "공허 중력장 설정값 연결 오류")

	anchor.free()
	expanded.free()
	pull_player.free()
	b0.free()
	b2.free()
	b3.free()
	pattern_boss.free()
	pattern_player.free()
	boss.free()
	field.free()
	game.player = null
	game.free()
	if failed:
		quit(1)
		return
	print("VOID_SLICE_OK")
	quit(0)
