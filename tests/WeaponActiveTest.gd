extends SceneTree

const MainScript = preload("res://Main.gd")
const PlayerScript = preload("res://Player.gd")
const ArrowScript = preload("res://Arrow.gd")

var failed := false


class DamageTarget:
	extends Node2D

	var damage_taken := 0.0
	var was_crit := false

	func take_damage(damage: float, crit: bool = false) -> void:
		damage_taken += damage
		was_crit = crit


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)


func _initialize() -> void:
	var game = MainScript.new()
	var player = PlayerScript.new()
	game.player = player

	_expect(game.WEAPON_ACTIVE_DEFS.size() == 5, "장비 무기 액티브 아키타입은 정확히 5개여야 함")
	var active_names := {}
	for archetype in game.WEAPON_ACTIVE_DEFS:
		var active_def: Dictionary = game.WEAPON_ACTIVE_DEFS[archetype]
		var active_name := str(active_def.get("name", ""))
		_expect(not active_name.is_empty(), "%s 액티브 표시 이름 누락" % archetype)
		_expect(float(active_def.get("cd", 0.0)) > 0.0, "%s 액티브 쿨다운이 유효하지 않음" % archetype)
		_expect(not str(active_def.get("glyph", "")).is_empty(), "%s 액티브 글리프 누락" % archetype)
		_expect(ResourceLoader.exists(str(active_def.get("icon", ""))), "%s 액티브 아이콘 리소스 누락" % archetype)
		_expect(not active_names.has(active_name), "액티브 표시 이름 중복: %s" % active_name)
		active_names[active_name] = true

	for weapon_kind in game.ALL_WEAPONS:
		_expect(game.WEAPON_ACTIVE_ARCHETYPE.has(weapon_kind), "전체 무기 %s의 E 아키타입 누락" % weapon_kind)
		var archetype := str(game.WEAPON_ACTIVE_ARCHETYPE.get(weapon_kind, ""))
		_expect(game.WEAPON_ACTIVE_DEFS.has(archetype), "전체 무기 %s가 잘못된 E 아키타입 %s를 참조" % [weapon_kind, archetype])
	for weapon_kind in game.STARTING_WEAPON_ACTIVE_VARIANTS:
		_expect(game.WEAPON_ACTIVE_ARCHETYPE.has(weapon_kind),
			"시작 무기 액티브 변형 %s가 5개 조작 문법에 연결되지 않음" % weapon_kind)

	var canonical := {
		"cleave": "sword",
		"axe": "axe",
		"soul_bolt": "staff",
		"knife": "dagger",
		"spear": "spear",
	}
	for weapon_kind in canonical:
		_expect(game._weapon_active_archetype(weapon_kind) == canonical[weapon_kind],
			"장비 무기 %s의 E 아키타입이 %s가 아님" % [weapon_kind, canonical[weapon_kind]])

	for character in GameConfig.characters():
		for field in ["weapon", "weapon2"]:
			var weapon_kind := str(character.get(field, ""))
			if weapon_kind != "":
				_expect(game.WEAPON_ACTIVE_ARCHETYPE.has(weapon_kind),
					"캐릭터 %s의 시작 무기 %s가 E 아키타입에 연결되지 않음" % [str(character.get("key", "?")), weapon_kind])

	# 장비가 없으면 캐릭터 시작 무기, 장착하면 장비 무기가 E를 결정한다.
	game.sel_char = {"key": "gustavo", "weapon": "cleave"}
	game.equipped = {"weapon": {}, "armor": {}, "trinket": {}}
	_expect(game._primary_weapon_kind() == "cleave", "빈 무기 슬롯은 캐릭터 시작 무기를 사용해야 함")
	_expect(str(game._current_weapon_active_def().get("name", "")) == "반격의 호",
		"cleave 시작 무기는 검 액티브를 사용해야 함")
	game.sel_char = {"key": "django", "weapon": "spread_shot"}
	_expect(str(game._current_weapon_active_def().get("name", "")) == "속사 난무",
		"장비가 없는 장고는 산탄 시작 무기 이름을 E에 유지해야 함")
	game.sel_char = {"key": "serafina", "weapon": "aura"}
	_expect(str(game._current_weapon_active_def().get("name", "")) == "성역 파동",
		"장비가 없는 세라피나는 오라 시작 무기 이름을 E에 유지해야 함")

	game.equipped["weapon"] = {
		"slot": "weapon",
		"rarity": "rare",
		"name": "얼어붙은 단검",
		"weapon_kind": "knife",
		"element": "ice",
		"affixes": [],
	}
	_expect(game._primary_weapon_kind() == "knife", "장착 무기가 캐릭터 시작 무기보다 우선해야 함")
	_expect(game._active_skill_element() == "ice", "E 속성은 장착 무기 접두 속성을 사용해야 함")
	_expect(str(game._current_weapon_active_def().get("name", "")) == "그림자 난무",
		"knife 장비는 단검 액티브를 사용해야 함")
	player.cooldown_mult = 0.8
	_expect(is_equal_approx(game._weapon_active_cooldown(), 3.2), "E 쿨다운은 플레이어 쿨다운 배율을 반영해야 함")

	var detail := game._gear_detail_text(game.equipped["weapon"])
	_expect("자동공격" in detail and "그림자 난무" in detail and "냉기 속성" in detail,
		"무기 상세 정보에 자동공격·E·속성이 함께 보여야 함")
	var hud := Label.new()
	game.skill_hud_label = hud
	game._refresh_skill_hud()
	_expect("그림자 난무" in hud.text and "Space 회피" in hud.text,
		"전투 HUD에 현재 무기 E 이름과 회피가 함께 보여야 함")

	# 같은 고속 난사 문법이라도 캐릭터 시작 무기는 자기 투사체를 유지한다.
	game.equipped = {"weapon": {}, "armor": {}, "trinket": {}}
	game.sel_char = {"key": "django", "weapon": "spread_shot"}
	game._sfx_cd["shoot"] = INF
	game._fire_dagger_active(Vector2.RIGHT)
	var bullet_count := 0
	for child in game.get_children():
		if child is Arrow and child.anim_dir == "res://assets/anim/proj_bullet":
			bullet_count += 1
	_expect(bullet_count == 7, "장고의 속사 난무는 단검 대신 총탄 7발을 사용해야 함")

	game.sel_char = {"key": "isolde", "weapon": "ice_lance"}
	game._sfx_cd["dash"] = INF
	game._fire_spear_active(Vector2.RIGHT)
	var found_ice_lance := false
	for child in game.get_children():
		if child is Arrow and child.anim_dir == "res://assets/anim/proj_icelance":
			found_ice_lance = child.slow_amount > 0.0
	_expect(found_ice_lance, "이졸데의 빙하 돌진은 둔화가 붙은 얼음창 투사체를 사용해야 함")

	# 투사체 고유 치명타 수치가 실제 명중 계산에 반영되는지 검증한다.
	var projectile = ArrowScript.new()
	projectile.damage = 10.0
	projectile.crit_chance = 1.0
	projectile.crit_mult = 2.2
	var target := DamageTarget.new()
	game._sfx_cd["hit"] = INF   # SceneTree 밖의 단위 테스트에서는 오디오 재생을 건너뛴다.
	game._apply_arrow_hit(projectile, target)
	_expect(target.was_crit, "투사체 치명타 확률 100%가 실제 판정에 반영되지 않음")
	_expect(is_equal_approx(target.damage_taken, 22.0), "투사체 고유 치명타 배수가 실제 피해에 반영되지 않음")

	projectile.free()
	target.free()
	hud.free()
	game.free()
	player.free()
	if failed:
		quit(1)
		return
	print("WEAPON_ACTIVE_OK")
	quit(0)
