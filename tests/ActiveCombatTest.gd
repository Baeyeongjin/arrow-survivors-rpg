extends SceneTree

const MainScript = preload("res://Main.gd")
const PlayerScript = preload("res://Player.gd")
const EnemyScript = preload("res://Enemy.gd")


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false


func _initialize() -> void:
	var player := PlayerScript.new()
	player.position = Vector2(500.0, 500.0)
	var start := player.position
	if not _expect(player.try_dodge(Vector2.RIGHT), "ready player must be able to dodge"):
		player.free()
		return
	if not _expect(player.is_dodging(), "dodge must enter its active movement window"):
		player.free()
		return
	if not _expect(player.invuln >= PlayerScript.DODGE_DURATION, "dodge invulnerability must cover the movement window"):
		player.free()
		return
	player._process(0.08)
	if not _expect(player.position.x > start.x + 40.0, "dodge must move in the requested direction"):
		player.free()
		return
	if not _expect(not player.try_dodge(Vector2.UP), "dodge cannot be retriggered during cooldown"):
		player.free()
		return
	for _i in 80:
		player._process(0.02)
	if not _expect(absf(player.position.x - start.x - PlayerScript.DODGE_DISTANCE) < 0.5,
			"dodge distance must stay frame-rate independent"):
		player.free()
		return
	if not _expect(is_zero_approx(player.dodge_cd), "dodge cooldown must expire"):
		player.free()
		return
	if not _expect(player.try_dodge(Vector2.UP), "dodge must become available after cooldown"):
		player.free()
		return

	var enemy := EnemyScript.new()
	enemy.position = Vector2.ZERO
	enemy.radius = 18.0
	enemy.behavior = ""
	enemy._strike_dir = Vector2.RIGHT
	enemy._melee_state = 1
	if not _expect(not enemy.can_damage_player(Vector2(36.0, 0.0), 12.0), "melee windup must not deal damage"):
		player.free()
		enemy.free()
		return
	enemy._melee_state = 2
	if not _expect(enemy.can_damage_player(Vector2(42.0, 0.0), 12.0), "active melee cone must hit in its warned direction"):
		player.free()
		enemy.free()
		return
	if not _expect(not enemy.can_damage_player(Vector2(-42.0, 0.0), 12.0), "normal melee must not hit behind its warning cone"):
		player.free()
		enemy.free()
		return
	if not _expect(not enemy.can_damage_player(Vector2(0.0, 60.0), 12.0), "normal melee must be sidestep-able"):
		player.free()
		enemy.free()
		return

	enemy.elite = true
	if not _expect(enemy.can_damage_player(Vector2(-42.0, 0.0), 12.0), "elite warning must resolve as a radial slam"):
		player.free()
		enemy.free()
		return
	enemy.behavior = "ranged"
	if not _expect(not enemy.can_damage_player(Vector2.ZERO, 12.0), "ranged enemies must not deal touch damage"):
		player.free()
		enemy.free()
		return
	enemy.behavior = "charge"
	enemy._cstate = 1
	if not _expect(not enemy.can_damage_player(Vector2.ZERO, 12.0), "charge windup must be harmless"):
		player.free()
		enemy.free()
		return
	enemy._cstate = 2
	if not _expect(enemy.can_damage_player(Vector2(20.0, 0.0), 12.0), "active charge body must deal damage"):
		player.free()
		enemy.free()
		return

	var game := MainScript.new()
	var hud := Label.new()
	game.player = player
	game.skill_hud_label = hud
	game._refresh_skill_hud()
	if not _expect("Space 회피" in hud.text, "combat HUD must identify Space as dodge"):
		hud.free()
		game.free()
		player.free()
		enemy.free()
		return

	hud.free()
	game.free()
	player.free()
	enemy.free()
	print("ACTIVE_COMBAT_OK")
	quit(0)
