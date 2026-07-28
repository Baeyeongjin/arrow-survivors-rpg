extends SceneTree
# 신규 3인(이졸데·그림블·모르덱) 걷기 애니가 스테이지1 키 규칙(<key>_1_walk)으로
# 실제 로드되는지 확인. 리네임+재임포트 검증용.

func _initialize() -> void:
	var ok := true
	for k in ["isolde", "grimble", "mordek"]:
		var frames: Array = Assets.frames("res://assets/anim/%s_1_walk" % k)
		print("%s_1_walk: %d frames" % [k, frames.size()])
		if frames.size() < 4:
			push_error("%s 걷기 프레임 로드 실패 (%d)" % [k, frames.size()])
			ok = false
	# 기존 캐릭터가 여전히 정상인지 회귀 확인
	var base: Array = Assets.frames("res://assets/anim/corvius_1_walk")
	if base.size() < 4:
		push_error("corvius 걷기 회귀 실패 (%d)" % base.size())
		ok = false
	if ok:
		print("WALK_OK")
		quit(0)
	else:
		quit(1)
