class_name Boss
extends Node2D

const SPRITE := "res://assets/boss/boss.png"

var key := "boss_1"   # 스테이지별 보스 (boss_1 ~ boss_5)
var max_hp := 1000.0
var hp := 1000.0
var radius := 42.0
var move_speed := 95.0
# VS식 보스: 별도 탄막 없이 플레이어를 지속 추격하는 엘리트형 적.
# Main.gd의 옛 패턴 함수는 도전 모드용 참고 코드로만 남겨두고 호출하지 않는다.
var _anim_t := 0.0
var _atk_t := 0.0
var _atk_play := 0.0   # >0이면 공격 애니 재생 중
var is_reaper := false  # 사신 피날레 보스 (특별 연출)
var weak := ""          # 약점 속성 (×1.5). 던전 보스는 던전 테마 속성에 약함 (Phase 2에서 세팅)
var resist := ""        # 저항 속성 (×0.6)
# 텔레그래프: 특수공격 전 예비동작(경고). 이 시간 동안 정지+붉게 충전 후 발사.
const TELE_DUR := 0.85
var _tele_t := 0.0
var _dmg_accum := 0.0   # 지속피해 누적 (0 표시 방지)
var _dmg_flush := 0.0

# M3 지옥 최종 보스: 예고 공격 → 화염 갑옷 파괴 → 짧은 딜타임의 반복 구조.
const HELL_ARMOR_THRESHOLDS := [0.70, 0.35]
const HELL_VULNERABLE_TIME := 5.0
const HELL_SLAM_RADIUS := 178.0
enum HellState { CHASE, SLAM_WINDUP, CHARGE_WINDUP, CHARGE, VOLLEY_WINDUP, RECOVERY, STUNNED }

var hell_final := false
var hell_phase := 1
var armor_max := 0.0
var armor_hp := 0.0
var vulnerable_t := 0.0
var attack_damage := 28.0
var unsealed_fissures := 0

var _hell_state: int = HellState.CHASE
var _hell_t := 1.25
var _hell_attack_index := 0
var _hell_lock_dir := Vector2.DOWN
var _hell_charge_hit := false
var _hell_armor_index := 0

# M5-A 묘지 최종 보스: 접촉 피해 없이 예고 패턴 3종(부채꼴 뼈파동·지연 묘지폭발·직선 영혼돌진) +
# 체력 60%에서 시작하는 영혼 방패(핵 파괴) 국면. 방패 핵은 어떤 무기·속성으로도 부순다.
const GRAVE_VULNERABLE_TIME := 5.0
const GRAVE_SHIELD_THRESHOLD := 0.60
const GRAVE_FAN_RADIUS := 150.0
const GRAVE_EXPLODE_RADIUS := 128.0
enum GraveState { CHASE, FAN_WINDUP, EXPLODE_WINDUP, CHARGE_WINDUP, CHARGE, RECOVERY, STUNNED }

var grave_final := false
var grave_phase := 1
var grave_shield_active := false
var grave_shield_started := false
var grave_shield_core_max := 1
var grave_shield_cores := 1
var grave_core_hp := 0.0
var grave_core_hp_max := 0.0
var sealed_graves := 0

var _grave_state: int = GraveState.CHASE
var _grave_t := 1.25
var _grave_attack_index := 0
var _grave_lock_dir := Vector2.DOWN
var _grave_charge_hit := false
var _grave_explode_pos := Vector2.ZERO

# M5-B 빙하 최종 보스: 고드름 부채·빙결 파동·지연 분출의 3개 예고 패턴과
# 70%/35% 얼음 갑옷. 화염이 빠르지만 모든 속성으로 갑옷을 파괴할 수 있다.
const GLACIER_ARMOR_THRESHOLDS := [0.70, 0.35]
const GLACIER_VULNERABLE_TIME := 5.0
const GLACIER_RING_RADIUS := 190.0
const GLACIER_RING_WIDTH := 34.0
const GLACIER_ERUPT_RADIUS := 132.0
enum GlacierState { CHASE, SHARD_WINDUP, RING_WINDUP, ERUPT_WINDUP, RECOVERY, STUNNED }

var glacier_final := false
var glacier_phase := 1
var lit_braziers := 0
var unlit_braziers := 3

var _glacier_state: int = GlacierState.CHASE
var _glacier_t := 1.25
var _glacier_attack_index := 0
var _glacier_lock_dir := Vector2.DOWN
var _glacier_erupt_pos := Vector2.ZERO
var _glacier_armor_index := 0

# M5-C 공허 최종 보스: 시선 원뿔·회전 광선·중력 붕괴의 3개 예고 패턴과
# 55% 분신 핵 국면. 안정화한 공허 닻이 많을수록 분신 핵 수가 줄어든다.
const VOID_ECHO_THRESHOLD := 0.55
const VOID_VULNERABLE_TIME := 5.0
const VOID_GAZE_RADIUS := 330.0
const VOID_GAZE_HALF_ANGLE := 0.58
const VOID_LASER_LENGTH := 430.0
const VOID_LASER_WIDTH := 18.0
const VOID_LASER_SWEEP_TIME := 1.45
const VOID_WELL_RADIUS := 224.0
enum VoidState { CHASE, GAZE_WINDUP, LASER_WINDUP, LASER_SWEEP, WELL_WINDUP, RECOVERY, STUNNED }

var void_final := false
var void_phase := 1
var stabilized_anchors := 0
var void_echo_active := false
var void_echo_started := false
var void_echo_core_max := 1
var void_echo_cores := 1
var void_core_hp := 0.0
var void_core_hp_max := 0.0

var _void_state: int = VoidState.CHASE
var _void_t := 1.25
var _void_attack_index := 0
var _void_lock_dir := Vector2.DOWN
var _void_well_pos := Vector2.ZERO
var _void_laser_angle := 0.0
var _void_laser_sweep_dir := 1.0

func _ready() -> void:
	add_to_group("boss")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func configure_hell_final(unsealed: int) -> void:
	hell_final = true
	unsealed_fissures = maxi(0, unsealed)
	weak = "ice"
	resist = "fire"
	hell_phase = 1
	armor_max = 0.0
	armor_hp = 0.0
	vulnerable_t = 0.0
	_hell_state = HellState.CHASE
	_hell_t = 2.45   # 등장 배너가 사라진 뒤 첫 패턴을 시작한다.
	_hell_attack_index = 0
	_hell_armor_index = 0


func uses_pattern_damage() -> bool:
	return hell_final or grave_final or glacier_final or void_final


func hell_armor_element_multiplier(element: String) -> float:
	match element:
		"ice":
			return 2.5
		"fire":
			return 0.25
		"dark":
			return 0.80
	return 1.0


func glacier_armor_element_multiplier(element: String) -> float:
	match element:
		"fire":
			return 2.5
		"ice":
			return 0.55
		"dark":
			return 0.85
	return 1.0


func configure_glacier_final(lit: int) -> void:
	glacier_final = true
	lit_braziers = clampi(lit, 0, 3)
	unlit_braziers = maxi(0, 3 - lit_braziers)
	weak = "fire"
	resist = "ice"
	glacier_phase = 1
	armor_max = 0.0
	armor_hp = 0.0
	vulnerable_t = 0.0
	_glacier_state = GlacierState.CHASE
	_glacier_t = 2.45
	_glacier_attack_index = 0
	_glacier_armor_index = 0


func configure_void_final(stabilized: int) -> void:
	void_final = true
	stabilized_anchors = clampi(stabilized, 0, 3)
	weak = "holy"
	resist = "dark"
	void_phase = 1
	void_echo_active = false
	void_echo_started = false
	void_echo_core_max = maxi(1, 4 - stabilized_anchors)
	void_echo_cores = void_echo_core_max
	void_core_hp = 0.0
	void_core_hp_max = 0.0
	vulnerable_t = 0.0
	_void_state = VoidState.CHASE
	_void_t = 2.45
	_void_attack_index = 0
	_void_laser_angle = 0.0


