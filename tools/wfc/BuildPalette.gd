extends SceneTree
# 생성 모델에 물려줄 팔레트 레퍼런스를 만든다.
#
# 배경: StageTileRenderer.gd 주석대로 "프롬프트에 색을 적는" 방식은 5회 실패했다.
# create_image_pixflux는 color_image로 팔레트를 강제할 수 있으므로, 말로 설명하는 대신
# 실제 색을 이미지로 넘긴다.
#
# 기존 묘지 팩의 실측 팔레트는 9색뿐이고 5색이 98.8%를 차지하는데 전부 거의 검정이다
# (#000000 ~ #202018). 그대로 강제하면 새 타일도 똑같이 납작해지므로, 같은 색 계열을
# 유지하되 톤 범위만 위로 넓힌 확장 팔레트를 쓴다.
#
# 실행:
#   godot --headless --path . --script res://tools/wfc/BuildPalette.gd

const OUT_DIR := "user://wfc_probe"

# 기존 팩에서 실측한 지배색 (비중 순).
const BASE_COLORS := [
	"000000", "101008", "181810", "201008", "202018", "201810", "282828", "283020", "505050",
]

# 확장 톤. 계열(중성 회녹 / 흙갈 / 이끼녹)은 유지하고 명도만 위로 넓힌다.
# 스프라이트 가독성을 위해 상한은 0x48 근처로 잡는다.
const EXTENDED_COLORS := [
	"2a2a20", "303028", "383830", "404038", "484840",   # 중성 석재
	"382a18", "402e1c", "4a3620",                        # 흙·모래
	"2a3a22", "34462a",                                  # 이끼
]


# 첫 시도에서 확장 팔레트를 균등하게 주니 결과가 기존 팩보다 3.4배 밝게 나왔다.
# 모델은 팔레트를 균등 분포로 읽는다. 목표 분포에 맞춰 어두운 색을 여러 번 넣는다.
const COLOR_WEIGHTS := {
	"101008": 4, "181810": 4, "201008": 3, "202018": 2, "000000": 1,
	"201810": 1, "283020": 1, "2a2a20": 1, "382a18": 1, "2a3a22": 1,
	"303028": 1, "34462a": 1, "402e1c": 1, "383830": 1,
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var colors: Array[Color] = []
	for hex in BASE_COLORS:
		colors.append(Color(hex))
	for hex in EXTENDED_COLORS:
		colors.append(Color(hex))

	# 가중 팔레트 — 생성용. 어두운 지배색이 여러 칸을 차지한다.
	var weighted: Array[Color] = []
	for hex in COLOR_WEIGHTS:
		for _n in int(COLOR_WEIGHTS[hex]):
			weighted.append(Color(hex))
	_save_palette(weighted, "palette_weighted_tiny.png", 1)
	print("가중 팔레트 %d칸 (고유 %d색), 평균 밝기 %.4f" % [
		weighted.size(), COLOR_WEIGHTS.size(), _mean_luma(weighted, 0, weighted.size())])

	_save_palette(colors, "palette_ref_graveyard.png", 16)
	# MCP 인자로 base64를 실어 보내면 길이 제한에 걸린다. 색 정보만 남긴 최소 크기 판.
	_save_palette(colors, "palette_ref_tiny.png", 1)

	var hex_list: Array[String] = []
	for c in colors:
		hex_list.append("#" + c.to_html(false))
	var f := FileAccess.open(OUT_DIR + "/palette_ref_graveyard.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"colors": hex_list}, "  "))
		f.close()

	var base_luma := _mean_luma(colors, 0, BASE_COLORS.size())
	var ext_luma := _mean_luma(colors, BASE_COLORS.size(), colors.size())
	print("확장 팔레트 %d색 (기존 %d + 확장 %d)" % [colors.size(), BASE_COLORS.size(), EXTENDED_COLORS.size()])
	print("  기존 평균 밝기 %.4f → 확장분 평균 밝기 %.4f" % [base_luma, ext_luma])
	print("  레퍼런스 이미지: %s/palette_ref_graveyard.png" % ProjectSettings.globalize_path(OUT_DIR))
	quit(0)


func _mean_luma(colors: Array[Color], from_index: int, to_index: int) -> float:
	var total := 0.0
	var n := 0
	for i in range(from_index, to_index):
		var c := colors[i]
		total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
		n += 1
	return total / maxf(1.0, float(n))


# 모델이 색을 읽기 쉽게 큼직한 색 블록으로 깐다.
func _save_palette(colors: Array[Color], filename: String, cell: int) -> void:
	var cols := 5
	var rows := int(ceil(colors.size() / float(cols)))
	var img := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	for i in colors.size():
		img.fill_rect(Rect2i((i % cols) * cell, (i / cols) * cell, cell, cell), colors[i])
	img.save_png(OUT_DIR + "/" + filename)
