extends SceneTree
## Integration tests isolate their save path before the deferred session starts.
var _failures: int = 0
var _checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func _run() -> void:
	var catalog := root.get_node("Catalog")
	var game := root.get_node("Game")
	var economy := root.get_node("Economy")
	var inventory := root.get_node("Inventory")
	var saves := root.get_node("SaveManager")
	var orders := root.get_node("BuyerOrders")
	var level := root.get_node("LevelXP")
	# Autoload ready has run, Game's deferred start may have run. Redirect all writes.
	saves.save_path = "user://integration-test.json"
	saves.write_blocked = false
	await process_frame
	check(catalog.errors.is_empty(), "catalog validation")
	check(catalog.species.size() == 12, "twelve authored species")
	game.plots.clear()
	for i: int in 16:
		game.plots.append(game.empty_plot(i < 6))
	inventory.stacks.clear()
	economy.coins = 120
	level.restore({"level": 1, "xp": 0})
	check(game.plant(0, "witness_bud"), "plant an available species")
	check(economy.coins == 114, "plant charges catalog cost once")
	check(not game.plant(0, "witness_bud"), "occupied plot rejects planting")
	check(not game.harvest(0), "growing plant cannot be harvested")
	check(not game.plant(1, "echo_obelisk"), "level lock enforced outside UI")
	game.plots[0].planted_at = game.now() - 31
	game.plots[0].ready_at = game.now() - 1
	check(game.harvest(0), "timestamp completion allows harvest")
	check(not game.harvest(0), "double harvest rejected")
	check(inventory.count_species("witness_bud") == 2, "harvest adds catalog yield")
	check(inventory.stacks[0].genes == inventory.normalize_genes(catalog.get_species("witness_bud").genes), "harvest preserves instance genes")
	var different: Dictionary = catalog.get_species("witness_bud").genes.duplicate()
	different.hue = 0.95
	inventory.add_crop("witness_bud", different, 1)
	check(inventory.stacks.size() == 2, "different genes form separate stacks")
	check(not inventory.remove_species("witness_bud", 4), "insufficient removal is atomic")
	check(inventory.count_species("witness_bud") == 3, "failed removal preserves counts")
	check(economy.sell("witness_bud", 1), "sell one crop")
	check(economy.coins == 122, "sell reward from catalog")
	orders.active = {"id":"test", "species_id":"witness_bud", "quantity":2, "coins":32, "xp":14, "expires_at":game.now()+60}
	check(orders.fulfill(), "courier consumes crops and awards reward")
	check(inventory.count_species("witness_bud") == 0, "order consumes exact quantity across gene stacks")
	check(not orders.fulfill(), "double delivery rejected")
	check(economy.coins == 154, "order reward granted once")
	game.plant(2, "murmur_cap")
	var payload: Dictionary = game.snapshot()
	check(saves.save_data(payload), "atomic save write")
	var loaded: Dictionary = saves.load_data()
	check(loaded.plots[2].ready_at == payload.plots[2].ready_at, "ready timestamp survives save/load exactly")
	check(loaded.coins == payload.coins, "currency survives save/load")
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy_v0.json"))
	var file := FileAccess.open(saves.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture))
	file.close()
	loaded = saves.load_data()
	check(int(loaded.schema_version) == int(saves.VERSION), "legacy save migrated to current version")
	inventory.restore(loaded.inventory)
	check(inventory.count_species("witness_bud") == 7, "legacy flat counts preserved")
	check(not inventory.stacks[0].genes.is_empty(), "legacy inventory gets default genes")
	# Newer saves must never be overwritten by an older client.
	file = FileAccess.open(saves.save_path, FileAccess.WRITE)
	file.store_string('{"schema_version":999,"coins":98765}')
	file.close()
	check(saves.load_data().is_empty() and saves.write_blocked, "future version protects source save")
	check(not saves.save_data(payload), "write protection enforced")
	saves.write_blocked = false
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(saves.save_path + suffix):
			DirAccess.remove_absolute(saves.save_path + suffix)
	print("RESULT: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)