func _process(delta: float) -> void:
	_anim_t += delta
	var pl := get_tree().get_first_node_in_group("player") as Player
	if pl:
		if hell_final:
			_process_hell(delta, pl)
		elif grave_final:
			_process_grave(delta, pl)
		elif glacier_final:
			_process_glacier(delta, pl)
		elif void_final:
			_process_void(delta, pl)
		else:
			var to: Vector2 = pl.position - position
			# 일반 보스는 기존 추격형 동작을 보존한다. 지옥 보스만 패턴 전투를 사용한다.
			if to.length() > 8.0:
				var main := get_parent()
				if main and main.has_method("stage_enemy_step"):
					position = main.stage_enemy_step(position, pl.position, move_speed * delta, radius)
				else:
					position += to.normalized() * move_speed * delta
				_atk_play = max(_atk_play, 0.5)   # 이동/접근 모션 유지
	if _atk_play > 0.0:
		_atk_play -= delta
		_atk_t += delta
	# 지속피해 누적 표시 (0.35초마다 합산 — 오라·회전검 딜 가시화, "0" 표시 방지)
	if _dmg_accum > 0.0:
		_dmg_flush += delta
		if _dmg_flush >= 0.35:
			var mm := get_parent()
			if mm and mm.has_method("_spawn_dmg_num") and _dmg_accum >= 1.0:
				mm._spawn_dmg_num(position + Vector2(0, -radius * 0.5), int(round(_dmg_accum)), true)
				_dmg_accum = 0.0
			_dmg_flush = 0.0
	queue_redraw()


func _process_hell(delta: float, pl: Player) -> void:
	var main := get_parent()
	if _hell_state == HellState.STUNNED:
		vulnerable_t = maxf(0.0, vulnerable_t - delta)
		if vulnerable_t <= 0.0:
			_hell_state = HellState.CHASE
			_hell_t = maxf(0.72, 1.32 - hell_phase * 0.16)
		return

	_hell_t -= delta
	match _hell_state:
		HellState.CHASE:
			var desired_distance := 126.0
			if position.distance_to(pl.position) > desired_distance:
				if main and main.has_method("stage_enemy_step"):
					position = main.stage_enemy_step(position, pl.position,
						move_speed * (1.0 + (hell_phase - 1) * 0.10) * delta, radius)
				else:
					position = position.move_toward(pl.position, move_speed * delta)
				_atk_play = maxf(_atk_play, 0.35)
			if _hell_t <= 0.0:
				_start_next_hell_attack(pl)
		HellState.SLAM_WINDUP:
			_atk_play = maxf(_atk_play, 0.25)
			if _hell_t <= 0.0:
				if main and main.has_method("hell_boss_slam"):
					main.hell_boss_slam(position, HELL_SLAM_RADIUS + (hell_phase - 1) * 16.0,
						attack_damage * (1.0 + (hell_phase - 1) * 0.14))
				_hell_state = HellState.RECOVERY
				_hell_t = 0.62
				_atk_play = 0.55
				_atk_t = 0.0
		HellState.CHARGE_WINDUP:
			_atk_play = maxf(_atk_play, 0.25)
			if _hell_t <= 0.0:
				_hell_state = HellState.CHARGE
				_hell_t = 0.50
				_hell_charge_hit = false
		HellState.CHARGE:
			var charge_speed := 440.0 + (hell_phase - 1) * 55.0
			var target := position + _hell_lock_dir * 900.0
			if main and main.has_method("stage_enemy_step"):
				position = main.stage_enemy_step(position, target, charge_speed * delta, radius)
			else:
				position += _hell_lock_dir * charge_speed * delta
			_atk_play = maxf(_atk_play, 0.28)
			if not _hell_charge_hit and position.distance_to(pl.position) <= radius + pl.radius + 10.0:
				_hell_charge_hit = true
				if main and main.has_method("apply_hell_boss_damage"):
					main.apply_hell_boss_damage(attack_damage * 1.15, position)
			if _hell_t <= 0.0:
				_hell_state = HellState.RECOVERY
				_hell_t = 0.52
		HellState.VOLLEY_WINDUP:
			_atk_play = maxf(_atk_play, 0.25)
			if _hell_t <= 0.0:
				if main and main.has_method("spawn_hell_boss_volley"):
					main.spawn_hell_boss_volley(position, 10 + (hell_phase - 1) * 2,
						attack_damage * 0.62)
				_hell_state = HellState.RECOVERY
				_hell_t = 0.72
				_atk_play = 0.5
				_atk_t = 0.0
		HellState.RECOVERY:
			if _hell_t <= 0.0:
				_hell_state = HellState.CHASE
				_hell_t = maxf(0.72, 1.38 - hell_phase * 0.16)


func _start_next_hell_attack(pl: Player) -> void:
	var pattern := _hell_attack_index % 3
	_hell_attack_index += 1
	match pattern:
		0:
			_hell_state = HellState.SLAM_WINDUP
			_hell_t = maxf(0.64, 0.92 - (hell_phase - 1) * 0.08)
		1:
			_hell_lock_dir = (pl.position - position).normalized()
			if _hell_lock_dir == Vector2.ZERO:
				_hell_lock_dir = Vector2.DOWN
			_hell_state = HellState.CHARGE_WINDUP
			_hell_t = maxf(0.58, 0.82 - (hell_phase - 1) * 0.07)
		_:
			_hell_state = HellState.VOLLEY_WINDUP
			_hell_t = maxf(0.62, 0.86 - (hell_phase - 1) * 0.06)


func _process_glacier(delta: float, pl: Player) -> void:
	var main := get_parent()
	if _glacier_state == GlacierState.STUNNED:
		vulnerable_t = maxf(0.0, vulnerable_t - delta)
		if vulnerable_t <= 0.0:
			_glacier_state = GlacierState.CHASE
			_glacier_t = maxf(0.74, 1.34 - glacier_phase * 0.14)
		return
	_glacier_t -= delta
	match _glacier_state:
		GlacierState.CHASE:
			var to := pl.position - position
			if to.length() > radius + 62.0:
				if main and main.has_method("stage_enemy_step"):
					position = main.stage_enemy_step(position, pl.position,
						move_speed * (0.92 + (glacier_phase - 1) * 0.08) * delta, radius)
				else:
					position += to.normalized() * move_speed * delta
				_atk_play = maxf(_atk_play, 0.32)
			if _glacier_t <= 0.0:
				_start_next_glacier_attack(pl)
		GlacierState.SHARD_WINDUP:
			_atk_play = maxf(_atk_play, 0.25)
			if _glacier_t <= 0.0:
				if main and main.has_method("glacier_boss_shards"):
					main.glacier_boss_shards(position, _glacier_lock_dir, 6 + glacier_phase,
						attack_damage * 0.68)
				_glacier_state = GlacierState.RECOVERY
				_glacier_t = 0.66
				_atk_play = 0.5
				_atk_t = 0.0
		GlacierState.RING_WINDUP:
			_atk_play = maxf(_atk_play, 0.25)
			if _glacier_t <= 0.0:
				if main and main.has_method("glacier_boss_ring"):
					main.glacier_boss_ring(position,
						GLACIER_RING_RADIUS + (glacier_phase - 1) * 13.0,
						GLACIER_RING_WIDTH, attack_damage * 1.02)
				_glacier_state = GlacierState.RECOVERY
				_glacier_t = 0.62
				_atk_play = 0.5
				_atk_t = 0.0
		GlacierState.ERUPT_WINDUP:
			_atk_play = maxf(_atk_play, 0.25)
			if _glacier_t <= 0.0:
				if main and main.has_method("glacier_boss_eruption"):
					main.glacier_boss_eruption(_glacier_erupt_pos,
						GLACIER_ERUPT_RADIUS + (glacier_phase - 1) * 12.0,
						attack_damage * 1.08)
				_glacier_state = GlacierState.RECOVERY
				_glacier_t = 0.64
				_atk_play = 0.5
				_atk_t = 0.0
		GlacierState.RECOVERY:
			if _glacier_t <= 0.0:
				_glacier_state = GlacierState.CHASE
				_glacier_t = maxf(0.74, 1.38 - glacier_phase * 0.14)


