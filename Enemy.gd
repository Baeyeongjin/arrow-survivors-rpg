class_name Enemy
extends Node2D

# 스프라이트 표시 크기 = radius * 이 배수. 충돌 반경(radius)과 분리돼 있어
# 밸런스를 안 건드리고 겉보기 크기만 조절할 수 있음. (3.05 → 2.14로 줄였다가 +15%)
const SPRITE_SCALE := 2.46

var hp := 20.0
var max_hp := 20.0   # 엘리트 HP바 비율용 (Main._make_enemy에서 최종 hp로 세팅)
var speed := 60.0
var radius := 18.0
var touch_damage := 8.0
var xp_value := 1
var color := Color(1.0, 0.4, 0.4)
var tier: Dictionary = {}
var elite := false   # 엘리트: 크고 강하고 보상 확정
var midboss := false # M3 지옥 세로 슬라이스: 용암 집행자 처치 보상/게이트 식별
var weak := ""       # 약점 속성 (이 속성으로 맞으면 ×1.5). 빈 문자열=약점 없음
var resist := ""     # 저항 속성 (이 속성으로 맞으면 ×0.6)

# 둔화 상태
var slow_factor := 1.0
var slow_timer := 0.0
# 지역 위협 상태. 체력 자체는 바꾸지 않고 공격·속도·받는 피해만 잠시 조정한다.
var threat_timer := 0.0
var threat_name := ""
var threat_damage_taken_mult := 1.0
var _threat_base_speed := 0.0
var _threat_base_touch_damage := 0.0
var _anim_t := 0.0
var _flash_t := 0.0
var _atk_t := 0.0
var _attacking := false
var _pl: Player = null   # 플레이어 참조 캐시 (매 프레임 그룹조회 방지)
var _kb := Vector2.ZERO  # 넉백 속도 (감쇠)
var sep := Vector2.ZERO  # 적끼리 밀어내기 변위 (Main이 격자로 매 물리프레임 채움)
var _hitstop := 0.0      # 피격 순간 자기 정지(멈칫)
var _face_left := false  # 좌우 반전 (플레이어 방향)
var _dir := "s"          # 바라보는 4방향 s/n/e/w
var _kb_cd := 0.0        # 넉백/멈칫 재적용 쿨다운 (지속타 잠김 방지)
var _dmg_accum := 0.0    # 지속피해(장판·오라·회전검) 누적 → 주기적으로 합산 숫자 표시
var _dmg_flush := 0.0    # 누적피해 표시 타이머
var despawn_t := 0.0     # >0이면 이 시간 뒤 자동 소멸 (개발 전투 프리뷰용)
var hold := false        # true면 플레이어가 방에 접근할 때까지 대기
# 행동 타입 (#27): "" 기본추격 / ranged 사수 / charge 돌진 / exploder 자폭 / splitter 분열
var behavior := ""
var _shoot_cd := 1.2     # 사수 발사 쿨다운
var _shoot_windup := 0.0 # 사수 조준선 표시 시간
var _shoot_lock := Vector2.RIGHT
var _cstate := 0         # 돌진 상태: 0 접근 / 1 예열 / 2 돌진 / 3 쿨다운
var _ctimer := 0.0       # 돌진 상태 타이머
var _clock := Vector2.ZERO  # 돌진 고정 방향
var _melee_state := 0    # 근접 상태: 0 접근 / 1 예고 / 2 타격 / 3 회복
var _melee_t := 0.0
var _strike_dir := Vector2.DOWN
var is_split := false    # 분열로 생성된 새끼 (재분열 방지)
# setup()에서 한 번만 해석하는 스프라이트 캐시 (_draw의 매 프레임 문자열 생성 제거).
var _frames_attack: Array = []
var _frames_walk: Array = []
var _frames_walk_n: Array = []
var _frames_walk_e: Array = []
var _sprite_tex: Texture2D = null
# 죽음 연출 (스쿼시→팝→페이드). 죽는 순간 잠깐 살아있는 상태로 애니 재생 후 소멸.
var _dying := false
var _die_t := 0.0
const DIE_DUR := 0.30
# 피격 임팩트 (스쿼시&스트레치 펀치): 맞는 순간 옆으로 늘고 위아래 눌렸다 튕김
var _hit_t := 0.0
const HIT_DUR := 0.15
const RANGED_WINDUP := 0.48
const CHARGE_WINDUP := 0.55
# 정예·중간보스 전용 특수 공격. 큰 기술이라 전조를 남기되 도형 오버레이는 쓰지 않는다
# (사장님: "원 같은 게 생겨서 집중도를 해친다"). 전조는 몸으로만 읽힌다:
#   1) 완전 정지 — 추격·일반 공격이 멈춘다
#   2) 몸이 기술 색으로 물든다 — 진행도만큼 진해진다
#   3) 공격 애니의 windup 포즈에서 프레임이 고정된다 — 루프하지 않아 "모으는 중"으로 읽힌다
const SPECIAL_WINDUP := 0.85
const SPECIAL_RECOVER := 0.95
const SPECIAL_CD := 7.0
const SPECIAL_RANGE := 430.0
const SPECIAL_SLAM_RADIUS := 130.0
var _sp: Dictionary = {}      # GameConfig.elite_special() 결과 (없으면 비어 있음)
var _sp_state := 0            # 0 없음 / 1 전조 / 2 후딜
var _sp_t := 0.0
var _sp_cd := 0.0
var _sp_lock := Vector2.DOWN
var _sp_flash := 0.0          # 발동 순간 몸이 하얗게 터지는 짧은 섬광


