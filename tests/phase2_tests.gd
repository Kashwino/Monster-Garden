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
