extends SceneTree
# 플레이어 11종과 일반 몬스터 22종의 걷기 프레임을 전수 검사한다.
# 고유 key와 스프라이트 파일명이 다른 정예·중간보스 8종도 실제 Enemy.setup()을
# 통과시켜 기본 몬스터의 걷기/공격 애니메이션을 재사용하는지 잠근다.

const MIN_WALK_FRAMES := 4
const MIN_ATTACK_FRAMES := 4


func _initialize() -> void:
	var ok := true
	ok = _check_player_walks() and ok
	ok = _check_monster_assets() and ok
	ok = _check_special_enemy_reuse() and ok

	if ok:
		print("WALK_OK: players=11 monsters=22 special_reuse=8")
		quit(0)
	else:
		quit(1)


func _check_player_walks() -> bool:
	var ok := true
	for character in GameConfig.characters():
		var key := str(character.get("key", ""))
		var path := "res://assets/anim/%s_1_walk" % key
		if not _check_frame_set(path, MIN_WALK_FRAMES, "%s player walk" % key):
			ok = false
	return ok


func _check_monster_assets() -> bool:
	var ok := true
	for tier in GameConfig.enemy_tiers():
		var key := str(tier.get("key", ""))
		var walk_path := "res://assets/anim/%s_walk" % key
		var attack_path := "res://assets/anim/%s_attack" % key
		if not _check_frame_set(walk_path, MIN_WALK_FRAMES, "%s monster walk" % key):
			ok = false
		if not _check_frame_set(attack_path, MIN_ATTACK_FRAMES, "%s monster attack" % key):
			ok = false
	return ok


func _check_special_enemy_reuse() -> bool:
	var cases := [
		{"tier": GameConfig.hell_elite_tier(), "asset_key": "hellhound"},
		{"tier": GameConfig.hell_midboss_tier(), "asset_key": "demon"},
		{"tier": GameConfig.graveyard_elite_tier(), "asset_key": "wraith_knight"},
		{"tier": GameConfig.graveyard_midboss_tier(), "asset_key": "dark_knight"},
		{"tier": GameConfig.glacier_elite_tier(), "asset_key": "ice_wisp"},
		{"tier": GameConfig.glacier_midboss_tier(), "asset_key": "frost_golem"},
		{"tier": GameConfig.void_elite_tier(), "asset_key": "void_wraith"},
		{"tier": GameConfig.void_midboss_tier(), "asset_key": "eye_mass"},
	]
	var ok := true
	for test_case in cases:
		var tier: Dictionary = test_case["tier"]
		var asset_key := str(test_case["asset_key"])
		var enemy := Enemy.new()
		enemy.setup(tier, 0.0)

		var expected_walk := Assets.frames("res://assets/anim/%s_walk" % asset_key)
		var expected_attack := Assets.frames("res://assets/anim/%s_attack" % asset_key)
		if enemy._frames_walk.size() != expected_walk.size() or expected_walk.size() < MIN_WALK_FRAMES:
			push_error("%s must reuse %s walk frames (actual=%d expected=%d)" % [
				tier.get("key", ""), asset_key, enemy._frames_walk.size(), expected_walk.size(),
			])
			ok = false
		if enemy._frames_attack.size() != expected_attack.size() or expected_attack.size() < MIN_ATTACK_FRAMES:
			push_error("%s must reuse %s attack frames (actual=%d expected=%d)" % [
				tier.get("key", ""), asset_key, enemy._frames_attack.size(), expected_attack.size(),
			])
			ok = false
		enemy.free()
	return ok


func _check_frame_set(path: String, minimum: int, label: String) -> bool:
	var frames := Assets.frames(path)
	if frames.size() < minimum:
		push_error("%s failed to load: %s (%d/%d frames)" % [label, path, frames.size(), minimum])
		return false
	for index in frames.size():
		if not frames[index] is Texture2D:
			push_error("%s contains an invalid texture: %s/%d.png" % [label, path, index])
			return false
	return true
