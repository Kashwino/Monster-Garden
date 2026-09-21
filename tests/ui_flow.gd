extends SceneTree
## Actual pointer dispatch through tutorial masks and real controls, with accelerated UTC timers.
var failures:=0
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error("FAIL: "+message)
func find_button(node: Node,prefix: String) -> Button:
	if node is Button:
		var button:=node as Button
		if button.is_visible_in_tree() and button.text.begins_with(prefix): return button
	for child: Node in node.get_children():
		var found:=find_button(child,prefix)
		if found!=null: return found
	return null
func click(prefix: String) -> void:
	await process_frame;await process_frame
	var button:=find_button(current_scene.get_node("HUD"),prefix)
	check(button!=null,"visible button: "+prefix)
	if button==null: return
	await tap(button.get_global_rect().get_center())
func tap(point: Vector2) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.pressed=true
	Input.parse_input_event(event);await process_frame
	event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.pressed=false
	Input.parse_input_event(event);await process_frame;await process_frame
func run() -> void:
	change_scene_to_file("res://scenes/Main.tscn")
	await process_frame;await process_frame
	var game:=root.get_node("Game")
	var tutorial:=root.get_node("Tutorial")
	var hud:=current_scene.get_node("HUD")
	var premium:=root.get_node("Premium")
	game.reset_garden()
	await create_timer(.5).timeout
	await click("Plant · 6 coins")
	check(tutorial.current_id()=="tutorial_wait","pointer plants through tutorial mask")
	if tutorial.current_id()!="tutorial_wait":
		print("UI DEBUG plot=",game.selected_plot," tab=",hud._tab)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("MONSTER_GARDEN_CAPTURE_DIR").path_join("ui-failure.png"))
		quit(1);return
	premium.finish(tutorial.target_plot)
	await process_frame;await process_frame
	await click("Harvest monster plant")
	await click("Sell one")
	check(tutorial.current_id()=="tutorial_order","pointer harvest and sale advance tutorial")
	await click("Close")
	var camera:=current_scene.get_node("CameraRig/Camera3D") as Camera3D
	await tap(camera.unproject_position(GardenLayout.plot_position(0)))
	await click("Harvest monster plant")
	await click("Orders")
	await click("Fulfil delivery")
	check(tutorial.current_id()=="tutorial_breed","first order reached through real UI")
	await click("Build · 65 coins")
	check(root.get_node("Breeding").bench_owned,"bench built with earned level and coins")
	await click("Close")
	premium.finish(1)
	await tap(camera.unproject_position(GardenLayout.plot_position(1)))
	await click("Harvest monster plant")
	await click("Breed")
	var options: Array[Node]=hud._modal_body.find_children("*","OptionButton",true,false)
	for option: Node in options:
		var select:=option as OptionButton
		select.select(select.item_count-1)
	await click("Graft a seed")
	check(tutorial.completed and root.get_node("Inventory").seeds.size()>0,"entire tutorial completes with a gene-carrying seed")
	print("RESULT: %d UI flow checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