func _start_next_glacier_attack(pl: Player) -> void:
	var pattern := _glacier_attack_index % 3
	_glacier_attack_index += 1
	match pattern:
		0:
			_glacier_lock_dir = (pl.position - position).normalized()
			if _glacier_lock_dir == Vector2.ZERO:
				_glacier_lock_dir = Vector2.DOWN
			_glacier_state = GlacierState.SHARD_WINDUP
			_glacier_t = maxf(0.64, 0.90 - (glacier_phase - 1) * 0.06)
		1:
			_glacier_state = GlacierState.RING_WINDUP
			_glacier_t = maxf(0.70, 0.98 - (glacier_phase - 1) * 0.06)
		_:
			_glacier_erupt_pos = pl.position
			_glacier_state = GlacierState.ERUPT_WINDUP
			_glacier_t = maxf(0.66, 0.94 - (glacier_phase - 1) * 0.05)


func _process_void(delta: float, pl: Player) -> void:
	var main := get_parent()
	if _void_state == VoidState.STUNNED:
		vulnerable_t = maxf(0.0, vulnerable_t - delta)
		if vulnerable_t <= 0.0:
			_void_state = VoidState.CHASE
			_void_t = maxf(0.70, 1.28 - void_phase * 0.13)
		return

	_void_t -= delta
	match _void_state:
		VoidState.CHASE:
			var to := pl.position - position
			if to.length() > radius + 105.0:
				if main and main.has_method("stage_enemy_step"):
					position = main.stage_enemy_step(position, pl.position,
						move_speed * (0.90 + (void_phase - 1) * 0.10) * delta, radius)
				else:
					position += to.normalized() * move_speed * delta
				_atk_play = maxf(_atk_play, 0.32)
			if _void_t <= 0.0:
				_start_next_void_attack(pl)
		VoidState.GAZE_WINDUP:
			_atk_play = maxf(_atk_play, 0.24)
			if _void_t <= 0.0:
				if main and main.has_method("void_boss_gaze"):
					main.void_boss_gaze(position, _void_lock_dir, VOID_GAZE_RADIUS,
						VOID_GAZE_HALF_ANGLE, attack_damage * 1.05)
				_void_state = VoidState.RECOVERY
				_void_t = 0.62
				_atk_play = 0.5
				_atk_t = 0.0
		VoidState.LASER_WINDUP:
			_atk_play = maxf(_atk_play, 0.24)
			if _void_t <= 0.0:
				_void_state = VoidState.LASER_SWEEP
				_void_t = VOID_LASER_SWEEP_TIME
				_atk_play = 0.5
				_atk_t = 0.0
		VoidState.LASER_SWEEP:
			var sweep_speed := (1.18 + (void_phase - 1) * 0.14) * _void_laser_sweep_dir
			_void_laser_angle += sweep_speed * delta
			if main and main.has_method("void_boss_laser"):
				main.void_boss_laser(position, Vector2.from_angle(_void_laser_angle),
					VOID_LASER_LENGTH, VOID_LASER_WIDTH, attack_damage * 0.62)
			if _void_t <= 0.0:
				_void_state = VoidState.RECOVERY
				_void_t = 0.58
		VoidState.WELL_WINDUP:
			_atk_play = maxf(_atk_play, 0.24)
			if _void_t <= 0.0:
				if main and main.has_method("spawn_void_gravity_field"):
					main.spawn_void_gravity_field(_void_well_pos, VOID_WELL_RADIUS,
						142.0 + (void_phase - 1) * 16.0, 4.2, attack_damage * 0.82)
				_void_state = VoidState.RECOVERY
				_void_t = 0.64
				_atk_play = 0.5
				_atk_t = 0.0
		VoidState.RECOVERY:
			if _void_t <= 0.0:
				_void_state = VoidState.CHASE
				_void_t = maxf(0.70, 1.32 - void_phase * 0.13)


func _start_next_void_attack(pl: Player) -> void:
	var pattern := _void_attack_index % 3
	_void_attack_index += 1
	match pattern:
		0:
			_void_lock_dir = (pl.position - position).normalized()
			if _void_lock_dir == Vector2.ZERO:
				_void_lock_dir = Vector2.DOWN
			_void_state = VoidState.GAZE_WINDUP
			_void_t = maxf(0.66, 0.96 - (void_phase - 1) * 0.06)
		1:
			_void_lock_dir = (pl.position - position).normalized()
			if _void_lock_dir == Vector2.ZERO:
				_void_lock_dir = Vector2.DOWN
			_void_laser_sweep_dir = -1.0 if _void_attack_index % 2 == 0 else 1.0
			_void_laser_angle = _void_lock_dir.angle() - _void_laser_sweep_dir * 0.74
			_void_state = VoidState.LASER_WINDUP
			_void_t = maxf(0.68, 0.94 - (void_phase - 1) * 0.05)
		_:
			_void_well_pos = pl.position
			_void_state = VoidState.WELL_WINDUP
			_void_t = maxf(0.68, 0.96 - (void_phase - 1) * 0.05)


func take_damage(d: float, _crit: bool = true, element: String = "") -> void:
	var m := get_parent()
	# 상성: 공격 속성 미지정이면 플레이어 공격 속성 사용. 약점 ×1.5 / 저항 ×0.6.
	var elem := element
	if elem == "" and m and "attack_element" in m:
		elem = str(m.attack_element)
	if grave_final:
		_take_damage_grave(d, _crit, elem, m)
		return
	if glacier_final:
		_take_damage_glacier(d, _crit, elem, m)
		return
	if void_final:
		_take_damage_void(d, _crit, elem, m)
		return
	# 화염 군주의 갑옷은 체력과 별도다. 냉기는 빠르게 파괴하고 화염은 거의 통하지 않는다.
	# 전용 무기 어픽스는 이 파괴량에만 적용해 일반 DPS 영구 누적을 만들지 않는다.
	if hell_final and armor_hp > 0.0:
		var armor_damage := d * hell_armor_element_multiplier(elem)
		if m and m.has_method("_hell_objective_damage_multiplier"):
			armor_damage *= float(m._hell_objective_damage_multiplier())
		var actual_armor_damage := minf(armor_hp, maxf(0.0, armor_damage))
		armor_hp -= armor_damage
		if m and m.has_method("record_damage_dealt"):
			m.record_damage_dealt(actual_armor_damage)
		if m and m.has_method("_spawn_dmg_num"):
			var armor_kind := "weak" if elem == "ice" else ("resist" if elem == "fire" else "")
			m._spawn_dmg_num(position + Vector2(0, -radius * 0.5),
				maxi(1, int(round(armor_damage))), _crit, armor_kind, elem)
		if armor_hp <= 0.0:
			_break_hell_armor()
		queue_redraw()
		return
	var hit_kind := ""
	if elem != "" and elem != "phys":
		if elem == weak:
			d *= 1.5
			hit_kind = "weak"
		elif elem == resist:
			d *= 0.6
			hit_kind = "resist"
	if hell_final and vulnerable_t > 0.0:
		d *= 1.70

	# 70%와 35%에서 체력을 정확히 멈춰 갑옷 파괴 국면을 건너뛰는 원샷을 막는다.
	if hell_final and _hell_armor_index < HELL_ARMOR_THRESHOLDS.size():
		var threshold_hp := max_hp * float(HELL_ARMOR_THRESHOLDS[_hell_armor_index])
		if hp > threshold_hp and hp - d <= threshold_hp:
			d = maxf(0.0, hp - threshold_hp)
	var actual_damage := minf(maxf(0.0, hp), maxf(0.0, d))
	if m and m.has_method("record_damage_dealt"):
		m.record_damage_dealt(actual_damage)
	hp -= d
	if m and m.has_method("_spawn_dmg_num"):
		if d >= 1.0:
			m._spawn_dmg_num(position + Vector2(0, -radius * 0.5), max(1, int(round(d))), true, hit_kind, elem)
		else:
			_dmg_accum += d   # 지속피해(오라·회전검 등)는 누적 후 주기 표시
	if hell_final and _hell_armor_index < HELL_ARMOR_THRESHOLDS.size():
		var reached_threshold := max_hp * float(HELL_ARMOR_THRESHOLDS[_hell_armor_index])
		if hp <= reached_threshold + 0.01:
			hp = reached_threshold
			_start_hell_armor()
			queue_redraw()
			return
	if hp <= 0:
		if m and m.has_method("on_boss_killed"):
			m.on_boss_killed()
		queue_free()


