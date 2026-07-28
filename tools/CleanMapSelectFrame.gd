extends SceneTree

const SOURCE := "res://assets/ui/map_select_frame.png"
const OUTPUT := "res://assets/ui/map_select_frame_clean.png"


func _initialize() -> void:
	var image := Image.load_from_file(SOURCE)
	if image == null or image.is_empty():
		push_error("Could not read " + SOURCE)
		quit(1)
		return
	var width := image.get_width()
	var height := image.get_height()
	var queue: Array[Vector2i] = []
	var visited := PackedByteArray()
	visited.resize(width * height)
	for x in width:
		_enqueue_if_checker(image, Vector2i(x, 0), width, queue, visited)
		_enqueue_if_checker(image, Vector2i(x, height - 1), width, queue, visited)
	for y in height:
		_enqueue_if_checker(image, Vector2i(0, y), width, queue, visited)
		_enqueue_if_checker(image, Vector2i(width - 1, y), width, queue, visited)
	var cursor := 0
	while cursor < queue.size():
		var point := queue[cursor]
		cursor += 1
		var pixel := image.get_pixelv(point)
		pixel.a = 0.0
		image.set_pixelv(point, pixel)
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			_enqueue_if_checker(image, point + offset, width, queue, visited)
	# The header splits a few matte squares from the outer connected region.
	# Remove only those neutral bright remnants in the top padding band.
	for y in mini(50, height):
		for x in width:
			var point := Vector2i(x, y)
			var color := image.get_pixelv(point)
			var neutral := maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b)) < 0.035
			if neutral and color.r > 0.55:
				color.a = 0.0
				image.set_pixelv(point, color)
	# The generated source has a permanent gold border around the middle card.
	# Replace it with the adjacent standard card frame; runtime selection supplies
	# the only gold highlight.
	image.blit_rect(image, Rect2i(170, 78, 116, 166), Vector2i(286, 78))
	var err := image.save_png(OUTPUT)
	if err != OK:
		push_error("Could not save " + OUTPUT)
		quit(1)
		return
	print("MAP_FRAME_CLEANED pixels=%d output=%s" % [queue.size(), OUTPUT])
	quit(0)


func _enqueue_if_checker(image: Image, point: Vector2i, width: int, queue: Array[Vector2i], visited: PackedByteArray) -> void:
	if point.x < 0 or point.y < 0 or point.x >= image.get_width() or point.y >= image.get_height():
		return
	var index := point.y * width + point.x
	if visited[index] != 0:
		return
	var color := image.get_pixelv(point)
	# Only the two neutral, bright checker colors baked into the outer matte.
	var neutral := maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b)) < 0.035
	if not neutral or color.r < 0.55:
		return
	visited[index] = 1
	queue.append(point)