func _melee_windup_duration() -> float:
	return 0.58 if elite else 0.36


func _melee_strike_duration() -> float:
	return 0.20 if elite else 0.16


func _melee_recovery_duration() -> float:
	return 0.82 if elite else 0.52


# 화면에 보이는 몸 반경. radius는 충돌·분리용 논리값이고 스프라이트는 radius * SPRITE_SCALE
# 크기로 그려지므로, "닿았다"의 기준은 이쪽이다.
func _visible_radius() -> float:
	return radius * SPRITE_SCALE * 0.5


# 피해 범위는 눈에 보이는 스프라이트를 기준으로 잡는다.
# 예전에는 radius + 30(정예 50)이라 반경 18 기준 48px까지 닿았는데, 스프라이트 반폭은
# radius * SPRITE_SCALE / 2 = 22px뿐이었다. 보이는 몸의 2배가 넘는 곳까지 맞았고,
# 예고 이펙트(_draw_attack_warning)까지 제거된 뒤로는 그 범위를 읽을 방법도 없었다.
# 이제 스프라이트 반폭에 무기 길이만 더한다.
func _melee_reach() -> float:
	return _visible_radius() + (18.0 if elite else 10.0)


func _ranged_windup_duration() -> float:
	return RANGED_WINDUP + (0.14 if elite else 0.0)


func _charge_windup_duration() -> float:
	return CHARGE_WINDUP + (0.18 if elite else 0.0)


# Main의 충돌 루프는 단순 접촉 대신 실제 공격 활성 프레임과 예고된 범위를 확인한다.
func can_damage_player(target: Vector2, target_radius: float) -> bool:
	if _dying:
		return false
	match behavior:
		"ranged":
			return false
		"charge":
			return _cstate == 2 and position.distance_to(target) <= radius + target_radius + 5.0
		_:
			if _melee_state != 2:
				return false
			var to_target := target - position
			if to_target.length() > _melee_reach() + target_radius:
				return false
			# 정예는 원형 강타, 일반 적은 고정 방향 부채꼴 베기다.
			if elite or to_target.length_squared() <= 0.01:
				return true
			return absf(_strike_dir.angle_to(to_target.normalized())) <= 0.72

func _ready() -> void:
	add_to_group("enemies")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _move_on_stage(target: Vector2, distance: float) -> void:
	var main := get_parent()
	if main and main.has_method("stage_enemy_step"):
		position = main.stage_enemy_step(position, target, distance, radius)
	else:
		position = position.move_toward(target, distance)

func apply_slow(amount: float, time: float) -> void:
	slow_factor = min(slow_factor, 1.0 - amount)
	slow_timer = max(slow_timer, time)


func apply_threat_buff(definition: Dictionary, duration_override: float = -1.0) -> void:
	if _dying:
		return
	# 새 위협이 겹쳐도 배수가 누적되지 않도록 원래 능력치부터 복구한다.
	if threat_timer > 0.0:
		clear_threat_buff()
	_threat_base_speed = speed
	_threat_base_touch_damage = touch_damage
	speed *= maxf(0.1, float(definition.get("speed_mult", 1.0)))
	touch_damage *= maxf(0.1, float(definition.get("attack_mult", 1.0)))
	threat_damage_taken_mult = maxf(0.05, float(definition.get("damage_taken_mult", 1.0)))
	threat_timer = (duration_override if duration_override >= 0.0
		else float(definition.get("duration", 0.0)))
	threat_name = str(definition.get("name", "몬스터 강화"))
	queue_redraw()


func clear_threat_buff() -> void:
	if threat_timer <= 0.0 and _threat_base_speed <= 0.0:
		return
	if _threat_base_speed > 0.0:
		speed = _threat_base_speed
	if _threat_base_touch_damage > 0.0:
		touch_damage = _threat_base_touch_damage
	threat_timer = 0.0
	threat_name = ""
	threat_damage_taken_mult = 1.0
	_threat_base_speed = 0.0
	_threat_base_touch_damage = 0.0
	queue_redraw()


