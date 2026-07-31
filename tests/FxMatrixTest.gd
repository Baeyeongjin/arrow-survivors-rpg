extends SceneTree
# 이펙트 매트릭스(형태 x 원소) 계약:
#  1) 모든 형태 x 원소 조합이 실제로 존재하는 자산을 가리킨다.
#     하나라도 비면 그 캐릭터의 그 공격만 조용히 이펙트가 사라진다 — 가장 놓치기 쉬운 실패다.
#  2) 무거운 변형(heavy)도 마찬가지이며, 정의가 없으면 기본으로 떨어진다.
#  3) 알 수 없는 원소는 phys로 떨어진다(크래시 대신 폴백).
#  4) 코드에 이펙트 이름 하드코딩이 되살아나지 않았다.
#  5) 캐릭터 11명의 원소가 전부 매트릭스가 아는 값이다.

const FxMatrixScript = preload("res://FxMatrix.gd")
const GameConfigScript = preload("res://GameConfig.gd")

var failed := false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)


func _frames_exist(name: String) -> bool:
	var dir_path := "res://assets/anim/%s" % name
	var d := DirAccess.open(dir_path)
	if d == null:
		return false
	var count := 0
	for f in d.get_files():
		if f.ends_with(".png"):
			count += 1
	return count >= 2


func _initialize() -> void:
	var checked := 0

	# 1) 전 조합이 실재하는 자산을 가리킨다.
	for form in FxMatrixScript.FORMS:
		var row: Dictionary = FxMatrixScript.FORMS[form]
		for element in FxMatrixScript.ELEMENTS:
			_expect(row.has(element),
				"매트릭스 구멍: 형태 %s 에 원소 %s 가 없다" % [form, element])
			if not row.has(element):
				continue
			var name := str(row[element])
			_expect(name != "", "형태 %s / 원소 %s 가 빈 이름" % [form, element])
			_expect(_frames_exist(name),
				"자산 없음: %s (형태 %s / 원소 %s)" % [name, form, element])
			checked += 1

	# 2) 무거운 변형도 실재해야 한다.
	for form in FxMatrixScript.HEAVY:
		var heavy_row: Dictionary = FxMatrixScript.HEAVY[form]
		for element in heavy_row:
			var heavy_name := str(heavy_row[element])
			_expect(_frames_exist(heavy_name),
				"무거운 변형 자산 없음: %s (형태 %s / 원소 %s)" % [heavy_name, form, element])
			checked += 1
		# heavy가 정의된 형태는 기본에도 있어야 한다(폴백 경로 보장).
		_expect(FxMatrixScript.FORMS.has(form),
			"heavy만 있고 기본이 없는 형태: %s" % form)

	# heavy 정의가 없는 형태는 기본으로 떨어진다.
	_expect(FxMatrixScript.resolve("slash", "fire", true)
		== FxMatrixScript.resolve("slash", "fire", false),
		"heavy 정의가 없는데 기본으로 안 떨어짐")
	# heavy 정의가 있는 형태는 실제로 달라야 한다(같으면 무거운 연출이 무의미).
	_expect(FxMatrixScript.resolve("impact", "fire", true)
		!= FxMatrixScript.resolve("impact", "fire", false),
		"impact heavy가 기본과 같다")

	# 3) 미지의 원소는 phys 폴백.
	_expect(FxMatrixScript.normalize_element("water") == "phys", "미지 원소 폴백 실패")
	_expect(FxMatrixScript.resolve("bolt", "water")
		== FxMatrixScript.resolve("bolt", "phys"), "미지 원소가 phys로 안 떨어짐")
	_expect(FxMatrixScript.resolve("no_such_form", "fire") == "",
		"없는 형태가 빈 문자열을 반환하지 않음")
	_expect(FxMatrixScript.resolve_path("bolt", "fire").begins_with("res://assets/anim/"),
		"resolve_path가 자산 경로를 만들지 않음")
	_expect(FxMatrixScript.resolve_path("no_such_form", "fire") == "",
		"없는 형태의 경로가 빈 문자열이 아님")

	# 4) 하드코딩 회귀 방지. 무기 이름마다 이펙트를 박던 방식으로 되돌아가면 안 된다.
	var main_source := FileAccess.get_file_as_string("res://Main.gd")
	for banned in ['spawn_fx("fx_', '.fx_hit = "fx_', 'anim_dir = "res://assets/anim/proj_']:
		_expect(not banned in main_source,
			"이펙트 이름 하드코딩이 되살아났다: %s" % banned)

	# 5) 캐릭터 원소가 전부 매트릭스가 아는 값이어야 한다. 모르는 값이면 전부 phys로
	#    떨어져 캐릭터 구분이 사라진다.
	var main_script := load("res://Main.gd")
	var char_skills: Dictionary = main_script.CHAR_SKILLS
	_expect(char_skills.size() >= 5, "캐릭터 스킬표가 비었다: %d" % char_skills.size())
	var seen_elements := {}
	for key in char_skills:
		var element := str((char_skills[key] as Dictionary).get("element", ""))
		_expect(element in FxMatrixScript.ELEMENTS,
			"캐릭터 %s 의 원소 %s 를 매트릭스가 모른다" % [key, element])
		seen_elements[element] = true
	# 원소가 하나뿐이면 캐릭터가 전부 같은 색으로 싸운다 — 재설계 목적이 사라진다.
	_expect(seen_elements.size() >= 3,
		"캐릭터 원소가 %d종뿐 — 캐릭터별 이펙트 구분이 약하다" % seen_elements.size())

	if failed:
		quit(1)
		return
	print("FX_MATRIX_OK combos=%d elements=%d" % [checked, seen_elements.size()])
	quit(0)
