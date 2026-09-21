extends SceneTree
var failures:=0
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error("FAIL: "+message)
func run() -> void:
	await process_frame
	var settings:=root.get_node("Settings")
	var audio:=root.get_node("AudioManager")
	var game:=root.get_node("Game")
	var save:=root.get_node("SaveManager")
	settings.set_graphics(false,.5);audio.set_volume("SFX",0)
	game.persist()
	var data: Dictionary=save.load_data()
	check(not data.settings.shadows and data.settings.particle_density==.5,"graphics preferences persisted")
	check(data.audio.SFX==0 and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"volume zero actually mutes its audio bus")
	var stamp: int=data.last_modified
	game.reset_garden()
	var owned:=0
	for plot: Dictionary in game.plots:
		if plot.unlocked: owned+=1
	check(owned==6 and game.plots.size()==24,"reset starts with exactly six owned plots out of 24")
	check(root.get_node("Inventory").stacks.is_empty() and root.get_node("Decorations").placements.is_empty(),"reset clears inventory and decorations")
	check(root.get_node("Economy").coins==120 and root.get_node("Premium").gems==5,"reset restores starter currencies")
	check(not root.get_node("Tutorial").completed,"intentional reset enables onboarding")
	data=save.load_data()
	check(int(data.last_modified)>stamp and int(data.schema_version)==12,"reset is a newer versioned save through the existing interface")
	print("RESULT: %d settings checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
