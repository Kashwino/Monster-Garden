extends SceneTree
## Deterministic full-garden fixture. Never run against a player's save.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	change_scene_to_file("res://scenes/Main.tscn")
	await process_frame;await process_frame
	var game:=root.get_node("Game")
	var tutorial:=root.get_node("Tutorial")
	var catalog:=root.get_node("Catalog")
	var decor:=root.get_node("Decorations")
	var factory:=root.get_node("AssetFactory")
	var output:=OS.get_environment("MONSTER_GARDEN_CAPTURE_DIR")
	var variant:="batched" if factory.batch_meshes else "unbatched"
	game.reset_garden()
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	if factory.batch_meshes: root.get_texture().get_image().save_png(output.path_join("tutorial.png"))
	tutorial.skip();current_scene.get_node("HUD")._close()
	await create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	if factory.batch_meshes: root.get_texture().get_image().save_png(output.path_join("garden.png"))
	root.get_node("LevelXP").level=30
	root.get_node("Economy").coins=3500
	for i: int in game.plots.size():
		game.plots[i]=game._plant_data(String(catalog.species.keys()[(i*5)%catalog.species.size()]),game.now()-50000)
		game.plot_changed.emit(i)
	decor.placements={"0":{"id":"keeper_castle","rotation":0},"1":{"id":"glass_nursery","rotation":0},"2":{"id":"whisper_fountain","rotation":0},"3":{"id":"eye_topiary","rotation":0},"4":{"id":"ivory_gazebo","rotation":0},"5":{"id":"spore_lamp","rotation":0},"6":{"id":"spore_lamp","rotation":0},"7":{"id":"moon_pond","rotation":0},"8":{"id":"dream_observatory","rotation":0},"9":{"id":"bone_arch","rotation":0},"10":{"id":"bloom_tower","rotation":0},"11":{"id":"spore_lamp","rotation":0}}
	decor.changed.emit();root.get_node("Economy").changed.emit()
	await create_timer(2).timeout
	# Let the initial toast/feedback clear before comparing identical scenes.
	await create_timer(2).timeout
	var frames: Array[float]=[]
	var draws:=0.0
	var primitives:=0.0
	for i: int in 90:
		var before:=Time.get_ticks_usec()
		await process_frame
		frames.append((Time.get_ticks_usec()-before)/1000.0)
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	frames.sort()
	var result: Dictionary={"variant":variant,"renderer":"Compatibility","adapter":RenderingServer.get_video_adapter_name(),"resolution":"480x900","plots":24,"decorations":12,"frames":90,"draw_calls_mean":draws/90,"primitives_mean":primitives/90,"frame_ms_median":frames[45],"frame_ms_p95":frames[85],"particle_pool":3,"particles_max":72,"node_count":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}
	var file:=FileAccess.open(output.path_join("performance-"+variant+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"));file.close()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("full-garden-"+variant+".png"))
	print("PERFORMANCE "+JSON.stringify(result));quit()
