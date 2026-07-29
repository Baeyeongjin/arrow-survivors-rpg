extends SceneTree
# M2 무기 숙련 분기 검증:
#  1) 주무기 숙련 4단계 직전(Lv3)에 갈림길 2장이 뜬다.
#  2) 분기를 고르면 mastery_branch 잠금 + 주무기가 숙련 단계로 진행 + 재제시 안 됨.
#  3) 잘못된 레벨/미선택 조건에서는 갈림길이 안 뜬다.
#  4) 모든 무기 아키타입이 MASTERY_FORK에 a/b(name·desc·eff) 완비 → 주무기가 분기 없이 방치되지 않음.
#  5) 슬롯 상한(주무기 집중형): MAX_WEAPONS=3, MAX_PASSIVES=4.

const MainScript = preload("res://Main.gd")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		quit(1)


func _initialize() -> void:
	var game = MainScript.new()

	# 5) 슬롯 상한
	_expect(game.MAX_WEAPONS == 3, "MAX_WEAPONS 는 3이어야 함(주무기1+보조2): %d" % game.MAX_WEAPONS)
	_expect(game.MAX_PASSIVES == 4, "MAX_PASSIVES 는 4여야 함: %d" % game.MAX_PASSIVES)

	# 4) 모든 아키타입 fork 완비 + 모든 무기가 유효 아키타입으로 매핑
	var fork_table: Dictionary = game.MASTERY_FORK
	for arch in ["sword", "axe", "staff", "dagger", "spear"]:
		_expect(fork_table.has(arch), "MASTERY_FORK 에 %s 아키타입 없음" % arch)
		for bkey in ["a", "b"]:
			var b: Dictionary = (fork_table[arch] as Dictionary).get(bkey, {})
			_expect(b.has("name") and b.has("desc") and b.has("eff"),
				"%s.%s 분기에 name/desc/eff 누락" % [arch, bkey])
	for wk in (game.WEAPON_ACTIVE_ARCHETYPE as Dictionary).keys():
		var a := str(game.WEAPON_ACTIVE_ARCHETYPE[wk])
		_expect(fork_table.has(a), "무기 %s 의 아키타입 %s 가 MASTERY_FORK에 없음(분기 방치)" % [wk, a])

	# 1) 갈림길 대기: 주무기 sword 계열(cleave) Lv3, 분기 미선택
	game.primary_weapon = "cleave"
	game.weapons = {"cleave": game.MASTERY_FORK_LEVEL - 1}
	game.mastery_branch = ""
	var fork := game._pending_mastery_fork()
	_expect(fork.size() == 2, "숙련 4단계 직전에 갈림길 2장이 떠야 함: %d" % fork.size())
	_expect(str(fork[0].get("title", "")).contains("숙련"), "갈림길 카드 제목이 숙련 표기 아님")

	# 3) 잘못된 레벨에서는 안 뜬다
	game.weapons = {"cleave": 1}
	_expect(game._pending_mastery_fork().is_empty(), "Lv1에서 갈림길이 떠선 안 됨")

	# 2) 분기 확정 → 잠금 + 주무기 숙련 단계 진행 (player 없이 데이터 경로만)
	game.weapons = {"cleave": game.MASTERY_FORK_LEVEL - 1}
	game.mastery_branch = ""
	game._take_mastery_branch("sword", "a")
	_expect(game.mastery_branch == "sword:a", "분기 잠금값이 틀림: %s" % game.mastery_branch)
	_expect(int(game.weapons["cleave"]) == game.MASTERY_FORK_LEVEL,
		"분기 선택 후 주무기가 숙련 단계로 진행되지 않음: %d" % int(game.weapons["cleave"]))
	_expect(game._pending_mastery_fork().is_empty(), "분기 선택 후에도 갈림길이 재제시됨")

	# 중복 호출은 무시(등급 보너스 재호출 방지)
	game.weapons = {"cleave": 2}
	game._take_mastery_branch("sword", "b")
	_expect(game.mastery_branch == "sword:a", "이미 고른 분기가 재호출로 덮어써짐: %s" % game.mastery_branch)

	# 6) 무기 시간캡: 던전(5분)에서 Lv8 도달 가능해야 함(진화 봉인 해제).
	game.map_stage = 1
	game.time_survived = 0.0
	_expect(game._weapon_time_cap() == 2, "던전 초반 무기캡은 2여야 함: %d" % game._weapon_time_cap())
	game.time_survived = 280.0
	_expect(game._weapon_time_cap() == game.MAX_WLEVEL,
		"던전 보스 시간(280s)에 무기캡이 Lv8이어야 진화 도달 가능: %d" % game._weapon_time_cap())
	game.map_stage = 0   # 일반/심연은 느린 뱀서 페이스
	_expect(game._weapon_time_cap() < game.MAX_WLEVEL,
		"비던전 280s에서는 아직 만렙 캡이 아니어야 함: %d" % game._weapon_time_cap())

	# 7) 숙련 최종 노드: 주무기 만렙 → 진화 카드, 그 외엔 없음.
	game.map_stage = 1
	game.primary_weapon = "cleave"
	game.evolved = {}
	game.weapons = {"cleave": game.MAX_WLEVEL}
	var evo := game._pending_primary_evolution()
	_expect(not evo.is_empty(), "주무기 만렙에 진화 카드가 떠야 함")
	_expect(str(evo.get("title", "")).contains("진화"), "진화 카드 제목이 아님: %s" % str(evo.get("title", "")))
	game.weapons = {"cleave": game.MAX_WLEVEL - 1}
	_expect(game._pending_primary_evolution().is_empty(), "만렙 전에는 진화 카드가 없어야 함")
	game.weapons = {"cleave": game.MAX_WLEVEL}
	game.evolved = {"cleave": true}
	_expect(game._pending_primary_evolution().is_empty(), "이미 진화했으면 진화 카드가 없어야 함")

	game.free()
	print("MASTERY_OK")
	quit(0)