func is_threatened() -> bool:
	return threat_timer > 0.0


func setup(t: Dictionary, time: float) -> void:
	tier = t
	color = t["color"]
	# 수가 줄어든 만큼 개체 경험치를 올렸었다(x2.4 = 총 XP 유지). 하지만 사장님은 총 XP가
	# 유지되는 게 아니라 줄기를 원한다("레벨업이 너무 빠름"). x2.0으로 낮추고 젬 드랍도
	# 확률로 바꿔(Main.GEM_DROP_CHANCE) 총 XP 수입을 예전의 약 42%로 내린다.
	xp_value = int(round(float(t["xp"]) * 2.0))
	radius = t.get("radius", 18.0)
	# 시간 강화는 Main의 런 진행 보정과 합쳐 한 번의 완만한 곡선이 되도록 제한한다.
	# 이전 0.45/초는 30분에 기본 HP 819를 만들어 스테이지 배수와 중복 폭증했다.
	# RPG 전환(사장님 요청 "수는 줄이고 한 마리한 마리 강력하게"): 수를 절반 이하로
	# 줄인 만큼 개체를 단단하게 만든다. 경험치 x2.4로 총 XP는 유지하되 한 마리를
	# 처리하는 시간이 길어져 HP바가 의미를 갖는다.
	# 2차 상향(사장님 "아직도 너무 쉬움"): 체력 x2.2 -> x2.8, 접촉 피해 x1.45 -> x1.75.
	# 자동공격 사거리 제한(Main.ATTACK_RANGE_BASE)과 함께 적용해 "몰려오는 걸 다 못 막는다"를 만든다.
	hp = (12.0 + time * 0.055) * float(t["hp_mult"]) * 2.8
	# 느린 적/빠른 적 차이를 끝까지 보존한다. 과거엔 10분 이후 대부분 상한 90에 붙었다.
	speed = min(96.0, (26.0 + time * 0.028) * float(t["speed_mult"]))
	# 30분 접촉 피해 기본값 약 24. 플레이어 방어·난이도 체력으로 생존 차이를 만든다.
	touch_damage = (10.0 + time * 0.008) * float(t.get("dmg_mult", 1.0)) * 1.75
	behavior = t.get("behavior", "")
	weak = t.get("weak", "")
	resist = t.get("resist", "")
	_shoot_cd = randf_range(0.8, 1.8)
	# 특수 공격은 정예로 승격됐을 때만 발동한다(elite는 Main이 setup 뒤에 세팅하므로
	# 여기서는 정의만 찾아 둔다). 첫 쿨다운을 흩어 정예 여럿이 동시에 터지지 않게 한다.
	_sp = GameConfig.elite_special(str(t.get("key", "")))
	_sp_cd = randf_range(2.4, SPECIAL_CD)
	# 스프라이트 경로는 tier가 정해지면 바뀌지 않는다. _draw에서 매 프레임 문자열을
	# 만들면 300마리 × 60fps = 초당 수만 번의 할당이 되므로 여기서 한 번만 해석한다.
	var key := str(t.get("key", ""))
	# 애니 폴더는 key가 아니라 스프라이트 파일명으로 찾는다. 정예·중간보스 티어 8종
	# (ember_stalker/hell_enforcer/grave_warden/tomb_knight/frost_sentry/icewall_golem/
	# rift_stalker/abyss_oracle)은
	# 고유 key를 쓰지만 스프라이트는 base 몹과 같으므로, 같은 프레임 폴더를 복제하지 않고
	# 그대로 재사용한다. 일반 몹은 key == 스프라이트 파일명이라 동작이 바뀌지 않는다.
	var sprite := str(t.get("sprite", ""))
	var akey := key if sprite.is_empty() else sprite.get_file().get_basename()
	_frames_attack = Assets.frames("res://assets/anim/%s_attack" % akey)
	_frames_walk = Assets.frames("res://assets/anim/%s_walk" % akey)
	_frames_walk_n = Assets.frames("res://assets/anim/%s_walk_n" % akey)
	_frames_walk_e = Assets.frames("res://assets/anim/%s_walk_e" % akey)
	_sprite_tex = Assets.tex(sprite)
	if _sprite_tex == null:
		_sprite_tex = Assets.tex("res://assets/enemies/%s.png" % key)

