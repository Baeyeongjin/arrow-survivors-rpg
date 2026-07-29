class_name PostFX
extends CanvasLayer
# 고전 레트로 후처리(레버 2): 월드 화면을 픽셀화 + 팔레트 축소(posterize)해서
# 뱀서식 굵고 납작한 도트 룩을 흉내낸다. 순수 후처리 — 스프라이트 원본은 그대로.
# 기본은 OFF(원본과 100% 동일). F4로 프리셋을 실시간 순환하며 굵기를 비교한다.
# 레이어 1: 월드(0) 위에 그려지고, HUD/오버레이(2/10)는 위에서 선명하게 유지.

var _rect: ColorRect
var _mat: ShaderMaterial
var _label: Label
var _label_t := 0.0
var _preset := 0

# 프리셋: pixel=1 이면 픽셀화 없음(원본), levels=64 면 색 축소 없음.
# 640p → pixel 2.0, 480p → 2.667, 427p → 3.0 (1280 기준 내부 해상도 환산).
const PRESETS := [
	{"name": "원본 (OFF)", "pixel": 1.0, "levels": 64.0},
	{"name": "640p · 은은", "pixel": 2.0, "levels": 32.0},
	{"name": "480p · 중간", "pixel": 2.667, "levels": 24.0},
	{"name": "427p · 굵게", "pixel": 3.0, "levels": 18.0},
]

const SHADER_CODE := "
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float pixel_size = 1.0;
uniform float color_levels = 64.0;
void fragment() {
	vec2 vp = 1.0 / SCREEN_PIXEL_SIZE;      // 뷰포트 픽셀 크기
	vec2 uv = SCREEN_UV;
	if (pixel_size > 1.001) {
		vec2 grid = vp / pixel_size;         // 저해상도 그리드
		uv = (floor(SCREEN_UV * grid) + 0.5) / grid;
	}
	vec3 col = texture(screen_tex, uv).rgb;
	if (color_levels < 63.0) {
		col = floor(col * color_levels + 0.5) / color_levels;   // 팔레트 축소
	}
	COLOR = vec4(col, 1.0);
}
"

func _ready() -> void:
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS   # 일시정지 중에도 라벨 페이드
	var sh := Shader.new()
	sh.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect = ColorRect.new()
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.visible = false   # 기본 OFF
	add_child(_rect)
	# 프리셋 표시 라벨 (전환 시 잠깐 표시)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
	_label.position = Vector2(20, 64)
	_label.visible = false
	add_child(_label)
	_apply()

func _process(delta: float) -> void:
	if _label.visible:
		_label_t -= delta
		if _label_t <= 0.0:
			_label.visible = false

# F4: 다음 프리셋으로 순환 (원본 → 640p → 480p → 427p → 원본…)
func cycle() -> void:
	_preset = (_preset + 1) % PRESETS.size()
	_apply()
	_label.text = "[화면] 레트로 도트: %s" % PRESETS[_preset]["name"]
	_label.visible = true
	_label_t = 2.2

func _apply() -> void:
	var p: Dictionary = PRESETS[_preset]
	_mat.set_shader_parameter("pixel_size", float(p["pixel"]))
	_mat.set_shader_parameter("color_levels", float(p["levels"]))
	_rect.visible = _preset != 0   # OFF일 땐 전체화면 리드로우 자체를 끔
