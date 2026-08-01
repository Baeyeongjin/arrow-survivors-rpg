class_name Player
extends Node2D

const BASE_RADIUS := 12.6   # 캐릭터 크기 (15→10.5로 줄였다가, 너무 작아 +20%)
const DODGE_DURATION := 0.17
const DODGE_DISTANCE := 112.0
const DODGE_INVULN := 0.28
const DODGE_COOLDOWN := 1.20
# 피격 넉백. 초기 속도 220px/s가 900px/s^2로 죽으면 총 이동 약 27px, 지속 0.24초.
# 회피 거리(112px)보다 훨씬 짧게 잡아 "밀렸다"는 무게감만 주고 조작권은 바로 돌려준다.
const KNOCKBACK_DECAY := 900.0
const KNOCKBACK_MELEE := 220.0
const KNOCKBACK_PROJECTILE := 150.0
const KNOCKBACK_BOSS := 300.0

# 뱀서식 스탯
var speed := 125.0   # 뱀서식: 느리고 묵직한 이동 (200 → 165 → 145 → 125)
var max_hp := 150.0
var hp := 150.0
var damage_mult := 1.0      # 모든 무기 피해 배수
var cooldown_mult := 1.0    # 무기 쿨다운 배수 (낮을수록 빠름)
var pickup_radius := 90.0   # 뱀서식 젬 흡수 범위 (55→90)
var attack_range := 0.0        # 자동공격 사거리 (Main이 매 프레임 갱신, 0이면 안 그림)
var attack_range_idle := false # 사거리 안에 표적이 없어 무기가 대기 중
var _kb := Vector2.ZERO        # 피격 넉백 속도 (px/s, 감쇠)
var regen := 0.0
var armor := 0.0
var area_mult := 1.0        # 범위 무기 크기 배수
var amount := 0             # 투사체 추가 개수 (복제의 룬)
var crit_chance := 0.0      # 치명타 확률 (매의 눈)
var crit_mult := 2.0        # 치명타 피해 배수 (광전사의 인장)

var radius := BASE_RADIUS
var invuln := 0.0           # 피격 무적 시간
var slow_t := 0.0           # 빙결 둔화 남은 시간 (아이스 퀸)
var environment_speed_mult := 1.0   # 빙하 누적 냉기처럼 환경이 주는 비누적 이동 배수
var dodge_t := 0.0          # 공용 회피 이동 남은 시간
var dodge_cd := 0.0         # 공용 회피 재사용 대기시간
var cam: Camera2D

# 최근 이동 방향은 자동 무기 조준과 방향 입력이 없을 때의 회피 방향에 함께 쓴다.
var _last_dir := Vector2(0, -1)
var _dodge_dir := Vector2(0, -1)
var moving := false   # 이번 프레임 이동 여부 (스폰 편향용 — 도망칠 틈)

func current_pickup_radius() -> float:
	return pickup_radius
var world_size := Vector2(2400, 2400)   # Main이 설정
var stage_layout = null    # 독립 맵 이동 가능 영역 (Main이 런 시작 시 설정)

# 진화 외형 (캐릭터별 4단계 — Main이 stages_data 설정)
var stages_data: Array = []
var stage := 0
var _stage_data: Dictionary = {}
var _evo := 1.0   # 현재 적용된 진화 능력치 배수 (중복 적용 방지)

# 애니메이션
var _walking := false
var _face_left := false   # 좌우 반전 (서쪽)
var _dir := "s"           # 바라보는 4방향: s/n/e/w (스프라이트 선택)
var _anim_t := 0.0
var _attack_t := 0.0
var _hurt_t := 0.0        # 피격 모션 재생 시간
var _dying := false       # 사망 모션 재생 중
var _death_t := 0.0

# 현재 방향에 맞는 모션 프레임 (없으면 south 폴백). 서(w)는 동(e)을 반전해 씀.
func _mframes(motion: String) -> Array:
	# 1방향 + 좌우 반전이 확정 아트 파이프라인이다(전면 재생산 때 결정).
	# 예전 4방향 시절의 _n/_e 폴더 조회가 남아 있었는데, 그 폴더는 하나도 없어서
	# 모든 프레임 선택마다 빈 조회만 하고 폴백했다. _dir 는 반전 판정에만 쓴다.
	return Assets.frames("res://assets/anim/%s_%s" % [_stage_data.get("key", "corvius_1"), motion])


func play_attack() -> void:
	_attack_t = 0.45

func play_hurt() -> void:
	if not _dying:
		_hurt_t = 0.3

func play_death() -> void:
	_dying = true
	_death_t = 0.0
	# 게임오버로 트리가 멈춰도 사망 모션은 계속 재생되도록
	process_mode = Node.PROCESS_MODE_ALWAYS


