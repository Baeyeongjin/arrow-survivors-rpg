class_name ChestRoulette
extends Control
# 보물상자 슬롯머신 (뱀서식): N개 릴(1/3/5)이 순차로 돌다 감속하며 보상에 정착.
# 순수 연출 — 보상은 Main에서 이미 적용됨. 정착 후 자동/클릭으로 닫힘.

var _rewards: Array = []     # [{icon:Texture2D, name:String}]
var _cycle: Array = []       # 순환용 아이콘 텍스처 풀
var _title := ""
var _on_close := Callable()
var _play_tick := Callable()

# 연출 순서 (뱀서식): 닫힘 → [열기] → 덜컹거림(RATTLE) → 개봉 폭발(BURST) → 릴 회전 → 정착
const RATTLE := 0.70    # 상자가 떨며 빛이 새어나오는 구간 (기대감)
const BURST := 0.54     # 32×32 9프레임 뚜껑 열림 구간 (프레임별 변화가 읽히도록 유지)

var _t := 0.0                 # 릴 시계 (BURST 종료 후부터 증가)
var _open_t := 0.0            # [열기] 이후 누적 시계 (덜컹→개봉 진행도)
var _n := 1
var _idx: Array = []
var _tick: Array = []
var _settle_at: Array = []
var _scroll: Array = []       # 릴별 세로 스크롤 누적(px) — 또로로록 회전
var _closed := false
var _opened := false          # 뱀서식: 처음엔 닫힌 상자 → "열기" 클릭해야 시작
var _intro_t := 0.0           # 열기 전 연출용 시계 (반짝임)
var _font: Font
var gold_display := 0.0        # >0이면 하단에 골드 카운트업 표시 (뱀서식 "55.00")
var _chest_tex: Texture2D
var _chest_frames: Array = []   # 상자 개봉 애니 프레임 (fx_chest_open). 없으면 정적 상자.
var _settled_flags: Array = []  # 릴별 정착 임팩트 1회 발동용
var _shake_t := 0.0             # 패널 흔들림 남은 시간
var _shake_mag := 0.0           # 흔들림 강도
var _flash := 0.0               # 전체 화면 백색 섬광 (개봉 순간)
var _burst_fired := false       # 개봉 폭발 1회 발동
var _coins: Array = []          # 금화비 파티클 [{p:Vector2, v:Vector2, life:float, mx:float}]
var _jackpot_fired := false     # 잭팟 금화비 1회 발동
var _confetti: Array = []       # 색종이 파티클 [{p,v,life,mx,col,rot,rv,sz}]
var _sparkles: Array = []       # 무대 부유 별가루 [{p:Vector2, ph:float, sz:float}]
var _jackpot_banner := 0.0      # "대박!" 배너 연출 시계 (>0이면 표시)

# 컨페티/무지개용 팔레트
const CONFETTI_COLS := [
	Color(1.0, 0.32, 0.42), Color(1.0, 0.78, 0.25), Color(0.4, 0.9, 0.55),
	Color(0.38, 0.72, 1.0), Color(0.78, 0.5, 1.0), Color(1.0, 0.95, 0.55),
]


func setup(rewards: Array, cycle: Array, title: String,
		on_close: Callable, tick_cb: Callable = Callable()) -> void:
	_rewards = rewards
	_cycle = cycle
	_title = title
	_on_close = on_close
	_play_tick = tick_cb


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load("res://assets/fonts/pixel.ttf")
	if _font == null:
		_font = ThemeDB.fallback_font
	# 이 안정 경로의 파일은 d13de538 PixelLab 원본/9프레임으로 교체되어 있다.
	_chest_tex = Assets.tex("res://assets/items/chest.png")
	_chest_frames = Assets.frames("res://assets/anim/fx_chest_open")
	_n = max(1, _rewards.size())
	for i in _n:
		_idx.append(randi() % max(1, _cycle.size()))
		_tick.append(0.0)
		_scroll.append(randf() * 1000.0)   # 시작 위상 랜덤
		_settle_at.append(0.85 + i * 0.13)   # 릴이 거의 동시에 '쫘르륵' 정착 (뱀서식)
		_settled_flags.append(false)


func _last_settle() -> float:
	return _settle_at[_n - 1]


func _close() -> void:
	if _closed:
		return
	_closed = true
	if _on_close.is_valid():
		_on_close.call()
	queue_free()


