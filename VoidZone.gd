class_name VoidZone
extends Node2D
# 공허구(블랙홀): 범위 내 적을 끌어당기며 지속 피해. 회전 소용돌이 비주얼.

var radius := 140.0
var dps := 20.0
var pull := 70.0
var life := 2.2
var max_life := 2.2
var col := Color(0.6, 0.3, 0.9)   # 장판 색 (독=초록 등)
var anim_dir := ""                # 장판 프레임 애니 (assets/anim/<name>) — 있으면 픽셀아트로 표시
var outline := true               # 외곽 링 표시 (독안개는 끔 — 초록 테두리가 거슬림)
# 독 중첩: >0이면 장판 안에 오래 머문 적일수록 피해 증가.
# stack_rate = 초당 쌓이는 배수, stack_max = 최대 추가 배수 (1.0이면 최대 2배)
var stack_rate := 0.0
var stack_max := 0.0
var _stacks := {}                 # 적 instance_id → 누적 중첩량
var _t := 0.0
var damage_source := ""

func _ready() -> void:
	add_to_group("voidzones")
	max_life = life
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var main := get_parent()
	if main and main.has_method("telemetry_current_damage_source"):
		damage_source = str(main.telemetry_current_damage_source())

func _process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var main := get_parent()
	var previous_damage_source := ""
	var tracks_source := main and main.has_method("telemetry_push_damage_source")
	if tracks_source:
		previous_damage_source = str(main.telemetry_push_damage_source(damage_source))
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			var to: Vector2 = position - e.position
			var d := to.length()
			if d < radius:
				var mul := 1.0
				if stack_rate > 0.0:
					# 계속 노출될수록 독이 쌓여 아파짐 (밀집 구간에서 장판을 유지할 이유)
					var id := e.get_instance_id()
					var s: float = min(float(_stacks.get(id, 0.0)) + stack_rate * delta, stack_max)
					_stacks[id] = s
					mul += s
				e.take_damage(dps * mul * delta, false, true)   # dot: 넉백·플래시 없음
				if is_instance_valid(e) and d > 18.0:
					e.position += to.normalized() * pull * delta
	var b = get_tree().get_first_node_in_group("boss")
	if b and is_instance_valid(b) and position.distance_to(b.position) < radius:
		b.take_damage(dps * 0.5 * delta)
	# 파괴 오브젝트(관·항아리 등)도 장판으로 부술 수 있게
	for br in get_tree().get_nodes_in_group("breakables"):
		if is_instance_valid(br) and position.distance_to(br.position) < radius + br.radius:
			br.take_damage(dps * delta)
	if tracks_source:
		main.telemetry_restore_damage_source(previous_damage_source)
	queue_redraw()

func _draw() -> void:
	var t: float = clamp(life / max_life, 0.0, 1.0)
	var a: float = 0.34 * min(1.0, t * 3.0)   # 연하게 (화면 가림 완화)
	# 픽셀아트 장판 애니 (지정 시): 반경에 맞춰 프레임 재생 + 외곽 링
	if anim_dir != "":
		var fr: Array = Assets.frames(anim_dir)
		if fr.size() > 0:
			var ft: Texture2D = fr[int(_t * 10.0) % fr.size()]
			var w := radius * 2.1
			var pulse: float = 0.85 + 0.15 * sin(_t * 4.0)
			# 반투명 (맵 가림 완화): 최대 ~0.55 알파
			draw_texture_rect(ft, Rect2(Vector2(-w / 2.0, -w / 2.0), Vector2(w, w)), false,
				Color(1, 1, 1, min(0.55, t * 1.8) * pulse))
			if outline:
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(col.r, col.g, col.b, a), 2.0)
			return
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(col.r, col.g, col.b, a), 2.5)
	# 끌어당기는 소용돌이(pull>0, 공허구)만 오브 텍스처 회전 표시
	if pull > 0.0:
		var tex := Assets.tex("res://assets/items/icon_voidorb.png")
		var sz := radius * 1.15
		if tex:
			draw_set_transform(Vector2.ZERO, _t * 6.0, Vector2.ONE)
			draw_texture_rect(tex, Rect2(Vector2(-sz / 2.0, -sz / 2.0), Vector2(sz, sz)), false,
				Color(1, 1, 1, min(1.0, t * 3.0)))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 장판 채움
	draw_circle(Vector2.ZERO, radius * 0.94, Color(col.r, col.g, col.b, a * 0.28))
	# 소용돌이/보글 파티클
	for i in 8:
		var ang: float = TAU * i / 8.0 - _t * 3.0
		var rr: float = radius * (0.3 + 0.6 * fmod(_t * 0.7 + i * 0.13, 1.0))
		draw_circle(Vector2(cos(ang), sin(ang)) * (radius - rr), 3.0,
			Color(col.r + 0.1, col.g + 0.1, col.b + 0.1, a))