func _process(delta: float) -> void:
	_anim_t += delta
	# 죽는 중: AI·이동 정지, 죽음 애니만 재생 후 소멸
	if _dying:
		_die_t -= delta
		if _die_t <= 0.0:
			queue_free()
			return
		queue_redraw()
		return
	if threat_timer > 0.0:
		threat_timer -= delta
		if threat_timer <= 0.0:
			clear_threat_buff()
	# 소멸 타이머: 개발 전투 프리뷰가 끝나면 테스트 몬스터를 정리한다.
	if despawn_t > 0.0:
		despawn_t -= delta
		if despawn_t <= 0.0 and not _dying:
			_dying = true
			_die_t = DIE_DUR
			remove_from_group("enemies")
			return
	# 누적 지속피해 주기 표시 (0.35초마다 합산 숫자 — 장판·오라·회전검 딜 가시화)
	if _dmg_accum > 0.0:
		_dmg_flush += delta
		if _dmg_flush >= 0.35:
			var m2 := get_parent()
			if m2 and m2.has_method("_spawn_dmg_num") and _dmg_accum >= 1.0:
				m2._spawn_dmg_num(position, int(round(_dmg_accum)), false)
				_dmg_accum = 0.0
			_dmg_flush = 0.0
	if _flash_t > 0.0:
		_flash_t -= delta
		self_modulate = Color(8, 8, 9) if _flash_t > 0.0 else Color(1, 1, 1)
	# 피격 스쿼시 펀치 진행 (그리기 갱신)
	if _hit_t > 0.0:
		_hit_t -= delta
		queue_redraw()
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_factor = 1.0
	if _kb_cd > 0.0:
		_kb_cd -= delta
	# 넉백 적용 + 감쇠 (피격 반응)
	if _kb.length_squared() > 1.0:
		_move_on_stage(position + _kb, _kb.length() * delta)
		_kb = _kb.move_toward(Vector2.ZERO, 900.0 * delta)
	# 피격 순간 멈칫: 이동 정지
	if _hitstop > 0.0:
		_hitstop -= delta
		queue_redraw()
		return
	# 플레이어 추격 + 근접 시 공격 모션
	if _pl == null or not is_instance_valid(_pl):
		_pl = get_tree().get_first_node_in_group("player") as Player
	var pl := _pl
	if pl:
		var to: Vector2 = pl.position - position
		var d := to.length()
		# 화면 밖으로 멀리 떨어진 잡몹 정리 (뱀서식 컬링 — 성능 + 밀도 재활용). 엘리트·고정·소멸형 제외.
		if d > 1500.0 and not elite and not hold and despawn_t <= 0.0:
			queue_free()
			return
		# 4방향 판정 (플레이어 방향)
		if abs(to.x) >= abs(to.y):
			_dir = "w" if to.x < 0.0 else "e"
		else:
			_dir = "n" if to.y < 0.0 else "s"
		# 뱀서식: 정면 스프라이트를 항상 플레이어 쪽으로 좌우 반전 (상하 이동 중에도 방향감)
		if abs(to.x) > 4.0:
			_face_left = to.x < 0.0
		var dir: Vector2 = to.normalized() if d > 1.0 else Vector2.ZERO
		# 정예·중간보스 특수 공격이 활성이면 일반 행동을 통째로 건너뛴다.
		# 이 "멈춤"이 전조의 1번 신호다 — 추격이 딱 멈추면 큰 게 온다는 뜻.
		if _tick_special(delta, dir, d):
			queue_redraw()
			return
		match behavior:
			"ranged":
				# 사수: 방향을 잠근 조준선을 먼저 보여준 뒤 발사한다.
				if _shoot_windup > 0.0:
					_shoot_windup -= delta
					_attacking = true
					_atk_t += delta
					if _shoot_windup <= 0.0:
						_shoot_cd = 1.7
						_attacking = false
						var m := get_parent()
						if m and m.has_method("spawn_enemy_arrow"):
							m.spawn_enemy_arrow(position, _shoot_lock, touch_damage * 1.1,
								tier.get("shot_chill", false), 220.0, false,
								str(tier.get("damage_source", "enemy_projectile")))
				else:
					var pref := radius + 190.0
					if not hold:
						if d < pref - 40.0:
							_move_on_stage(position - dir * 600.0, speed * 0.9 * slow_factor * delta)
						elif d > pref + 40.0:
							_move_on_stage(pl.position, speed * slow_factor * delta)
					_attacking = false
					_shoot_cd -= delta
					if _shoot_cd <= 0.0 and d < 460.0 and _hitstop <= 0.0:
						_shoot_windup = _ranged_windup_duration()
						_shoot_lock = dir if dir != Vector2.ZERO else Vector2.DOWN
						_atk_t = 0.0
			"charge":
				# 돌진: 접근→고정된 경로 예고→고속 돌진→쿨다운
				match _cstate:
					0:
						_attacking = false
						if d > 1.0 and not hold:
							_move_on_stage(pl.position, speed * slow_factor * delta)
						if d < radius + 210.0:
							_cstate = 1
							_ctimer = _charge_windup_duration()
							_clock = dir if dir != Vector2.ZERO else Vector2.DOWN
							_atk_t = 0.0
					1:
						_ctimer -= delta
						_attacking = true
						_atk_t += delta
						if _ctimer <= 0.0:
							_cstate = 2
							_ctimer = 0.4
					2:
						_ctimer -= delta
						_move_on_stage(position + _clock * 800.0, max(speed * 2.6, 340.0) * slow_factor * delta)
						_attacking = true
						_atk_t += delta
						if _ctimer <= 0.0:
							_cstate = 3
							_ctimer = 1.4
					3:
						_attacking = false
						_ctimer -= delta
						if d > 1.0 and not hold:
							_move_on_stage(pl.position, speed * 0.5 * slow_factor * delta)
						if _ctimer <= 0.0:
							_cstate = 0
			_:
				# 기본 근접: 추격→부채꼴/원형 예고→짧은 타격→회복.
				# 자폭·분열도 죽기 전까지는 이 공통 공격을 사용한다.
				match _melee_state:
					0:
						_attacking = false
						if d <= _melee_reach() + 34.0:
							_melee_state = 1
							_melee_t = _melee_windup_duration()
							_strike_dir = dir if dir != Vector2.ZERO else Vector2.DOWN
							_atk_t = 0.0
						elif d > 1.0 and not hold:
							_move_on_stage(pl.position, speed * slow_factor * delta)
					1:
						_attacking = true
						_atk_t += delta
						_melee_t -= delta
						if _melee_t <= 0.0:
							_melee_state = 2
							_melee_t = _melee_strike_duration()
					2:
						_attacking = true
						_atk_t += delta
						_melee_t -= delta
						if not hold:
							var strike_speed := maxf(speed * (1.35 if elite else 2.2), 115.0 if elite else 190.0)
							_move_on_stage(position + _strike_dir * 600.0, strike_speed * slow_factor * delta)
						if _melee_t <= 0.0:
							_melee_state = 3
							_melee_t = _melee_recovery_duration()
					3:
						_attacking = false
						_melee_t -= delta
						if d > _melee_reach() + 16.0 and not hold:
							_move_on_stage(pl.position, speed * 0.22 * slow_factor * delta)
						if _melee_t <= 0.0:
							_melee_state = 0
	# 적끼리 밀어내기: 겹친 무리를 벌려 뱀서식 '벽'을 만듦. walkable 보정 경유(벽 통과 방지).
	if sep != Vector2.ZERO:
		_move_on_stage(position + sep, sep.length())
		sep = Vector2.ZERO
	queue_redraw()

