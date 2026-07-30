extends Node2D

# 공허 닻·중간보스·최종보스가 공유하는 중력장.
# 예고 뒤 플레이어를 중심으로 끌어당기며, 보스형 중력장은 중심부에 주기 피해를 준다.

const TELEGRAPH_TIME := 0.70
const PULSE_INTERVAL := 0.82

var radius := 220.0
var pull_strength := 118.0
var pulse_damage := 0.0
var life := 4.0
var max_life := 4.0
var follow_target: Node2D

var _telegraph_t := TELEGRAPH_TIME
var _pulse_t := PULSE_INTERVAL
var _anim_t := 0.0
var _texture: Texture2D


func _ready() -> void:
	add_to_group("void_gravity_fields")
	add_to_group("floor_runtime")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture = Assets.tex("res://assets/items/icon_voidorb.png")


func configure(field_radius: float, gravity_strength: float, duration: float,
		damage: float = 0.0, target: Node2D = null) -> void:
	radius = maxf(48.0, field_radius)
	pull_strength = maxf(0.0, gravity_strength)
	life = maxf(0.4, duration)
	max_life = life
	pulse_damage = maxf(0.0, damage)
	follow_target = target
	_telegraph_t = minf(TELEGRAPH_TIME, life * 0.25)
	_pulse_t = PULSE_INTERVAL


func force_active_for_preview() -> void:
	_telegraph_t = 0.0
	_anim_t = 0.55
	queue_redraw()


func _process(delta: float) -> void:
	_anim_t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if follow_target:
		if not is_instance_valid(follow_target):
			queue_free()
			return
		position = follow_target.position
	if _telegraph_t > 0.0:
		_telegraph_t -= delta
		queue_redraw()
		return

	var main := get_parent()
	if main and main.has_method("apply_void_pull"):
		main.apply_void_pull(position, radius, pull_strength, delta)
	if pulse_damage > 0.0:
		_pulse_t -= delta
		if _pulse_t <= 0.0:
			_pulse_t = PULSE_INTERVAL
			var pl := get_tree().get_first_node_in_group("player") as Player
			if pl and pl.position.distance_to(position) <= radius * 0.38 + pl.radius \
					and main and main.has_method("apply_void_boss_damage"):
				main.apply_void_boss_damage(pulse_damage, position)
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_anim_t * 8.0)
	if _telegraph_t > 0.0:
		var progress := clampf(1.0 - _telegraph_t / maxf(0.001, minf(TELEGRAPH_TIME, max_life * 0.25)),
			0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(0.48, 0.22, 0.72, 0.04 + progress * 0.07))
		draw_arc(Vector2.ZERO, lerpf(radius * 1.35, radius, progress), 0.0, TAU, 56,
			Color(0.78, 0.52, 1.0, 0.38 + progress * 0.46), 3.0 + progress * 2.0)
		return

	var fade := clampf(life / maxf(0.001, max_life), 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(0.25, 0.08, 0.42, (0.09 + pulse * 0.035) * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56,
		Color(0.66, 0.38, 0.94, (0.48 + pulse * 0.22) * fade), 3.0)
	draw_arc(Vector2.ZERO, radius * 0.38, 0.0, TAU, 36,
		Color(0.92, 0.64, 1.0, (0.62 + pulse * 0.26) * fade), 4.0)
	for i in 10:
		var angle := TAU * float(i) / 10.0 - _anim_t * 1.7
		var start := Vector2.from_angle(angle) * radius * 0.82
		var finish := Vector2.from_angle(angle + 0.28) * radius * 0.48
		draw_line(start, finish, Color(0.72, 0.46, 1.0, 0.30 * fade), 2.0)
	if _texture:
		var size := radius * (0.50 + pulse * 0.06)
		draw_set_transform(Vector2.ZERO, _anim_t * 2.8, Vector2.ONE)
		draw_texture_rect(_texture, Rect2(-Vector2(size, size) * 0.5, Vector2(size, size)),
			false, Color(0.92, 0.72, 1.0, 0.72 * fade))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
