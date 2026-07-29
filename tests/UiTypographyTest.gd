extends SceneTree

const UiTypographyScript = preload("res://UiTypography.gd")
const DamageNumScript = preload("res://DamageNum.gd")
const ExpeditionRulesScript = preload("res://ExpeditionRules.gd")

var failed := false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)


func _initialize() -> void:
	_expect(ResourceLoader.exists(UiTypographyScript.FONT_PATH), "공용 픽셀 폰트 리소스 누락")
	var shared_font := UiTypographyScript.font()
	var ui_theme := UiTypographyScript.make_theme()
	_expect(shared_font != null, "공용 픽셀 폰트를 불러오지 못함")
	_expect(ui_theme.default_font == shared_font, "UI 테마가 공용 픽셀 폰트를 사용하지 않음")

	var damage_number = DamageNumScript.new()
	damage_number._ready()
	_expect(damage_number._font == shared_font, "데미지 숫자와 UI 폰트가 서로 다름")
	damage_number.free()

	var icon_paths := [
		"res://assets/ui/icons/backpack.png",
		"res://assets/ui/icons/anvil.png",
		"res://assets/ui/icons/codex.png",
		"res://assets/ui/icons/achievement.png",
		"res://assets/ui/icons/options.png",
		"res://assets/ui/route_selection_frame.png",
	]
	for node_key in ExpeditionRulesScript.NODE_DEFS:
		var node: Dictionary = ExpeditionRulesScript.NODE_DEFS[node_key]
		_expect(not node.has("glyph"), "%s 경로에 인라인 글리프가 남아 있음" % node_key)
		icon_paths.append(str(node.get("icon", "")))
	for icon_path in icon_paths:
		_expect(ResourceLoader.exists(icon_path), "UI 픽셀 아이콘 누락: %s" % icon_path)

	print("UI_TYPOGRAPHY_TEST %s font=%s icons=%d" % [
		"FAIL" if failed else "PASS",
		UiTypographyScript.FONT_PATH,
		icon_paths.size(),
	])
	quit(1 if failed else 0)