func _skip() -> void:
	if _open_t < RATTLE + BURST:
		_open_t = RATTLE + BURST   # 개봉 즉시 완료
	elif _t < _last_settle():
		_t = _last_settle()        # 모든 릴 즉시 정착
	else:
		_close()


func _open() -> void:
	# 1단계 "열기" 클릭 → 릴 회전 시작
	_opened = true
	if _play_tick.is_valid():
		_play_tick.call()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not _opened:
			_open()
		elif _t >= 0.35:
			_skip()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if not _opened:
			_open()
		elif _t >= 0.35:
			_skip()


func _process(delta: float) -> void:
	# 열기 전엔 시간 정지 (닫힌 상자 유지). 배경 반짝임만 갱신.
	if not _opened:
		_intro_t += delta
		queue_redraw()
		return

	if _flash > 0.0:
		_flash = max(0.0, _flash - delta * 5.0)
	if _jackpot_banner > 0.0:
		_jackpot_banner += delta
	_step_confetti(delta)
	_step_sparkles(delta)

	# ── 개봉 시퀀스: 덜컹거림 → 폭발 ──
	if _open_t < RATTLE + BURST:
		_open_t += delta
		# 덜컹거림: 진행할수록 격해짐 (기대감 고조) + 틱 사운드 가속
		if _open_t < RATTLE:
			var rp: float = _open_t / RATTLE
			_shake_t = 0.30
			_shake_mag = 1.5 + 11.0 * rp * rp
			_tick[0] -= delta
			if _tick[0] <= 0.0:
				_tick[0] = lerp(0.14, 0.04, rp)
				if _play_tick.is_valid():
					_play_tick.call()
		elif not _burst_fired:
			# 뚜껑 개봉: 백색 섬광 + 큰 흔들림 + 금화 분출
			_burst_fired = true
			_flash = 1.0
			_shake_t = 0.30
			_shake_mag = 22.0
			_spawn_coin_rain(14 + _n * 4)
			_spawn_confetti(26 + _n * 6)
			if _play_tick.is_valid():
				_play_tick.call()
		_step_coins(delta)
		queue_redraw()
		return

	# ── 릴 회전 구간 ──
	_t += delta
	# 패널 흔들림 감쇠
	if _shake_t > 0.0:
		_shake_t = max(0.0, _shake_t - delta)
	for i in _n:
		if _t < _settle_at[i]:
			# 세로 스크롤 속도: 정착 다가올수록 감속 (ease-out)
			var p: float = clamp(_t / _settle_at[i], 0.0, 1.0)
			var speed: float = 2600.0 * (1.0 - p * p)
			_scroll[i] += speed * delta
			# 아이템이 한 칸 지날 때마다 틱 사운드
			_tick[i] -= delta
			if _tick[i] <= 0.0:
				_tick[i] = lerp(0.03, 0.15, p)
				if i == 0 and _play_tick.is_valid():
					_play_tick.call()
		elif not _settled_flags[i]:
			# 릴 정착 순간: 아이템이 '쾅' 내리꽂힘 — 흔들림 + 틱 + 금화 튐 + 컨페티
			_settled_flags[i] = true
			_shake_t = 0.22
			_shake_mag = 9.0
			_spawn_confetti(10)
			if _play_tick.is_valid():
				_play_tick.call()
	# 모든 릴 정착 → 잭팟 금화비 1회 (상자는 이미 열려 있음)
	if _t >= _last_settle() and not _jackpot_fired:
		_jackpot_fired = true
		_flash = 0.55
		_shake_t = 0.30
		_shake_mag = 14.0 + _n * 2.0
		_spawn_coin_rain(18 + _n * 8)
		_spawn_confetti(40 + _n * 10)
		_jackpot_banner = 0.0001   # 배너 시계 기동
	_step_coins(delta)
	# 자동 닫힘 없음 — 연출을 다 보고 확인(클릭/키)으로만 닫힘
	queue_redraw()


# 금화비 파티클 물리 (중력 낙하 + 소멸)
func _step_coins(delta: float) -> void:
	if _coins.is_empty():
		return
	var alive: Array = []
	for cn in _coins:
		var vv: Vector2 = cn["v"]
		vv.y += 900.0 * delta
		cn["v"] = vv
		cn["p"] = (cn["p"] as Vector2) + vv * delta
		cn["life"] = float(cn["life"]) - delta
		if float(cn["life"]) > 0.0:
			alive.append(cn)
	_coins = alive


