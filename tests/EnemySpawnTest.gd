extends SceneTree
# 던전 일반 몬스터가 화면 밖의 열린 바닥에서 태어나는지 검증한다.
# 막힌 후보를 nearest_walkable로 벽 가장자리에 붙이던 회귀를 차단한다.

const MainScript = preload("res://Main.gd")
const StageLayoutScript = preload("res://StageLayout.gd")
const GameConfigScript = preload("res://GameConfig.gd")
const HALF_VIEW := Vector2(640.0, 360.0)
const SAMPLES_PER_CENTER := 10

var failed := false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)


func _initialize() -> void:
	seed(20260730)
	var source := FileAccess.get_file_as_string("res://Main.gd")
	_expect(not "func _edge_pos(" in source,
		"막힌 점을 벽 가장자리로 투영하던 _edge_pos가 다시 추가됨")

	var game = MainScript.new()
	var checked := 0
	for stage in range(1, 6):
		var layout = StageLayoutScript.make(stage, Color.WHITE, 73000 + stage)
		game.stage_layout = layout
		game.map_stage = stage
		var mode := str(GameConfigScript.stage_spawn_profile(stage).get("mode", "wide"))
		var centers: Array[Vector2] = [StageLayoutScript.WORLD * 0.5]
		for room_index in mini(4, layout.rooms.size()):
			centers.append(layout.rooms[room_index].get_center())
		for center in centers:
			if not layout.is_walkable(center, 24.0):
				center = layout.nearest_walkable(center, 24.0)
			for _sample in SAMPLES_PER_CENTER:
				var position: Vector2 = game._find_stage_spawn_pos(center, HALF_VIEW, mode)
				var delta := (position - center).abs()
				var expanded := HALF_VIEW + Vector2.ONE * MainScript.ENEMY_SPAWN_MARGIN
				_expect(layout.is_walkable(position, MainScript.ENEMY_SPAWN_CLEARANCE),
					"stage %d: 스폰이 벽 여유 %.0fpx를 확보하지 못함: %s" % [
						stage, MainScript.ENEMY_SPAWN_CLEARANCE, position])
				_expect(delta.x > expanded.x or delta.y > expanded.y,
					"stage %d: 스폰이 화면 바깥 여백을 확보하지 못함: %s" % [
						stage, position])
				checked += 1
	game.free()

	if failed:
		quit(1)
		return
	print("ENEMY_SPAWN_OK stages=5 samples=%d clearance=%.0f margin=%.0f" % [
		checked, MainScript.ENEMY_SPAWN_CLEARANCE, MainScript.ENEMY_SPAWN_MARGIN])
	quit(0)
