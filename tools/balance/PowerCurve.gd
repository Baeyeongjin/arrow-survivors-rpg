extends SceneTree
# 성장 곡선 실측: 플레이어 화력과 적 실효 HP가 런 동안 각각 몇 배로 자라는가.
#
# 왜 필요한가: "후반에 몬스터가 다 한방"이라는 체감의 원인을 감으로 찾으면 안 된다.
# 레벨 요구 XP는 이미 세 번(2.5배 → 3.6배) 올렸는데도 체감이 그대로다. 즉 레벨 속도가
# 아니라 다른 축이 범인일 수 있다. 두 곡선을 나란히 재서 어디서 벌어지는지 본다.
#
# 무엇을 재는가
#   적 실효 HP  — 엔진의 실제 코드로 계산한다(Enemy.setup + 런 스케일링 공식).
#                 플레이어 레벨에 따라 티어가 바뀌므로 티어 상승분도 포함된다.
#   플레이어 화력 — 코드에 결정적으로 박혀 있는 것만 센다.
#                 무기 레벨 배율(_weapon_level_scale), 무기 개수, 진화 배율.
#
# 무엇을 빼는가 (중요)
#   damage_mult(레벨업 카드 +0.06/+0.10, 스탯 포인트 +0.04, 패시브, 장비)는 뺐다.
#   픽 순서에 따라 달라져 결정적으로 모델링할 수 없다. 다만 이들은 전부 화력을
#   올리기만 하므로, 아래 결과는 실제 격차의 '하한'이다. 실제는 이보다 더 벌어진다.
#
# 실행:
#   godot --headless --path . --script res://tools/balance/PowerCurve.gd -- [--minutes=30] [--stage=1]

const MainScript = preload("res://Main.gd")
const GameConfigScript = preload("res://GameConfig.gd")

# 레벨은 초당 XP 수입을 게임의 실제 _xp_requirement에 통과시켜 구한다.
# 분당 몇 레벨을 상수로 박으면 곡선을 고쳐도 프로브가 옛 가정을 계속 쓴다.
#
# 수입 91 XP/초는 사장님 실측(2층 3분 시점 Lv51, 원정 1층 포함 약 5분)을
# 개편 전 곡선으로 역산한 값이다. 곡선을 바꿔도 수입은 그대로이므로 비교 기준이 된다.
const XP_PER_SECOND := 91.0
const MAX_LEVEL := 200

# 무기는 레벨업 카드로 올라가고 8레벨에서 배율이 상한이다(_weapon_level_scale).
# 카드를 무기에 몰아준다는 가정으로, 무기 개수가 적을수록 빨리 만렙이 된다.
const WEAPON_MAX_LEVEL := 8
# 레벨업 중 무기 강화에 쓰이는 비율. 나머지는 패시브·스탯으로 샌다.
const WEAPON_CARD_SHARE := 0.5


