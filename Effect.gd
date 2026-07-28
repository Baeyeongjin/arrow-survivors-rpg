class_name Effect
extends Node2D
# 짧게 나타났다 사라지는 시각 효과 (번개 줄기 / 폭발 링)

var kind := "ring"          # "ring" 또는 "bolt"
var life := 0.3
var max_life := 0.3
var rad := 60.0
var col := Color(1, 1, 1)
var from_global := Vector2.ZERO   # bolt 시작점(전역)
var delay := 0.0                  # 시작 지연 (다중 링 연출용)
var dir := Vector2.ZERO           # spark: 타격 진행방향 (이 방향 위주로 샤드가 튐)
var _zig := PackedVector2Array()  # 번개 지그재그 경로 (로컬)

var _parts := []   # burst 파티클 [방향, 속도]

# 가산합성 머티리얼 (전 인스턴스 공유 — 에너지 이펙트가 어두운 배경 위에서 빛나게).
# 스프라이트 애니(FxAnim)엔 쓰지 않음: 가산은 검은 외곽선을 지워 청크한 도트가 망가짐.
static var _add_mat: CanvasItemMaterial = null

# 이펙트 강도 설정 (옵션): 0=끔 1=약함 2=보통 3=화려함. Main이 설정 로드 시 주입.
static var fx_level := 2

# 강도별 파티클 배수 (0이면 아예 생성 안 함)
static func _pmul() -> float:
	return [0.0, 0.55, 1.0, 1.5][clamp(fx_level, 0, 3)]

var points := PackedVector2Array()

func _ready() -> void:
	if fx_level == 0:
		queue_free()
		return
	add_to_group("effects")
	# 흡혈(drain)은 가산합성 제외 — 피는 빛나면 안 되고, 가산이면 붉은 발광이 되어버림
	if kind != "drain":
		if _add_mat == null:
			_add_mat = CanvasItemMaterial.new()
			_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = _add_mat
	var pm := _pmul()
	if kind == "burst":
		for i in int(round(10 * pm)):
			var ang := randf() * TAU
			_parts.append([Vector2(cos(ang), sin(ang)), randf_range(60.0, 160.0)])
	if kind == "spark":
		# 타격 진행방향 위주로 샤드가 튐 (방향성 임팩트). 방향 없으면 사방.
		var base: float = dir.angle() if dir != Vector2.ZERO else randf() * TAU
		for i in int(round(7 * pm)):
			var ang := base + randf_range(-1.0, 1.0)
			_parts.append([Vector2(cos(ang), sin(ang)), randf_range(90.0, 230.0)])
	if kind == "drain":
		# 흡혈: 피격 지점(position)에서 플레이어(from_global)로 핏방울이 빨려감.
		# [시작 오프셋 방향, 출발 지연]
		for i in int(round(9 * pm)):
			var ang := randf() * TAU
			_parts.append([Vector2(cos(ang), sin(ang)), randf_range(0.0, 0.45)])
	if kind == "bolt":
		var rel := from_global - position
		var n := 6
		_zig.append(rel)
		for i in range(1, n):
			var p: Vector2 = rel.lerp(Vector2.ZERO, float(i) / n)
			p += Vector2(randf_range(-14, 14), randf_range(-6, 6))
			_zig.append(p)
		_zig.append(Vector2.ZERO)
	if kind == "shatter":
		for i in int(round(12 * pm)):
			var ang := TAU * i / 12.0 + randf_range(-0.12, 0.12)
			_parts.append([Vector2(cos(ang), sin(ang)), randf_range(0.72, 1.08)])

func _process(delta: float) -> void:
	if delay > 0.0:
		delay -= delta
		return
	life -= delta
	if life <= 0.0:
		queue_free()
	queue_redraw()

# 채찍 한 가닥. 뿌리가 끝보다 항상 TRAIL만큼 뒤처지게 해서 스윙 내내 휘어져 보인다.
# (base→lead 보간으로 하면 스윙 중간에 두 각이 같아져 채찍이 직선이 됨)
const LASH_TRAIL := 1.25   # 뿌리가 끝보다 뒤처지는 각(rad) — 클수록 많이 휨
func _draw_lash(base: float, half: float, prog: float, c: Color, lead_spark: bool) -> void:
	var lead := base - half + prog * 2.0 * half
	var n := 14
	var pts := PackedVector2Array()
	for i in n + 1:
		var f := float(i) / float(n)
		# f=0(뿌리): lead-TRAIL  →  f=1(끝): lead. f²라 끝쪽이 확 펴지며 후려치는 모양.
		var ang: float = lead - LASH_TRAIL * (1.0 - f * f)
		pts.append(Vector2(cos(ang), sin(ang)) * (rad * f))
	for i in range(pts.size() - 1):
		var w: float = 6.0 * (1.0 - float(i) / float(n)) + 1.4
		draw_line(pts[i], pts[i + 1], c, w)
	if lead_spark:
		# 채찍 끝 크랙
		var tip: Vector2 = pts[pts.size() - 1]
		draw_circle(tip, 3.8, Color(1, 1, 1, c.a))
		draw_circle(tip, 7.5, Color(c.r, c.g, c.b, c.a * 0.4))


