class_name FxAnim
extends Node2D
# 프레임 애니메이션 이펙트: assets/anim/<dir>/0..N.png 을 1회 재생 후 소멸

var frames_dir := ""
var fps := 16.0
var size_px := 72.0
var rot := 0.0
var tint := Color.WHITE
# 비균등 스케일 (rot 적용 후 로컬축 기준). 채찍처럼 '길고 얇게' 뽑을 때 씀 —
# size_px만으로 키우면 길이와 함께 두께도 커져 굵은 띠가 됨.
var stretch := Vector2.ONE
var _t := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	_t += delta
	var frames: Array = Assets.frames(frames_dir)
	if frames.is_empty() or int(_t * fps) >= frames.size():
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var frames: Array = Assets.frames(frames_dir)
	if frames.is_empty():
		return
	var idx: int = clamp(int(_t * fps), 0, frames.size() - 1)
	var tex: Texture2D = frames[idx]
	draw_set_transform(Vector2.ZERO, rot, stretch)
	draw_texture_rect(tex, Rect2(Vector2(-size_px / 2.0, -size_px / 2.0), Vector2(size_px, size_px)), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
