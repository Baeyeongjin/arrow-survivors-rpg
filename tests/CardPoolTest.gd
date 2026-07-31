extends SceneTree

const MainScript = preload("res://Main.gd")
const PlayerScript = preload("res://Player.gd")


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false


func _expect_regular_three(cards: Array, context: String) -> bool:
	if not _expect(cards.size() == 3, "%s: level-up choice must contain exactly three cards" % context):
		return false
	for card in cards:
		if not _expect(str(card.get("t", "")) != "arcana", "%s: Arcana card leaked into level-up pool" % context):
			return false
	return true


func _initialize() -> void:
	var game = MainScript.new()
	game.meta = {"ach": {}}

	var fresh_pool: Array = game._card_options()
	if not _expect(fresh_pool.size() >= 3, "fresh run: card pool must contain at least three cards"):
		game.free()
		return
	if not _expect_regular_three(game._pick3(fresh_pool), "fresh run"):
		game.free()
		return

	# 성장을 전부 소진시킨다: 스킬 9종 만렙 + 패시브 만렙.
	# 이 상태에서도 카드 3장이 나와야 한다(리밋 브레이크가 받아 준다).
	for arch in SkillDefs.ARCHETYPES.keys():
		game.skill_levels[arch] = SkillDefs.MAX_SKILL_LEVEL
	for key in game._passive_defs().keys():
		game.passives[key] = game.MAX_PLEVEL

	var exhausted_cards: Array = game._card_options()
	if not _expect(exhausted_cards.size() >= 3, "exhausted growth pool must still contain at least three cards"):
		game.free()
		return
	if not _expect_regular_three(game._pick3(exhausted_cards), "exhausted growth pool"):
		game.free()
		return

	game.player = PlayerScript.new()
	game.meta["unlocked_relics"] = {"black_chalice": true}
	game.global_lifesteal = 0.0
	game._apply_unlocked_relic_effects()
	if not _expect(is_equal_approx(game.global_lifesteal, 0.015), "Black Chalice must preserve 1.5% global lifesteal"):
		game.player.free()
		game.free()
		return

	game.meta["unlocked_relics"] = {"hungry_heart": true, "metaglio": true, "black_chalice": true}
	game.global_lifesteal = 0.0
	game._apply_relic_set_effects()
	if not _expect(is_equal_approx(game.global_lifesteal, 0.02), "Immortal Heart set must preserve 2% global lifesteal"):
		game.player.free()
		game.free()
		return

	game.player.free()
	game.free()
	print("CARD_POOL_OK")
	quit(0)
