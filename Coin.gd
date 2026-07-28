class_name Coin
extends Node2D
# 골드 코인: 젬처럼 자석 범위에 들어오면 빨려옴

var value := 1
var radius := 8.0
var _t := 0.0

func _ready() -> void:
	add_to_group("coins")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	_t += delta
	var pl := get_tree().get_first_node_in_group("player") as Player
	if pl == null:
		return
	var to: Vector2 = pl.position - position
	var dist := to.length()
	if dist < 16.0:
		get_parent().collect_coin(value)
		queue_free()
		return
	if dist < pl.current_pickup_radius():
		position += to.normalized() * 340.0 * delta
	queue_redraw()

func _draw() -> void:
	var bob := sin(_t * 4.0) * 1.5
	var tex := Assets.tex("res://assets/items/coin.png")
	if tex:
		draw_texture_rect(tex, Rect2(Vector2(-9, -9 + bob), Vector2(18, 18)), false)
		return
	draw_circle(Vector2(0, bob), 7.0, Color(1.0, 0.82, 0.25))
	draw_circle(Vector2(0, bob), 4.5, Color(1.0, 0.92, 0.55))
