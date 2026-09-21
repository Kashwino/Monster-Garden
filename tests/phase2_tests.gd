extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
func run() -> void:
	await process_frame
	var catalog := root.get_node("Catalog")
	var unlock := root.get_node("UnlockManager")
	var save := root.get_node("SaveManager")
	var game := root.get_node("Game")
	unlock.granted.clear()
	check(catalog.species.size() == 120 and catalog.families.size() == 10, "120 species / ten families")
	check(catalog.errors.is_empty(), "catalog references and unlocks validate")
	var level_count := 0
	for id: String in catalog.species:
		var entry: Dictionary = catalog.species[id]
		if entry.unlock.type == "level":
			level_count += 1
		else:
			check(not unlock.is_available(id), "event locked by default: " + id)
	check(level_count == 90, "majority use levels")
	check(unlock.grant("discover_many_eyed_oracle"), "event grant succeeds")
	check(unlock.is_available("many_eyed_oracle"), "single availability resolver sees grant")
	check(not unlock.grant("discover_many_eyed_oracle"), "duplicate unlock is idempotent")
	unlock.granted.clear()
	var breeding := root.get_node("Breeding")
	var inventory := root.get_node("Inventory")
	var economy := root.get_node("Economy")
	var level := root.get_node("LevelXP")
	inventory.stacks.clear()
	inventory.seeds.clear()
	breeding.bench_owned = true
	var genes: Dictionary = inventory.normalize_genes({"hue":.98,"glow":.8,"scale":1.1,"appendages":4})
	inventory.add_crop("witness_bud", genes, 1)
	var key: String = inventory.stack_key("witness_bud", genes)
	check(not breeding.can_breed(key,key), "same stack requires two units")
	check(breeding.combine(key,key).is_empty() and inventory.count_species("witness_bud")==1, "failed breed consumes nothing")
	inventory.add_crop("witness_bud", genes, 1)
	var original_recipes: Array = breeding.recipes.duplicate(true)
	breeding.recipes[0].chance = 1.0
	var result: Dictionary = breeding.combine(key,key)
	check(not result.is_empty() and inventory.count_species("witness_bud")==0, "breeding consumes exactly two units")
	check(inventory.seeds.size()==1 and inventory.seeds[0].genes==result.genes, "offspring seed retains genes")
	check(result.species_id=="many_eyed_oracle" and unlock.is_available(result.species_id), "rare gene recipe discovers and unlocks a species")
	var coins_before: int = economy.coins
	check(not game.discover(result.species_id) and economy.coins==coins_before, "discovery reward only once")
	game.plots[2]=game.empty_plot(true)
	check(game.plant_seed(2,inventory.seeds[0].key), "bred seed plants without another purchase")
	check(game.plots[2].genes==result.genes, "planted offspring retains genes")
	breeding.recipes=original_recipes
	var quests := root.get_node("QuestManager")
	quests.restore({})
	check(quests.daily_ids.size()==3, "exactly three UTC daily goals")
	quests.record("harvest", 2, "witness_bud")
	check(quests.can_claim("keeper_harvest"), "harvest signal objective becomes claimable")
	check(quests.claim("keeper_harvest") and not quests.claim("keeper_harvest"), "quest rewards can only be claimed once")
	quests.record("order",1)
	check(quests.can_claim("keeper_orders"), "quest chain unlocks its successor")
	quests.claim("keeper_orders")
	var old_date: String=quests.utc_date
	quests.reconcile(game.now()+86400)
	check(quests.utc_date>old_date and quests.daily_ids.size()==3, "daily goals rotate on next UTC date")
	check(quests.claimed.has("keeper_harvest"), "daily rotation preserves progression claims")
	quests.reconcile(game.now())
	check(quests.utc_date>old_date, "clock rollback cannot reclaim yesterday’s daily rewards")
	var orders := root.get_node("BuyerOrders")
	orders.restore({})
	check(orders.slots.size()==3, "three simultaneous order slots")
	orders.reputation=30
	economy.coins=1000
	check(orders.reroll(2) and orders.slots[2].order.type=="gene", "high reputation enables gene orders")
	check(orders.reroll(1) and orders.slots[1].order.type=="mixed", "second tier enables mixed orders")
	inventory.stacks.clear()
	var low: Dictionary=genes.duplicate(true);low.glow=.1
	inventory.add_crop("witness_bud",low,3)
	inventory.add_crop("witness_bud",genes,1)
	orders.slots[0].order={"id":"gene_test","type":"gene","requests":[{"family":"ocular","quantity":2,"min_glow":.45}],"coins":30,"xp":5,"expires_at":game.now()+60}
	check(not orders.can_fulfill(0), "gene orders reject low-glow substitutes")
	check(not orders.fulfill(0) and inventory.count_species("witness_bud")==4, "unsatisfied gene request consumes nothing")
	inventory.add_crop("witness_bud",genes,1)
	check(orders.fulfill(0) and inventory.count_species("witness_bud")==3, "gene order consumes only matching units")
	check(orders.reputation==33, "delivery raises reputation")
	orders.slots[0].order={"id":"expired","type":"simple","requests":[{"species_id":"witness_bud","quantity":1}],"coins":2,"xp":1,"expires_at":game.now()-1}
	orders.refresh()
	check(orders.slots[0].order.is_empty() and orders.reputation==32, "expiry vacates slot and lowers reputation")
	orders.refresh()
	check(orders.reputation==32, "expiry penalty is applied once")
	var clock := root.get_node("OfflineProgression")
	var notices := root.get_node("Notifications")
	game.plots[3]=game._plant_data("witness_bud",game.now()-100)
	clock.last_active=game.now()-80
	clock.reconcile()
	check(int(clock.last_summary.ready)>=1, "offline summary counts completed growth")
	clock.reconcile()
	check(int(clock.last_summary.ready)==0, "resume summary does not repeat completions")
	notices.enabled=true
	game.plots[4]=game._plant_data("witness_bud",game.now())
	game.plots[5]=game._plant_data("murmur_cap",game.now()+10)
	notices.schedule_pending()
	var latest:=0
	for plot: Dictionary in game.plots:
		if plot.species_id!="" and float(plot.ready_at)>game.now(): latest=maxi(latest,int(plot.ready_at))
	check(notices.scheduled_at==latest, "notification uses longest pending completion")
	check(not notices.supported(), "native notification is a no-op in editor")
	var premium:=root.get_node("Premium")
	premium.gems=100
	premium.fertiliser=2
	game.plots[4]=game._plant_data("witness_bud",game.now())
	var old_remaining: int=game.remaining(4)
	check(premium.apply_fertiliser(4), "fertiliser applies to a growing plot")
	check(game.remaining(4)<old_remaining and float(game.plots[4].mutation_bonus)>.0, "fertiliser reduces time and raises mutation probability")
	check(not premium.apply_fertiliser(4) and premium.fertiliser==1, "fertiliser cannot be stacked on the same crop")
	check(premium.finish(4) and game.progress(4)>=1, "gem instant finish completes growth")
	var gems_before: int=premium.gems
	check(not premium.finish(4) and premium.gems==gems_before, "finished crops do not charge gems again")
	level.level=1
	game.plots[6]=game.empty_plot(false)
	check(not game.unlock_plot(6,"gems") and premium.gems==gems_before, "gems never bypass plot level requirements")
	check(not game.unlock_plot(6,"coins"), "coins never bypass plot level requirements")
	level.level=game.plot_unlock_level(6)
	check(game.unlock_plot(6,"coins"), "plot requires level plus purchase")
	check(not root.get_node("IAPService").purchase("gems_small").ok, "IAP seam never pretends a purchase succeeded")
	var decor:=root.get_node("Decorations")
	decor.restore({});level.level=1;economy.coins=10000
	check(not decor.buy("keeper_castle") and economy.coins==10000, "decoration purchase enforces its level")
	check(decor.buy("spore_lamp") and economy.coins==9975, "decoration purchase charges exactly once")
	check(decor.place("spore_lamp",0) and not decor.place("spore_lamp",1), "placing consumes owned stock")
	check(decor.move(0,1) and decor.remove(1) and int(decor.storage.spore_lamp)==1, "move and storage preserve decoration ownership")
	decor.restore(decor.snapshot())
	check(int(decor.storage.spore_lamp)==1, "decoration state round trips")
	check(game.PLOT_COUNT==24, "garden has 24 reusable plot sites")
	# Reload all earlier schemas through the only save interface.
	for name: String in ["foundation_v1.json", "art_v2.json"]:
		var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+name)) as Dictionary
		save.save_path = "res://builds/migration-test.json"
		var file := FileAccess.open(save.save_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(original, "", true, true))
		file.close()
		var loaded: Dictionary = save.load_data()
		check(int(loaded.schema_version) == int(save.VERSION), "migration version: " + name)
		check(loaded.plots == original.plots and loaded.inventory == original.inventory and loaded.coins == original.coins, "old resources unchanged: " + name)
	check(save.save_data(game.snapshot()), "new payload saves")
	var payload: Dictionary = save.load_data()
	check(payload.has("unlocks"), "unlock state persists")
	print("RESULT: %d phase 2 checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
