extends SceneTree

const GameConfigScript = preload("res://GameConfig.gd")
const MainScript = preload("res://Main.gd")


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false


func _initialize() -> void:
	var difficulties: Array = GameConfigScript.difficulties()
	var expected_keys := ["easy", "normal", "hard", "nightmare"]
	if not _expect(difficulties.size() == expected_keys.size(), "difficulty count must match the four expedition tiers"):
		return

	var previous: Dictionary = {}
	for i in difficulties.size():
		var difficulty: Dictionary = difficulties[i]
		if not _expect(str(difficulty.get("key", "")) == expected_keys[i], "difficulty order/key mismatch at index %d" % i):
			return
		for required_key in ["player_hp", "enemy_hp", "enemy_speed", "spawn", "loot", "gold", "xp", "gear", "rarity_luck"]:
			if not _expect(difficulty.has(required_key), "%s is missing %s" % [difficulty.get("key", "?"), required_key]):
				return
		if not previous.is_empty():
			if not _expect(float(difficulty["player_hp"]) < float(previous["player_hp"]), "higher difficulty must reduce player HP"):
				return
			if not _expect(float(difficulty["enemy_hp"]) > float(previous["enemy_hp"]), "higher difficulty must increase enemy HP"):
				return
			if not _expect(float(difficulty["enemy_speed"]) > float(previous["enemy_speed"]), "higher difficulty must increase enemy speed"):
				return
			if not _expect(float(difficulty["spawn"]) < float(previous["spawn"]), "higher difficulty must spawn enemies faster"):
				return
			if not _expect(float(difficulty["gold"]) >= float(previous["gold"]), "higher difficulty must not reduce gold rewards"):
				return
			if not _expect(float(difficulty["xp"]) >= float(previous["xp"]), "higher difficulty must not reduce XP rewards"):
				return
			if not _expect(float(difficulty["gear"]) > float(previous["gear"]), "higher difficulty must increase gear drops"):
				return
			if not _expect(float(difficulty["rarity_luck"]) >= float(previous["rarity_luck"]), "higher difficulty must not reduce rarity luck"):
				return
		previous = difficulty

	var game = MainScript.new()
	for difficulty in difficulties:
		game._apply_difficulty_profile(difficulty)
		if not _expect(str(game.sel_diff.get("key", "")) == str(difficulty["key"]), "selected difficulty was not retained"):
			game.free()
			return
		if not _expect(is_equal_approx(game.diff_enemy_hp, float(difficulty["enemy_hp"])), "enemy HP profile was not applied"):
			game.free()
			return
		if not _expect(is_equal_approx(game.diff_gold_reward, float(difficulty["gold"])), "gold reward profile was not applied"):
			game.free()
			return
		if not _expect(is_equal_approx(game.diff_gear_drop, float(difficulty["gear"])), "gear reward profile was not applied"):
			game.free()
			return
		if not _expect(is_equal_approx(game.diff_rarity_luck, float(difficulty["rarity_luck"])), "rarity profile was not applied"):
			game.free()
			return

	if not _expect(str(game._difficulty_by_key("unknown")["key"]) == "normal", "unknown difficulty must fall back to normal"):
		game.free()
		return

	game.free()
	print("DIFFICULTY_OK")
	quit(0)
