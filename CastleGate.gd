extends Node2D

# M5-D 마왕성 던전의 관문형 목표 — 성문.
# 다른 던전의 목표는 "점령/파괴/버티기"라 시간이 곧 진행이었다. 마왕성은 최종 빌드를
# 검증하는 전투 관문 던전이므로, 성문은 체력벽도 타이머도 아니다:
#   접근하면 봉쇄전이 걸려 지휘관이 섞인 정예 웨이브가 소환되고, 전부 처치하면 열린다.
# 시간으로 넘길 수 없으니 "지금 내 빌드로 이 정예 묶음을 녹일 수 있는가"만 묻는다.
# 열린 관문 수는 마왕의 왕좌 지휘관 수에 반영된다(Main이 Boss.configure_castle_final로 전달).

const ART_PATH := "res://assets/maps/demon_castle/castle_gate.png"
const ENGAGE_RADIUS := 150.0

var radius := ENGAGE_RADIUS
var encounter_index := 0

var _engaged := false
var _opened := false
var _fade := 0.7
var _anim_t := 0.0
var _in_range := false
var _guards: Array = []
var _texture: Texture2D


func _ready() -> void:
	add_to_group("castle_gates")
	add_to_group("castle_objectives")
	add_to_group("floor_runtime")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture = Assets.tex(ART_PATH)


func configure(index: int, engage_radius: float) -> void:
	encounter_index = index
	radius = maxf(48.0, engage_radius)


func is_engaged() -> bool:
	return _engaged


func is_opened() -> bool:
	return _opened


# 봉쇄전 시작. 이미 걸렸거나 열렸으면 false — Main이 수비대를 두 번 소환하지 않게 한다.
func engage() -> bool:
	if _engaged or _opened:
		return false
	_engaged = true
	return true


func register_guard(guard: Node) -> void:
	if guard != null:
		_guards.append(guard)


# 살아 있는 수비대 수. 죽은 참조는 세지 않는다(Enemy는 죽음 애니 후 queue_free).
func alive_guard_count() -> int:
	var alive := 0
	for guard in _guards:
		if is_instance_valid(guard) and not guard.is_queued_for_deletion():
			alive += 1
	return alive


# 봉쇄전이 끝났는지 판정하고, 끝났으면 1회만 개방한다. 테스트가 직접 호출한다.
func check_open() -> bool:
	if _opened or not _engaged:
		return false
	if alive_guard_count() > 0:
		return false
	_open()
	return true


func _process(delta: float) -> void:
	_anim_t += delta
	if _opened:
		_fade -= delta
		if _fade <= 0.0:
			queue_free()
			return
		queue_redraw()
		return
	_in_range = _player_in_range()
	if not _engaged and _in_range:
		var main := get_parent()
		if main and main.has_method("on_castle_gate_engaged"):
			main.on_castle_gate_engaged(self)
	elif _engaged:
		check_open()
	queue_redraw()


func _player_in_range() -> bool:
	var pl := get_tree().get_first_node_in_group("player")
	return pl != null and is_instance_valid(pl) and pl.position.distance_to(position) <= radius


# 마왕 등장 시 미개방 관문은 보상 없이 사라진다. 다른 던전 목표와 같은 규약.
func absorb_without_reward() -> void:
	if _opened:
		return
	_opened = true
	remove_from_group("castle_objectives")
	_fade = 0.12


func _open() -> void:
	_opened = true
	remove_from_group("castle_objectives")
	var main := get_parent()
	if main and main.has_method("on_castle_gate_opened"):
		main.on_castle_gate_opened(self)


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_anim_t * 4.0)
	if _opened:
		var fade := clampf(_fade / 0.7, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius * (1.0 + (1.0 - fade) * 0.35), 0.0, TAU, 44,
			Color(1.0, 0.86, 0.44, fade), 4.0)
		return

	# 관문 구역: 봉쇄 전에는 잠긴 붉은 고리, 봉쇄전 중에는 주황으로 달군다.
	var zone_col := Color(0.92, 0.44, 0.18, 0.13 + pulse * 0.05) if _engaged \
		else Color(0.58, 0.24, 0.28, 0.10)
	draw_circle(Vector2.ZERO, radius, zone_col)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 46,
		Color(1.0, 0.58, 0.24, 0.52 + pulse * 0.26) if _engaged
		else Color(0.78, 0.40, 0.42, 0.46),
		2.5 + (pulse * 1.8 if _engaged else 0.0))

	if _texture:
		var art := 128.0
		draw_texture_rect(_texture,
			Rect2(Vector2(-art * 0.5, -art * 0.74), Vector2(art, art)), false,
			Color(1.20, 0.92, 0.78) if _engaged else Color(0.86, 0.82, 0.86))
	else:
		# 폴백: 두 짝 성문 + 빗장. 색이 아니라 형태로도 관문임이 읽혀야 한다.
		draw_rect(Rect2(Vector2(-34, -58), Vector2(30, 84)), Color(0.30, 0.24, 0.28))
		draw_rect(Rect2(Vector2(4, -58), Vector2(30, 84)), Color(0.30, 0.24, 0.28))
		draw_rect(Rect2(Vector2(-34, -20), Vector2(68, 7)), Color(0.52, 0.44, 0.34))

	# 잠금/봉쇄 상태를 형태로 표시한다. 잠김 = 가로 빗장, 봉쇄전 = 남은 수비대 사각 점.
	if not _engaged:
		var bar_w := 58.0
		draw_rect(Rect2(-bar_w * 0.5, -radius - 20.0, bar_w, 7.0), Color(0.06, 0.04, 0.06, 0.92))
		draw_rect(Rect2(-bar_w * 0.5 + 2.0, -radius - 18.0, bar_w - 4.0, 3.0),
			Color(0.82, 0.40, 0.42, 0.70 + pulse * 0.25))
		return
	var remaining := alive_guard_count()
	for i in remaining:
		draw_rect(Rect2(Vector2(-float(remaining) * 6.0 + float(i) * 12.0, -radius - 24.0),
			Vector2(8, 8)), Color(1.0, 0.72, 0.30))