func _draw() -> void:
	if delay > 0.0:
		return
	var t: float = clamp(life / max_life, 0.0, 1.0)
	if kind == "moonbeam":
		# 월광강림: 하늘에서 내리쬐는 은백 달빛 기둥 + 초승달 호.
		# sin 엔벨로프로 부드럽게 차오르고 사그라든다 (팍 나타났다 사라지면 끊겨 보임).
		var prog: float = 1.0 - t                       # 0 → 1 진행도
		var env: float = sin(clamp(prog, 0.0, 1.0) * PI)  # 0 → 1 → 0 (인/아웃 이징)
		var grow: float = minf(1.0, prog * 3.2)         # 기둥이 빠르게 자라남
		var beam_h: float = 190.0 * grow
		var beam_w: float = rad * 0.42
		for j in 3:
			var jw: float = beam_w * (1.0 - j * 0.28)
			var ja: float = (0.10 + j * 0.11) * env
			# 세로 그라데이션 폴리곤 — 위로 갈수록 투명해져 하늘로 자연스럽게 사라진다
			var bc := Color(col.r, col.g, col.b, ja)
			var tc := Color(col.r, col.g, col.b, 0.0)
			draw_polygon(
				PackedVector2Array([Vector2(-jw / 2.0, 0), Vector2(jw / 2.0, 0),
					Vector2(jw / 2.0, -beam_h), Vector2(-jw / 2.0, -beam_h)]),
				PackedColorArray([bc, bc, tc, tc]))
		# 지면 달빛 웅덩이 (차오르며 퍼짐 — 은은하게 작게)
		draw_circle(Vector2.ZERO, rad * (0.24 + 0.28 * prog), Color(col.r, col.g, col.b, 0.26 * env))
		draw_circle(Vector2.ZERO, rad * 0.16 * grow, Color(1, 1, 1, 0.45 * env))
		# 초승달 호 문양 (살짝 회전하며 떠오름)
		draw_arc(Vector2.ZERO, rad * 0.24, PI * 0.15 + prog * 0.5, PI * 1.15 + prog * 0.5, 16,
			Color(1, 1, 1, 0.7 * env), 2.5)
		return
	if kind == "spin":
		# 회오리 베기: 회전하는 검격 3날
		var age := max_life - life
		for i in 3:
			var a0 := age * 14.0 + i * TAU / 3.0
			draw_arc(Vector2.ZERO, rad * 0.82, a0, a0 + 1.2, 12, Color(col.r, col.g, col.b, t * 0.85), 5.0)
			draw_arc(Vector2.ZERO, rad * 0.55, -a0, -a0 + 0.9, 10, Color(1, 1, 1, t * 0.4), 3.0)
		return
	if kind == "whip":
		# 채찍: 뿌리는 굵고 끝은 얇은 곡선이 부채꼴을 후려친다. 잔상 3겹으로 속도감.
		# (범용 slash는 부채꼴 채움이라 '채찍으로 때린다'는 느낌이 안 났음)
		var wbase := (from_global - position).angle()
		var wage := max_life - life
		var wprog: float = clamp(wage / max_life, 0.0, 1.0)
		for k in range(3, -1, -1):
			var p: float = wprog - k * 0.11
			if p <= 0.0:
				continue
			var a: float = (1.0 if k == 0 else 0.34 - k * 0.09) * t
			_draw_lash(wbase, 1.05, clamp(p, 0.0, 1.0), Color(col.r, col.g, col.b, a), k == 0)
		return
	if kind == "cleave":
		# 검기: 초승달 칼날이 호를 그으며 지나가고 잔상이 남는다 ('배는' 느낌)
		var cbase := (from_global - position).angle()
		var cage := max_life - life
		var cprog: float = clamp(cage / max_life, 0.0, 1.0)
		var chalf := 1.15
		for k in range(4, -1, -1):
			var p2: float = cprog - k * 0.085
			if p2 <= 0.0:
				continue
			var lead: float = cbase - chalf + clamp(p2, 0.0, 1.0) * 2.0 * chalf
			var a2: float = (1.0 if k == 0 else 0.26 - k * 0.05) * t
			var wdt: float = 7.0 - k * 1.1
			draw_arc(Vector2.ZERO, rad * 0.86, lead - 0.40, lead + 0.40, 14,
				Color(col.r, col.g, col.b, a2), max(1.5, wdt))
			if k == 0:
				# 선두 칼날: 흰 심지 + 베는 궤적
				draw_arc(Vector2.ZERO, rad * 0.86, lead - 0.16, lead + 0.16, 8, Color(1, 1, 1, t), 3.0)
				var tipd := Vector2(cos(lead), sin(lead))
				draw_line(tipd * rad * 0.30, tipd * rad * 0.98, Color(1, 1, 1, t * 0.9), 2.5)
		return
	if kind == "drain":
		# 흡혈: 피격 지점 → 플레이어로 핏방울이 가속하며 빨려감
		var to := from_global - position
		var dage := max_life - life
		var dpr: float = clamp(dage / max_life, 0.0, 1.0)
		for p3 in _parts:
			var dly: float = p3[1]
			var d: float = clamp((dpr - dly) / max(0.05, 1.0 - dly), 0.0, 1.0)
			if d <= 0.0:
				continue
			var st: Vector2 = (p3[0] as Vector2) * 13.0
			var pp: Vector2 = st.lerp(to, d * d)   # 가속 (뒤로 갈수록 빠르게 빨림)
			draw_circle(pp, 3.6 * (1.0 - d * 0.55), Color(0.85, 0.08, 0.12, (1.0 - d) * 0.95))
		# 피격 지점의 붉은 섬광
		draw_circle(Vector2.ZERO, rad * 0.5 * (1.0 - dpr), Color(0.9, 0.1, 0.15, (1.0 - dpr) * 0.5))
		return
	if kind == "slash":
		# 크레센트 검기 스윙 (from_global - position = 방향). 밝은 칼날이 부채꼴을 쓸고 지나감.
		var dir := (from_global - position)
		var base := dir.angle()
		var age := max_life - life
		var prog: float = clamp(age / max_life, 0.0, 1.0)
		var half := 1.15
		# 옅은 채움 (검기 잔광)
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in 17:
			var a := base - half + i * (2.0 * half / 16.0)
			pts.append(Vector2(cos(a), sin(a)) * rad)
		draw_colored_polygon(pts, Color(col.r, col.g, col.b, t * 0.28))
		# 외곽 호(칼날 궤적)
		draw_arc(Vector2.ZERO, rad * 0.9, base - half, base + half, 24,
			Color(col.r, col.g, col.b, t * 0.8), 4.0)
		# 밝은 선두 칼날 (진행에 따라 스윕)
		var lead := base - half + prog * (2.0 * half)
		var p0 := Vector2(cos(lead), sin(lead)) * rad * 0.25
		var p1 := Vector2(cos(lead), sin(lead)) * rad
		draw_line(p0, p1, Color(1, 1, 1, t), 5.0)
		return
	if kind == "burst":
		# 폭발 파편: 중심 코어 플래시 + 꼬리 달린 스파크가 튀며 크기 감쇠 (단색 네모 폐기)
		var age := max_life - life
		var pr: float = clamp(age / max_life, 0.0, 1.0)
		draw_circle(Vector2.ZERO, rad * (0.25 + 0.40 * pr), Color(1, 1, 1, (1.0 - pr) * 0.7))
		draw_circle(Vector2.ZERO, rad * (0.5 + 0.7 * pr), Color(col.r, col.g, col.b, (1.0 - pr) * 0.22))
		for p in _parts:
			var tip: Vector2 = p[0] * p[1] * age
			var tail: Vector2 = tip * 0.62
			var a: float = (1.0 - pr) * 0.95
			draw_line(tail, tip, Color(col.r, col.g, col.b, a), 2.6 * (1.0 - pr) + 0.7)
			draw_circle(tip, 1.6 * (1.0 - pr) + 0.4, Color(1, 1, 1, a))
		return
	if kind == "spark":
		# 타격 임팩트: 흰 코어 플래시(빠르게 팽창→소멸) + 진행방향으로 튀는 샤드 라인
		var age := max_life - life
		var pr: float = clamp(age / max_life, 0.0, 1.0)
		# 글로우 헤일로 (가산합성 → 은은한 블룸으로 번짐)
		draw_circle(Vector2.ZERO, rad * (0.9 + 1.3 * pr), Color(col.r, col.g, col.b, (1.0 - pr) * 0.16))
		# 흰 코어 플래시
		var cr: float = rad * (0.35 + 0.55 * pr)
		draw_circle(Vector2.ZERO, cr, Color(1, 1, 1, (1.0 - pr) * 0.7))
		draw_circle(Vector2.ZERO, cr * 0.5, Color(1, 1, 1, (1.0 - pr) * 0.9))
		# 방향성 샤드 (뒤꼬리 있는 선분 → 속도감)
		for p in _parts:
			var tip: Vector2 = p[0] * p[1] * age
			var tail: Vector2 = tip * 0.55
			draw_line(tail, tip, Color(col.r, col.g, col.b, (1.0 - pr) * 0.95), 2.5 * (1.0 - pr) + 0.8)
		return
	if kind == "bolt":
		# 낙뢰: 명멸(깜빡임) + 굵은 글로우 심 + 흰 코어 + 갈래(fork) + 착탄 섬광
		var flick: float = 0.7 + 0.3 * sin(life * 90.0)   # 빠른 깜빡임으로 전기 느낌
		var c := Color(col.r, col.g, col.b, t * flick)
		var glow := Color(col.r, col.g, col.b, t * 0.25)
		for i in range(_zig.size() - 1):
			draw_line(_zig[i], _zig[i + 1], glow, 6.0)            # 바깥 글로우
			draw_line(_zig[i], _zig[i + 1], c, 3.0)
			draw_line(_zig[i], _zig[i + 1], Color(1, 1, 1, t * 0.6 * flick), 1.5)  # 흰 코어
			# 마디마다 짧은 갈래 번개 (홀수 인덱스만 — 과하지 않게)
			if i % 2 == 1 and i < _zig.size() - 1:
				var mid: Vector2 = _zig[i]
				var perp: Vector2 = (_zig[i + 1] - _zig[i]).orthogonal().normalized()
				var fork: Vector2 = mid + perp * randf_range(8.0, 16.0) + (_zig[i + 1] - _zig[i]) * 0.4
				draw_line(mid, fork, Color(col.r, col.g, col.b, t * 0.5 * flick), 1.5)
		draw_circle(Vector2.ZERO, 12.0 * t, glow)                 # 착탄 글로우
		draw_circle(Vector2.ZERO, 7.0 * t, c)
		draw_circle(Vector2.ZERO, 3.5 * t, Color(1, 1, 1, t * flick))
		return
	if kind == "chain":
		if points.size() < 2:
			return
		var flick: float = 0.7 + 0.3 * sin(life * 90.0)
		var cc := Color(col.r, col.g, col.b, t * flick)
		var glow := Color(col.r, col.g, col.b, t * 0.22)
		# 각 구간을 지터로 잘게 꺾어 직선 대신 전기 아크처럼 (마디 3분할 + 수직 흔들림)
		for i in range(points.size() - 1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var perp: Vector2 = (b - a).orthogonal().normalized()
			var prev: Vector2 = a
			for k in range(1, 4):
				var f := float(k) / 3.0
				var pt: Vector2 = a.lerp(b, f)
				if k < 3:
					pt += perp * randf_range(-5.0, 5.0)
				draw_line(prev, pt, glow, 6.0)
				draw_line(prev, pt, cc, 3.0)
				draw_line(prev, pt, Color(1, 1, 1, t * 0.6 * flick), 1.3)
				prev = pt
		for p in points:
			draw_circle(p, 9.0 * t, glow)
			draw_circle(p, 4.5 * t, Color(cc.r, cc.g, cc.b, t * 0.85))
			draw_circle(p, 2.0 * t, Color(1, 1, 1, t * flick))
		return
	if kind == "shatter":
		var age := 1.0 - t
		for p in _parts:
			var d: Vector2 = p[0]
			var dist: float = rad * float(p[1]) * age
			var tip := d * dist
			var tail: Vector2 = d * maxf(0.0, dist - rad * 0.28)
			draw_line(tail, tip, Color(col.r, col.g, col.b, t), 3.0)
			draw_line(tail, tip, Color(1, 1, 1, t * 0.75), 1.1)
		return
	else:
		# 기본 링/폭발: 바깥으로 퍼지는 2겹 충격파 + 코어 섬광 + 은은한 글로우 (단일 호 폐기)
		var pr: float = 1.0 - t                       # 0 → 1 진행
		draw_circle(Vector2.ZERO, rad * 0.5 * (1.0 - pr), Color(1, 1, 1, t * t * 0.5))   # 코어 섬광
		var r1: float = rad * pr + 8.0
		draw_circle(Vector2.ZERO, r1 * 0.6, Color(col.r, col.g, col.b, t * 0.12))         # 글로우 헤일로
		draw_arc(Vector2.ZERO, r1, 0.0, TAU, 40, Color(col.r, col.g, col.b, t * 0.85), 4.0)
		var r2: float = rad * pr * 1.5 + 4.0                                              # 앞선 얇은 파동
		draw_arc(Vector2.ZERO, r2, 0.0, TAU, 40, Color(col.r, col.g, col.b, t * 0.4), 2.0)
