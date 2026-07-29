extends SceneTree
# 기존 바닥 팩의 실제 팔레트를 뽑는다.
#
# StageTileRenderer.gd 주석에 "생성 모델은 우리 바닥 색을 모르므로 프롬프트에 색을
# 적어도 계속 겉돌았다(5회 실측)"고 적혀 있다. 프롬프트로 색을 맞추려는 시도는 이미
# 실패한 경로다. 대신 기존 팩의 색을 정확히 뽑아두고, 생성한 타일을 나중에 이 팔레트로
# 강제 양자화한다.
#
# 실행:
#   godot --headless --path . --script res://tools/wfc/PaletteProbe.gd -- --stage=graveyard

const OUT_DIR := "user://wfc_probe"
const TOP_N := 24


func _initialize() -> void:
	var stage_dir := "graveyard"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			stage_dir = arg.split("=")[1]
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var images := _load_pack(stage_dir)
	if images.is_empty():
		print("팩 없음: %s" % stage_dir)
		quit(1)
		return

	# 색 빈도 집계. 8비트 그대로 세면 노이즈가 많아 5비트로 양자화해 묶는다.
	var counts := {}
	var total := 0
	for img in images:
		for y in img.get_height():
			for x in img.get_width():
				var c: Color = img.get_pixel(x, y)
				if c.a < 0.5:
					continue
				var key := _quantize_key(c)
				counts[key] = int(counts.get(key, 0)) + 1
				total += 1

	var keys: Array = counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])

	print("=".repeat(70))
	print("바닥 팩 팔레트: %s  (타일 %d장, 불투명 픽셀 %d개)" % [stage_dir, images.size(), total])
	print("=".repeat(70))
	print("%-4s %-10s %8s %8s" % ["#", "HEX", "픽셀수", "비중"])
	var shown: Array[Color] = []
	for i in mini(TOP_N, keys.size()):
		var c := _key_to_color(keys[i])
		shown.append(c)
		print("%-4d %-10s %8d %7.2f%%" % [
			i, "#" + c.to_html(false), counts[keys[i]], 100.0 * counts[keys[i]] / float(total)])

	print("\n서로 다른 색(5비트 양자화 기준): %d개" % keys.size())
	var cover := 0
	for i in mini(TOP_N, keys.size()):
		cover += counts[keys[i]]
	print("상위 %d색이 전체의 %.1f%%를 덮는다." % [mini(TOP_N, keys.size()), 100.0 * cover / float(total)])

	# GDScript/도구가 바로 읽을 수 있게 JSON으로도 남긴다.
	var hex_list: Array[String] = []
	for c in shown:
		hex_list.append("#" + c.to_html(false))
	var f := FileAccess.open(OUT_DIR + "/palette_%s.json" % stage_dir, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"stage": stage_dir, "colors": hex_list}, "  "))
		f.close()

	_save_swatch(shown, "palette_%s.png" % stage_dir)
	_probe_edge_darkening(images)
	print("\n출력: %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit(0)


# 인게임에서 보이는 32px 격자가 배치 탓인지 타일 자체 탓인지 가른다.
# 타일 테두리 픽셀이 안쪽보다 체계적으로 어두우면, 어떻게 배치해도 격자선이 그려진다.
func _probe_edge_darkening(images: Array) -> void:
	print("\n[격자감의 출처] 타일 테두리 vs 안쪽 밝기")
	var edge_total := 0.0
	var inner_total := 0.0
	var darker_count := 0
	for img: Image in images:
		var w := img.get_width()
		var h := img.get_height()
		var edge_sum := 0.0
		var edge_n := 0
		var inner_sum := 0.0
		var inner_n := 0
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				var luma := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
				if x == 0 or y == 0 or x == w - 1 or y == h - 1:
					edge_sum += luma
					edge_n += 1
				else:
					inner_sum += luma
					inner_n += 1
		var e := edge_sum / maxf(1.0, float(edge_n))
		var i2 := inner_sum / maxf(1.0, float(inner_n))
		edge_total += e
		inner_total += i2
		if e < i2:
			darker_count += 1
	var n := float(images.size())
	print("  테두리 평균 %.4f / 안쪽 평균 %.4f  (차이 %.4f)" % [
		edge_total / n, inner_total / n, inner_total / n - edge_total / n])
	print("  %d장 중 %d장이 테두리가 더 어둡다." % [images.size(), darker_count])
	if darker_count > images.size() / 2:
		print("  → 격자선이 타일 아트 자체에 그려져 있다. 배치를 바꿔도 안 없어진다.")
	else:
		print("  → 타일 자체에는 격자선이 없다. 격자감은 다른 원인이다.")


func _quantize_key(c: Color) -> int:
	var r := int(c.r * 255.0) >> 3
	var g := int(c.g * 255.0) >> 3
	var b := int(c.b * 255.0) >> 3
	return (r << 10) | (g << 5) | b


func _key_to_color(key: int) -> Color:
	var r := ((key >> 10) & 31) << 3
	var g := ((key >> 5) & 31) << 3
	var b := (key & 31) << 3
	return Color8(r, g, b)


func _load_pack(dir_name: String) -> Array:
	var images: Array = []
	for i in 24:
		var path := "res://assets/maps/%s/floor/%02d.png" % [dir_name, i]
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		var img := tex.get_image()
		if img == null or img.is_empty():
			continue
		img.convert(Image.FORMAT_RGBA8)
		images.append(img)
	return images


func _save_swatch(colors: Array[Color], filename: String) -> void:
	var cell := 48
	var cols := 8
	var rows := int(ceil(colors.size() / float(cols)))
	var img := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	for i in colors.size():
		img.fill_rect(Rect2i((i % cols) * cell, (i / cols) * cell, cell, cell), colors[i])
	img.save_png(OUT_DIR + "/" + filename)
