extends SceneTree

const StageLayoutScript = preload("res://StageLayout.gd")
const StageTileRendererScript = preload("res://StageTileRenderer.gd")
# 실제 게임과 같은 월드 크기로 구워야 텍스처 크기·베이크 비용이 의미가 있다.
const WORLD := StageLayout.WORLD
const STAGE_DIRS := ["graveyard", "hell_bridge", "glacier", "void_altar", "demon_castle"]


func _pure_lower_color_count(texture: Texture2D, layout) -> int:
	var colors := {}
	var image := texture.get_image()
	var cell := int(StageTileRendererScript.CELL)
	var columns := int(image.get_width() / float(cell))
	var rows := int(image.get_height() / float(cell))
	var half_cell := int(cell * 0.5)
	for row in rows:
		for column in columns:
			var origin := Vector2(column * cell, row * cell)
			if layout.is_walkable(origin, 0.0) \
					or layout.is_walkable(origin + Vector2(cell, 0), 0.0) \
					or layout.is_walkable(origin + Vector2(0, cell), 0.0) \
					or layout.is_walkable(origin + Vector2(cell, cell), 0.0):
				continue
			colors[image.get_pixel(
				column * cell + half_cell,
				row * cell + half_cell).to_rgba32()] = true
	return colors.size()


func _initialize() -> void:
	var failures: Array[String] = []
	for stage_id in range(1, 6):
		var layout = StageLayoutScript.make(stage_id, Color.WHITE)
		var texture := StageTileRendererScript.build(layout, stage_id, WORLD)
		if texture == null:
			failures.append("stage %d: texture build failed" % stage_id)
			continue
		# 32px 격자로 올림한 크기. WORLD가 바뀌어도 따라간다.
		var cell := float(StageTileRendererScript.CELL)
		var expected := Vector2i(
			int(ceil(WORLD.x / cell) * cell), int(ceil(WORLD.y / cell) * cell))
		if texture.get_size() != Vector2(expected):
			failures.append(
				"stage %d: expected %s, got %s" % [stage_id, expected, texture.get_size()]
			)
		else:
			print("STAGE_TILE_OK stage=%d size=%s" % [stage_id, texture.get_size()])
			var lower_color_count := _pure_lower_color_count(texture, layout)
			if lower_color_count < 3:
				failures.append(
					"stage %d: lower field is still a flat/repeating tile (%d sampled colors)" % [
						stage_id, lower_color_count])
			else:
				print("STAGE_LOWER_FIELD_OK stage=%d colors=%d" % [
					stage_id, lower_color_count])
			if "--render-stage-previews" in OS.get_cmdline_user_args():
				var preview_path := OS.get_temp_dir().path_join("arrow_stage_%d.png" % stage_id)
				var save_error := texture.get_image().save_png(preview_path)
				if save_error != OK:
					failures.append("stage %d: preview save failed (%d)" % [stage_id, save_error])
				else:
					print("STAGE_TILE_PREVIEW %s" % preview_path)
			if "--write-map-card-previews" in OS.get_cmdline_user_args():
				var card_image := texture.get_image()
				card_image.resize(192, 192, Image.INTERPOLATE_NEAREST)
				var card_path := "res://assets/maps/%s/preview.png" % STAGE_DIRS[stage_id - 1]
				var card_error := card_image.save_png(card_path)
				if card_error != OK:
					failures.append("stage %d: card preview save failed (%d)" % [stage_id, card_error])
				else:
					print("STAGE_CARD_PREVIEW %s" % card_path)
	if failures.is_empty():
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