# 색종이(컨페티): 프레임 상단에서 팔랑이며 떨어지는 컬러 조각
func _spawn_confetti(n: int) -> void:
	var vs: Vector2 = size if size != Vector2.ZERO else get_viewport_rect().size
	var fw: float = min(440.0, vs.x * 0.42)
	var cx: float = vs.x * 0.5
	var top: float = vs.y * 0.5 - min(660.0, vs.y * 0.84) * 0.5 + 40.0
	for i in n:
		_confetti.append({
			"p": Vector2(cx + randf_range(-fw * 0.48, fw * 0.48), top + randf_range(-20.0, 30.0)),
			"v": Vector2(randf_range(-150.0, 150.0), randf_range(-260.0, -60.0)),
			"life": randf_range(1.1, 2.0),
			"mx": 2.0,
			"col": CONFETTI_COLS[randi() % CONFETTI_COLS.size()],
			"rot": randf() * TAU,
			"rv": randf_range(-9.0, 9.0),
			"sz": randf_range(5.0, 10.0),
		})


func _step_confetti(delta: float) -> void:
	if _confetti.is_empty():
		return
	var alive: Array = []
	for cf in _confetti:
		var vv: Vector2 = cf["v"]
		vv.y += 620.0 * delta          # 중력
		vv.x += sin(float(cf["life"]) * 9.0) * 60.0 * delta   # 팔랑팔랑 좌우
		vv *= (1.0 - 1.4 * delta)       # 공기 저항
		cf["v"] = vv
		cf["p"] = (cf["p"] as Vector2) + vv * delta
		cf["rot"] = float(cf["rot"]) + float(cf["rv"]) * delta
		cf["life"] = float(cf["life"]) - delta
		if float(cf["life"]) > 0.0:
			alive.append(cf)
	_confetti = alive


# 무대 배경 부유 별가루 (상시 반짝임) — 최초 1회 시딩 후 위상만 흐른다.
func _step_sparkles(delta: float) -> void:
	if _sparkles.is_empty():
		var vs: Vector2 = size if size != Vector2.ZERO else get_viewport_rect().size
		var fw: float = min(440.0, vs.x * 0.42)
		var fh: float = min(660.0, vs.y * 0.84)
		var c: Vector2 = vs * 0.5
		for i in 26:
			_sparkles.append({
				"p": Vector2(c.x + randf_range(-fw * 0.5, fw * 0.5), c.y + randf_range(-fh * 0.5, fh * 0.5)),
				"ph": randf() * TAU,
				"sz": randf_range(1.2, 2.8),
			})
	for sp in _sparkles:
		sp["ph"] = float(sp["ph"]) + delta * randf_range(2.4, 3.2)


# 4갈래 반짝이 별 그리기 (컨페티/스파크용)
func _draw_star(pos: Vector2, r: float, col: Color) -> void:
	draw_line(pos + Vector2(-r, 0), pos + Vector2(r, 0), col, 1.5)
	draw_line(pos + Vector2(0, -r), pos + Vector2(0, r), col, 1.5)
	var d := r * 0.45
	draw_line(pos + Vector2(-d, -d), pos + Vector2(d, d), Color(col.r, col.g, col.b, col.a * 0.6), 1.0)
	draw_line(pos + Vector2(-d, d), pos + Vector2(d, -d), Color(col.r, col.g, col.b, col.a * 0.6), 1.0)


# 패널 흔들림 오프셋 (정착·개봉 순간 화면 임팩트)
func _shake_off() -> Vector2:
	if _shake_t <= 0.0:
		return Vector2.ZERO
	var m: float = _shake_mag * (_shake_t / 0.30)
	return Vector2(randf_range(-m, m), randf_range(-m, m))


# 현재 상자 텍스처: 개봉(BURST) 시작 후 프레임이 진행, 그 전엔 닫힌 첫 프레임/폴백
func _chest_current_tex() -> Texture2D:
	if _chest_frames.size() > 0:
		var ot: float = _open_t - RATTLE
		if ot >= 0.0:
			# BURST 구간에 딱 맞춰 전 프레임 재생 → 폭발이 끝날 때 완전히 열림
			var idx: int = int(ot / (BURST / _chest_frames.size()))
			return _chest_frames[clamp(idx, 0, _chest_frames.size() - 1)]
		return _chest_frames[0]
	return _chest_tex