# dot=true → 장판·오라 같은 지속피해. 넉백·멈칫 없이 피해만 준다.
# (매 프레임 틱마다 넉백이 걸리면 적이 장판 밖으로 계속 밀려나 장판이 무의미해짐)
func take_damage(d: float, crit: bool = false, dot: bool = false, element: String = "") -> void:
	var m := get_parent()
	# 상성: 공격 속성이 지정 안 되면 플레이어의 현재 공격 속성 사용. 약점 ×1.5 / 저항 ×0.6.
	var elem := element
	if elem == "" and m and "attack_element" in m:
		elem = str(m.attack_element)
	var hit_kind := ""
	if elem != "" and elem != "phys":
		if elem == weak:
			d *= 1.5
			hit_kind = "weak"
		elif elem == resist:
			d *= 0.6
			hit_kind = "resist"
	d *= threat_damage_taken_mult
	var actual_damage := minf(maxf(0.0, hp), maxf(0.0, d))
	if m and m.has_method("record_damage_dealt"):
		m.record_damage_dealt(actual_damage)
	hp -= d
	# 지속피해는 흰 피격 플래시도 생략 — 매 프레임 갱신되면 적이 계속 하얗게 떠서
	# 장판 안의 적이 흰 덩어리로 보임
	if not dot:
		_flash_t = 0.09
		_hit_t = HIT_DUR
		self_modulate = Color(8, 8, 9)
	# 데미지 숫자: 단발 타격(≥1)은 즉시, 지속피해(<1 틱)는 누적 후 주기 표시 (0 표시 방지)
	if m and m.has_method("_spawn_dmg_num"):
		if d >= 1.0 or crit:
			m._spawn_dmg_num(position, max(1, int(round(d))), crit, hit_kind, elem)
		else:
			_dmg_accum += d   # 장판·오라 등 → _process에서 합산해 표시
	# 넉백 + 멈칫 (플레이어 반대 방향). 엘리트 저항. 쿨다운으로 지속타 잠김 방지.
	if not dot and _kb_cd <= 0.0 and hp > 0.0:
		if _pl and is_instance_valid(_pl):
			var away := (position - _pl.position)
			if away.length_squared() > 0.01:
				var resist: float = 0.3 if elite else 1.0
				_kb = away.normalized() * 150.0 * resist   # 넉백 완화 (다단히트로 너무 멀리 밀리던 것)
		_hitstop = 0.05 if elite else 0.08
		_kb_cd = 0.25
	if hp <= 0 and not _dying:
		var main := get_parent()
		if main and main.has_method("on_enemy_killed"):
			main.on_enemy_killed(self)   # 보상·젬·폭발 이펙트 (죽는 순간)
		# 즉시 소멸 대신 죽음 애니 재생 (충돌/타겟에서 제외)
		_dying = true
		_die_t = DIE_DUR
		_kb = Vector2.ZERO
		remove_from_group("enemies")

