class_name StageTileRenderer
extends RefCounted

const CELL := 32
# 네 모서리가 전부 upper(=바닥)인 채움 타일의 인덱스. 넓은 바닥의 대부분이 이 칸이다.
const FILL_INDEX := 15
# 스테이지별 채움 타일 팩(assets/maps/<dir>/floor/NN.png)의 장수.
# Wang 타일셋은 '두 지형의 경계 처리'용이라 채움 타일이 한 장뿐이고, 넓은 바닥에
# 그 한 장만 무한 반복돼 도장을 찍은 격자로 보였다. 밝기만 바꾼 변형으로는
# 무늬가 그대로라 반복감이 남았다. 사람이 같은 팔레트로 그린 바닥 팩(DCSS, CC0)으로 대체.
# 생성 모델은 우리 바닥 색을 모르므로 프롬프트에 색을 적어도 계속 겉돌았다(5회 실측).
const STAGE_FILL_PACK := {
	"graveyard": 12,
	"hell_bridge": 7,
	"glacier": 13,
	"void_altar": 8,
	"demon_castle": 16,
}
# 채움 팩 전용 감광. 팩마다 원본 밝기가 달라 스테이지 톤 보정과 따로 잡는다.
# 빙하·공허 팩은 원본이 밝은 파랑이라 그대로 두면 캐릭터가 묻히고 경계 타일과도 어긋난다.
const STAGE_FILL_TINTS := {
	"graveyard": Color(1.18, 1.18, 1.18),
	"hell_bridge": Color(1.22, 1.10, 1.10),
	"glacier": Color(0.70, 0.78, 0.92),
	"void_altar": Color(0.86, 0.86, 1.02),
	"demon_castle": Color(1.20, 1.20, 1.24),
}
const STAGE_DIRS := {
	1: "graveyard",
	2: "hell_bridge",
	3: "glacier",
	4: "void_altar",
	5: "demon_castle",
}


# Builds one map texture from the exact same StageLayout used by movement.
# The 16 PixelLab Wang tiles are selected by the four walkable corner values.
static func build(layout, stage_id: int, world_size: Vector2, tint := Color.WHITE) -> Texture2D:
	var stage_dir := str(STAGE_DIRS.get(stage_id, ""))
	if stage_dir == "":
		return null
	var base := "res://assets/maps/%s/" % stage_dir
	var metadata_path := base + "metadata_v2.json"
	var image_path := base + "tileset_v2.png"
	if not FileAccess.file_exists(metadata_path) or not FileAccess.file_exists(image_path):
		return null

	var metadata_file := FileAccess.open(metadata_path, FileAccess.READ)
	if metadata_file == null:
		return null
	var parsed = JSON.parse_string(metadata_file.get_as_text())
	if not parsed is Dictionary:
		return null

	var atlas_texture := load(image_path) as Texture2D
	if atlas_texture == null:
		return null
	var atlas := atlas_texture.get_image()
	if atlas == null or atlas.is_empty():
		return null
	var tile_rects: Dictionary = {}
	for tile in parsed.get("tileset_data", {}).get("tiles", []):
		var corners: Dictionary = tile.get("corners", {})
		var index := _corner_value(corners.get("NW", "lower")) * 8
		index += _corner_value(corners.get("NE", "lower")) * 4
		index += _corner_value(corners.get("SW", "lower")) * 2
		index += _corner_value(corners.get("SE", "lower"))
		var box: Dictionary = tile.get("bounding_box", {})
		tile_rects[index] = Rect2i(
			int(box.get("x", 0)), int(box.get("y", 0)),
			int(box.get("width", CELL)), int(box.get("height", CELL)))
	if tile_rects.size() < 16:
		return null

	# 경계 타일에만 스테이지 톤 보정을 미리 굽는다. 채움 팩은 이미 어둡고 채도가 잡혀 있어
	# 같은 보정을 먹이면 뭉개진다. 그래서 그리는 쪽은 흰색으로 두고 여기서 나눠 적용한다.
	if tint != Color.WHITE:
		_apply_tint(atlas, tint)

	# 채움 칸 변형. 팩이 있으면 그걸 쓰고, 없으면 기존 Wang 채움 타일 한 장으로 되돌아간다.
	var fill_variants: Array[Image] = []
	for i in int(STAGE_FILL_PACK.get(stage_dir, 0)):
		var pack_path := base + "floor/%02d.png" % i
		if not ResourceLoader.exists(pack_path):
			continue
		var pack_tex := load(pack_path) as Texture2D
		if pack_tex == null:
			continue
		var pack_img := pack_tex.get_image()
		if pack_img == null or pack_img.is_empty():
			continue
		pack_img.convert(Image.FORMAT_RGBA8)
		var fill_tint: Color = STAGE_FILL_TINTS.get(stage_dir, Color.WHITE)
		if fill_tint != Color.WHITE:
			_apply_tint(pack_img, fill_tint)
		fill_variants.append(pack_img)
	if fill_variants.is_empty() and tile_rects.has(FILL_INDEX):
		var v := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
		v.blit_rect(atlas, tile_rects[FILL_INDEX], Vector2i.ZERO)
		fill_variants.append(v)

	var columns := ceili(world_size.x / float(CELL))
	var rows := ceili(world_size.y / float(CELL))
	var map_image := Image.create(columns * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(stage_dir)   # 스테이지마다 고정 — 매 판 같은 맵이 나온다
	for row in rows:
		for column in columns:
			var origin := Vector2(column * CELL, row * CELL)
			var index := 0
			if layout.is_walkable(origin, 0.0):
				index += 8
			if layout.is_walkable(origin + Vector2(CELL, 0), 0.0):
				index += 4
			if layout.is_walkable(origin + Vector2(0, CELL), 0.0):
				index += 2
			if layout.is_walkable(origin + Vector2(CELL, CELL), 0.0):
				index += 1
			var dst := Vector2i(column * CELL, row * CELL)
			# 사방이 전부 바닥인 칸만 변형. 경계 타일은 이어짐이 깨지면 안 되므로 원본 유지.
			if index == FILL_INDEX and fill_variants.size() > 0:
				var pick := rng.randi_range(0, fill_variants.size() - 1)
				map_image.blit_rect(fill_variants[pick], Rect2i(0, 0, CELL, CELL), dst)
			else:
				map_image.blit_rect(atlas, tile_rects[index], dst)
	return ImageTexture.create_from_image(map_image)


static func _apply_tint(img: Image, tint: Color) -> void:
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))


static func _corner_value(value) -> int:
	return 1 if str(value) == "upper" else 0
