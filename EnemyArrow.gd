class_name EnemyArrow
extends Node2D

var velocity := Vector2(0, 300)
var damage := 9.0
var radius := 8.0
var life := 3.0
var chill := false   # 명중 시 플레이어 이동 둔화 (아이스 퀸)

func _ready() -> void:
	add_to_group("enemy_arrows")

func _process(delta: float) -> void:
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if chill:
		draw_circle(Vector2.ZERO, radius, Color(0.55, 0.85, 1.0))
		draw_circle(Vector2.ZERO, radius * 0.5, Color(0.85, 0.95, 1.0))
	else:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.3, 0.7))
		draw_circle(Vector2.ZERO, radius * 0.5, Color(1.0, 0.7, 0.9))