func _start_hell_armor() -> void:
	_hell_armor_index += 1
	hell_phase = _hell_armor_index + 1
	var cycle_bonus := float(_hell_armor_index - 1) * 0.04
	armor_max = max_hp * (0.15 + cycle_bonus + float(unsealed_fissures) * 0.035)
	armor_hp = armor_max
	vulnerable_t = 0.0
	_hell_state = HellState.CHASE
	_hell_t = 2.30   # 갑옷 안내 배너 아래에서 즉시 공격하지 않는다.
	var main := get_parent()
	if main and main.has_method("on_hell_boss_armor_started"):
		main.on_hell_boss_armor_started(_hell_armor_index, armor_max)


func _break_hell_armor() -> void:
	armor_hp = 0.0
	vulnerable_t = HELL_VULNERABLE_TIME
	_hell_state = HellState.STUNNED
	_hell_t = vulnerable_t
	var main := get_parent()
	if main and main.has_method("on_hell_boss_armor_broken"):
		main.on_hell_boss_armor_broken(vulnerable_t)


func configure_grave_final(sealed: int) -> void:
	grave_final = true
	sealed_graves = maxi(0, sealed)
	weak = ""       # 묘지는 입문 던전 — 강제 약점/저항 없음.
	resist = ""
	grave_phase = 1
	grave_shield_active = false
	grave_shield_started = false
	grave_shield_core_max = maxi(1, 4 - sealed_graves)   # 봉인 많을수록 핵이 적다.
	grave_shield_cores = grave_shield_core_max
	grave_core_hp = 0.0
	grave_core_hp_max = 0.0
	vulnerable_t = 0.0
	_grave_state = GraveState.CHASE
	_grave_t = 2.45   # 등장 배너가 사라진 뒤 첫 패턴을 시작한다.
	_grave_attack_index = 0


func _process_grave(delta: float, pl: Player) -> void:
	var main := get_parent()
	if _grave_state == GraveState.STUNNED:
		vulnerable_t = maxf(0.0, vulnerable_t - delta)
		if vulnerable_t <= 0.0:
			_grave_state = GraveState.CHASE
			_grave_t = maxf(0.72, 1.30 - grave_phase * 0.14)
		return
	_grave_t -= delta
	match _grave_state:
		GraveState.CHASE:
			if position.distance_to(pl.position) > 150.0:
				if main and main.has_method("stage_enemy_step"):
					position = main.stage_enemy_step(position, pl.position, move_speed * delta, radius)
				else:
					position = position.move_toward(pl.position, move_speed * delta)
				_atk_play = maxf(_atk_play, 0.35)
			if _grave_t <= 0.0:
				_start_next_grave_attack(pl)
		GraveState.FAN_WINDUP:
			_atk_play = maxf(_atk_play, 0.25)
			if _grave_t <= 0.0:
				if main and main.has_method("grave_boss_fan"):
					main.grave_boss_fan(position, _grave_lock_dir, 7 + grave_phase,
						attack_damage * 0.58)
				_grave_state = GraveState.RECOVERY
				_grave_t = 0.66
				_atk_play = 0.5
				_atk_t = 0.0
		GraveState.EXPLODE_WINDUP:
			_atk_play = maxf(_atk_play, 0.2)
			if _grave_t <= 0.0:
				if main and main.has_method("grave_boss_explosion"):
					main.grave_boss_explosion(_grave_explode_pos,
						GRAVE_EXPLODE_RADIUS + (grave_phase - 1) * 12.0, attack_damage * 1.05)
				_grave_state = GraveState.RECOVERY
				_grave_t = 0.60
		GraveState.CHARGE_WINDUP:
			_atk_play = maxf(_atk_play, 0.25)
			if _grave_t <= 0.0:
				_grave_state = GraveState.CHARGE
				_grave_t = 0.50
				_grave_charge_hit = false
		GraveState.CHARGE:
			var charge_speed := 430.0 + (grave_phase - 1) * 45.0
			var target := position + _grave_lock_dir * 900.0
			if main and main.has_method("stage_enemy_step"):
				position = main.stage_enemy_step(position, target, charge_speed * delta, radius)
			else:
				position += _grave_lock_dir * charge_speed * delta
			_atk_play = maxf(_atk_play, 0.28)
			if not _grave_charge_hit and position.distance_to(pl.position) <= radius + pl.radius + 10.0:
				_grave_charge_hit = true
				if main and main.has_method("apply_grave_boss_damage"):
					main.apply_grave_boss_damage(attack_damage * 1.1, position)
			if _grave_t <= 0.0:
				_grave_state = GraveState.RECOVERY
				_grave_t = 0.52
		GraveState.RECOVERY:
			if _grave_t <= 0.0:
				_grave_state = GraveState.CHASE
				_grave_t = maxf(0.72, 1.34 - grave_phase * 0.14)


func _start_next_grave_attack(pl: Player) -> void:
	var pattern := _grave_attack_index % 3
	_grave_attack_index += 1
	match pattern:
		0:
			_grave_lock_dir = (pl.position - position).normalized()
			if _grave_lock_dir == Vector2.ZERO:
				_grave_lock_dir = Vector2.DOWN
			_grave_state = GraveState.FAN_WINDUP
			_grave_t = maxf(0.62, 0.88 - (grave_phase - 1) * 0.06)
		1:
			_grave_explode_pos = pl.position   # 예고 시점의 플레이어 위치를 고정.
			_grave_state = GraveState.EXPLODE_WINDUP
			_grave_t = maxf(0.66, 0.92 - (grave_phase - 1) * 0.05)
		_:
			_grave_lock_dir = (pl.position - position).normalized()
			if _grave_lock_dir == Vector2.ZERO:
				_grave_lock_dir = Vector2.DOWN
			_grave_state = GraveState.CHARGE_WINDUP
			_grave_t = maxf(0.58, 0.80 - (grave_phase - 1) * 0.06)


func _start_grave_shield() -> void:
	grave_shield_started = true
	grave_shield_active = true
	grave_phase = 2
	grave_shield_cores = grave_shield_core_max
	grave_core_hp_max = maxf(1.0, max_hp * 0.12)
	grave_core_hp = grave_core_hp_max
	vulnerable_t = 0.0
	_grave_state = GraveState.CHASE
	_grave_t = 2.30   # 방패 안내 배너 아래에서 즉시 공격하지 않는다.
	var main := get_parent()
	if main and main.has_method("on_grave_shield_started"):
		main.on_grave_shield_started(grave_shield_cores)


func _break_grave_shield() -> void:
	grave_shield_active = false
	grave_phase = 3
	vulnerable_t = GRAVE_VULNERABLE_TIME
	_grave_state = GraveState.STUNNED
	_grave_t = vulnerable_t
	var main := get_parent()
	if main and main.has_method("on_grave_shield_broken"):
		main.on_grave_shield_broken(vulnerable_t)


