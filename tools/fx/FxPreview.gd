extends SceneTree
# 절차 이펙트(Effect.gd)를 게임 없이 바로 렌더해 캡처한다.
#
# 이펙트를 눈으로 확인하려면 원래 해당 무기를 들고 실제로 휘둘러야 했다.
# 여기서는 Effect 인스턴스를 진행도별로 나란히 세워 한 장에 담는다.
# 애니메이션이라 정지 프레임 여러 장을 봐야 모양을 판단할 수 있다.
#
# 실행 (헤드리스 아님 — 실제 렌더가 필요하다):
#   godot --path . --script res://tools/fx/FxPreview.gd -- --kind=whip

const OUT := "user://wfc_probe/fx_preview.png"
const COLS := 5
const CELL := 260.0


func _initialize() -> void:
	var kind := "whip"
	var col := Color(1.0, 0.86, 0.48)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):
			kind = arg.split("=")[1]
	DirAccess.make_dir_recursive_absolute("user://wfc_probe")

	var root_node := Node2D.new()
	root.add_child(root_node)

	# 어두운 배경. 이펙트는 가산합성이라 검은 바탕이 실제 화면에 가깝다.
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.09)
	bg.size = Vector2(COLS * CELL, CELL * 1.2)
	root_node.add_child(bg)

	# 진행도 0.85 → 0.05 (life가 줄수록 후반). 5장으로 스윙 전체를 본다.
	var stages := [0.85, 0.65, 0.45, 0.25, 0.08]
	for i in stages.size():
		var fx := Effect.new()
		fx.kind = kind
		fx.rad = 96.0
		fx.col = col
		fx.max_life = 0.26
		fx.life = 0.26 * float(stages[i])
		var center := Vector2(CELL * (float(i) + 0.5), CELL * 0.6)
		fx.position = center
		# whip/cleave/slash는 (from_global - position)으로 방향을 잡는다.
		fx.from_global = center + Vector2.RIGHT * fx.rad
		fx.dir = Vector2.RIGHT
		root_node.add_child(fx)
		# 정지 프레임으로 고정. 두면 _process가 life를 깎아 사라진다.
		fx.set_process(false)

	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(OUT)
	print("kind=%s 프리뷰 저장: %s" % [kind, ProjectSettings.globalize_path(OUT)])
	print("왼쪽이 스윙 시작, 오른쪽이 끝.")
	quit(0)
