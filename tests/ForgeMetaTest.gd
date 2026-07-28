extends SceneTree

const MainScript = preload("res://Main.gd")


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false


func _sample_gear(slot: String, name: String, value: float) -> Dictionary:
	return {
		"slot": slot,
		"rarity": "rare",
		"name": name,
		"affixes": [{"stat": "damage_mult", "name": "공격력", "value": value, "pct": true}],
		"_found": true,
		"lvl": 0,
	}


func _initialize() -> void:
	var game = MainScript.new()
	game.meta = {
		"gold": 0,
		"stash": [],
		"loadout": {"weapon": {}, "armor": {}, "trinket": {}},
	}
	game.equipped = {"weapon": _sample_gear("weapon", "시험 검", 0.10), "armor": {}, "trinket": {}}
	game.inventory = [_sample_gear("armor", "시험 갑옷", 20.0)]

	var banked := game._bank_found_gear()
	if not _expect(banked == 2, "expected two found items to be banked"):
		return
	var stash: Array = game.meta["stash"]
	if not _expect(stash.size() == 2, "banked items were not added to the stash"):
		return
	if not _expect(not bool(game.equipped["weapon"].get("_found", false)), "banked equipped item kept its _found flag"):
		return
	if not _expect(not bool(game.inventory[0].get("_found", false)), "banked inventory item kept its _found flag"):
		return
	if not _expect(game._bank_found_gear() == 0, "banked gear must not duplicate on a second end screen"):
		return

	var upgraded: Dictionary = stash[0].duplicate(true)
	var base_value := float(upgraded["affixes"][0]["base_value"])
	upgraded["lvl"] = 1
	upgraded = game._normalize_persistent_gear(upgraded)
	if not _expect(is_equal_approx(float(upgraded["affixes"][0]["value"]), base_value * 1.12), "forge upgrade did not apply the expected 12% bonus"):
		return

	game.meta["stash"][0] = upgraded
	game.meta["loadout"]["weapon"] = upgraded.duplicate(true)
	game._ensure_gear_meta()
	var loadout_weapon: Dictionary = game.meta["loadout"]["weapon"]
	if not _expect(game._same_gear(loadout_weapon, game.meta["stash"][0]), "loadout item must remain linked to its stash item"):
		return
	if not _expect(is_equal_approx(float(loadout_weapon["affixes"][0]["value"]), base_value * 1.12), "loadout lost the upgraded affix value"):
		return
	print("FORGE_META_OK")
	quit(0)
