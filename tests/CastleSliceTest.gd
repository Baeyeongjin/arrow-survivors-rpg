extends SceneTree
# M5-D 마왕성 세로 슬라이스 회귀 검증:
#  1) 성문 2곳 → 흑기사 사령관 → 마지막 성문 → 5분 마왕 아바돈 리듬.
#  2) 관문 좌표가 실제 이동 가능 영역 안이고 양 끝으로 벌어져 있다.
#  3) 관문은 시간이 아니라 봉쇄전으로만 열린다(수비대 전멸 = 개방).
#  4) 마왕 3패턴 · 45% 왕좌 게이트 · 관문 수행량별 지휘관 수 · 2단 게이트 · 5초 취약.
#  5) 슬롯별 마왕성 전용 어픽스와 전용 티어 3종.

const MainScript = preload("res://Main.gd")
const BossScript = preload("res://Boss.gd")
const PlayerScript = preload("res://Player.gd")
const GateScript = preload("res://CastleGate.gd")
const EnemyScript = preload("res://Enemy.gd")
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

	# 1) 첫 성문 → 중간보스 → 마지막 성문 → 최종 보스 순서.
	_expect(game.CASTLE_GATE_TIMES.size() == game.CASTLE_GATE_REQUIRED,
		"성문 시간표와 요구 개수가 다름")
	_expect(float(game.CASTLE_GATE_TIMES[0]) < game.CASTLE_MIDBOSS_TIME
		and game.CASTLE_MIDBOSS_TIME < float(game.CASTLE_GATE_TIMES[1])
		and float(game.CASTLE_GATE_TIMES[1]) < game.DUNGEON_BOSS_TIME,
		"성문→흑기사 사령관→성문→마왕 리듬 순서가 깨짐")
	# 마왕성만 목표가 2개다. 관문 하나가 정예 묶음 전투 하나이므로 3개면 과밀해진다.
	_expect(game.CASTLE_GATE_REQUIRED == 2, "마왕성 관문은 2곳이어야 함")

	# 2) 관문 좌표는 목표 지점 양 끝(0번·2번)을 쓴다 — 같은 방에 둘이 몰리지 않게.
	for layout_seed in LAYOUT_SEEDS:
		var layout = StageLayoutScript.make(game.CASTLE_STAGE,
			Color(GameConfigScript.stage_info(game.CASTLE_STAGE)["tint"]), layout_seed)
		_expect(layout.objective_positions.size() >= 3,
			"마왕성 목표 좌표가 3개 미만 (seed=%d)" % layout_seed)
		var first: Vector2 = layout.objective_positions[0]
		var last: Vector2 = layout.objective_positions[2]
		for gate_position in [first, last]:
			var checked: Vector2 = gate_position
			_expect(layout.is_walkable(checked, 58.0),
				"관문 좌표가 벽 안에 있음: %s (seed=%d)" % [checked, layout_seed])
			# 봉쇄전 수비대가 관문 주위 고리에 태어나므로 그 고리도 열려 있어야 한다.
			var open_ring := 0
			for sample in 24:
				var ring_point: Vector2 = checked \
					+ Vector2.from_angle(TAU * float(sample) / 24.0) \
					* (game.CASTLE_GATE_RADIUS * 0.62)
				if layout.is_walkable(ring_point, 20.0):
					open_ring += 1
			_expect(open_ring >= 6,
				"관문 수비대 소환 고리가 막혀 있음: %s (%d/24 seed=%d)" % [
					checked, open_ring, layout_seed])
		_expect(first.distance_to(last) > game.CASTLE_GATE_RADIUS * 2.0,
			"두 관문이 서로의 봉쇄 반경 안에 있음 (seed=%d)" % layout_seed)

	# 3) 관문은 봉쇄전으로만 열린다. 접근만으로도, 시간만으로도 열리지 않는다.
	var gate = GateScript.new()
	gate.configure(0, game.CASTLE_GATE_RADIUS)
	_expect(not gate.is_engaged() and not gate.is_opened(), "새 관문 초기 상태 오류")
	_expect(not gate.check_open(), "봉쇄전 전에 관문이 열림")
	_expect(gate.engage(), "첫 봉쇄전 진입이 거부됨")
	_expect(not gate.engage(), "봉쇄전이 두 번 시작됨(수비대 중복 소환)")
	var guards: Array = []
	for i in 3:
		var guard = EnemyScript.new()
		guards.append(guard)
		gate.register_guard(guard)
	_expect(gate.alive_guard_count() == 3, "수비대 등록 수 오류: %d" % gate.alive_guard_count())
	_expect(not gate.check_open(), "수비대가 살아 있는데 관문이 열림")
	for i in 2:
		guards[i].free()
	_expect(gate.alive_guard_count() == 1,
		"죽은 수비대가 계속 집계됨: %d" % gate.alive_guard_count())
	_expect(not gate.check_open(), "마지막 수비대가 남았는데 관문이 열림")
	guards[2].free()
	_expect(gate.check_open() and gate.is_opened(), "수비대 전멸 뒤 관문이 열리지 않음")
	_expect(not gate.check_open(), "개방이 두 번 통보됨")

	# 4) 관문 수행량 → 왕좌 지휘관 수. 둘 다 열면 1명, 하나도 못 열면 3명.
	var b0 = BossScript.new()
	b0.configure_castle_final(0)
	_expect(b0.castle_guard_max == 3, "관문 0 → 왕좌 지휘관 3명이어야 함")
	var b1 = BossScript.new()
	b1.configure_castle_final(1)
	_expect(b1.castle_guard_max == 2, "관문 1 → 왕좌 지휘관 2명이어야 함")
	var b2 = BossScript.new()
	b2.configure_castle_final(2)
	_expect(b2.castle_guard_max == 1, "관문 2 → 왕좌 지휘관 1명이어야 함")

	# 3패턴 순환: 처형선 → 부채꼴 → 소환 지휘.
	var pattern_boss = BossScript.new()
	var pattern_player = PlayerScript.new()
	pattern_player.position = Vector2(300.0, 0.0)
	pattern_boss.configure_castle_final(1)
	pattern_boss._start_next_castle_attack(pattern_player)
	_expect(pattern_boss._castle_state == pattern_boss.CastleState.EXECUTE_WINDUP,
		"첫 패턴이 처형선 예고가 아님")
	pattern_boss._start_next_castle_attack(pattern_player)
	_expect(pattern_boss._castle_state == pattern_boss.CastleState.FAN_WINDUP,
		"둘째 패턴이 부채꼴 예고가 아님")
	pattern_boss._start_next_castle_attack(pattern_player)
	_expect(pattern_boss._castle_state == pattern_boss.CastleState.SUMMON_WINDUP,
		"셋째 패턴이 소환 지휘 예고가 아님")

	# 45% 왕좌 게이트 + 2단 게이트(지휘관 → 보호막) + 5초 취약.
	var boss = BossScript.new()
	boss.max_hp = 1000.0
	boss.hp = 1000.0
	boss.configure_castle_final(0)
	boss.take_damage(700.0, false, "phys")
	_expect(is_equal_approx(boss.hp, 450.0) and boss.castle_throne_active
		and boss.castle_guards_alive == 3,
		"45%% 왕좌 게이트 또는 지휘관 3명 시작 실패 (hp=%.1f)" % boss.hp)
	# 지휘관이 살아 있으면 보호막도 본체도 전혀 깎이지 않는다.
	var shield_before: float = boss.castle_shield_hp
	boss.take_damage(500.0, false, "phys")
	_expect(is_equal_approx(boss.castle_shield_hp, shield_before)
		and is_equal_approx(boss.hp, 450.0),
		"지휘관이 남았는데 피해가 통과함 (shield=%.1f hp=%.1f)" % [
			boss.castle_shield_hp, boss.hp])
	for i in 3:
		boss.on_castle_guard_killed()
	_expect(boss.castle_guards_alive == 0, "지휘관 전멸 집계 실패")
	# 전멸 뒤에는 보호막만 깎인다. 보호막을 부수면 5초 취약이 열린다.
	boss.take_damage(boss.castle_shield_hp_max * 0.5, false, "phys")
	_expect(boss.castle_throne_active and is_equal_approx(boss.hp, 450.0),
		"보호막이 남았는데 본체 체력이 깎임: %.1f" % boss.hp)
	boss.take_damage(boss.castle_shield_hp_max, false, "phys")
	_expect(not boss.castle_throne_active
		and is_equal_approx(boss.vulnerable_t, boss.CASTLE_VULNERABLE_TIME),
		"보호막 파괴 뒤 5초 취약이 열리지 않음")
	boss.take_damage(100.0, false, "phys")
	_expect(is_equal_approx(boss.hp, 270.0), "왕좌 취약 1.8배 피해 오류: %.1f" % boss.hp)
	_expect(boss.uses_pattern_damage(), "마왕이 접촉 피해 대신 패턴 피해를 쓰지 않음")

	# 5) 슬롯별 전용 장비와 실제 배수, 전용 티어 3종.
	var expected_specials := {
		"weapon": "siegebreaker", "armor": "bulwark_of_gates", "trinket": "commanders_seal",
	}
	for slot in expected_specials:
		var item: Dictionary = game._roll_castle_gear(true, slot)
		_expect(str(item.get("dungeon_tag", "")) == "castle",
			"%s 장비에 마왕성 태그 없음" % slot)
		_expect(str(item.get("special", {}).get("key", "")) == expected_specials[slot],
			"%s 전용 효과 키 오류: %s" % [slot, item.get("special", {})])
		_expect(int(game.RARITY_ORDER.get(str(item.get("rarity", "")), 0)) >= 3,
			"확정 마왕성 장비가 에픽 미만")
	game.equipped = {"weapon": game._roll_castle_gear(true, "weapon"), "armor": {}, "trinket": {}}
	_expect(is_equal_approx(game._castle_shield_damage_multiplier(), 1.35),
		"공성의 무기 보호막 파괴 피해 +35% 미적용")
	game.equipped = {"weapon": {}, "armor": game._roll_castle_gear(true, "armor"), "trinket": {}}
	_expect(is_equal_approx(game._castle_incoming_damage_multiplier(), 0.74),
		"관문의 방벽 패턴 피해 -26% 미적용")

	var elite := GameConfigScript.castle_elite_tier()
	var mid := GameConfigScript.castle_midboss_tier()
	var throne := GameConfigScript.castle_guard_tier()
	_expect(str(elite.get("key", "")) == "gate_commander", "마왕성 정예 키 오류")
	_expect(str(mid.get("key", "")) == "black_marshal", "마왕성 중간보스 키 오류")
	_expect(str(throne.get("key", "")) == "throne_guard", "왕좌 지휘관 키 오류")
	# 전용 티어는 고유 키를 쓰지만 스프라이트는 base 몹과 공유한다(애니 폴더 재사용).
	for tier in [elite, mid, throne]:
		_expect(str(tier.get("sprite", "")).begins_with("res://assets/enemies/"),
			"전용 티어 스프라이트 경로 오류: %s" % tier.get("sprite", ""))
		_expect(not GameConfigScript.elite_special(str(tier["key"])).is_empty(),
			"전용 티어 %s에 특수 공격이 없음" % tier["key"])
	_expect("성문" in str(GameConfigScript.stage_info(game.CASTLE_STAGE).get("rule", "")),
		"마왕성 규칙에 성문 설명이 없음")

	gate.free()
	b0.free()
	b1.free()
	b2.free()
	pattern_boss.free()
	pattern_player.free()
	boss.free()
	game.free()
	if failed:
		quit(1)
		return
	print("CASTLE_SLICE_OK")
	quit(0)