func _initialize() -> void:
	var minutes := 30
	var stage := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--minutes="):
			minutes = int(arg.split("=")[1])
		elif arg.begins_with("--stage="):
			stage = int(arg.split("=")[1])

	var game = MainScript.new()
	game.diff_enemy_hp = 1.0
	game.diff_enemy_speed = 1.0
	game.run_pressure_mult = 1.0

	print("=".repeat(86))
	print("성장 곡선 실측 — 스테이지 %d, %d분, XP 수입 %.0f/초" % [stage, minutes, XP_PER_SECOND])
	print("=".repeat(86))
	print("화력에는 damage_mult(카드·스탯·패시브·장비)를 넣지 않았다. 실제 격차는 아래보다 크다.")
	print("")
	print("%5s %6s %-12s %10s %8s %9s %9s %9s" % [
		"분", "레벨", "적 티어", "적 HP", "HP배수", "무기1", "무기2", "무기3"])
	print("-".repeat(86))

	var base_hp := 0.0
	var base_power := {}
	var rows: Array = []

	for minute in range(0, minutes + 1, 2):
		var t := float(minute) * 60.0
		var level: int = _level_at(game, t)
		var tier: Dictionary = GameConfigScript.pick_enemy_tier(level, stage)

		var probe := Enemy.new()
		probe.setup(tier, t)
		game._apply_enemy_run_scaling(probe, t)
		var hp: float = probe.hp
		probe.free()

		if base_hp <= 0.0:
			base_hp = hp

		var powers := {}
		for count in [1, 2, 3]:
			powers[count] = _player_power(game, level, count)
			if not base_power.has(count):
				base_power[count] = powers[count]

		print("%5d %6d %-12s %10.0f %7.2fx %9.2f %9.2f %9.2f" % [
			minute, level, str(tier.get("name", "?")), hp, hp / maxf(1.0, base_hp),
			powers[1], powers[2], powers[3]])
		rows.append({"minute": minute, "hp": hp, "powers": powers})

	print("-".repeat(86))
	print("\n[핵심] 시작 대비 배수와 '적을 한 번에 몇 마리 몫으로 때리나'(화력배수 / HP배수)")
	print("%5s %9s %12s %12s %12s" % ["분", "HP배수", "무기1", "무기2", "무기3"])
	for row in rows:
		var hp_mult: float = float(row["hp"]) / maxf(1.0, base_hp)
		var line := "%5d %8.2fx" % [row["minute"], hp_mult]
		for count in [1, 2, 3]:
			var pm: float = float(row["powers"][count]) / maxf(0.001, float(base_power[count]))
			line += " %11.2fx" % (pm / maxf(0.01, hp_mult))
		print(line)
	print("\n마지막 열들이 1.00x면 성장과 적 강화가 균형이다. 값이 커질수록 적이 물러진다.")

	# 무기 배율이 일찍 상한에 닿으므로, 그 뒤의 성장은 전부 damage_mult가 낸다.
	# 그렇다면 "적과 보조를 맞추려면 damage_mult가 얼마여야 하는가"를 역산할 수 있다.
	# 실제 게임이 이보다 많이 주면 그 초과분이 곧 '몬스터가 한방'인 이유다.
	# 실제 상한을 읽는다. 숫자를 박아두면 MAX_WEAPONS를 고쳐도 옛 열을 계속 보게 된다.
	var slots: int = clampi(MainScript.MAX_WEAPONS, 1, 3)
	print("\n[역산] 적과 보조를 맞추는 데 필요한 damage_mult (무기 %d개 = 현재 MAX_WEAPONS)" % slots)
	print("%5s %9s %14s %16s" % ["분", "HP배수", "무기화력배수", "필요 damage_mult"])
	for row in rows:
		var hp_mult: float = float(row["hp"]) / maxf(1.0, base_hp)
		var pm: float = float(row["powers"][slots]) / maxf(0.001, float(base_power[slots]))
		print("%5d %8.2fx %13.2fx %15.2fx" % [row["minute"], hp_mult, pm, hp_mult / maxf(0.01, pm)])
	print("\n레벨업 카드는 회당 +0.06~0.10, 스탯 포인트는 +0.04다.")
	print("필요치를 넘는 순간부터 적이 한방에 죽기 시작한다.")
	game.free()
	quit(0)


# 게임의 실제 _xp_requirement를 그대로 걸어 시각 t의 레벨을 구한다.
func _level_at(game, seconds: float) -> int:
	var budget := XP_PER_SECOND * seconds
	var level := 1
	while level < MAX_LEVEL:
		var need: float = float(game._xp_requirement(level))
		if budget < need:
			break
		budget -= need
		level += 1
	return level


# 결정적으로 계산 가능한 화력만 센다. 무기 레벨 배율 × 무기 수 × 진화.
func _player_power(game, level: int, weapon_count: int) -> float:
	# 레벨업 카드의 절반이 무기로 가고, 그것을 보유 무기가 나눠 갖는다고 본다.
	var weapon_cards := float(level - 1) * WEAPON_CARD_SHARE
	var per_weapon: float = weapon_cards / float(weapon_count)
	var weapon_level: int = clampi(1 + int(per_weapon), 1, WEAPON_MAX_LEVEL)
	var scale: float = game._weapon_level_scale(weapon_level)
	# 진화는 무기가 만렙에 닿아야 열린다. 만렙이면 1.45배(_fire_weapon의 진화 배율).
	var evo: float = 1.45 if weapon_level >= WEAPON_MAX_LEVEL else 1.0
	return scale * evo * float(weapon_count)
