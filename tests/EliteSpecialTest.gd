extends SceneTree
# 정예·중간보스 특수 공격과 플레이어 피격 넉백 회귀 검증:
#  1) 22종 일반 몹 + 던전 전용 정예·중간보스 8종 전부에 특수 공격이 배정돼 있다.
#  2) 상태기계: 비정예/사거리 밖은 발동하지 않고, 전조 동안 일반 행동을 멈춘다.
#  3) 지면 강타는 붙어 있을 때만 시작한다(멀리서 허공을 치면 전조를 학습할 수 없다).
#  4) 플레이어 넉백은 때린 쪽 반대로 밀리고 감쇠하며, 회피 중에는 무시된다.

const EnemyScript = preload("res://Enemy.gd")
const PlayerScript = preload("res://Player.gd")
const GameConfigScript = preload("res://GameConfig.gd")

var failed := false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)


func _make_elite(key: String) -> Enemy:
	var mob = EnemyScript.new()
	mob.setup(GameConfigScript.tier_by_key(key), 0.0)
	mob.elite = true
	return mob


func _initialize() -> void:
	# 1) 배정 누락이 없어야 한다. 정예로 승격됐는데 특수 공격이 없으면 그냥 체력만 두꺼운 몹이다.
	for tier in GameConfigScript.enemy_tiers():
		var key := str(tier["key"])
		var special: Dictionary = GameConfigScript.elite_special(key)
		_expect(not special.is_empty(), "일반 몹 %s에 특수 공격이 없음" % key)
		_expect(GameConfigScript.ELITE_SPECIALS.has(str(special.get("kind", ""))),
			"%s의 특수 공격 종류가 정의 표에 없음: %s" % [key, special])
	for dungeon_tier in [
		GameConfigScript.hell_elite_tier(), GameConfigScript.hell_midboss_tier(),
		GameConfigScript.graveyard_elite_tier(), GameConfigScript.graveyard_midboss_tier(),
		GameConfigScript.glacier_elite_tier(), GameConfigScript.glacier_midboss_tier(),
		GameConfigScript.void_elite_tier(), GameConfigScript.void_midboss_tier(),
	]:
		var dungeon_key := str(dungeon_tier["key"])
		_expect(not GameConfigScript.elite_special(dungeon_key).is_empty(),
			"던전 전용 티어 %s에 특수 공격이 없음" % dungeon_key)
	_expect(GameConfigScript.elite_special("no_such_monster").is_empty(),
		"미정의 키가 특수 공격을 반환함")

	# 2) 비정예는 절대 발동하지 않는다. 잡몹까지 큰 기술을 쓰면 전조가 의미를 잃는다.
	var grunt = EnemyScript.new()
	grunt.setup(GameConfigScript.tier_by_key("skeleton"), 0.0)
	grunt._sp_cd = 0.0
	_expect(not grunt._tick_special(0.016, Vector2.RIGHT, 100.0),
		"비정예가 특수 공격을 발동함")

	# 사거리 밖에서도 발동하지 않는다.
	var archer := _make_elite("skeleton")
	archer._sp_cd = 0.0
	_expect(not archer._tick_special(0.016, Vector2.RIGHT, EnemyScript.SPECIAL_RANGE + 50.0),
		"사거리 밖에서 특수 공격이 발동함")
	_expect(archer._sp_state == 0, "발동 실패인데 상태가 남음: %d" % archer._sp_state)

	# 전조 진입 → 전조 유지 → 발동 → 후딜 → 쿨다운 복귀.
	var volley := _make_elite("skeleton")
	volley._sp_cd = 0.0
	_expect(volley._tick_special(0.016, Vector2.RIGHT, 200.0)
		and volley._sp_state == 1, "사거리 안에서 전조가 시작되지 않음")
	_expect(volley._sp_lock == Vector2.RIGHT, "전조 시작 시 조준 방향이 잠기지 않음")
	_expect(volley._attacking, "전조 중에는 공격 포즈가 유지돼야 함")
	# 전조 도중에는 계속 true(= 일반 행동 정지)를 반환한다.
	_expect(volley._tick_special(0.1, Vector2.UP, 200.0) and volley._sp_state == 1,
		"전조 도중에 상태가 풀림")
	_expect(volley._sp_lock == Vector2.RIGHT, "전조 도중 조준 방향이 바뀜")
	# 남은 전조를 모두 흘리면 발동하고 후딜로 넘어간다. 부모가 없으므로 투사체는 생성되지 않는다.
	volley._tick_special(EnemyScript.SPECIAL_WINDUP, Vector2.RIGHT, 200.0)
	_expect(volley._sp_state == 2, "전조가 끝났는데 후딜로 넘어가지 않음: %d" % volley._sp_state)
	_expect(volley._sp_flash > 0.0, "발동 순간 섬광이 켜지지 않음")
	# 발동 프레임에는 타격 포즈가 남아 있고(그게 곧 타격 연출), 다음 프레임부터 풀린다.
	_expect(volley._attacking, "발동 프레임에 타격 포즈가 없음")
	volley._tick_special(0.016, Vector2.RIGHT, 200.0)
	_expect(not volley._attacking, "후딜 중에는 공격 포즈가 풀려야 함")
	volley._tick_special(EnemyScript.SPECIAL_RECOVER, Vector2.RIGHT, 200.0)
	_expect(volley._sp_state == 0, "후딜이 끝났는데 상태가 남음: %d" % volley._sp_state)
	_expect(is_equal_approx(volley._sp_cd, EnemyScript.SPECIAL_CD),
		"특수 공격 쿨다운이 초기화되지 않음: %.2f" % volley._sp_cd)

	# 3) 지면 강타는 근접 전용이다.
	var slammer := _make_elite("orc")
	_expect(str(GameConfigScript.elite_special("orc").get("kind", "")) == "ground_slam",
		"오크 특수 공격이 지면 강타가 아님")
	slammer._sp_cd = 0.0
	_expect(not slammer._tick_special(0.016, Vector2.RIGHT, 320.0),
		"지면 강타가 원거리에서 발동함")
	slammer._sp_cd = 0.0
	_expect(slammer._tick_special(0.016, Vector2.RIGHT, 60.0),
		"지면 강타가 근접에서 발동하지 않음")

	# 4) 플레이어 넉백: 반대 방향 + 감쇠 + 회피 무시.
	var hero = PlayerScript.new()
	hero.position = Vector2(500.0, 500.0)
	hero.knockback(Vector2(450.0, 500.0), PlayerScript.KNOCKBACK_MELEE)
	_expect(hero._kb.x > 0.0 and is_zero_approx(hero._kb.y),
		"넉백이 때린 쪽 반대로 향하지 않음: %s" % hero._kb)
	_expect(is_equal_approx(hero._kb.length(), PlayerScript.KNOCKBACK_MELEE),
		"넉백 초기 속도 오류: %.1f" % hero._kb.length())
	var before: float = hero.position.x
	hero._process(0.05)
	_expect(hero.position.x > before, "넉백이 실제 이동으로 반영되지 않음")
	for _i in 40:
		hero._process(0.02)
	_expect(hero._kb.length_squared() <= 1.0,
		"넉백이 감쇠하지 않고 남음: %s" % hero._kb)
	# 넉백 총 이동은 회피 거리보다 짧아야 한다 — 조작권을 오래 빼앗으면 안 된다.
	var travel: float = hero.position.x - before
	_expect(travel < PlayerScript.DODGE_DISTANCE,
		"넉백 이동 거리가 회피 거리보다 큼: %.1f" % travel)
	hero.position = Vector2(500.0, 500.0)
	hero._kb = Vector2.ZERO
	hero.dodge_t = 0.1
	hero.knockback(Vector2(450.0, 500.0), PlayerScript.KNOCKBACK_MELEE)
	_expect(hero._kb == Vector2.ZERO, "회피 중에 넉백이 적용됨")

	grunt.free()
	archer.free()
	volley.free()
	slammer.free()
	hero.free()
	if failed:
		quit(1)
		return
	print("ELITE_SPECIAL_OK")
	quit(0)