func _movement_input() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		v.x += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		v.y -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		v.y += 1.0
	if v == Vector2.ZERO:
		v = _stick_input()
	return v.normalized() if v != Vector2.ZERO else Vector2.ZERO


# 게임패드 왼쪽 스틱. 데드존 밖의 초과분만 남기고 다시 스케일한다.
#
# 예전에는 stick.length() > 0.25 면 그 값을 그대로 썼는데, 위에서 normalized()가
# 걸려서 0.26짜리 드리프트도 전속력이 됐다. 축이 살짝 틀어진 패드가 꽂혀 있으면
# 손을 안 대도 캐릭터가 한 방향으로 계속 걸어갔다(사장님 신고: 시작하면 오른쪽으로 감).
#
# 연결된 패드가 없으면 아예 읽지 않는다. 장치가 없는데도 축이 0이 아닌 값을 주는
# 환경이 있어서, 길이 검사만으로는 못 막는다.
const STICK_DEADZONE := 0.35


func _stick_input() -> Vector2:
	if Input.get_connected_joypads().is_empty():
		return Vector2.ZERO
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	var mag := stick.length()
	if mag <= STICK_DEADZONE:
		return Vector2.ZERO
	# 데드존을 뺀 나머지를 0~1로 다시 편다. 데드존 경계에서 속도가 튀지 않는다.
	return stick.normalized() * ((mag - STICK_DEADZONE) / (1.0 - STICK_DEADZONE))


# 마우스 커서의 월드 좌표. 자동조준을 걷어내고 조준을 플레이어 손에 돌려준다.
# 카메라 줌·흔들림이 걸려 있어 화면 좌표를 그대로 쓰면 어긋나므로 캔버스 역변환을 쓴다.
func aim_point() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return position + _last_dir * 100.0
	return vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()


# 커서를 향하는 단위 벡터. 커서가 캐릭터 위에 겹쳐 있으면 마지막 방향을 유지한다.
func aim_dir() -> Vector2:
	var to := aim_point() - position
	return to.normalized() if to.length_squared() > 4.0 else _last_dir


