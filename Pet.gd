class_name Pet
extends Node2D

# 플라잉 소드: 플레이어 주위를 공전하며 가장 가까운 적을 자동 공격
var orbit := 62.0
var damage := 7.0
var fire_interval := 0.7
var index := 0
var _angle := 0.0
var _timer := 0.0

func _ready() -> void:
	add_to_group("pets")

func _process(delta: float) -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl:
		_angle += delta * 2.2
		position = pl.position + Vector2(cos(_angle + index * 2.0), sin(_angle + index * 2.0)) * orbit
	_timer -= delta
	if _timer <= 0.0:
		_timer = fire_interval
		get_parent().spawn_pet_arrow(self)
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2(0, 10), Vector2(0, -12), Color(0.8, 0.95, 1.0), 4)
	draw_line(Vector2(-6, 6), Vector2(6, 6), Color(0.7, 0.8, 1.0), 3)