# 특수 공격 진행. true를 반환하면 이번 프레임의 일반 행동을 건너뛴다(= 몸이 멈춘다).
# 전조 중에는 이동·일반 공격을 모두 멈추고, _draw가 몸 색과 포즈로 신호를 낸다.
func _tick_special(delta: float, dir: Vector2, distance: float) -> bool:
	if _sp_flash > 0.0:
		_sp_flash -= delta
	if _sp.is_empty() or not elite:
		return false
	match _sp_state:
		1:
			_sp_t -= delta
			_attacking = true
			if _sp_t <= 0.0:
				_release_special()
				_sp_state = 2
				_sp_t = SPECIAL_RECOVER
			return true
		2:
			_sp_t -= delta
			_attacking = false
			if _sp_t <= 0.0:
				_sp_state = 0
				_sp_cd = SPECIAL_CD
			return true
	_sp_cd -= delta
	if _sp_cd > 0.0 or distance > SPECIAL_RANGE or _hitstop > 0.0 or hold:
		return false
	# 지면 강타는 붙어서만 의미가 있다. 멀리서 허공을 치면 전조를 학습할 수 없다.
	if str(_sp.get("kind", "")) == "ground_slam" and distance > SPECIAL_SLAM_RADIUS + 70.0:
		return false
	_sp_state = 1
	_sp_t = SPECIAL_WINDUP
	_sp_lock = dir if dir != Vector2.ZERO else Vector2.DOWN
	_atk_t = 0.0
	_attacking = true
	return true


func _release_special() -> void:
	# 섬광은 순수 연출이라 Main 훅 유무와 무관하게 항상 켠다(부모 없는 테스트에서도 동일).
	_sp_flash = 0.14
	var m := get_parent()
	if m == null:
		return
	var dmg := touch_damage
	match str(_sp.get("kind", "")):
		"venom_burst":
			# 사방 10발 저속 독탄. 몸으로 막는 대신 틈을 보고 빠져나가야 한다.
			for i in 10:
				var a := TAU * float(i) / 10.0
				_shoot(m, Vector2.from_angle(a), dmg * 0.75, 128.0, false)
		"web_snare":
			# 앞쪽 3발 둔화탄. 맞으면 발이 묶여 다음 근접을 피하기 어려워진다.
			for i in 3:
				var a := _sp_lock.angle() + (float(i) - 1.0) * 0.30
				_shoot(m, Vector2.from_angle(a), dmg * 0.70, 240.0, true)
		"bone_volley":
			# 넓은 부채꼴 5발. 옆으로 흘리는 이동을 강제한다.
			for i in 5:
				var a := _sp_lock.angle() + (float(i) - 2.0) * 0.26
				_shoot(m, Vector2.from_angle(a), dmg * 0.72, 285.0, false)
		"flame_lash":
			# 좁은 3발 고속 화염. 직선상에 서 있으면 겹쳐 맞는다.
			for i in 3:
				var a := _sp_lock.angle() + (float(i) - 1.0) * 0.09
				_shoot(m, Vector2.from_angle(a), dmg * 0.85, 360.0, false, true)
		"ground_slam":
			# 투사체 없는 근접 광역. 전조를 보고 물러나는 것만이 답이다.
			if m.has_method("apply_player_damage") and "player" in m and m.player:
				var pl = m.player
				if pl.invuln <= 0.0 \
						and position.distance_to(pl.position) <= SPECIAL_SLAM_RADIUS + pl.radius:
					m.apply_player_damage(maxf(1.0, dmg * 1.9 - pl.armor), "enemy_slam")
					pl.invuln = 0.62
					pl.play_hurt()
					pl.knockback(position, 420.0)
			if "shake_t" in m:
				m.shake_t = maxf(float(m.shake_t), 0.22)
		"hex_orb":
			# 느린 대형 저주 구체 1발 + 좌우 보조 2발. 진로를 막아 위치를 강제한다.
			_shoot(m, _sp_lock, dmg * 1.05, 96.0, true)
			for s in [-0.55, 0.55]:
				_shoot(m, Vector2.from_angle(_sp_lock.angle() + float(s)),
					dmg * 0.55, 150.0, true)