# 금화비: 프레임 상단에서 쏟아져 내리는 금화 파티클
func _spawn_coin_rain(n: int) -> void:
	var vs: Vector2 = size if size != Vector2.ZERO else get_viewport_rect().size
	var fw: float = min(440.0, vs.x * 0.42)
	var cx: float = vs.x * 0.5
	var top: float = vs.y * 0.5 - min(660.0, vs.y * 0.84) * 0.5
	for i in n:
		_coins.append({
			"p": Vector2(cx + randf_range(-fw * 0.42, fw * 0.42), top + randf_range(-10.0, 40.0)),
			"v": Vector2(randf_range(-60.0, 60.0), randf_range(-40.0, 120.0)),
			"life": randf_range(0.7, 1.3),
			"mx": 1.3,
		})


func _draw() -> void:
	var vs: Vector2 = size if size != Vector2.ZERO else get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.02, 0.04, 0.86))
	var c: Vector2 = vs * 0.5 + _shake_off()

	# ── 1단계: 아직 안 열림 → "보물 발견!" + 닫힌 상자 + 열기 안내 (뱀서식) ──
	if not _opened:
		var fw0: float = min(440.0, vs.x * 0.42)
		var fh0: float = min(520.0, vs.y * 0.72)
		var f0 := Rect2(c.x - fw0 * 0.5, c.y - fh0 * 0.5, fw0, fh0)
		# 은은한 광휘 + 프레임 (플랫 UI 통일: 각진 검정 + 얇은 회백 테두리)
		draw_circle(c, fw0 * 0.6 + 20.0 * sin(_intro_t * 3.0), Color(1.0, 0.85, 0.4, 0.06))
		draw_rect(f0, Color(0.02, 0.02, 0.03, 0.96))
		draw_rect(f0, Color(0.75, 0.75, 0.8), false, 2.0)
		# 타이틀
		draw_string(_font, Vector2(f0.position.x, f0.position.y + 54.0), "✦  보물 발견!  ✦",
			HORIZONTAL_ALIGNMENT_CENTER, fw0, 34, Color(1.0, 0.88, 0.42))
		# 닫힌 상자 (살짝 둥실)
		var bob := sin(_intro_t * 2.2) * 6.0
		var itex: Texture2D = _chest_current_tex()
		if itex:
			var chw := fw0 * 0.5
			draw_texture_rect(itex, Rect2(Vector2(c.x - chw * 0.5, c.y - chw * 0.4 + bob), Vector2(chw, chw)), false)
		else:
			draw_rect(Rect2(c.x - 60.0, c.y - 40.0 + bob, 120.0, 80.0), Color(0.5, 0.32, 0.14))
			draw_rect(Rect2(c.x - 60.0, c.y - 40.0 + bob, 120.0, 20.0), Color(0.8, 0.6, 0.2))
		# 열기 안내 (깜빡임)
		var blink0: float = 0.5 + 0.5 * sin(_intro_t * 5.0)
		draw_string(_font, Vector2(f0.position.x, f0.position.y + fh0 - 40.0), "▶  열기 (클릭)",
			HORIZONTAL_ALIGNMENT_CENTER, fw0, 26, Color(1.0, 0.9, 0.5, blink0))
		return

	# ── 2단계: 덜컹거림 → 개봉 폭발 (릴 등장 전) ──
	if _open_t < RATTLE + BURST:
		var fw1: float = min(440.0, vs.x * 0.42)
		var fh1: float = min(520.0, vs.y * 0.72)
		var f1 := Rect2(c.x - fw1 * 0.5, c.y - fh1 * 0.5, fw1, fh1)
		var rp1: float = clamp(_open_t / RATTLE, 0.0, 1.0)
		var bt: float = max(0.0, _open_t - RATTLE)     # 폭발 경과
		var bursting := _open_t >= RATTLE
		draw_rect(f1, Color(0.02, 0.02, 0.03, 0.96))
		draw_rect(f1, Color(0.75, 0.75, 0.8), false, 2.0)
		# 광휘: 덜컹거릴수록 강해짐 (틈으로 빛이 새어나옴). 프레임 배경 뒤에 그리면 가려짐 → 위에.
		# 폭발이 시작되면 걷힘 — 안 그러면 노란 얼룩으로 남아 폭발을 뭉갠다.
		var gfade: float = 1.0 - clamp(bt / BURST, 0.0, 1.0)
		draw_circle(c, fw1 * (0.30 + 0.26 * rp1), Color(1.0, 0.85, 0.4, (0.05 + 0.20 * rp1 * rp1) * gfade))
		draw_string(_font, Vector2(f1.position.x, f1.position.y + 54.0), "✦  보물 발견!  ✦",
			HORIZONTAL_ALIGNMENT_CENTER, fw1, 34, Color(1.0, 0.88, 0.42))
		var chest_p := Vector2(c.x, c.y - fw1 * 0.05)
		# 개봉 폭발: 광선 기둥 + 확산 링
		if bursting:
			var bp: float = clamp(bt / BURST, 0.0, 1.0)
			var pw: float = fw1 * 0.42 * (1.0 - bp * 0.35)
			# 제목은 연출 광선과 분리해 어떤 프레임에서도 글자가 묻히지 않게 한다.
			var beam_top := f1.position.y + 84.0
			draw_rect(Rect2(chest_p.x - pw * 0.5, beam_top, pw, chest_p.y - beam_top),
				Color(1.0, 0.95, 0.65, 0.5 * (1.0 - bp * 0.5)))
			draw_rect(Rect2(chest_p.x - pw * 0.22, beam_top, pw * 0.44, chest_p.y - beam_top),
				Color(1.0, 1.0, 0.9, 0.55 * (1.0 - bp * 0.4)))
			# 코어 섬광은 상자 근처로 억제 — 크게 키우면 프레임 밖으로 번져 얼룩이 된다.
			draw_circle(chest_p, fw1 * (0.14 + bp * 0.22), Color(1.0, 0.93, 0.6, 0.45 * (1.0 - bp)))
			draw_arc(chest_p, 40.0 + bp * 420.0, 0.0, TAU, 48, Color(1.0, 0.97, 0.75, 0.8 * (1.0 - bp)), 5.0)
		# 상자 (덜컹거릴 땐 좌우로 떨림 — _shake_off가 화면 전체를 흔들고, 여기선 회전 흔들림 추가)
		var ctex1: Texture2D = _chest_current_tex()
		var chw1: float = fw1 * 0.5
		var ang: float = 0.0 if bursting else sin(_open_t * 46.0) * 0.05 * rp1
		draw_set_transform(chest_p, ang, Vector2.ONE)
		if ctex1:
			draw_texture_rect(ctex1, Rect2(Vector2(-chw1, -chw1) * 0.5, Vector2(chw1, chw1)), false)
		else:
			draw_rect(Rect2(-60.0, -40.0, 120.0, 80.0), Color(0.5, 0.32, 0.14))
			draw_rect(Rect2(-60.0, -40.0, 120.0, 20.0), Color(0.8, 0.6, 0.2))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 금화 + 전체 섬광
		for cn1 in _coins:
			var ca1: float = clamp(float(cn1["life"]) / float(cn1["mx"]), 0.0, 1.0)
			var cp1: Vector2 = cn1["p"]
			draw_circle(cp1, 6.0, Color(0.85, 0.62, 0.15, ca1))
			draw_circle(cp1, 4.2, Color(1.0, 0.85, 0.35, ca1))
		if _flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, _flash * 0.42))
		return

	var all_settled := _t >= _last_settle()

	# ── 대박 잭팟 연출: 3/5갈래가 다 정착하면 화면 전역 금색 광선 폭발 (뱀서식 "쫘르륵!") ──
	if all_settled and _n >= 3:
		var jt: float = _t - _last_settle()
		var burst_a: float = clamp(1.0 - jt / 0.8, 0.0, 1.0)   # 0.8초에 걸쳐 페이드
		if burst_a > 0.0:
			var rays: int = 20 + _n * 4
			var reach: float = max(vs.x, vs.y) * (0.4 + jt * 0.6)
			for r in rays:
				var ra: float = TAU * r / float(rays) + jt * 0.6
				var dd := Vector2(cos(ra), sin(ra))
				draw_line(c + dd * 40.0, c + dd * reach,
					Color(1.0, 0.9, 0.45, burst_a * 0.5), 3.0)
			# 확산 링 2겹
			for k in 2:
				draw_arc(c, 60.0 + jt * (520.0 + k * 120.0), 0.0, TAU, 48,
					Color(1.0, 0.95, 0.6, burst_a * 0.6), 4.0)

	# ── 무대 프레임 (플랫 UI 통일: 각진 검정 + 얇은 회백 테두리) ──
	var fw: float = min(440.0, vs.x * 0.42)
	var fh: float = min(660.0, vs.y * 0.84)
	var fx: float = c.x - fw * 0.5
	var fy: float = c.y - fh * 0.5
	var frame := Rect2(fx, fy, fw, fh)
	# 프레임 뒤 은은한 광휘
	draw_circle(c, fw * 0.72 + 24.0 * sin(_t * 3.0), Color(1.0, 0.85, 0.4, 0.05))
	draw_rect(frame, Color(0.02, 0.02, 0.03, 0.96))
	# 잭팟 순간엔 테두리가 무지개로 순환하며 굵어짐
	if _jackpot_banner > 0.0:
		var bcol := Color.from_hsv(fposmod(_t * 0.6, 1.0), 0.55, 1.0)
		draw_rect(frame.grow(2.0), Color(bcol.r, bcol.g, bcol.b, 0.9), false, 4.0)
	else:
		draw_rect(frame, Color(0.75, 0.75, 0.8), false, 2.0)

	# 무대 배경 부유 별가루 (프레임 안에서 은은히 반짝임)
	for sp in _sparkles:
		var spp: Vector2 = sp["p"]
		if not frame.has_point(spp):
			continue
		var tw2: float = 0.35 + 0.65 * (0.5 + 0.5 * sin(float(sp["ph"])))
		_draw_star(spp, float(sp["sz"]) * (0.7 + tw2 * 0.6), Color(1.0, 0.96, 0.8, tw2 * 0.5))

	# 타이틀 (프레임 안쪽 상단 — 밖에 두면 HUD 타이머와 겹침)
	draw_string(_font, Vector2(fx, fy + 40.0), _title,
		HORIZONTAL_ALIGNMENT_CENTER, fw, 28, Color(1.0, 0.85, 0.4))

	# ── 상자(하단) + 세로 스크롤 룰렛 창 + 광선 기둥 ──
	var chest_c := Vector2(c.x, fy + fh - fh * 0.19)
	var win_cy := fy + fh * 0.29           # 스크롤 창 중심
	var win_h := fh * 0.34                  # 창 높이(아이템 약 3개)
	var item_h := win_h / 3.0
	var win_top := win_cy - win_h * 0.5
	var win_bot := win_cy + win_h * 0.5
	# 릴 열 배치 (1개면 넓게, 여러개면 나눠)
	var col_w: float = fw * 0.52 if _n == 1 else (fw * 0.30 if _n == 3 else fw * 0.185)
	var cgap := 10.0
	var ctot := _n * col_w + (_n - 1) * cgap
	var cx0 := c.x - ctot * 0.5
	# 광선 기둥 (각 열 → 상자)
	for i in _n:
		var colx0 := cx0 + col_w * 0.5 + i * (col_w + cgap)
		var bwid: float = col_w * 0.86 + 6.0 * sin(_t * 7.0 + i)
		draw_rect(Rect2(colx0 - bwid * 0.5, win_top, bwid, chest_c.y - win_top), Color(0.42, 0.56, 1.0, 0.26))
		draw_rect(Rect2(colx0 - bwid * 0.30, win_top, bwid * 0.6, chest_c.y - win_top), Color(0.72, 0.83, 1.0, 0.24))
	# 상자는 이미 열려 있음 (개봉은 릴 회전 전에 끝남) — 상시 황금 광휘로 열린 티를 냄.
	# 반경을 키우면 푸른 광선 위에서 잿빛 얼룩으로 보임 → 상자 크기로 억제.
	var glow: float = 0.30 + 0.07 * sin(_t * 4.0)
	draw_circle(chest_c + Vector2(0, -fw * 0.06), fw * 0.20, Color(1.0, 0.92, 0.55, glow * 0.35))
	draw_circle(chest_c + Vector2(0, -fw * 0.06), fw * 0.12, Color(1.0, 0.98, 0.8, glow * 0.5))
	var ctex: Texture2D = _chest_current_tex()
	if ctex:
		var chw: float = fw * 0.42
		draw_texture_rect(ctex, Rect2(chest_c - Vector2(chw, chw) * 0.5, Vector2(chw, chw)), false)
	else:
		draw_rect(Rect2(chest_c - Vector2(42, 28), Vector2(84, 56)), Color(0.5, 0.32, 0.14))
		draw_rect(Rect2(chest_c - Vector2(42, 28), Vector2(84, 14)), Color(0.8, 0.6, 0.2))

	# ── 각 열: 아이템 세로 스크롤 → 정착 ──
	for i in _n:
		var colx := cx0 + col_w * 0.5 + i * (col_w + cgap)
		var settled: bool = _t >= _settle_at[i]
		var isz: float = min(col_w * 0.72, item_h * 0.86)
		var ctr := Vector2(colx, win_cy)
		if not settled and _cycle.size() > 0:
			# 세로 스크롤: 아이템들이 흘러 지나감 (창 경계에서 페이드)
			var base_idx: int = int(floor(float(_scroll[i]) / item_h))
			var frac: float = float(_scroll[i]) - base_idx * item_h
			for k in range(-2, 3):
				var iy: float = win_cy + k * item_h - frac
				if iy < win_top - item_h or iy > win_bot + item_h:
					continue
				var idxc := ((base_idx + k) % _cycle.size() + _cycle.size()) % _cycle.size()
				var t2: Texture2D = _cycle[idxc]
				if t2 == null:
					continue
				var al: float = clamp(1.0 - abs(iy - win_cy) / (win_h * 0.55), 0.15, 1.0)
				draw_texture_rect(t2, Rect2(Vector2(colx - isz * 0.5, iy - isz * 0.5), Vector2(isz, isz)), false, Color(1, 1, 1, al))
		else:
			# 정착: 보상 중앙 확대 + 스파크 버스트
			var t2: Texture2D = _rewards[i].get("icon", null)
			var sb: float = clamp((_t - _settle_at[i]) / 0.5, 0.0, 1.0)
			var pop: float = 1.0 + 0.15 * (1.0 - sb)
			if t2:
				var fsz := isz * 1.12 * pop
				draw_texture_rect(t2, Rect2(ctr - Vector2(fsz, fsz) * 0.5, Vector2(fsz, fsz)), false)
			if sb < 1.0:
				var rr: float = isz * (0.55 + sb * 0.9)
				for s in 10:
					var a2 := TAU * s / 10.0 + _t * 0.5
					var dd := Vector2(cos(a2), sin(a2))
					draw_line(ctr + dd * isz * 0.4, ctr + dd * rr, Color(0.9, 0.94, 1.0, (1.0 - sb) * 0.9), 3.0)
				draw_arc(ctr, rr, 0.0, TAU, 32, Color(1.0, 0.95, 0.6, (1.0 - sb) * 0.7), 3.0)
		# 창 상/하 프레임 바 + 선택 하이라이트 (정착하면 흰 테두리로 강조)
		draw_rect(Rect2(colx - col_w * 0.5, win_top - 4.0, col_w, 4.0), Color(0.78, 0.78, 0.84))
		draw_rect(Rect2(colx - col_w * 0.5, win_bot, col_w, 4.0), Color(0.78, 0.78, 0.84))
		var hl: Color = Color(1, 1, 1, 0.9) if settled else Color(1, 1, 1, 0.14)
		draw_rect(Rect2(colx - col_w * 0.5, win_cy - item_h * 0.5, col_w, item_h), hl, false, 2.0)

	# ── 골드 카운트업 (하단, 뱀서식 "55.00" + 코인) ──
	# ── 보상 이름 (릴 창 바로 아래, 중앙 정렬) ──
	if all_settled:
		var a: float = clamp((_t - _last_settle()) / 0.25, 0.0, 1.0)
		var ny := win_bot + 30.0
		for i in _n:
			var nm: String = str(_rewards[i].get("name", ""))
			draw_string(_font, Vector2(fx, ny), nm,
				HORIZONTAL_ALIGNMENT_CENTER, fw, 22, Color(1, 1, 0.85, a))
			ny += 28.0

	# ── 골드 카운트업 (상자 아래, 숫자+코인 블록을 통째로 중앙 정렬) ──
	if all_settled and gold_display > 0.0:
		var ga: float = clamp((_t - _last_settle()) / 0.5, 0.0, 1.0)
		var gtxt := "%0.2f" % (gold_display * ga)
		var gy := chest_c.y + fh * 0.14
		var tw: float = _font.get_string_size(gtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var block := tw + 34.0
		var gx := c.x - block * 0.5
		draw_string(_font, Vector2(gx, gy), gtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.85, 0.35))
		var coin_c := Vector2(gx + tw + 18.0, gy - 9.0)
		draw_circle(coin_c, 11.0, Color(1.0, 0.82, 0.3))
		draw_circle(coin_c, 7.0, Color(1.0, 0.92, 0.5))

	# ── 금화비 파티클 (개봉 순간 쏟아짐) ──
	for cn in _coins:
		var ca: float = clamp(float(cn["life"]) / float(cn["mx"]), 0.0, 1.0)
		var cp: Vector2 = cn["p"]
		draw_circle(cp, 6.0, Color(0.85, 0.62, 0.15, ca))
		draw_circle(cp, 4.2, Color(1.0, 0.85, 0.35, ca))
		draw_circle(cp + Vector2(-1.2, -1.2), 1.6, Color(1.0, 0.98, 0.8, ca))

	# ── 색종이 파티클 (회전하는 컬러 조각) ──
	for cf in _confetti:
		var fa: float = clamp(float(cf["life"]) / float(cf["mx"]), 0.0, 1.0)
		var fp: Vector2 = cf["p"]
		var fcol: Color = cf["col"]
		var s: float = float(cf["sz"])
		var rot: float = float(cf["rot"])
		# 회전에 따라 폭이 줄었다 늘었다 (팔랑이는 종이 느낌)
		var wobble: float = absf(cos(rot))
		draw_set_transform(fp, rot, Vector2.ONE)
		draw_rect(Rect2(-s * 0.5, -s * 0.5 * wobble, s, maxf(1.0, s * wobble)),
			Color(fcol.r, fcol.g, fcol.b, fa))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ── 잭팟 배너: 릴 정착 순간 크게 튀어오르며 펄스 → 위로 떠오르며 페이드 ("★ 대박! ★") ──
	if _jackpot_banner > 0.0:
		var bt2: float = _jackpot_banner
		# 페이드: 0.9초 유지 후 0.7초에 걸쳐 소멸 (보상을 오래 가리지 않게)
		var bfade: float = clamp(1.0 - (bt2 - 0.9) / 0.7, 0.0, 1.0)
		if bfade > 0.0:
			var pop_in: float = clamp(bt2 / 0.28, 0.0, 1.0)
			var overshoot: float = 1.0 + (1.0 - pop_in) * 0.8   # 튀어오르는 오버슈트
			var pulse: float = 1.0 + 0.06 * sin(bt2 * 9.0)
			var bscale: float = overshoot * pulse
			var btxt: String = "★ 대박! ★" if _n >= 3 else "★ 획득! ★"
			var bfs: int = 46 if _n >= 3 else 38
			var bhue: float = fposmod(bt2 * 0.7, 1.0)
			var bc := Color.from_hsv(bhue, 0.35, 1.0)
			var bsz: Vector2 = _font.get_string_size(btxt, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs)
			# 소멸하며 살짝 위로 떠오름
			var by: float = fy + fh * 0.13 - (1.0 - bfade) * 24.0
			draw_set_transform(Vector2(c.x, by), 0.0, Vector2(bscale, bscale))
			draw_string(_font, Vector2(-bsz.x * 0.5, bfs * 0.35), btxt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color(bc.r, bc.g, bc.b, 0.32 * bfade))
			draw_string(_font, Vector2(-bsz.x * 0.5, bfs * 0.35 - 2.0), btxt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color(bc.r, bc.g, bc.b, bfade))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ── 확인 안내 (프레임 하단, 깜빡임) ──
	if all_settled:
		var blink: float = 0.55 + 0.45 * sin(_t * 5.0)
		draw_string(_font, Vector2(fx, fy + fh + 30.0), "▶ 확인 (클릭)",
			HORIZONTAL_ALIGNMENT_CENTER, fw, 20, Color(1.0, 0.9, 0.5, blink))

	# ── 전체 화면 섬광 (잭팟 순간) ──
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, _flash * 0.42))
