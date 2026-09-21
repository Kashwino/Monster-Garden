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
