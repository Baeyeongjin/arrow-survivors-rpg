extends SceneTree

const StageLayoutScript = preload("res://StageLayout.gd")
const StageTileRendererScript = preload("res://StageTileRenderer.gd")
const WORLD := Vector2(2800, 2800)
const STAGE_DIRS := ["graveyard", "hell_bridge", "glacier", "void_altar", "demon_castle"]


func _initialize() -> void:
	var failures: Array[String] = []
	for stage_id in range(1, 6):
		var layout = StageLayoutScript.make(stage_id, Color.WHITE)
		var texture := StageTileRendererScript.build(layout, stage_id, WORLD)
		if texture == null:
			failures.append("stage %d: texture build failed" % stage_id)
			continue
		var expected := Vector2i(2816, 2816)
		if texture.get_size() != Vector2(expected):
			failures.append(
				"stage %d: expected %s, got %s" % [stage_id, expected, texture.get_size()]
			)
		else:
			print("STAGE_TILE_OK stage=%d size=%s" % [stage_id, texture.get_size()])
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