func _shoot(m: Node, dir: Vector2, dmg: float, speed_px: float,
		chill: bool, fire: bool = false) -> void:
	if not m.has_method("spawn_enemy_arrow"):
		return
	m.spawn_enemy_arrow(position, dir, dmg, chill, speed_px, fire,
		str(tier.get("damage_source", "enemy_projectile")))


# 몸박 넉백: 플레이어(또는 지점)에 겹칠 때 반대로 밀어냄. 쿨다운 무시(겹침 유지 방지).
# 엘리트/보스급은 저항으로 덜 밀림. 죽는 중엔 무시.
func shove(from: Vector2, force: float) -> void:
	if _dying:
		return
	var away := position - from
	if away.length_squared() > 0.01:
		var resist: float = 0.35 if elite else 1.0
		_kb = away.normalized() * force * resist


func _draw() -> void:
	# 죽음 연출: 잠깐 흰빛으로 팽창 → 쪼그라들며 위로 떠올라 사라짐 (뱀서식 펑)
	if _dying:
		var dtex := _sprite_tex
		if dtex:
			var p: float = clamp(1.0 - _die_t / DIE_DUR, 0.0, 1.0)
			# 초반 살짝 팽창(팝) 후 급격히 수축
			var s: float = 1.28 if p < 0.16 else lerp(1.28, 0.0, (p - 0.16) / 0.84)
			var a: float = 1.0 - p * p        # 후반 급페이드
			var yoff: float = -p * 14.0        # 떠오름
			var w := radius * SPRITE_SCALE * s
			# 초반 흰빛(플래시) → 이후 원색 페이드
			var tint := Color(2.6, 2.6, 2.8, a) if p < 0.22 else Color(1.1, 1.0, 1.05, a)
			draw_texture_rect(dtex, Rect2(Vector2(-w / 2.0, -w / 2.0 + yoff), Vector2(w, w)), false, tint)
		return
	# 공격 예고 도형은 제거했다(사장님 "모션으로만 파악"). 22종 공격 애니가 windup
	# 시작부터 재생되므로 예고 역할을 모션이 맡는다. 보스 패턴 전조는 Boss.gd가 따로 그린다.
	if slow_factor < 1.0:
		draw_circle(Vector2.ZERO, radius + 3.0, Color(0.5, 0.8, 1.0, 0.28))
	# HP바: RPG 전환으로 개체가 단단해졌으니(체력 x2.2) 잡몹도 남은 체력이 보여야
	# 계속 때릴지 피할지 판단할 수 있다. 엘리트는 금색·굵게, 잡몹은 붉게·얇게 구분.
	# 만피 잡몹은 바를 숨겨 화면이 바로 뒤덮이지 않게 한다(맞은 적만 표시).
	var hp_ratio: float = clamp(hp / maxf(1.0, max_hp), 0.0, 1.0)
	if elite or hp_ratio < 0.999:
		var ebw: float = radius * 2.0
		var eby: float = -radius * SPRITE_SCALE * 0.5 - 9.0
		var bar_h: float = 5.0 if elite else 3.0
		draw_rect(Rect2(-ebw / 2.0 - 1.0, eby - 1.0, ebw + 2.0, bar_h + 2.0), Color(0.05, 0.04, 0.06, 0.92))
		draw_rect(Rect2(-ebw / 2.0, eby, ebw * hp_ratio, bar_h),
			Color(1.0, 0.78, 0.28) if elite else Color(0.92, 0.32, 0.30))
	var tex: Texture2D = null
	if _sp_state == 1 and _frames_attack.size() > 0:
		# 전조 신호 3: windup 포즈에서 프레임을 고정한다. 루프하지 않으므로 평소 공격과
		# 확실히 구분되고, "무기를 들어올린 채 멈춰 있다"로 읽힌다.
		tex = _frames_attack[mini(2, _frames_attack.size() - 1)]
	elif _attacking and _frames_attack.size() > 0:
		tex = _frames_attack[int(_atk_t * 12.0) % _frames_attack.size()]
	if tex == null:
		# 걷기 4방향 (없으면 south 폴백, 서=동 반전)
		var fw: Array = _frames_walk
		if _dir == "n" and _frames_walk_n.size() > 0:
			fw = _frames_walk_n
		elif (_dir == "e" or _dir == "w") and _frames_walk_e.size() > 0:
			fw = _frames_walk_e
		if fw.size() > 0:
			# 속도 연동 재생: 느린 몹은 어슬렁, 빠른 몹은 종종걸음 (7프레임으로도 자연스러운 보행)
			var wfps: float = 9.0 * clamp(speed / 55.0, 0.7, 1.55)
			tex = fw[int(_anim_t * wfps) % fw.size()]
	if tex == null:
		tex = _sprite_tex
	if tex:
		var w := radius * SPRITE_SCALE
		# 지역 위협은 겹치는 원형 표식 대신 몸 전체를 붉게 물들인다.
		# 피격 플래시는 self_modulate에서 별도로 처리하므로 순간 타격감도 유지된다.
		var tint := (Color(4.0, 0.14, 0.12) if threat_timer > 0.0
			else (Color(1.3, 1.08, 0.5) if elite else Color(1, 1, 1)))
		# 전조 신호 2: 몸이 기술 색으로 물든다. 진행도만큼 진해져 발동 시점을 읽게 한다.
		if _sp_state == 1:
			var sp_p: float = clampf(1.0 - _sp_t / SPECIAL_WINDUP, 0.0, 1.0)
			var glow: Color = _sp.get("color", Color(1.0, 0.6, 0.2))
			tint = tint.lerp(Color(glow.r * 2.6, glow.g * 2.6, glow.b * 2.6),
				0.30 + sp_p * 0.60)
		elif _sp_flash > 0.0:
			# 발동 순간만 하얗게 터진다. 링이 아니라 몸 자체가 번쩍여 타격 프레임이 읽힌다.
			tint = tint.lerp(Color(3.4, 3.4, 3.6), clampf(_sp_flash / 0.14, 0.0, 1.0))
		# 스프라이트 기본이 '왼쪽 향함'이므로: 왼쪽 볼 땐 그대로(1), 오른쪽 볼 땐 반전(-1)
		var sx := 1.0 if _face_left else -1.0
		# 걷기 흔들림(bob) + 미세 기우뚱(waddle): 단일 걷기 프레임에 생동감. 공격/멈칫 중엔 정지.
		var bob := 0.0
		var wob := 0.0
		if not _attacking and _hitstop <= 0.0:
			var spd_n: float = clamp(speed / 55.0, 0.6, 1.7)
			var ph := _anim_t * 8.5 * spd_n
			bob = sin(ph * 2.0) * (w * 0.012)     # 상하 통통 (약하게 — 7프레임 걷기 애니가 주 동작, 붕 뜸 완화)
			wob = sin(ph) * 0.02                   # 좌우 기우뚱 (약하게)
		# 피격 스쿼시 펀치: 맞는 순간 가로로 늘고 세로로 눌림 → 빠르게 원복 (임팩트감)
		var punch: float = clamp(_hit_t / HIT_DUR, 0.0, 1.0)
		var scx := sx * (1.0 + 0.28 * punch)
		var scy := 1.0 - 0.20 * punch
		var yoff2 := (w * 0.10 * punch) - bob   # 눌리며 살짝 바닥으로 + 걷기 통통
		draw_set_transform(Vector2.ZERO, wob, Vector2(scx, scy))
		draw_texture_rect(tex, Rect2(Vector2(-w / 2.0, -w / 2.0 + yoff2), Vector2(w, w)), false, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	var c := color
	var r := radius
	match tier.get("shape", "blob"):
		"bat":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-r * 1.7, -2), Vector2(-r * 0.4, -r * 0.6), Vector2(-r * 0.3, 4)]), c)
			draw_colored_polygon(PackedVector2Array([
				Vector2(r * 1.7, -2), Vector2(r * 0.4, -r * 0.6), Vector2(r * 0.3, 4)]), c)
			draw_circle(Vector2.ZERO, r, c)
		"skull":
			draw_circle(Vector2.ZERO, r, c)
			draw_rect(Rect2(-r * 0.4, r * 0.3, r * 0.8, r * 0.55), c)
		"orc":
			draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), c)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-7, r * 0.5), Vector2(-2, r * 0.5), Vector2(-4.5, r)]), Color.WHITE)
			draw_colored_polygon(PackedVector2Array([
				Vector2(7, r * 0.5), Vector2(2, r * 0.5), Vector2(4.5, r)]), Color.WHITE)
		"demon":
			draw_circle(Vector2.ZERO, r, c)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-r * 0.7, -r * 0.6), Vector2(-r * 0.3, -r * 0.5), Vector2(-r * 1.05, -r * 1.4)]), c)
			draw_colored_polygon(PackedVector2Array([
				Vector2(r * 0.7, -r * 0.6), Vector2(r * 0.3, -r * 0.5), Vector2(r * 1.05, -r * 1.4)]), c)
		_:
			draw_circle(Vector2(0, -2), r, c)
			draw_rect(Rect2(-r, -2, r * 2.0, r), c)

	draw_circle(Vector2(-6, -4), 3, Color.BLACK)
	draw_circle(Vector2(6, -4), 3, Color.BLACK)
