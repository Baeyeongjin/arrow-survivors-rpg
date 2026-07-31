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
# 프레임 사이 교차 페이드. VFX 팩이 6프레임뿐이라 딱딱 끊어 바꾸면 뚝뚝 끊겨 보인다
# (사장님: "팩 프레임 좀더 부드럽게"). 현재 프레임과 다음 프레임을 겹쳐 그려
# 6프레임으로도 연속된 움직임으로 읽히게 한다. 마지막 프레임은 겹칠 대상이 없어 그대로.
var blend := true
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


func _blit(tex: Texture2D, col: Color) -> void:
	draw_texture_rect(tex,
		Rect2(Vector2(-size_px / 2.0, -size_px / 2.0), Vector2(size_px, size_px)),
		false, col)


func _draw() -> void:
	var frames: Array = Assets.frames(frames_dir)
	if frames.is_empty():
		return
	var pos: float = _t * fps
	var idx: int = clampi(int(pos), 0, frames.size() - 1)
	draw_set_transform(Vector2.ZERO, rot, stretch)
	if blend and idx + 1 < frames.size():
		# 단순 선형 페이드는 중간 지점에서 둘 다 반투명이라 밝기가 꺼진 것처럼 보인다.
		# 제곱근 가중(등전력 교차 페이드)으로 겹치는 동안 체감 밝기를 유지한다.
		var f: float = clampf(pos - float(idx), 0.0, 1.0)
		_blit(frames[idx], Color(tint.r, tint.g, tint.b, tint.a * sqrt(1.0 - f)))
		_blit(frames[idx + 1], Color(tint.r, tint.g, tint.b, tint.a * sqrt(f)))
	else:
		_blit(frames[idx], tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
