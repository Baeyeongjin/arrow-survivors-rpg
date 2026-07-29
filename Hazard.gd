class_name Hazard
extends Node2D
# 바닥 장판 (라바 골렘 등): 위에 서 있으면 지속 피해

var radius := 55.0
var dps := 12.0
var life := 4.0
var max_life := 4.0
var col := Color(1.0, 0.45, 0.15)

func _ready() -> void:
	add_to_group("hazards")
	max_life = life

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var pl := get_tree().get_first_node_in_group("player") as Player
	if pl and pl.position.distance_to(position) < radius + pl.radius * 0.5:
		var main := get_parent()
		if main and main.has_method("apply_player_damage"):
			main.apply_player_damage(dps * delta, "hazard")
		else:
			pl.hp -= dps * delta
	queue_redraw()

func _draw() -> void:
	var t: float = clamp(life / max_life, 0.0, 1.0)
	var a: float = 0.30 * min(1.0, t * 3.0)
	draw_circle(Vector2.ZERO, radius, Color(col.r, col.g, col.b, a))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(col.r, col.g, col.b, a * 2.2), 3.0)
	# 부글거리는 점
	for i in 5:
		var ang := TAU * i / 5.0 + life * 2.0
		draw_circle(Vector2(cos(ang), sin(ang)) * radius * 0.5, 4.0, Color(col.r, col.g, col.b, a * 2.0))
