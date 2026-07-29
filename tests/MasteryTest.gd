extends SceneTree
# M2 무기 숙련 트리 검증:
#  1) 슬롯 상한(주무기 집중형): MAX_WEAPONS=3, MAX_PASSIVES=4.
#  2) 모든 아키타입이 갈림길 2단계(Lv4·Lv6) × a/b(name·desc·eff) 완비 + 모든 무기가 유효 매핑.
#  3) 각 갈림길이 해당 레벨 직전에 뜨고, 고르면 잠금 + 주무기가 그 단계로 진행 + 재제시 안 됨.
#  4) 잘못된 레벨/중복 선택은 무시.
#  5) 던전 무기 시간캡이 Lv8 도달 가능(진화 봉인 해제) + 비던전은 느린 페이스.
#  6) 숙련 최종 노드: 주무기 만렙 → 진화 카드, 그 외엔 없음.

const MainScript = preload("res://Main.gd")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		quit(1)


func _initialize() -> void:
	var game = MainScript.new()

	# 1) 슬롯 상한
	_expect(game.MAX_WEAPONS == 3, "MAX_WEAPONS 는 3이어야 함: %d" % game.MAX_WEAPONS)
	_expect(game.MAX_PASSIVES == 4, "MAX_PASSIVES 는 4여야 함: %d" % game.MAX_PASSIVES)

	# 2) 갈림길 완비: 아키타입별 [Lv4, Lv6] 2단계, 각 a/b(name/desc/eff)
	var fork_table: Dictionary = game.MASTERY_FORK
	var levels: Array = game.MASTERY_FORK_LEVELS
	for arch in ["sword", "axe", "staff", "dagger", "spear"]:
		_expect(fork_table.has(arch), "MASTERY_FORK 에 %s 없음" % arch)
		var tiers: Array = fork_table[arch]
		_expect(tiers.size() == levels.size(),
			"%s 갈림길 단계 수(%d)가 MASTERY_FORK_LEVELS(%d)와 다름" % [arch, tiers.size(), levels.size()])
		for tier in tiers:
			for bkey in ["a", "b"]:
				var b: Dictionary = (tier as Dictionary).get(bkey, {})
				_expect(b.has("name") and b.has("desc") and b.has("eff"),
					"%s 어떤 단계의 %s 분기에 name/desc/eff 누락" % [arch, bkey])
	for wk in (game.WEAPON_ACTIVE_ARCHETYPE as Dictionary).keys():
		var a := str(game.WEAPON_ACTIVE_ARCHETYPE[wk])
		_expect(fork_table.has(a), "무기 %s 의 아키타입 %s 가 MASTERY_FORK에 없음(분기 방치)" % [wk, a])

	game.primary_weapon = "cleave"   # sword 계열

	# 3a) 1단계 갈림길(Lv4): Lv3에서 뜬다
	game.weapons = {"cleave": levels[0] - 1}
	game.mastery_picks = {}
	_expect(game._pending_mastery_fork().size() == 2, "Lv4 직전에 갈림길 2장이 떠야 함")
	# 4) 잘못된 레벨에서는 안 뜬다
	game.weapons = {"cleave": 1}
	_expect(game._pending_mastery_fork().is_empty(), "Lv1에서 갈림길이 떠선 안 됨")
	# 3a) 1단계 확정 → 잠금 + Lv4 진행
	game.weapons = {"cleave": levels[0] - 1}
	game._take_mastery_branch(levels[0], "a")
	_expect(str(game.mastery_picks.get(levels[0], "")) == "a", "1단계 잠금값 틀림: %s" % str(game.mastery_picks))
	_expect(int(game.weapons["cleave"]) == levels[0], "1단계 선택 후 주무기 미진행: %d" % int(game.weapons["cleave"]))
	_expect(game._pending_mastery_fork().is_empty(), "1단계 선택 후 Lv4 갈림길 재제시됨")
	# 중복 무시
	game.weapons = {"cleave": levels[0] - 1}
	game._take_mastery_branch(levels[0], "b")
	_expect(str(game.mastery_picks.get(levels[0], "")) == "a", "이미 고른 1단계가 덮어써짐")

	# 3b) 2단계 갈림길(Lv6): Lv5에서 뜬다 (1단계는 이미 선택됨)
	game.weapons = {"cleave": levels[1] - 1}
	_expect(game._pending_mastery_fork().size() == 2, "Lv6 직전에 2단계 갈림길이 떠야 함")
	game._take_mastery_branch(levels[1], "b")
	_expect(str(game.mastery_picks.get(levels[1], "")) == "b", "2단계 잠금값 틀림: %s" % str(game.mastery_picks))
	_expect(int(game.weapons["cleave"]) == levels[1], "2단계 선택 후 주무기 미진행: %d" % int(game.weapons["cleave"]))
	_expect(game._pending_mastery_fork().is_empty(), "모든 갈림길 선택 후에도 재제시됨")

	# 5) 무기 시간캡: 던전(5분)에서 Lv8 도달, 비던전은 느림
	game.map_stage = 1
	game.time_survived = 0.0
	_expect(game._weapon_time_cap() == 2, "던전 초반 무기캡은 2여야 함")
	game.time_survived = 280.0
	_expect(game._weapon_time_cap() == game.MAX_WLEVEL, "던전 280s에 무기캡이 Lv8이어야 함: %d" % game._weapon_time_cap())
	game.map_stage = 0
	_expect(game._weapon_time_cap() < game.MAX_WLEVEL, "비던전 280s는 아직 만렙 캡 아님: %d" % game._weapon_time_cap())

	# 6) 숙련 최종 노드: 주무기 만렙 → 진화 카드
	game.map_stage = 1
	game.primary_weapon = "cleave"
	game.evolved = {}
	game.weapons = {"cleave": game.MAX_WLEVEL}
	_expect(not game._pending_primary_evolution().is_empty(), "주무기 만렙에 진화 카드가 떠야 함")
	game.weapons = {"cleave": game.MAX_WLEVEL - 1}
	_expect(game._pending_primary_evolution().is_empty(), "만렙 전에는 진화 카드 없어야 함")
	game.weapons = {"cleave": game.MAX_WLEVEL}
	game.evolved = {"cleave": true}
	_expect(game._pending_primary_evolution().is_empty(), "이미 진화했으면 진화 카드 없어야 함")

	game.free()
	print("MASTERY_OK")
	quit(0)