# 묘지 보스 피해: 방패 활성이면 핵부터 부수고(속성 무관), 아니면 60% 게이트·취약 보너스 적용.
func _take_damage_grave(d: float, crit: bool, elem: String, m) -> void:
	if grave_shield_active:
		var actual_core := minf(grave_core_hp, maxf(0.0, d))
		grave_core_hp -= d
		if m and m.has_method("record_damage_dealt"):
			m.record_damage_dealt(actual_core)
		if m and m.has_method("_spawn_dmg_num") and d >= 1.0:
			m._spawn_dmg_num(position + Vector2(0, -radius * 0.5), maxi(1, int(round(d))), crit, "", elem)
		if grave_core_hp <= 0.0:
			grave_shield_cores -= 1
			if grave_shield_cores > 0:
				grave_core_hp = grave_core_hp_max
				if m and m.has_method("on_grave_shield_core_broken"):
					m.on_grave_shield_core_broken(grave_shield_cores)
			else:
				_break_grave_shield()
		queue_redraw()
		return
	if vulnerable_t > 0.0:
		d *= 1.70
	var hit_kind := ""
	if elem != "" and elem != "phys":
		if elem == weak:
			d *= 1.5
			hit_kind = "weak"
		elif elem == resist:
			d *= 0.6
			hit_kind = "resist"
	# 60% 방패 게이트(1회): 정확히 60%에서 멈춰 방패 국면을 건너뛰는 원샷을 막는다.
	if not grave_shield_started:
		var threshold_hp := max_hp * GRAVE_SHIELD_THRESHOLD
		if hp > threshold_hp and hp - d <= threshold_hp:
			d = maxf(0.0, hp - threshold_hp)
	var actual := minf(maxf(0.0, hp), maxf(0.0, d))
	if m and m.has_method("record_damage_dealt"):
		m.record_damage_dealt(actual)
	hp -= d
	if m and m.has_method("_spawn_dmg_num"):
		if d >= 1.0:
			m._spawn_dmg_num(position + Vector2(0, -radius * 0.5), maxi(1, int(round(d))), true, hit_kind, elem)
		else:
			_dmg_accum += d
	if not grave_shield_started and hp <= max_hp * GRAVE_SHIELD_THRESHOLD + 0.01:
		hp = max_hp * GRAVE_SHIELD_THRESHOLD
		_start_grave_shield()
		queue_redraw()
		return
	if hp <= 0:
		if m and m.has_method("on_boss_killed"):
			m.on_boss_killed()
		queue_free()


func _start_glacier_armor() -> void:
	_glacier_armor_index += 1
	glacier_phase = _glacier_armor_index + 1
	var cycle_bonus := float(_glacier_armor_index - 1) * 0.04
	armor_max = max_hp * (0.16 + cycle_bonus + float(unlit_braziers) * 0.03)
	armor_hp = armor_max
	vulnerable_t = 0.0
	_glacier_state = GlacierState.CHASE
	_glacier_t = 2.30
	var main := get_parent()
	if main and main.has_method("on_glacier_boss_armor_started"):
		main.on_glacier_boss_armor_started(_glacier_armor_index, armor_max)


func _break_glacier_armor() -> void:
	armor_hp = 0.0
	vulnerable_t = GLACIER_VULNERABLE_TIME
	_glacier_state = GlacierState.STUNNED
	_glacier_t = vulnerable_t
	var main := get_parent()
	if main and main.has_method("on_glacier_boss_armor_broken"):
		main.on_glacier_boss_armor_broken(vulnerable_t)


# 빙결 거상 피해: 갑옷은 화염 2.5배·냉기 0.55배지만 어떤 속성도 피해를 준다.
# 체력은 70%/35% 게이트에서 정확히 멈춰 갑옷 국면을 건너뛸 수 없다.
func _take_damage_glacier(d: float, crit: bool, elem: String, m) -> void:
	if armor_hp > 0.0:
		var armor_damage := d * glacier_armor_element_multiplier(elem)
		if m and m.has_method("_glacier_objective_damage_multiplier"):
			armor_damage *= float(m._glacier_objective_damage_multiplier())
		var actual_armor := minf(armor_hp, maxf(0.0, armor_damage))
		armor_hp -= armor_damage
		if m and m.has_method("record_damage_dealt"):
			m.record_damage_dealt(actual_armor)
		if m and m.has_method("_spawn_dmg_num") and armor_damage >= 1.0:
			var armor_kind := "weak" if elem == "fire" else ("resist" if elem == "ice" else "")
			m._spawn_dmg_num(position + Vector2(0, -radius * 0.5),
				maxi(1, int(round(armor_damage))), crit, armor_kind, elem)
		if armor_hp <= 0.0:
			_break_glacier_armor()
		queue_redraw()
		return

	var hit_kind := ""
	if elem != "" and elem != "phys":
		if elem == weak:
			d *= 1.5
			hit_kind = "weak"
		elif elem == resist:
			d *= 0.6
			hit_kind = "resist"
	if vulnerable_t > 0.0:
		d *= 1.70
	if _glacier_armor_index < GLACIER_ARMOR_THRESHOLDS.size():
		var threshold_hp := max_hp * float(GLACIER_ARMOR_THRESHOLDS[_glacier_armor_index])
		if hp > threshold_hp and hp - d <= threshold_hp:
			d = maxf(0.0, hp - threshold_hp)
	var actual := minf(maxf(0.0, hp), maxf(0.0, d))
	if m and m.has_method("record_damage_dealt"):
		m.record_damage_dealt(actual)
	hp -= d
	if m and m.has_method("_spawn_dmg_num"):
		if d >= 1.0:
			m._spawn_dmg_num(position + Vector2(0, -radius * 0.5),
				maxi(1, int(round(d))), crit, hit_kind, elem)
		else:
			_dmg_accum += d
	if _glacier_armor_index < GLACIER_ARMOR_THRESHOLDS.size():
		var reached_threshold := max_hp * float(GLACIER_ARMOR_THRESHOLDS[_glacier_armor_index])
		if hp <= reached_threshold + 0.01:
			hp = reached_threshold
			_start_glacier_armor()
			queue_redraw()
			return
	if hp <= 0.0:
		if m and m.has_method("on_boss_killed"):
			m.on_boss_killed()
		queue_free()


func _start_void_echo() -> void:
	void_echo_started = true
	void_echo_active = true
	void_phase = 2
	void_echo_cores = void_echo_core_max
	void_core_hp_max = maxf(1.0, max_hp * 0.105)
	void_core_hp = void_core_hp_max
	vulnerable_t = 0.0
	_void_state = VoidState.CHASE
	_void_t = 2.30
	var main := get_parent()
	if main and main.has_method("on_void_echo_started"):
		main.on_void_echo_started(void_echo_cores)


func _break_void_echo() -> void:
	void_echo_active = false
	void_core_hp = 0.0
	void_phase = 3
	vulnerable_t = VOID_VULNERABLE_TIME
	_void_state = VoidState.STUNNED
	_void_t = vulnerable_t
	var main := get_parent()
	if main and main.has_method("on_void_echo_broken"):
		main.on_void_echo_broken(vulnerable_t)


# 공허 감시자 피해 규칙. 55%에서 체력을 정확히 고정한 뒤 분신 핵을 모두
# 파괴해야 본체 피해가 다시 들어간다. 안정화한 닻이 많을수록 핵 수가 줄어든다.
func _take_damage_void(d: float, crit: bool, elem: String, m) -> void:
	if void_echo_active:
		var core_damage := maxf(0.0, d)
		if m and m.has_method("_void_core_damage_multiplier"):
			core_damage *= float(m._void_core_damage_multiplier())
		var actual_core := minf(void_core_hp, core_damage)
		void_core_hp -= core_damage
		if m and m.has_method("record_damage_dealt"):
			m.record_damage_dealt(actual_core)
		if m and m.has_method("_spawn_dmg_num") and core_damage >= 1.0:
			m._spawn_dmg_num(position + Vector2(0, -radius * 0.5),
				maxi(1, int(round(core_damage))), crit, "", elem)
		if void_core_hp <= 0.0:
			void_echo_cores -= 1
			if void_echo_cores > 0:
				void_core_hp = void_core_hp_max
				if m and m.has_method("on_void_echo_core_broken"):
					m.on_void_echo_core_broken(void_echo_cores)
			else:
				_break_void_echo()
		queue_redraw()
		return

	var hit_kind := ""
	if elem != "" and elem != "phys":
		if elem == weak:
			d *= 1.5
			hit_kind = "weak"
		elif elem == resist:
			d *= 0.6
			hit_kind = "resist"
	if vulnerable_t > 0.0:
		d *= 1.75

	if not void_echo_started:
		var threshold_hp := max_hp * VOID_ECHO_THRESHOLD
		if hp > threshold_hp and hp - d <= threshold_hp:
			d = maxf(0.0, hp - threshold_hp)
	var actual := minf(maxf(0.0, hp), maxf(0.0, d))
	if m and m.has_method("record_damage_dealt"):
		m.record_damage_dealt(actual)
	hp -= d
	if m and m.has_method("_spawn_dmg_num"):
		if d >= 1.0:
			m._spawn_dmg_num(position + Vector2(0, -radius * 0.5),
				maxi(1, int(round(d))), crit, hit_kind, elem)
		else:
			_dmg_accum += d
	if not void_echo_started and hp <= max_hp * VOID_ECHO_THRESHOLD + 0.01:
		hp = max_hp * VOID_ECHO_THRESHOLD
		_start_void_echo()
		queue_redraw()
		return
	if hp <= 0.0:
		if m and m.has_method("on_boss_killed"):
			m.on_boss_killed()
		queue_free()