func _face_direction(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	_last_dir = dir
	if abs(dir.x) >= abs(dir.y):
		_dir = "w" if dir.x < 0.0 else "e"
		_face_left = dir.x < 0.0
	else:
		_dir = "n" if dir.y < 0.0 else "s"


# 피격 넉백 적용. from은 때린 쪽 위치 — 그 반대로 밀린다. 회피 중에는 무시한다.
func knockback(from: Vector2, force: float) -> void:
	if _dying or dodge_t > 0.0:
		return
	var away := position - from
	if away.length_squared() <= 0.01:
		return
	_kb = away.normalized() * force


func try_dodge(direction: Vector2 = Vector2.ZERO) -> bool:
	if _dying or dodge_cd > 0.0 or dodge_t > 0.0:
		return false
	var chosen: Vector2 = direction.normalized() if direction.length_squared() > 0.01 else _movement_input()
	if chosen == Vector2.ZERO:
		chosen = _last_dir
	_dodge_dir = chosen.normalized()
	dodge_t = DODGE_DURATION
	dodge_cd = DODGE_COOLDOWN
	invuln = maxf(invuln, DODGE_INVULN)
	_face_direction(_dodge_dir)
	queue_redraw()
	return true


func is_dodging() -> bool:
	return dodge_t > 0.0


func _ready() -> void:
	add_to_group("player")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_stage(0)
	# 카메라 추적
	cam = Camera2D.new()
	cam.zoom = Vector2(1.5, 1.5)   # 뱀서식: 가까이 당겨 캐릭터·적을 크게 (몰입·압박↑)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(world_size.x)
	cam.limit_bottom = int(world_size.y)
	add_child(cam)
	cam.make_current()

func set_stage(s: int) -> void:
	if stages_data.is_empty():
		stages_data = GameConfig.char_stages("corvius")
	stage = clamp(s, 0, stages_data.size() - 1)
	# 외형·애니는 항상 기본(0단계) 고정 — 레벨업 시 겉모습 진화 없음(능력치만 강화).
	_stage_data = stages_data[0]
	radius = BASE_RADIUS * float(_stage_data["scale"])
	# 진화 능력치 강화 (단계 상승분만 반영, 중복 방지)
	var np: float = GameConfig.stage_power(stage)
	if np != _evo:
		damage_mult *= np / _evo
		max_hp *= 1.0 + (np / _evo - 1.0) * 0.6   # 체력은 절반 정도만
		hp = min(max_hp, hp + max_hp * 0.15)        # 진화 시 소량 회복
		_evo = np
	queue_redraw()

func _process(delta: float) -> void:
	# 사망 모션 재생 중엔 입력/이동 정지
	if _dying:
		_death_t += delta
		_anim_t += delta
		queue_redraw()
		return
	var v := _movement_input()
	if slow_t > 0.0:
		slow_t = maxf(0.0, slow_t - delta)
	if invuln > 0.0:
		invuln = maxf(0.0, invuln - delta)
	if dodge_cd > 0.0:
		dodge_cd = maxf(0.0, dodge_cd - delta)
	var eff_speed := speed * clampf(environment_speed_mult, 0.25, 1.0) * (0.55 if slow_t > 0.0 else 1.0)
	if dodge_t > 0.0:
		# 프레임이 크게 끊겨도 총 회피 거리가 DODGE_DISTANCE를 넘지 않게 남은 시간만 적분한다.
		var dodge_motion_time := minf(delta, dodge_t)
		var dodge_step := DODGE_DISTANCE / DODGE_DURATION * dodge_motion_time
		var dodge_target := position + _dodge_dir * dodge_step
		position = stage_layout.resolve_move(position, dodge_target, radius) if stage_layout else dodge_target
		dodge_t = maxf(0.0, dodge_t - delta)
		moving = true
		_walking = true
	elif v != Vector2.ZERO:
		var desired := position + v * eff_speed * delta
		position = stage_layout.resolve_move(position, desired, radius) if stage_layout else desired
		_face_direction(v)
		moving = true
		_walking = true
	else:
		moving = false
		_walking = false
	# 피격 넉백. 로그라이크를 벗어난 뒤로는 "맞아도 제자리"가 무게감을 깎는다(사장님 요청).
	# 입력 이동과 별개로 적분하고 지형은 resolve_move로 통과시켜, 벽을 뚫고 밀려나지 않게 한다.
	# 회피 중에는 넉백을 받지 않는다 — 회피의 값이 사라지면 안 된다.
	if _kb.length_squared() > 1.0:
		if dodge_t > 0.0:
			_kb = Vector2.ZERO
		else:
			var kb_target := position + _kb * delta
			position = stage_layout.resolve_move(position, kb_target, radius) if stage_layout else kb_target
			_kb = _kb.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	_anim_t += delta
	if _attack_t > 0.0:
		_attack_t -= delta
	if _hurt_t > 0.0:
		_hurt_t -= delta

	position.x = clamp(position.x, radius, world_size.x - radius)
	position.y = clamp(position.y, radius, world_size.y - radius)
	if stage_layout:
		position = stage_layout.nearest_walkable(position, radius)

	queue_redraw()

func _draw() -> void:
	var r := radius
	# 회피 잔상: 이동 방향 반대쪽에 짧은 속도선을 남겨 순간 이동량과 무적 구간을 읽게 한다.
	if dodge_t > 0.0:
		var dodge_alpha := clampf(dodge_t / DODGE_DURATION, 0.0, 1.0)
		var side := _dodge_dir.orthogonal()
		for i in 3:
			var lane := float(i - 1) * r * 0.45
			var trail_from := -_dodge_dir * r * 0.3 + side * lane
			var trail_to := -_dodge_dir * r * (1.8 + i * 0.45) + side * lane
			draw_line(trail_from, trail_to, Color(0.55, 0.9, 1.0, dodge_alpha * (0.62 - i * 0.12)), 3.0 - i * 0.55)
	# 라이트 헤일로(주변을 밝히던 원 2겹)는 제거 — 캐릭터 주변에 원이 떠 보였음.
	# 발밑 그림자는 유지: 없으면 캐릭터가 바닥에서 떠 보임.
	draw_set_transform(Vector2(0, r * 0.85), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, r * 0.95, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var aura: Color = _stage_data["aura"]
	if aura.a > 0.0:
		draw_circle(Vector2.ZERO, r + 8.0, aura)

	# 애니메이션 프레임 선택: 사망 > 피격 > 대시 > 공격 > 걷기 > 대기 (1방향 + 좌우 반전)
	var tex: Texture2D = null
	if _dying:
		var fd: Array = _mframes("death")
		if fd.size() > 0:
			var di: int = int(_death_t * 10.0)
			tex = fd[clamp(di, 0, fd.size() - 1)]   # 마지막 프레임에서 정지
	if tex == null and _hurt_t > 0.0:
		var fh: Array = _mframes("hurt")
		if fh.size() > 0:
			var hi: int = int((0.3 - _hurt_t) / 0.3 * fh.size())
			tex = fh[clamp(hi, 0, fh.size() - 1)]
	if tex == null and _attack_t > 0.0:
		var fa: Array = _mframes("attack")
		if fa.size() > 0:
			var idx: int = int((0.45 - _attack_t) / 0.45 * fa.size())
			tex = fa[clamp(idx, 0, fa.size() - 1)]
	if tex == null and _walking:
		var fw: Array = _mframes("walk")
		if fw.size() > 0:
			tex = fw[int(_anim_t * 10.0) % fw.size()]
	if tex == null:   # 정지 시 대기(idle) 애니
		var fi: Array = _mframes("idle")
		if fi.size() > 0:
			tex = fi[int(_anim_t * 6.0) % fi.size()]
	if tex == null:
		tex = Assets.tex(_stage_data.get("sprite", ""))
	# 캐스팅 플로리시: 발사 직후 0.15초 팝(반동+늘어남). attack 프레임 유무와 무관하게 적용.
	var cast: float = clamp((_attack_t - 0.30) / 0.15, 0.0, 1.0)
	# 피격 플래시. 예전에는 캐릭터 둘레에 하얀 링을 그려 알렸는데, 위 257번 줄에서
	# 헤일로를 걷어낸 것과 같은 이유로("캐릭터 주변에 원이 떠 보였음") 링을 없앴다.
	# hurt 애니메이션 자산이 없으므로 스프라이트를 붉게 물들여 대신한다.
	var hurt_flash: float = clampf(_hurt_t / 0.3, 0.0, 1.0)
	var body_tint := Color.WHITE
	if hurt_flash > 0.0:
		body_tint = Color(1.0, 1.0 - 0.6 * hurt_flash, 1.0 - 0.6 * hurt_flash)

	if tex:
		var w := r * 2.6
		var sx := 1.0 if _dir == "w" else -1.0   # 스프라이트 기본 '왼쪽 향함': 서쪽은 그대로, 동쪽만 반전
		var recoil := -_last_dir * (r * 0.16 * cast)   # 발사 반동(조준 반대로 살짝)
		var popx := sx * (1.0 - 0.05 * cast)
		var popy := 1.0 + 0.10 * cast                   # 살짝 곧추섬
		draw_set_transform(recoil, 0.0, Vector2(popx, popy))
		draw_texture_rect(tex, Rect2(Vector2(-w / 2.0, -w / 2.0), Vector2(w, w)), false, body_tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var col: Color = _stage_data["color"]
		draw_circle(Vector2.ZERO, r, col * body_tint)
		draw_circle(Vector2.ZERO, r * 0.6, (col * body_tint).lightened(0.35))

	# 캐스팅 섬광: 발사 방향(손끝)에 밝은 스파크 — 무기를 쏘는 순간의 시각 신호
	if cast > 0.0:
		var mp := _last_dir * (r * 1.15)
		draw_circle(mp, r * 0.55 * cast, Color(1.0, 0.95, 0.6, 0.5 * cast))
		draw_circle(mp, r * 0.30 * cast, Color(1.0, 1.0, 0.95, 0.65 * cast))

	# 진화 단계 표시. 체력 바가 상시 표기라 그 아래로 (겹치지 않게)
	for i in stage:
		draw_circle(Vector2(-r + 6.0 + i * 8.0, r + 15.0), 3.0, Color(1, 0.9, 0.3))

	# 체력 바 (뱀서식: HUD 대신 캐릭터 발밑에 얇은 적색 바). 만피여도 상시 표기.
	if not _dying:
		var bw := r * 2.2
		var bh := 3.0
		var by := r + 4.0
		var f: float = clamp(hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(Vector2(-bw / 2.0 - 1.0, by - 1.0), Vector2(bw + 2.0, bh + 2.0)), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(Vector2(-bw / 2.0, by), Vector2(bw * f, bh)), Color(0.88, 0.18, 0.20))

	# 회피 무적만 링으로 알린다. 회피는 플레이어가 직접 쓴 기술이라 남은 무적을
	# 읽을 수 있어야 하기 때문이다. 피격 무적은 위의 붉은 플래시로 대신한다.
	if dodge_t > 0.0 and invuln > 0.0:
		draw_arc(Vector2.ZERO, r + 5.0, 0.0, TAU, 24, Color(0.45, 0.9, 1.0, 0.9), 2.0)
	# 자동공격 사거리. 표적이 없어 무기가 멈춰 있을 때만 또렷하게 그려서
	# "왜 안 쏘는지"를 알려 주고, 전투 중에는 거의 안 보이게 죽인다.
	if attack_range > 0.0:
		var range_alpha := 0.20 if attack_range_idle else 0.05
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 72,
			Color(0.92, 0.86, 0.62, range_alpha), 1.0)
