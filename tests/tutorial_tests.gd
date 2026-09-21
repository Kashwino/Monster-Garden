extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error("FAIL: "+message)
func run() -> void:
	await process_frame
	var tutorial:=root.get_node("Tutorial")
	var game:=root.get_node("Game")
	var quests:=root.get_node("QuestManager")
	var events:=root.get_node("Events")
	var inventory:=root.get_node("Inventory")
	quests.restore({});tutorial.restore({});tutorial._resume()
	root.get_node("Economy").coins=1000
	game.plots[2]=game.empty_plot(true)
	check(tutorial.current_id()=="tutorial_plant","new garden begins at planting")
	check(game.plant(2,"witness_bud"),"tutorial seed can be planted")
	await process_frame
	check(tutorial.current_id()=="tutorial_wait" and tutorial.target_plot==2,"plant event advances and remembers actual plot")
	events.plot_ready.emit(1)
	await process_frame
	check(tutorial.current_id()=="tutorial_wait","another crop cannot complete the wait step")
	game.plots[2].ready_at=game.now()-1
	tutorial.restore(tutorial.snapshot());tutorial._resume()
	await process_frame
	check(tutorial.current_id()=="tutorial_harvest","resume recognizes a crop that finished offline")
	game.harvest(2)
	await process_frame
	check(tutorial.current_id()=="tutorial_sell","harvest advances to sale")
	root.get_node("Economy").sell("witness_bud",1)
	await process_frame
	check(tutorial.current_id()=="tutorial_order","sale advances to delivery")
	quests.record("order",1)
	await process_frame
	check(tutorial.current_id()=="tutorial_breed","delivery advances to breeding")
	quests.record("breed",1)
	await process_frame
	check(tutorial.completed and quests.tutorial_active_id=="","all six steps complete once")
	tutorial.restore(tutorial.snapshot());tutorial._resume()
	check(tutorial.completed,"completed tutorial never replays")
	tutorial.restore({});tutorial.skip()
	check(tutorial.completed and tutorial.skipped,"skip is saved")
	print("RESULT: %d tutorial checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