func _draw() -> void:
	if hell_final:
		_draw_hell_warning()
	elif grave_final:
		_draw_grave_warning()
	elif glacier_final:
		_draw_glacier_warning()
	elif void_final:
		_draw_void_warning()
	var tex: Texture2D = null
	if _atk_play > 0.0:
		var fa: Array = Assets.frames("res://assets/anim/%s_attack" % key)
		if fa.size() > 0:
			tex = fa[int(_atk_t * 11.0) % fa.size()]
	if tex == null:
		var fw: Array = Assets.frames("res://assets/anim/%s_walk" % key)
		if fw.is_empty():
			fw = Assets.frames("res://assets/anim/boss_walk")
		if fw.size() > 0:
			tex = fw[int(_anim_t * 9.0) % fw.size()]
	if tex == null:
		tex = Assets.tex("res://assets/boss/%s.png" % key)
	if tex == null:
		tex = Assets.tex(SPRITE)
	# 텔레그래프 경고: 특수공격 예비동작 동안 붉은 링이 수축하며 조준 완성 (플레이어에게 회피 시간)
	if _tele_t > 0.0:
		var p: float = clamp(1.0 - _tele_t / TELE_DUR, 0.0, 1.0)   # 0→1 충전
		var pulse: float = 0.5 + 0.5 * sin(_tele_t * 34.0)
		# 바닥 경고 원(옅게 채움) — 위험 범위 암시
		draw_circle(Vector2.ZERO, radius * 3.0, Color(1.0, 0.2, 0.15, 0.08 + 0.14 * p))
		# 수축하는 조준 링
		var rr: float = radius * (3.2 - 1.8 * p)
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 44, Color(1.0, 0.3, 0.22, 0.4 + 0.45 * p), 4.0 + 4.0 * p)
		# 완성 직전 번쩍이는 내측 링
		if p > 0.55:
			draw_arc(Vector2.ZERO, radius * 1.15, 0.0, TAU, 40, Color(1.0, 0.85, 0.4, 0.5 * pulse), 3.0)
	if tex:
		var w := radius * 2.6
		var tint := Color(0.55, 0.5, 0.7) if is_reaper else Color(1, 1, 1)   # 사신: 어둡게
		if hell_final and armor_hp > 0.0:
			tint = Color(1.35, 0.72, 0.34)
		elif hell_final and vulnerable_t > 0.0:
			tint = Color(0.62, 0.88, 1.18)
		elif grave_final and grave_shield_active:
			tint = Color(0.72, 0.86, 1.22)
		elif grave_final and vulnerable_t > 0.0:
			tint = Color(0.70, 1.12, 0.86)
		elif glacier_final and armor_hp > 0.0:
			tint = Color(0.68, 0.88, 1.28)
		elif glacier_final and vulnerable_t > 0.0:
			tint = Color(1.18, 0.88, 0.54)
		elif void_final and void_echo_active:
			tint = Color(0.86, 0.58, 1.30)
		elif void_final and vulnerable_t > 0.0:
			tint = Color(1.20, 0.92, 0.58)
		# 충전 중엔 붉게 달아오름 (맥동)
		if _tele_t > 0.0:
			var tp: float = clamp(1.0 - _tele_t / TELE_DUR, 0.0, 1.0)
			var glow: float = 0.5 + 0.5 * sin(_tele_t * 34.0)
			tint = tint.lerp(Color(1.9, 0.55, 0.4), 0.35 + 0.35 * tp * glow)
		draw_texture_rect(tex, Rect2(Vector2(-w / 2.0, -w / 2.0), Vector2(w, w)), false, tint)
	elif is_reaper:
		# 사신 폴백: 검은 후드 형상 + 붉은 눈 + 낫
		draw_circle(Vector2(0, 4), radius, Color(0.08, 0.06, 0.12))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-radius * 0.9, radius), Vector2(0, -radius * 1.2), Vector2(radius * 0.9, radius)]),
			Color(0.05, 0.04, 0.09))
		draw_circle(Vector2(-radius * 0.28, -radius * 0.1), 6, Color(1.0, 0.15, 0.15))
		draw_circle(Vector2(radius * 0.28, -radius * 0.1), 6, Color(1.0, 0.15, 0.15))
		draw_line(Vector2(radius * 0.7, -radius), Vector2(radius * 1.1, radius), Color(0.7, 0.7, 0.75), 4.0)
		draw_arc(Vector2(radius * 1.0, -radius), radius * 0.5, -1.2, 0.6, 12, Color(0.85, 0.85, 0.9), 4.0)
	else:
		draw_circle(Vector2.ZERO, radius, Color(0.8, 0.2, 0.35))
		draw_circle(Vector2.ZERO, radius * 0.7, Color(0.95, 0.4, 0.5))
		draw_circle(Vector2(-20, -10), 7, Color.BLACK)
		draw_circle(Vector2(20, -10), 7, Color.BLACK)

	var w2 := 120.0
	var ratio: float = clamp(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(Vector2(-w2 / 2.0, -radius - 22), Vector2(w2, 9)), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(Vector2(-w2 / 2.0, -radius - 22), Vector2(w2 * ratio, 9)), Color(1.0, 0.3, 0.3))
	if hell_final and armor_max > 0.0 and armor_hp > 0.0:
		var armor_ratio := clampf(armor_hp / armor_max, 0.0, 1.0)
		draw_rect(Rect2(Vector2(-w2 / 2.0, -radius - 34), Vector2(w2, 7)),
			Color(0.08, 0.05, 0.04, 0.94))
		draw_rect(Rect2(Vector2(-w2 / 2.0, -radius - 34), Vector2(w2 * armor_ratio, 7)),
			Color(1.0, 0.56, 0.12))
		# 갑옷 바 왼쪽의 냉기 파쇄 표식.
		draw_colored_polygon(PackedVector2Array([
			Vector2(-w2 * 0.5 - 12.0, -radius - 31.0),
			Vector2(-w2 * 0.5 - 6.0, -radius - 38.0),
			Vector2(-w2 * 0.5, -radius - 31.0),
			Vector2(-w2 * 0.5 - 6.0, -radius - 24.0),
		]), Color(0.55, 0.90, 1.0))
	if grave_final and grave_shield_active and grave_core_hp_max > 0.0:
		var core_ratio := clampf(grave_core_hp / grave_core_hp_max, 0.0, 1.0)
		draw_rect(Rect2(Vector2(-w2 / 2.0, -radius - 34), Vector2(w2, 7)),
			Color(0.05, 0.06, 0.10, 0.94))
		draw_rect(Rect2(Vector2(-w2 / 2.0, -radius - 34), Vector2(w2 * core_ratio, 7)),
			Color(0.55, 0.82, 1.0))
		# 남은 핵 수를 사각 점(형태)으로도 — 색만이 아니라 개수로 읽힌다.
		for ci in grave_shield_cores:
			draw_rect(Rect2(Vector2(-w2 * 0.5 + ci * 10.0, -radius - 46), Vector2(7, 7)),
				Color(0.72, 0.92, 1.0))
	if glacier_final and armor_max > 0.0 and armor_hp > 0.0:
		var glacier_armor_ratio := clampf(armor_hp / armor_max, 0.0, 1.0)
		draw_rect(Rect2(Vector2(-w2 / 2.0, -radius - 34), Vector2(w2, 7)),
			Color(0.04, 0.08, 0.13, 0.94))
		draw_rect(Rect2(Vector2(-w2 / 2.0, -radius - 34), Vector2(w2 * glacier_armor_ratio, 7)),
			Color(0.42, 0.82, 1.0))
		# 불꽃 모양 마커로 화염 특효를 보여 주되 갑옷 자체는 모든 속성으로 파괴 가능하다.
		draw_colored_polygon(PackedVector2Array([
			Vector2(-w2 * 0.5 - 11.0, -radius - 27.0),
			Vector2(-w2 * 0.5 - 8.0, -radius - 41.0),
			Vector2(-w2 * 0.5 - 3.0, -radius - 33.0),
			Vector2(-w2 * 0.5, -radius - 43.0),
			Vector2(-w2 * 0.5 + 3.0, -radius - 27.0),
		]), Color(1.0, 0.58, 0.16))
	if void_final and void_echo_active and void_core_hp_max > 0.0:
		var void_core_ratio := clampf(void_core_hp / void_core_hp_max, 0.0, 1.0)
		draw_rect(Rect2(Vector2(-w2 / 2.0, -radius - 34), Vector2(w2, 7)),
			Color(0.06, 0.02, 0.10, 0.96))
		draw_rect(Rect2(Vector2(-w2 / 2.0, -radius - 34), Vector2(w2 * void_core_ratio, 7)),
			Color(0.72, 0.42, 1.0))
		for ci in void_echo_cores:
			var marker_x := -w2 * 0.5 + 4.0 + float(ci) * 11.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(marker_x, -radius - 43.0),
				Vector2(marker_x + 4.0, -radius - 47.0),
				Vector2(marker_x + 8.0, -radius - 43.0),
				Vector2(marker_x + 4.0, -radius - 39.0),
			]), Color(0.84, 0.64, 1.0))


