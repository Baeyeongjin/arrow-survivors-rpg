class_name Arrow
extends Node2D

var velocity := Vector2(0, -780)
var damage := 10.0
var pierce := 0
var radius := 6.0
var hit := {}

# 수식어 (Main이 발사 시 설정)
var crit_chance := 0.0
var crit_mult := 2.0
var explode_radius := 0.0
var explode_damage := 0.0
var bounce := 0
var homing := 0.0
var slow_amount := 0.0
var slow_time := 0.0
var gravity := 0.0                # 포물선 낙하 가속 (도끼 등)
var lifesteal := 0.0
var life := 2.2   # 수명(초) — 월드가 넓어 화면 컬링 대신 사용
var sprite_path := "res://assets/items/arrow.png"
var spin := 0.0                   # >0이면 진행방향 대신 스스로 회전 (차크람·도끼 등)
var upright := false              # true면 회전 없이 똑바로 (불꽃·에너지 등 원소 이펙트 프레임 애니)
var trail := false                # 잔상 트레일 (스킬용)
var trail_col := Color(1, 0.9, 0.5)  # 트레일 색 (무기별)
var scale_mul := 1.0              # 스프라이트 크기 배수
var _vis := 1.0                   # 무기 성장 시각 배율 (Main.wfx_boost 캡처 — 크기 상한도 함께 키움)
var _etint := Color(1.0, 0.85, 0.45)   # 진화 시그니처 색 (Main.EVO_TINT — 후광·틴트·트레일)
var anim_dir := ""                # 투사체 프레임 애니메이션 (assets/anim/<dir>)
var fx_hit := ""                  # 명중 시 스폰할 이펙트 애니 이름 (assets/anim/<fx_hit>)
var fx_hit_size := 72.0           # 명중 이펙트 표시 크기
var _age := 0.0
var _hist: Array = []
var evolved_glow := false          # 진화 무기 투사체: 황금 후광 + 발광 + 확대
var _homing_target: Node2D = null  # 유도 타겟 캐시 (스로틀 재탐색)
var _retarget_t := 0.0
var boomerang := false              # 부메랑: 나갔다 감속 후 플레이어에게 되돌아옴
var _boomer_ret := false            # 귀환 단계
var _pl_ref: Node2D = null

# 뱀서식 전역 투사체 속도 배율 (묵직한 템포). 사거리는 수명 보정으로 유지.
const SPEED_SCALE := 0.82
# 뱀서식 사거리 상한: 투사체는 화면 언저리(약 반화면 이상)에서 소멸. 무한히 날아가지 않음.
const MAX_RANGE := 590.0

var visual_kind := ""

func _ready() -> void:
	add_to_group("arrows")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var p := get_parent()
	# 무기 성장 시각 배율 캡처 (발사 중 동기 생성이라 유효). 레벨·진화에 따라 투사체가 커진다.
	if p and "wfx_boost" in p:
		_vis = clampf(float(p.wfx_boost), 1.0, 1.8)
		scale_mul *= _vis
	if p and "_evo_spawn" in p and p._evo_spawn:
		evolved_glow = true
		# 진화 무기 시그니처 효과 (EVO_FX 테이블에서 조회 → 투사체가 다르게 공격)
		var ek: String = p._evo_kind if "_evo_kind" in p else ""
		# 시그니처 색: 투사체·후광·트레일이 진화 색으로 물든다 (진화가 한눈에 보이게)
		if ek != "" and p.has_method("_evo_tint"):
			_etint = p._evo_tint(ek)
			trail = true
			trail_col = _etint
		var fx: Dictionary = p.EVO_FX.get(ek, {}) if ek != "" else {}
		if fx.has("pierce"):
			pierce = max(pierce, int(fx["pierce"]))
		if fx.has("homing"):
			homing = max(homing, float(fx["homing"]))
		if fx.has("slow"):
			slow_amount = max(slow_amount, float(fx["slow"]))
			slow_time = max(slow_time, float(fx.get("slow_t", 1.6)))
		if fx.has("ls"):
			lifesteal += float(fx["ls"])
		if fx.has("explode"):
			explode_radius = max(explode_radius, float(fx["explode"]))
			explode_damage = max(explode_damage, damage * float(fx.get("efrac", 0.5)))
	life /= SPEED_SCALE   # 느려진 만큼 오래 살아 같은 거리 이동 (사거리 보존)
	# 사거리 상한 적용 (유도탄은 추적 여유를 위해 1.4배 허용). 부메랑은 자체 궤도라 제외.
	if not boomerang:
		var spd := velocity.length() * SPEED_SCALE
		if spd > 1.0:
			var cap := (MAX_RANGE * (1.4 if homing > 0.0 else 1.0)) / spd
			life = min(life, cap)

