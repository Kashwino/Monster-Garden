extends SceneTree
## Run with a real display. Captures the actual Godot UI, never a mock-up.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	await create_timer(1.0).timeout
	var output := OS.get_environment("MONSTER_GARDEN_CAPTURE_DIR")
	if output.is_empty():
		output = "user://"
	var game := root.get_node("Game")
	var hud := current_scene.get_node("HUD")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("garden.png"))
	# Touch-select a specific plot through the real viewport input dispatch.
	var grid := current_scene.get_node("GridManager")
	var camera := current_scene.get_node("CameraRig/Camera3D") as Camera3D
	var point := camera.unproject_position(grid.plot_position(5))
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = point
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = point
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	assert(game.selected_plot == 5, "Touch should select plot 6 through viewport dispatch")
	for tab: String in ["seeds", "basket", "orders", "codex", "guide"]:
		hud._open(tab)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(tab + ".png"))
		hud._close()
	print("VISUAL SMOKE PASS: rendered garden, five panels, touch plot selection")
	quit()