func _draw_void_warning() -> void:
	var danger := Color(0.76, 0.42, 1.0)
	match _void_state:
		VoidState.GAZE_WINDUP:
			var duration := maxf(0.66, 0.96 - (void_phase - 1) * 0.06)
			var progress := clampf(1.0 - _void_t / duration, 0.0, 1.0)
			var base := _void_lock_dir.angle()
			var points := PackedVector2Array([Vector2.ZERO])
			for i in 17:
				var angle := base - VOID_GAZE_HALF_ANGLE \
					+ VOID_GAZE_HALF_ANGLE * 2.0 * float(i) / 16.0
				points.append(Vector2.from_angle(angle) * VOID_GAZE_RADIUS)
			draw_colored_polygon(points,
				Color(danger.r, danger.g, danger.b, 0.06 + progress * 0.13))
			draw_arc(Vector2.ZERO, VOID_GAZE_RADIUS,
				base - VOID_GAZE_HALF_ANGLE, base + VOID_GAZE_HALF_ANGLE, 32,
				Color(0.90, 0.62, 1.0, 0.42 + progress * 0.46), 3.0)
		VoidState.LASER_WINDUP:
			var duration := maxf(0.68, 0.94 - (void_phase - 1) * 0.05)
			var progress := clampf(1.0 - _void_t / duration, 0.0, 1.0)
			var direction := Vector2.from_angle(_void_laser_angle)
			var side := direction.orthogonal() * VOID_LASER_WIDTH
			var finish := direction * VOID_LASER_LENGTH
			draw_colored_polygon(PackedVector2Array([-side, side, finish + side, finish - side]),
				Color(danger.r, danger.g, danger.b, 0.05 + progress * 0.13))
			draw_line(Vector2.ZERO, finish,
				Color(0.92, 0.68, 1.0, 0.48 + progress * 0.46), 2.0 + progress * 3.0)
		VoidState.LASER_SWEEP:
			var direction := Vector2.from_angle(_void_laser_angle)
			draw_line(Vector2.ZERO, direction * VOID_LASER_LENGTH,
				Color(0.92, 0.58, 1.0, 0.92), VOID_LASER_WIDTH * 1.25)
			draw_line(Vector2.ZERO, direction * VOID_LASER_LENGTH,
				Color(1.0, 0.90, 1.0, 0.94), 4.0)
		VoidState.WELL_WINDUP:
			var duration := maxf(0.68, 0.96 - (void_phase - 1) * 0.05)
			var progress := clampf(1.0 - _void_t / duration, 0.0, 1.0)
			var local := _void_well_pos - position
			draw_circle(local, VOID_WELL_RADIUS,
				Color(danger.r, danger.g, danger.b, 0.05 + progress * 0.10))
			draw_arc(local, lerpf(VOID_WELL_RADIUS * 1.36, VOID_WELL_RADIUS, progress),
				0.0, TAU, 52, Color(0.86, 0.58, 1.0, 0.44 + progress * 0.45),
				3.0 + progress * 2.0)
	if void_echo_active:
		var pulse := 0.5 + 0.5 * sin(_anim_t * 8.0)
		draw_arc(Vector2.ZERO, radius * 1.62, 0.0, TAU, 48,
			Color(0.72, 0.42, 1.0, 0.58 + pulse * 0.26), 4.0)
		for i in void_echo_cores:
			var angle := TAU * float(i) / float(maxi(1, void_echo_core_max)) \
				- PI * 0.5 + _anim_t * 0.34
			var center := Vector2.from_angle(angle) * radius * 1.62
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -7), center + Vector2(7, 0),
				center + Vector2(0, 7), center + Vector2(-7, 0),
			]), Color(0.88, 0.68, 1.0))
	elif vulnerable_t > 0.0:
		var pulse := 0.5 + 0.5 * sin(_anim_t * 10.0)
		draw_arc(Vector2.ZERO, radius * (1.32 + pulse * 0.10), 0.0, TAU, 42,
			Color(1.0, 0.78, 0.38, 0.76), 4.0)


func _draw_glacier_warning() -> void:
	var danger := Color(0.46, 0.82, 1.0)
	match _glacier_state:
		GlacierState.SHARD_WINDUP:
			var duration := maxf(0.64, 0.90 - (glacier_phase - 1) * 0.06)
			var progress := clampf(1.0 - _glacier_t / duration, 0.0, 1.0)
			var spread := 1.18
			var base := _glacier_lock_dir.angle()
			for i in 5:
				var angle := base - spread * 0.5 + spread * float(i) / 4.0
				var dir := Vector2.from_angle(angle)
				draw_line(dir * (radius + 8.0), dir * (245.0 + progress * 65.0),
					Color(danger.r, danger.g, danger.b, 0.30 + progress * 0.55), 3.0)
		GlacierState.RING_WINDUP:
			var duration := maxf(0.70, 0.98 - (glacier_phase - 1) * 0.06)
			var progress := clampf(1.0 - _glacier_t / duration, 0.0, 1.0)
			var rr := GLACIER_RING_RADIUS + (glacier_phase - 1) * 13.0
			var closing := lerpf(rr * 1.22, rr, progress)
			draw_arc(Vector2.ZERO, closing, 0.0, TAU, 56,
				Color(0.58, 0.88, 1.0, 0.42 + progress * 0.45), GLACIER_RING_WIDTH * 0.35)
			draw_arc(Vector2.ZERO, rr - GLACIER_RING_WIDTH, 0.0, TAU, 56,
				Color(0.72, 0.94, 1.0, 0.24 + progress * 0.30), 2.0)
			draw_arc(Vector2.ZERO, rr + GLACIER_RING_WIDTH, 0.0, TAU, 56,
				Color(0.72, 0.94, 1.0, 0.24 + progress * 0.30), 2.0)
		GlacierState.ERUPT_WINDUP:
			var duration := maxf(0.66, 0.94 - (glacier_phase - 1) * 0.05)
			var progress := clampf(1.0 - _glacier_t / duration, 0.0, 1.0)
			var local := _glacier_erupt_pos - position
			var rr := GLACIER_ERUPT_RADIUS + (glacier_phase - 1) * 12.0
			draw_circle(local, rr, Color(danger.r, danger.g, danger.b, 0.07 + progress * 0.13))
			draw_arc(local, lerpf(rr * 1.45, rr, progress), 0.0, TAU, 48,
				Color(0.68, 0.92, 1.0, 0.45 + progress * 0.45), 3.0 + progress * 2.0)
	if armor_hp > 0.0:
		var pulse := 0.5 + 0.5 * sin(_anim_t * 8.0)
		draw_circle(Vector2.ZERO, radius * 1.50, Color(0.35, 0.72, 1.0, 0.08 + pulse * 0.05))
		draw_arc(Vector2.ZERO, radius * 1.50, 0.0, TAU, 44,
			Color(0.52, 0.86, 1.0, 0.60 + pulse * 0.26), 4.0)
		for i in 6:
			var angle := TAU * float(i) / 6.0
			var center := Vector2.from_angle(angle) * radius * 1.48
			draw_line(center - Vector2.from_angle(angle) * 7.0,
				center + Vector2.from_angle(angle) * 7.0,
				Color(0.78, 0.96, 1.0, 0.82), 3.0)
	elif vulnerable_t > 0.0:
		var pulse := 0.5 + 0.5 * sin(_anim_t * 10.0)
		draw_arc(Vector2.ZERO, radius * (1.30 + pulse * 0.10), 0.0, TAU, 40,
			Color(1.0, 0.68, 0.28, 0.72), 4.0)


