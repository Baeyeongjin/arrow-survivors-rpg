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
# PixelLab에서 만든 외곽 전용 재질. 원본은 128px지만 게임에서는 64px로 한 번
# 줄였다가 정수 2배 확대해 캐릭터·32px 바닥과 같은 굵기의 도트 클러스터를 만든다.
const OUTER_TILE_SIZE := 128
const OUTER_LOGICAL_SIZE := 64
const OUTER_REGION_SIZE := 512
const STAGE_OUTER_PACK := {
	"graveyard": 6,
	"hell_bridge": 6,
	"glacier": 6,
	"void_altar": 6,
	"demon_castle": 6,
}
const STAGE_OUTER_BASE_INDEX := {
	"graveyard": 2,
	"hell_bridge": 5,
	"glacier": 5,
	"void_altar": 5,
	"demon_castle": 5,
}
const STAGE_OUTER_ACCENTS := {
	"graveyard": [0, 1, 5],
	"hell_bridge": [0, 1, 4],
	"glacier": [0, 3],
	"void_altar": [0, 1, 4],
	"demon_castle": [0, 1, 3],
}
# 이동 불가 외곽은 바닥보다 한 단계 어두워야 플레이어·적·경계가 먼저 읽힌다.
const STAGE_OUTER_TINTS := {
	"graveyard": Color(0.82, 0.82, 0.78),
	"hell_bridge": Color(0.86, 0.76, 0.76),
	"glacier": Color(0.58, 0.67, 0.78),
	"void_altar": Color(0.78, 0.76, 0.88),
	"demon_castle": Color(0.75, 0.71, 0.74),
}
# 경계(전이) 타일의 하이라이트 압축. Wang 아틀라스 원본은 바닥 팩보다 훨씬 밝아서
# 어두운 바닥 위에 UI 선처럼 얹혀 보였다(사장님: 빙하 흰 피아노 건반, 묘지 형광 연두 테두리).
# 실측(assets/maps 전수, 보정 적용 후 HSV):
#   테마      바닥 명도  경계 명도  경계 p95
#   묘지        0.09      0.27      0.47
#   지옥        0.15      0.22      0.41
#   빙하        0.33      0.70      0.95   <- 거의 순백
#   공허        0.16      0.18      0.38
#   마왕성      0.10      0.27      0.56
# 채도는 오히려 바닥이 더 높아(지옥 1.00) 원인이 아니었다. 순수하게 명도 문제다.
# 곱셈 틴트로 누르면 어두운 묘사까지 같이 죽어 형태가 뭉개지므로, knee 위의 밝은 픽셀만
# 선형 압축한다. 색조는 RGB 비율을 그대로 유지해 테마색이 바래지 않는다.
# 경계는 바닥보다 "살짝" 밝아야 경계로 읽히므로 0으로 눌러 없애지 않는다.
# cap은 빌드된 맵의 실측 대비(StageTileRendererTest의 STAGE_EDGE_TONE)로 되잡았다.
# 1차 추정값 → 실측 gap → 보정한 값이다. 소스 아틀라스만 보고 정하면 팩 감광·톤 보정이
# 겹쳐 실제 화면과 어긋난다.
#   테마     1차 cap  실측 gap  보정 cap  최종 gap
#   묘지       0.36    +0.157     0.31     +0.13 이하
#   지옥       0.42    -0.072     0.44     그대로(벽이 바닥보다 어두운 건 정상)
#   빙하       0.62    +0.235     0.48     +0.13 이하
#   공허       0.40    +0.089     0.40     그대로
#   마왕성     0.40    +0.134     0.37     여유 확보
const STAGE_EDGE_ROLLOFF := {
	# 묘지 경계는 분포가 평평해서(평균 0.226 · 피크 0.235) knee 0.22로는 압축 대상이 거의
	# 없었다. cap만 내려도 gap이 0.005밖에 안 움직였다. knee를 평균 아래로 내려야 걸린다.
	"graveyard": {"knee": 0.14, "cap": 0.26},
	"hell_bridge": {"knee": 0.30, "cap": 0.44},
	"glacier": {"knee": 0.38, "cap": 0.48},
	"void_altar": {"knee": 0.26, "cap": 0.40},
	"demon_castle": {"knee": 0.24, "cap": 0.37},
}
const STAGE_DIRS := {
	1: "graveyard",
	2: "hell_bridge",
	3: "glacier",
	4: "void_altar",
	5: "demon_castle",
}
const LOWER_MACRO := 128
const LOWER_PALETTES := {
	"graveyard": {
		"base": Color(0.027, 0.035, 0.039),
		"deep": Color(0.043, 0.052, 0.050),
		"mid": Color(0.071, 0.086, 0.071),
		"accent": Color(0.145, 0.165, 0.105),
	},
	"hell_bridge": {
		"base": Color(0.025, 0.020, 0.026),
		"deep": Color(0.060, 0.039, 0.043),
		"mid": Color(0.105, 0.058, 0.055),
		"accent": Color(0.365, 0.105, 0.060),
	},
	"glacier": {
		"base": Color(0.025, 0.052, 0.082),
		"deep": Color(0.039, 0.086, 0.130),
		"mid": Color(0.064, 0.145, 0.205),
		"accent": Color(0.235, 0.485, 0.610),
	},
	"void_altar": {
		"base": Color(0.018, 0.013, 0.031),
		"deep": Color(0.043, 0.026, 0.074),
		"mid": Color(0.082, 0.043, 0.135),
		"accent": Color(0.330, 0.165, 0.510),
	},
	"demon_castle": {
		"base": Color(0.029, 0.029, 0.039),
		"deep": Color(0.057, 0.054, 0.068),
		"mid": Color(0.105, 0.094, 0.112),
		"accent": Color(0.280, 0.215, 0.205),
	},
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
	# 아틀라스는 이제 경계 칸에만 쓰인다(채움은 팩, 이동 불가는 외곽 재질). 그래서 여기서
	# 하이라이트를 누르면 정확히 "테두리만" 어두워지고 바닥·외곽은 건드리지 않는다.
	var rolloff: Dictionary = STAGE_EDGE_ROLLOFF.get(stage_dir, {})
	if not rolloff.is_empty():
		_compress_highlights(atlas, float(rolloff["knee"]), float(rolloff["cap"]))

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

	var outer_variants := _load_outer_variants(base, stage_dir)
	var columns := ceili(world_size.x / float(CELL))
	var rows := ceili(world_size.y / float(CELL))
	var map_image := Image.create(columns * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	# Wang lower tiles are intentionally skipped in fully blocked cells. Their tiny
	# 32 px pattern looked like an editor grid when it covered most of the screen.
	# Theme-specific PixelLab materials cover that field; irregular region masks keep
	# their six variants from turning into another visible square grid.
	_paint_lower_field(map_image, stage_dir, outer_variants)
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
			if index == 0:
				continue
			# 사방이 전부 바닥인 칸만 변형. 경계 타일은 이어짐이 깨지면 안 되므로 원본 유지.
			if index == FILL_INDEX and fill_variants.size() > 0:
				var pick := rng.randi_range(0, fill_variants.size() - 1)
				map_image.blit_rect(fill_variants[pick], Rect2i(0, 0, CELL, CELL), dst)
			else:
				map_image.blit_rect(atlas, tile_rects[index], dst)
	return ImageTexture.create_from_image(map_image)


static func _load_outer_variants(base: String, stage_dir: String) -> Array[Image]:
	var variants: Array[Image] = []
	for i in int(STAGE_OUTER_PACK.get(stage_dir, 0)):
		var path := base + "outer/%02d.png" % i
		if not ResourceLoader.exists(path):
			continue
		var texture := load(path) as Texture2D
		if texture == null:
			continue
		var source := texture.get_image()
		if source == null or source.is_empty():
			continue
		source.convert(Image.FORMAT_RGBA8)
		# PixelLab의 128px 원본은 미세 묘사가 캐릭터보다 촘촘하다. nearest로
		# 64→128 정수 확대해 흐림 없이 2px 단위의 굵은 도트로 통일한다.
		source.resize(OUTER_LOGICAL_SIZE, OUTER_LOGICAL_SIZE, Image.INTERPOLATE_NEAREST)
		source.resize(OUTER_TILE_SIZE, OUTER_TILE_SIZE, Image.INTERPOLATE_NEAREST)
		var outer_tint: Color = STAGE_OUTER_TINTS.get(stage_dir, Color.WHITE)
		if outer_tint != Color.WHITE:
			_apply_tint(source, outer_tint)
		variants.append(source)
	return variants


static func _paint_lower_field(
		image: Image, stage_dir: String, variants: Array[Image]) -> void:
	if variants.is_empty():
		_paint_lower_fallback(image, stage_dir)
		return

	var base_index := clampi(
		int(STAGE_OUTER_BASE_INDEX.get(stage_dir, 0)), 0, variants.size() - 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("outer-field-%s" % stage_dir)
	_paint_outer_base(image, variants[base_index], rng)

	# 변형을 네모 칸으로 나열하면 서로 다른 지질의 이음선이 바로 보인다. 큰 패치의
	# 중심과 윤곽을 흔들어 뿌리·용암·빙벽·성운·석벽이 자연스럽게 섞이게 한다.
	var half_region := int(OUTER_REGION_SIZE * 0.5)
	for y in range(
			-OUTER_REGION_SIZE,
			image.get_height() + OUTER_REGION_SIZE,
			OUTER_REGION_SIZE):
		for x in range(
				-OUTER_REGION_SIZE,
				image.get_width() + OUTER_REGION_SIZE,
				OUTER_REGION_SIZE):
			if rng.randf() > 0.72:
				continue
			var center := Vector2i(
				x + half_region + rng.randi_range(-120, 120),
				y + half_region + rng.randi_range(-120, 120))
			var patch_size := Vector2i(
				rng.randi_range(150, 280),
				rng.randi_range(120, 240))
			var accent_indices: Array = STAGE_OUTER_ACCENTS.get(stage_dir, [])
			var pick := base_index
			if not accent_indices.is_empty():
				pick = int(accent_indices[rng.randi_range(0, accent_indices.size() - 1)])
				pick = clampi(pick, 0, variants.size() - 1)
			_paint_jagged_texture(
				image,
				center,
				patch_size,
				variants[pick],
				Vector2i(rng.randi_range(0, 127), rng.randi_range(0, 127)),
				rng)


static func _paint_outer_base(
		image: Image, tile: Image, rng: RandomNumberGenerator) -> void:
	# 하나의 큰 암반 무늬가 128px마다 같은 방향으로 반복되면 새 아트도 격자로 보인다.
	# 좌우 또는 상하만 뒤집으면 이웃 타일과 거울축이 생겨 나비 무늬 벽지가 된다(실제 렌더에서
	# 확인했다. 빙하가 가장 심했다). 점대칭인 180도 회전만 섞으면 거울축 없이 윤곽 반복만 끊긴다.
	var orientations: Array[Image] = []
	for rotated in 2:
		var variant := Image.create(
			tile.get_width(), tile.get_height(), false, Image.FORMAT_RGBA8)
		variant.blit_rect(
			tile,
			Rect2i(Vector2i.ZERO, tile.get_size()),
			Vector2i.ZERO)
		if rotated == 1:
			variant.flip_x()
			variant.flip_y()
		orientations.append(variant)
	# 방향이 2개뿐이라 "직전과 다르게" 규칙을 두면 엄격한 교대 = 또 다른 규칙적 무늬가 된다.
	# 그냥 5:5로 뽑는다.
	for y in range(0, image.get_height(), OUTER_TILE_SIZE):
		for x in range(0, image.get_width(), OUTER_TILE_SIZE):
			var pick := rng.randi_range(0, orientations.size() - 1)
			var copy_size := Vector2i(
				mini(OUTER_TILE_SIZE, image.get_width() - x),
				mini(OUTER_TILE_SIZE, image.get_height() - y))
			image.blit_rect(
				orientations[pick],
				Rect2i(Vector2i.ZERO, copy_size),
				Vector2i(x, y))


static func _paint_jagged_texture(
		image: Image, center: Vector2i, size: Vector2i, tile: Image,
		texture_offset: Vector2i, rng: RandomNumberGenerator) -> void:
	var row_height := 8
	var half_h := maxi(row_height, int(size.y * 0.5))
	for py in range(-half_h, half_h, row_height):
		var edge_ratio := absf(float(py)) / float(half_h)
		var half_width := int(
			float(size.x) * 0.5 * sqrt(maxf(0.0, 1.0 - edge_ratio * edge_ratio)))
		var width := maxi(8, half_width * 2 + rng.randi_range(-12, 14))
		var left := center.x - int(width * 0.5) + rng.randi_range(-8, 8)
		_blit_tiled_rect(
			image,
			tile,
			Rect2i(
				left,
				center.y + py,
				width,
				row_height),
			texture_offset)


static func _blit_tiled_rect(
		image: Image, tile: Image, rect: Rect2i, source_offset: Vector2i) -> void:
	var clipped := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	var tile_size := tile.get_size()
	if tile_size.x <= 0 or tile_size.y <= 0:
		return
	var end_x := clipped.position.x + clipped.size.x
	var end_y := clipped.position.y + clipped.size.y
	var y := clipped.position.y
	while y < end_y:
		var source_y := posmod(y + source_offset.y, tile_size.y)
		var copy_h := mini(end_y - y, tile_size.y - source_y)
		var x := clipped.position.x
		while x < end_x:
			var source_x := posmod(x + source_offset.x, tile_size.x)
			var copy_w := mini(end_x - x, tile_size.x - source_x)
			image.blit_rect(
				tile,
				Rect2i(source_x, source_y, copy_w, copy_h),
				Vector2i(x, y))
			x += copy_w
		y += copy_h


static func _paint_lower_fallback(image: Image, stage_dir: String) -> void:
	var palette: Dictionary = LOWER_PALETTES.get(stage_dir, LOWER_PALETTES["graveyard"])
	var base: Color = palette["base"]
	var deep: Color = palette["deep"]
	var mid: Color = palette["mid"]
	var accent: Color = palette["accent"]
	image.fill(base)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("lower-field-%s" % stage_dir)
	var half_macro := int(LOWER_MACRO * 0.5)
	for y in range(-LOWER_MACRO, image.get_height() + LOWER_MACRO, LOWER_MACRO):
		for x in range(-LOWER_MACRO, image.get_width() + LOWER_MACRO, LOWER_MACRO):
			var center := Vector2i(
				x + half_macro + rng.randi_range(-34, 34),
				y + half_macro + rng.randi_range(-34, 34))
			var patch_size := Vector2i(
				rng.randi_range(78, 172),
				rng.randi_range(62, 154))
			_paint_jagged_patch(image, center, patch_size, deep, rng)
			if rng.randf() < 0.62:
				_paint_jagged_patch(
					image,
					center + Vector2i(rng.randi_range(-28, 28), rng.randi_range(-24, 24)),
					Vector2i(maxi(32, int(patch_size.x * 0.58)),
						maxi(28, int(patch_size.y * 0.48))),
					mid,
					rng)
			match stage_dir:
				"hell_bridge":
					if rng.randf() < 0.58:
						_paint_crack(image,
							center + Vector2i(rng.randi_range(-38, 38), -half_macro),
							rng.randi_range(4, 7), accent, rng, true)
				"glacier":
					if rng.randf() < 0.68:
						_paint_crack(image,
							center + Vector2i(-half_macro, rng.randi_range(-32, 32)),
							rng.randi_range(4, 7), accent, rng, false)
				"void_altar":
					_paint_void_sparks(image, center, accent, rng)
				"demon_castle":
					if rng.randf() < 0.54:
						var seam_y := center.y + rng.randi_range(-46, 46)
						_fill_rect_clipped(image,
							Rect2i(center.x - 72, seam_y, 144, 3), accent)
						var seam_x := center.x + rng.randi_range(-46, 46)
						_fill_rect_clipped(image,
							Rect2i(seam_x, seam_y - 42, 3, 84), deep)
				_:
					if rng.randf() < 0.34:
						_paint_crack(image,
							center + Vector2i(rng.randi_range(-30, 30), -half_macro),
							rng.randi_range(3, 5), accent, rng, true)


static func _paint_jagged_patch(
		image: Image, center: Vector2i, size: Vector2i,
		color: Color, rng: RandomNumberGenerator) -> void:
	var row_height := 8
	var half_h := maxi(row_height, int(size.y * 0.5))
	for py in range(-half_h, half_h, row_height):
		var edge_ratio := absf(float(py)) / float(half_h)
		var inset := int(edge_ratio * float(size.x) * 0.34) + rng.randi_range(-8, 10)
		inset = maxi(0, inset)
		var width := maxi(8, size.x - inset * 2)
		_fill_rect_clipped(image,
			Rect2i(center.x - int(size.x * 0.5) + inset, center.y + py,
				width, row_height),
			color)


static func _paint_crack(
		image: Image, start: Vector2i, segments: int, color: Color,
		rng: RandomNumberGenerator, mostly_vertical: bool) -> void:
	var cursor := start
	var thickness := rng.randi_range(2, 4)
	for _segment in segments:
		var next := cursor
		if mostly_vertical:
			next += Vector2i(rng.randi_range(-22, 22), rng.randi_range(18, 38))
		else:
			next += Vector2i(rng.randi_range(18, 38), rng.randi_range(-22, 22))
		var x0 := mini(cursor.x, next.x)
		var y0 := mini(cursor.y, next.y)
		_fill_rect_clipped(image,
			Rect2i(x0, cursor.y, absi(next.x - cursor.x) + thickness, thickness),
			color)
		_fill_rect_clipped(image,
			Rect2i(next.x, y0, thickness, absi(next.y - cursor.y) + thickness),
			color)
		cursor = next


static func _paint_void_sparks(
		image: Image, center: Vector2i, color: Color,
		rng: RandomNumberGenerator) -> void:
	for _spark in rng.randi_range(1, 3):
		var p := center + Vector2i(rng.randi_range(-58, 58), rng.randi_range(-58, 58))
		var size := 2 if rng.randf() < 0.78 else 3
		_fill_rect_clipped(image, Rect2i(p, Vector2i(size, size)), color)
		if size == 3 and rng.randf() < 0.45:
			_fill_rect_clipped(image, Rect2i(p + Vector2i(-3, 1), Vector2i(9, 1)), color)
			_fill_rect_clipped(image, Rect2i(p + Vector2i(1, -3), Vector2i(1, 9)), color)


static func _fill_rect_clipped(image: Image, rect: Rect2i, color: Color) -> void:
	var clipped := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if clipped.size.x > 0 and clipped.size.y > 0:
		image.fill_rect(clipped, color)


static func _apply_tint(img: Image, tint: Color) -> void:
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))


# knee 위의 밝은 픽셀만 선형 압축한다. v=1.0이 정확히 cap으로 떨어지고 knee 이하는 그대로다.
# RGB를 같은 배수로 줄이므로 색조·채도는 보존되고 밝기만 내려간다.
# 테스트가 같은 규칙을 직접 호출한다(StageTileRendererTest).
static func compress_value(v: float, knee: float, cap: float) -> float:
	if v <= knee or v <= 0.0:
		return v
	var span := maxf(0.0001, 1.0 - knee)
	return knee + (v - knee) * ((cap - knee) / span)


static func _compress_highlights(img: Image, knee: float, cap: float) -> void:
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var v: float = maxf(c.r, maxf(c.g, c.b))
			if v <= knee:
				continue
			var scale := compress_value(v, knee, cap) / v
			img.set_pixel(x, y, Color(c.r * scale, c.g * scale, c.b * scale, c.a))


static func _corner_value(value) -> int:
	return 1 if str(value) == "upper" else 0