func _process(delta: float) -> void:
	# 부메랑: 나갔다 감속 → 플레이어에게 귀환 (도착 시 소멸)
	if boomerang:
		if _boomerang_move(delta):
			queue_free()
			return
		_age += delta
		if trail:
			_hist.append(position)
			if _hist.size() > 7:
				_hist.pop_front()
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		queue_redraw()
		return
	# 유도: 가장 가까운 적 방향으로 서서히 선회 (타겟 재탐색은 스로틀 → 부하 절감)
	if homing > 0.0:
		_retarget_t -= delta
		if _retarget_t <= 0.0 or not is_instance_valid(_homing_target):
			_homing_target = _nearest()
			_retarget_t = 0.08
		if is_instance_valid(_homing_target):
			var spd := velocity.length()
			var desired: Vector2 = (_homing_target.position - position).normalized() * spd
			# 빠른 락온(스냅): 발사 후 곧장 적을 향해 휘어 '슉' 꽂힘 (빙빙 도는 잔류 방지)
			velocity = velocity.lerp(desired, clamp(homing * delta * 2.4, 0.0, 1.0))

	if gravity > 0.0:
		velocity.y += gravity * delta
	position += velocity * delta * SPEED_SCALE
	_age += delta
	if trail:
		_hist.append(position)
		if _hist.size() > 7:
			_hist.pop_front()
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()

# 부메랑 이동: 나가며 감속 → 귀환 시 플레이어로 가속. true 반환 시 소멸.
func _boomerang_move(delta: float) -> bool:
	if not _boomer_ret:
		velocity = velocity.move_toward(Vector2.ZERO, 1150.0 * delta)
		if velocity.length() < 55.0 or _age > 0.5:
			_boomer_ret = true
			hit.clear()   # 귀환길에 다시 타격 허용
	else:
		if _pl_ref == null or not is_instance_valid(_pl_ref):
			_pl_ref = get_tree().get_first_node_in_group("player")
		if _pl_ref:
			var to: Vector2 = _pl_ref.position - position
			if to.length() < 28.0:
				return true
			velocity = velocity.move_toward(to.normalized() * 660.0, 3200.0 * delta)
	position += velocity * delta * SPEED_SCALE
	return false


func _nearest():
	var best = null
	var best_d := 1e9
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			var d := position.distance_to(e.position)
			if d < best_d:
				best_d = d
				best = e
	for b in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(b):
			var d := position.distance_to(b.position)
			if d < best_d:
				best_d = d
				best = b
	# 주변 파괴 오브젝트(관·상자)도 유도 대상 (적 우선 위해 +90 후순위 보정)
	for br in get_tree().get_nodes_in_group("breakables"):
		if is_instance_valid(br):
			var d := position.distance_to(br.position) + 90.0
			if d < best_d:
				best_d = d
				best = br
	return best

