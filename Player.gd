class_name Player
extends Node2D

const BASE_RADIUS := 12.6   # 캐릭터 크기 (15→10.5로 줄였다가, 너무 작아 +20%)

# 뱀서식 스탯
var speed := 125.0   # 뱀서식: 느리고 묵직한 이동 (200 → 165 → 145 → 125)
var max_hp := 150.0
var hp := 150.0
var damage_mult := 1.0      # 모든 무기 피해 배수
var cooldown_mult := 1.0    # 무기 쿨다운 배수 (낮을수록 빠름)
var pickup_radius := 90.0   # 뱀서식 젬 흡수 범위 (55→90)
var regen := 0.0
var armor := 0.0
var area_mult := 1.0        # 범위 무기 크기 배수
var amount := 0             # 투사체 추가 개수 (복제의 룬)
var crit_chance := 0.0      # 치명타 확률 (매의 눈)
var crit_mult := 2.0        # 치명타 피해 배수 (광전사의 인장)

var radius := BASE_RADIUS
var invuln := 0.0           # 피격 무적 시간
var magnet_t := 0.0         # 자석 아이템 버프 남은 시간
var slow_t := 0.0           # 빙결 둔화 남은 시간 (아이스 퀸)
var cam: Camera2D

# 뱀서식: 대시 없음 (이동만). _last_dir는 무기 조준용으로 유지.
var _last_dir := Vector2(0, -1)
var moving := false   # 이번 프레임 이동 여부 (스폰 편향용 — 도망칠 틈)

func current_pickup_radius() -> float:
	return pickup_radius + (220.0 if magnet_t > 0.0 else 0.0)
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
	var key: String = _stage_data.get("key", "corvius_1")
	var base := "res://assets/anim/%s_%s" % [key, motion]
	var suf := ""
	if _dir == "n":
		suf = "_n"
	elif _dir == "e" or _dir == "w":
		suf = "_e"
	if suf != "":
		var f: Array = Assets.frames(base + suf)
		if f.size() > 0:
			return f
	return Assets.frames(base)


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
	# 4방향 애니가 기본 외형에만 있으므로 이렇게 하면 항상 작동.
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
	var v := Vector2.ZERO
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		v.x += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		v.y -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		v.y += 1.0
	# 게임패드 아날로그 스틱 (키 입력 없을 때)
	if v == Vector2.ZERO:
		var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
		if stick.length() > 0.25:
			v = stick
	if slow_t > 0.0:
		slow_t -= delta
	var eff_speed := speed * (0.55 if slow_t > 0.0 else 1.0)
	moving = v != Vector2.ZERO
	if v != Vector2.ZERO:
		var vn := v.normalized()
		var desired := position + vn * eff_speed * delta
		position = stage_layout.resolve_move(position, desired, radius) if stage_layout else desired
		_last_dir = vn
		# 4방향 판정: 수평 우세면 동/서, 수직 우세면 북/남
		if abs(vn.x) >= abs(vn.y):
			_dir = "w" if vn.x < 0.0 else "e"
			_face_left = vn.x < 0.0
		else:
			_dir = "n" if vn.y < 0.0 else "s"
	_walking = v != Vector2.ZERO
	_anim_t += delta
	if _attack_t > 0.0:
		_attack_t -= delta
	if _hurt_t > 0.0:
		_hurt_t -= delta

	position.x = clamp(position.x, radius, world_size.x - radius)
	position.y = clamp(position.y, radius, world_size.y - radius)
	if stage_layout:
		position = stage_layout.nearest_walkable(position, radius)

	if invuln > 0.0:
		invuln -= delta
	if magnet_t > 0.0:
		magnet_t -= delta

	queue_redraw()

func _draw() -> void:
	var r := radius
	# 라이트 헤일로(주변을 밝히던 원 2겹)는 제거 — 캐릭터 주변에 원이 떠 보였음.
	# 발밑 그림자는 유지: 없으면 캐릭터가 바닥에서 떠 보임.
	draw_set_transform(Vector2(0, r * 0.85), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, r * 0.95, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var aura: Color = _stage_data["aura"]
	if aura.a > 0.0:
		draw_circle(Vector2.ZERO, r + 8.0, aura)

	# 애니메이션 프레임 선택: 사망 > 피격 > 대시 > 공격 > 걷기 > 대기 (4방향 대응)
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
	if tex:
		var w := r * 2.6
		var sx := 1.0 if _dir == "w" else -1.0   # 스프라이트 기본 '왼쪽 향함': 서쪽은 그대로, 동쪽만 반전
		var recoil := -_last_dir * (r * 0.16 * cast)   # 발사 반동(조준 반대로 살짝)
		var popx := sx * (1.0 - 0.05 * cast)
		var popy := 1.0 + 0.10 * cast                   # 살짝 곧추섬
		draw_set_transform(recoil, 0.0, Vector2(popx, popy))
		draw_texture_rect(tex, Rect2(Vector2(-w / 2.0, -w / 2.0), Vector2(w, w)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var col: Color = _stage_data["color"]
		draw_circle(Vector2.ZERO, r, col)
		draw_circle(Vector2.ZERO, r * 0.6, col.lightened(0.35))

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

	# 피격 무적 표시
	if invuln > 0.0:
		draw_arc(Vector2.ZERO, r + 5.0, 0.0, TAU, 24, Color(1, 1, 1, 0.7), 2.0)
	# 자석 버프 표시 (흡수 범위 링)
	if magnet_t > 0.0:
		draw_arc(Vector2.ZERO, current_pickup_radius(), 0.0, TAU, 48, Color(0.7, 0.5, 1.0, 0.35), 2.0)
