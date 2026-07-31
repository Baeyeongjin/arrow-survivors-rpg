extends SceneTree
# 자동공격 사거리 제한과 난이도 상향 회귀 검증 (사장님 "아직도 너무 쉬움"):
#  1) 사거리 = 기준값 × 범위 소프트캡. 범위에 몰아도 무한히 늘어나지 않는다.
#  2) 레벨업 요구 XP가 이전 곡선보다 확실히 무겁고 단조 증가한다.
#  3) 몬스터 체력·접촉 피해 상향이 실제 setup에 반영된다.

const MainScript = preload("res://Main.gd")
const PlayerScript = preload("res://Player.gd")
const EnemyScript = preload("res://Enemy.gd")
const GameConfigScript = preload("res://GameConfig.gd")

var failed := false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)


func _initialize() -> void:
	var game = MainScript.new()
	var player = PlayerScript.new()
	game.player = player

	# 1) 사거리는 기준값 × _area_scale(). 소프트캡 위에서는 초과분이 30%만 반영된다.
	player.area_mult = 1.0
	_expect(is_equal_approx(game._attack_range(), game.ATTACK_RANGE_BASE),
		"기본 사거리가 기준값과 다름: %.1f" % game._attack_range())
	# 상한에 닿기 전까지는 범위 투자가 사거리에도 그대로 보상된다.
	player.area_mult = 1.3
	_expect(is_equal_approx(game._attack_range(), game.ATTACK_RANGE_BASE * 1.3),
		"상한 아래에서는 투자한 만큼 사거리가 늘어야 함: %.1f" % game._attack_range())
	# 무제한이었던 예전 동작으로 되돌아가지 않게 하드 상한을 걸어 둔다. 소프트캡 감쇠만으로는
	# 범위를 몰아준 빌드에서 1200px을 넘어(실측) 화면 밖 적 자동 처리가 되살아난다.
	# 상한은 범위 소프트캡(x1.6 = 576)보다 낮게 잡혀 있어 감쇠 구간 전에 먼저 걸린다.
	_expect(game.ATTACK_RANGE_MAX < game.ATTACK_RANGE_BASE * game.AREA_SOFT_CAP,
		"사거리 상한이 소프트캡보다 높아 감쇠가 먼저 걸린다")
	for extreme_area in [game.AREA_SOFT_CAP, 4.0, 8.0]:
		player.area_mult = float(extreme_area)
		_expect(is_equal_approx(game._attack_range(), game.ATTACK_RANGE_MAX),
			"범위 %.1f에서 사거리가 상한에 붙지 않음: %.1f" % [
				float(extreme_area), game._attack_range()])
	_expect(game.ATTACK_RANGE_MAX < 720.0,
		"사거리 상한이 화면 규모(1280x720)를 넘어섬: %.1f" % game.ATTACK_RANGE_MAX)
	# 사거리 판정은 제곱 거리 비교다. 경계 바로 안/밖이 뒤집히지 않는지 확인한다.
	player.area_mult = 1.0
	var limit: float = game._attack_range()
	_expect(Vector2.ZERO.distance_squared_to(Vector2(limit - 1.0, 0.0)) <= limit * limit
		and Vector2.ZERO.distance_squared_to(Vector2(limit + 1.0, 0.0)) > limit * limit,
		"사거리 경계 판정이 뒤집혔다")

	# 2) 레벨업 곡선: 단조 증가 + 이전 2.5배 곡선보다 무겁다.
	var previous := 0
	for level in range(1, 41):
		var need: int = game._xp_requirement(level)
		_expect(need > previous, "요구 XP가 단조 증가하지 않음 (Lv%d: %d <= %d)" % [
			level, need, previous])
		previous = need
	var late := maxi(0, 10 - 20)
	var old_curve := int((8 + 10 * 5 + int(pow(float(late), 1.35) * 0.65)) * 2.5)
	_expect(game._xp_requirement(10) > old_curve,
		"Lv10 요구 XP가 이전 곡선보다 무겁지 않음: %d <= %d" % [
			game._xp_requirement(10), old_curve])

	# 3) 몬스터 상향이 실제 스탯에 반영되는지 — 티어 배수와 시간 성장을 함께 확인한다.
	var tier: Dictionary = GameConfigScript.enemy_tiers()[0]
	var mob = EnemyScript.new()
	mob.setup(tier, 0.0)
	var expected_hp: float = 12.0 * float(tier["hp_mult"]) * 3.3   # 3차 상향과 동기
	_expect(is_equal_approx(mob.hp, expected_hp),
		"몬스터 체력 x2.8 상향 미적용: %.2f (기대 %.2f)" % [mob.hp, expected_hp])
	var expected_touch: float = 10.0 * float(tier.get("dmg_mult", 1.0)) * 2.0
	_expect(is_equal_approx(mob.touch_damage, expected_touch),
		"접촉 피해 x1.75 상향 미적용: %.2f (기대 %.2f)" % [mob.touch_damage, expected_touch])
	# max_hp는 setup이 아니라 Main._make_enemy가 런 보정까지 끝낸 뒤 세팅한다(HP바 비율용).

	# 4) XP 수입: 젬 값 배수 x2.0 + 잡몹 확률 드랍. 둘을 곱한 것이 성장 복리 루프의 입력이다.
	_expect(mob.xp_value == int(round(float(tier["xp"]) * 2.0)),
		"젬 값 배수 x2.0 미적용: %d (티어 xp=%d)" % [mob.xp_value, int(tier["xp"])])
	_expect(game.GEM_DROP_CHANCE > 0.0 and game.GEM_DROP_CHANCE < 1.0,
		"잡몹 젬 드랍이 확률이 아님(100% 드랍으로 회귀): %.2f" % game.GEM_DROP_CHANCE)
	# 총 XP 수입이 예전(드랍 100% x 값 2.4)보다 확실히 낮아야 한다. 여기가 풀리면
	# 요구 XP를 올려도 레벨업 속도가 되돌아간다.
	var income_ratio: float = game.GEM_DROP_CHANCE * (2.0 / 2.4)
	_expect(income_ratio < 0.55,
		"XP 수입이 충분히 줄지 않음: 예전의 %.0f%%" % (income_ratio * 100.0))

	mob.free()
	game.player = null
	player.free()
	game.free()
	if failed:
		quit(1)
		return
	print("ATTACK_RANGE_OK")
	quit(0)