func _draw_grave_warning() -> void:
	var danger := Color(0.62, 0.80, 1.0)
	match _grave_state:
		GraveState.FAN_WINDUP:
			var progress := clampf(1.0 - _grave_t / maxf(0.62, 0.88 - (grave_phase - 1) * 0.06), 0.0, 1.0)
			var half := 0.62
			var base := _grave_lock_dir.angle()
			var pts := PackedVector2Array([Vector2.ZERO])
			var reach := GRAVE_FAN_RADIUS * (0.7 + progress * 0.4)
			for i in 13:
				var a := base - half + (2.0 * half) * float(i) / 12.0
				pts.append(Vector2.from_angle(a) * reach)
			draw_colored_polygon(pts, Color(danger.r, danger.g, danger.b, 0.08 + progress * 0.14))
			draw_arc(Vector2.ZERO, reach, base - half, base + half, 24,
				Color(0.72, 0.88, 1.0, 0.5 + progress * 0.4), 3.0)
		GraveState.EXPLODE_WINDUP:
			var progress := clampf(1.0 - _grave_t / maxf(0.66, 0.92 - (grave_phase - 1) * 0.05), 0.0, 1.0)
			var local := _grave_explode_pos - position
			var rr := GRAVE_EXPLODE_RADIUS + (grave_phase - 1) * 12.0
			draw_circle(local, rr, Color(0.55, 0.45, 0.85, 0.10 + progress * 0.16))
			draw_arc(local, lerpf(rr * 1.4, rr, progress), 0.0, TAU, 44,
				Color(0.74, 0.62, 1.0, 0.45 + progress * 0.45), 3.0 + progress * 2.0)
		GraveState.CHARGE_WINDUP:
			var progress := clampf(1.0 - _grave_t / maxf(0.58, 0.80 - (grave_phase - 1) * 0.06), 0.0, 1.0)
			var side := _grave_lock_dir.orthogonal() * (radius + 14.0)
			var end := _grave_lock_dir * 360.0
			draw_colored_polygon(PackedVector2Array([-side, side, end + side, end - side]),
				Color(danger.r, danger.g, danger.b, 0.06 + progress * 0.12))
			draw_line(-side, end - side, Color(0.70, 0.85, 1.0, 0.50 + progress * 0.40), 3.0)
			draw_line(side, end + side, Color(0.70, 0.85, 1.0, 0.50 + progress * 0.40), 3.0)
	if grave_shield_active:
		var pulse := 0.5 + 0.5 * sin(_anim_t * 8.0)
		draw_arc(Vector2.ZERO, radius * 1.5, 0.0, TAU, 44,
			Color(0.55, 0.80, 1.0, 0.55 + pulse * 0.28), 4.0)
		for i in grave_shield_cores:
			var a := TAU * float(i) / float(maxi(1, grave_shield_core_max)) - PI * 0.5
			draw_circle(Vector2.from_angle(a) * radius * 1.5, 6.0, Color(0.75, 0.92, 1.0))
	elif vulnerable_t > 0.0:
		var pulse := 0.5 + 0.5 * sin(_anim_t * 10.0)
		draw_arc(Vector2.ZERO, radius * (1.30 + pulse * 0.10), 0.0, TAU, 40,
			Color(0.60, 1.0, 0.80, 0.70), 4.0)


func _draw_hell_warning() -> void:
	var danger := Color(1.0, 0.18, 0.06)
	match _hell_state:
		HellState.SLAM_WINDUP:
			var duration := maxf(0.64, 0.92 - (hell_phase - 1) * 0.08)
			var progress := clampf(1.0 - _hell_t / duration, 0.0, 1.0)
			var rr := HELL_SLAM_RADIUS + (hell_phase - 1) * 16.0
			draw_circle(Vector2.ZERO, rr, Color(danger.r, danger.g, danger.b, 0.06 + progress * 0.10))
			draw_arc(Vector2.ZERO, lerpf(rr * 1.35, rr, progress), 0.0, TAU, 48,
				Color(1.0, 0.58, 0.16, 0.42 + progress * 0.48), 4.0 + progress * 2.0)
		HellState.CHARGE_WINDUP:
			var duration := maxf(0.58, 0.82 - (hell_phase - 1) * 0.07)
			var progress := clampf(1.0 - _hell_t / duration, 0.0, 1.0)
			var length := 360.0
			var side := _hell_lock_dir.orthogonal() * (radius + 14.0)
			var end := _hell_lock_dir * length
			var lane := PackedVector2Array([-side, side, end + side, end - side])
			draw_colored_polygon(lane, Color(danger.r, danger.g, danger.b, 0.06 + progress * 0.12))
			draw_line(-side, end - side, Color(1.0, 0.42, 0.10, 0.50 + progress * 0.40), 3.0)
			draw_line(side, end + side, Color(1.0, 0.42, 0.10, 0.50 + progress * 0.40), 3.0)
		HellState.VOLLEY_WINDUP:
			var duration := maxf(0.62, 0.86 - (hell_phase - 1) * 0.06)
			var progress := clampf(1.0 - _hell_t / duration, 0.0, 1.0)
			var count := 10 + (hell_phase - 1) * 2
			for i in count:
				var dir := Vector2.from_angle(TAU * float(i) / float(count))
				draw_line(dir * (radius + 6.0), dir * (94.0 + progress * 38.0),
					Color(1.0, 0.55, 0.14, 0.25 + progress * 0.55), 2.0)
	if armor_hp > 0.0:
		var pulse := 0.5 + 0.5 * sin(_anim_t * 8.0)
		draw_circle(Vector2.ZERO, radius * 1.48, Color(1.0, 0.30, 0.04, 0.08 + pulse * 0.06))
		draw_arc(Vector2.ZERO, radius * 1.48, 0.0, TAU, 44,
			Color(1.0, 0.58, 0.12, 0.60 + pulse * 0.26), 4.0)
	elif vulnerable_t > 0.0:
		var pulse := 0.5 + 0.5 * sin(_anim_t * 10.0)
		draw_arc(Vector2.ZERO, radius * (1.30 + pulse * 0.10), 0.0, TAU, 40,
			Color(0.55, 0.92, 1.0, 0.70), 4.0)
		for i in 6:
			var a := TAU * float(i) / 6.0 + _anim_t * 0.35
			draw_line(Vector2.from_angle(a) * radius * 0.72,
				Vector2.from_angle(a + 0.15) * radius * 1.15,
				Color(0.78, 0.96, 1.0, 0.82), 2.0)