func _draw() -> void:
	# 잔상 트레일
	if trail and _hist.size() > 1:
		for i in range(_hist.size() - 1):
			var a2: float = float(i) / _hist.size() * 0.6
			draw_line(_hist[i] - position, _hist[i + 1] - position,
				Color(trail_col.r, trail_col.g, trail_col.b, a2), 3.5)
	# 진화 오라: 중심에 맥동하는 황금 후광 (진화 무기 식별) + 발광·확대
	var emod := Color(1, 1, 1)
	var escale := 1.0
	if evolved_glow:
		# 진화 시그니처 색으로 후광·스프라이트 틴트 (무기마다 다른 색 — EVO_TINT)
		var pls: float = 0.5 + 0.5 * sin(_age * 9.0)
		var gr: float = min(10.0 * _vis, 5.0 * (radius / 6.0) * scale_mul) * (1.15 + 0.2 * pls)
		draw_circle(Vector2.ZERO, gr, Color(_etint.r, _etint.g, _etint.b, 0.18 + 0.13 * pls))
		draw_circle(Vector2.ZERO, gr * 0.62, Color(minf(_etint.r * 1.3, 1.0), minf(_etint.g * 1.3, 1.0), minf(_etint.b * 1.3, 1.0), 0.20 + 0.15 * pls))
		emod = Color(0.6 + _etint.r * 0.8, 0.6 + _etint.g * 0.8, 0.6 + _etint.b * 0.8)
		escale = 1.22
	# 방향: upright=원소 이펙트(회전 안 함) / spin>0=자체 회전 / 그 외=진행방향 지향
	var ang := 0.0 if upright else ((_age * spin) if spin > 0.0 else (velocity.angle() + PI / 2.0))
	draw_set_transform(Vector2.ZERO, ang, Vector2(escale, escale))
	# 프레임 애니메이션 투사체 (지정 시 우선)
	if anim_dir != "":
		var fr: Array = Assets.frames(anim_dir)
		if fr.size() > 0:
			var ft: Texture2D = fr[int(_age * 14.0) % fr.size()]
			# 투사체 크기 대폭 축소(캐릭터보다 작게). 상한도 성장 배율(_vis)만큼 함께 커짐.
			var fw: float = min(13.0 * _vis, 7.0 * (radius / 6.0) * scale_mul)
			draw_texture_rect(ft, Rect2(Vector2(-fw / 2.0, -fw / 2.0), Vector2(fw, fw)), false, emod)
			return
	# 전용 프레임이 아직 없을 때만 코드 기반 실루엣을 사용한다.
	if visual_kind != "":
		_draw_procedural_projectile(visual_kind)
		return
	var tex := Assets.tex(sprite_path)
	if tex:
		# 뱀서식: 투사체 작게 (화면 가림 방지). 상한은 성장 배율(_vis)만큼 함께 커짐.
		var w: float = min(13.0 * _vis, 7.0 * (radius / 6.0) * scale_mul)
		draw_texture_rect(tex, Rect2(Vector2(-w / 2.0, -w / 2.0), Vector2(w, w)), false, emod)
		return
	var k := radius / 6.0   # 큰 화살이면 길게
	var col := Color(1, 0.9, 0.4)
	if explode_radius > 0.0:
		col = Color(1, 0.55, 0.2)      # 폭발 화살: 주황
	elif homing > 0.0:
		col = Color(0.6, 1.0, 0.7)     # 유도 화살: 녹색
	elif slow_amount > 0.0:
		col = Color(0.6, 0.85, 1.0)    # 둔화 화살: 하늘
	draw_line(Vector2(0, 9 * k), Vector2(0, -9 * k), col, 3 * k)
	draw_line(Vector2(0, -9 * k), Vector2(-4 * k, -3 * k), col, 2 * k)
	draw_line(Vector2(0, -9 * k), Vector2(4 * k, -3 * k), col, 2 * k)


func _draw_procedural_projectile(kind: String) -> void:
	var k: float = maxf(0.8, radius / 6.0) * scale_mul
	if kind == "tempest":
		var c := Color(0.35, 0.9, 1.0, 1.0)
		var gold := Color(1.0, 0.78, 0.28, 1.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -12 * k), Vector2(4 * k, -3 * k), Vector2(2 * k, 12 * k),
			Vector2(0, 6 * k), Vector2(-2 * k, 12 * k), Vector2(-4 * k, -3 * k)
		]), c)
		draw_line(Vector2(0, -11 * k), Vector2(0, 10 * k), Color(1, 1, 1, 0.9), 1.5 * k)
		draw_line(Vector2(-5 * k, -4 * k), Vector2(5 * k, 4 * k), gold, 1.5 * k)
		return
	if kind == "meteor":
		var c2 := Color(1.0, 0.3, 0.08, 1.0)
		draw_circle(Vector2.ZERO, 7.5 * k, Color(1.0, 0.58, 0.12, 0.42))
		draw_circle(Vector2.ZERO, 5.5 * k, c2)
		draw_circle(Vector2(-1.5 * k, -2.0 * k), 2.8 * k, Color(1.0, 0.95, 0.62, 1.0))
		draw_line(Vector2(-4 * k, 4 * k), Vector2(-12 * k, 12 * k), Color(1.0, 0.32, 0.08, 0.75), 3.0 * k)
		return
	var c3 := Color(1.0, 0.9, 0.38, 1.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -10 * k), Vector2(3 * k, -2 * k), Vector2(1.5 * k, 10 * k),
		Vector2(-1.5 * k, 10 * k), Vector2(-3 * k, -2 * k)
	]), c3)
	draw_line(Vector2(0, -10 * k), Vector2(0, 10 * k), Color(1, 1, 1, 0.85), 1.2 * k)
