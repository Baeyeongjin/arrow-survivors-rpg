class_name UiTypography
extends RefCounted

# 전투 데미지 숫자와 모든 UI가 반드시 같은 픽셀 폰트 리소스를 공유한다.
# 화면별로 직접 load()하지 않아 폰트 교체와 회귀 검증 지점을 하나로 고정한다.
const FONT_PATH := "res://assets/fonts/pixel.ttf"
const DEFAULT_SIZE := 15

static var _font: Font


static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH) as Font
		if _font == null:
			_font = ThemeDB.fallback_font
	return _font


static func make_theme(default_size: int = DEFAULT_SIZE) -> Theme:
	var ui_theme := Theme.new()
	ui_theme.default_font = font()
	ui_theme.default_font_size = default_size
	return ui_theme
