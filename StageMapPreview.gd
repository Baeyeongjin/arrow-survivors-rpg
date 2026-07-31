class_name StageMapPreview
extends Control

const UiTypographyScript = preload("res://UiTypography.gd")

var world_size := Vector2(2400.0, 2400.0)
var tracked_player: Node2D = null
var reveal_names := false

const RELIC_NAMES := {
	"spinach": "시금치", "armor": "갑옷", "wings": "날개", "tome": "빈 마도서",
	"candela": "촛대", "heart": "공허의 심장", "tomato": "토마토",
	"duplicator": "복제의 룬", "spellbinder": "봉인의 서", "crown": "왕관",
	"stone_mask": "돌가면", "clover": "네잎클로버", "keen_eye": "매의 눈",
	"berserker": "광전사의 인장", "vitality": "생명력", "iron_will": "강철의지",
	"swiftness": "표범의 발", "skull": "저주 해골",
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var frame := Rect2(Vector2(8, 8), size - Vector2(16, 16))
	draw_rect(frame, Color(0.025, 0.035, 0.055, 0.95), true)
	draw_rect(frame, Color(0.35, 0.65, 0.85, 0.7), false, 2.0)
	for i in range(1, 4):
		var gx := lerpf(frame.position.x, frame.end.x, i / 4.0)
		var gy := lerpf(frame.position.y, frame.end.y, i / 4.0)
		draw_line(Vector2(gx, frame.position.y), Vector2(gx, frame.end.y), Color(0.2, 0.32, 0.42, 0.22), 1.0)
		draw_line(Vector2(frame.position.x, gy), Vector2(frame.end.x, gy), Color(0.2, 0.32, 0.42, 0.22), 1.0)
	var font := UiTypographyScript.font()
	for node in get_tree().get_nodes_in_group("landmarks"):
		var landmark := node as Pickup
		if landmark == null:
			continue
		var point := _world_to_map(landmark.position, frame)
		draw_circle(point, 6.0, Color(0.35, 0.9, 1.0))
		draw_circle(point, 9.0, Color(0.35, 0.9, 1.0, 0.3), false, 2.0)
		if reveal_names:
			var key := str(landmark.kind).trim_prefix("passive:")
			draw_string(font, point + Vector2(10, 5), str(RELIC_NAMES.get(key, key)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.82, 0.94, 1.0))
	if tracked_player and is_instance_valid(tracked_player):
		var player_point := _world_to_map(tracked_player.position, frame)
		draw_circle(player_point, 7.0, Color(1.0, 0.86, 0.25))
		draw_circle(player_point, 11.0, Color(1.0, 0.86, 0.25, 0.35), false, 2.0)


func _world_to_map(world_pos: Vector2, frame: Rect2) -> Vector2:
	var normalized := Vector2(
		clampf(world_pos.x / maxf(1.0, world_size.x), 0.0, 1.0),
		clampf(world_pos.y / maxf(1.0, world_size.y), 0.0, 1.0)
	)
	return frame.position + normalized * frame.size
