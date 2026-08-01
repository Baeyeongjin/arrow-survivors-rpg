extends SceneTree
# 장비 아이콘 계약:
#  1) 모든 명사가 GEAR_NOUN_ICON 에 있다. 빠지면 그 장비만 조용히 빈칸으로 나온다 —
#     크래시가 없어서 가장 놓치기 쉬운 실패다.
#  2) 그 경로에 실제 파일이 있다.
#  3) 슬롯별로 명사가 충분하다. 등급이 3단계인데 종류가 적으면 다른 등급을 먹어도
#     같은 그림·같은 이름이라 새로 얻은 느낌이 안 난다.

const MainScript = preload("res://Main.gd")

const MIN_NOUNS_PER_SLOT := 8

var failed := false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)


func _initialize() -> void:
	var nouns: Dictionary = MainScript.GEAR_NOUNS
	var icons: Dictionary = MainScript.GEAR_NOUN_ICON
	var total := 0
	var seen_icons := {}

	for slot in nouns:
		var list: Array = nouns[slot]
		_expect(list.size() >= MIN_NOUNS_PER_SLOT,
			"%s 명사가 %d종뿐 (최소 %d) — 등급을 올려도 같은 그림이 나온다" % [
				slot, list.size(), MIN_NOUNS_PER_SLOT])
		for noun in list:
			total += 1
			var key := str(noun)
			_expect(icons.has(key), "명사 '%s' 에 아이콘 매핑이 없다 (%s 슬롯)" % [key, slot])
			if not icons.has(key):
				continue
			var path := str(icons[key])
			_expect(path != "", "명사 '%s' 의 아이콘 경로가 비었다" % key)
			_expect(ResourceLoader.exists(path),
				"아이콘 파일이 없다: %s (명사 '%s')" % [path, key])
			# 같은 그림을 여러 명사가 쓰면 인벤토리에서 구분이 안 된다.
			_expect(not seen_icons.has(path),
				"아이콘 중복: %s 를 '%s' 와 '%s' 가 함께 쓴다" % [
					path, str(seen_icons.get(path, "")), key])
			seen_icons[path] = key

	if failed:
		quit(1)
		return
	print("GEAR_ICON_OK nouns=%d icons=%d" % [total, seen_icons.size()])
	quit(0)
