extends Node
signal plot_changed(index: int)
signal selection_changed(index: int)
signal restored
const PLOT_COUNT := 16
const SAVE_MODULES := {"unlocks":"UnlockManager"}
var plots: Array[Dictionary] = []
var selected_plot: int = 0
var discovered: Array[String] = []
var offline_message: String = ""
var _loaded := false
var _autosave: Timer

func _ready() -> void:
	# Defer until all autoloads, including the order system, exist.
	call_deferred("start_session")

func now() -> float:
	# Whole UTC seconds are stable across JSON implementations and devices.
	return floorf(Time.get_unix_time_from_system())

func empty_plot(unlocked: bool) -> Dictionary:
	return {"unlocked": unlocked, "species_id": "", "planted_at": 0.0, "ready_at": 0.0, "genes": {}}

func start_session() -> void:
	var payload := SaveManager.load_data()
	if payload.is_empty():
		for i: int in PLOT_COUNT:
			plots.append(empty_plot(i < 6))
		# A mature starter gives the player something to touch immediately.
		plots[0] = _plant_data("witness_bud", now() - 31.0)
		plots[1] = _plant_data("murmur_cap", now() - 10.0)
		discovered.assign(["witness_bud", "murmur_cap"])
	else:
		_restore(payload)
	for key: String in SAVE_MODULES:
		get_node("/root/" + SAVE_MODULES[key]).restore(payload.get(key, {}))
	BuyerOrders.restore(payload.get("orders", {}))
	_loaded = true
	LevelXP.leveled_up.connect(_on_level_up)
	_autosave = Timer.new()
	_autosave.wait_time = 15
	_autosave.timeout.connect(persist)
	add_child(_autosave)
	_autosave.start()
	restored.emit()
	persist()
	if SaveManager.write_blocked:
		Events.toast_requested.emit("Save could not be loaded. Original files are protected; saving is disabled.")

func _plant_data(id: String, planted_at: float) -> Dictionary:
	var entry := Catalog.get_species(id)
	return {"unlocked": true, "species_id": id, "planted_at": planted_at,
		"ready_at": planted_at + float(entry.grow_seconds), "genes": Inventory.normalize_genes(entry.genes)}

func select_plot(index: int) -> void:
	if index >= 0 and index < plots.size():
		selected_plot = index
		selection_changed.emit(index)

func plant(index: int, id: String) -> bool:
	if index < 0 or index >= plots.size() or not Catalog.is_available(id, LevelXP.level):
		return false
	if not bool(plots[index].unlocked) or plots[index].species_id != "":
		return false
	var entry := Catalog.get_species(id)
	if not Economy.spend(int(entry.seed_cost)):
		Events.toast_requested.emit("Not enough coins for this seed.")
		return false
	plots[index] = _plant_data(id, now())
	plot_changed.emit(index)
	Events.crop_planted.emit(index, id)
	Events.toast_requested.emit("%s is taking root." % entry.name)
	persist()
	return true

func progress(index: int) -> float:
	var plot := plots[index]
	if plot.species_id == "":
		return 0.0
	var duration := maxf(1.0, float(plot.ready_at) - float(plot.planted_at))
	return clampf((now() - float(plot.planted_at)) / duration, 0.0, 1.0)

func remaining(index: int) -> int:
	return maxi(0, int(ceil(float(plots[index].ready_at) - now())))

func harvest(index: int) -> bool:
	if index < 0 or index >= plots.size() or plots[index].species_id == "" or progress(index) < 1.0:
		return false
	var plot := plots[index].duplicate(true)
	var entry := Catalog.get_species(plot.species_id)
	plots[index] = empty_plot(true)
	Inventory.add_crop(plot.species_id, plot.genes, int(entry.yield))
	LevelXP.add_xp(int(entry.xp))
	if not discovered.has(plot.species_id):
		discovered.append(plot.species_id)
		Events.species_discovered.emit(plot.species_id)
	plot_changed.emit(index)
	Events.crop_harvested.emit(plot.species_id, int(entry.yield), plot.genes.duplicate(true))
	Events.toast_requested.emit("+%d %s · +%d XP" % [entry.yield, entry.name, entry.xp])
	persist()
	return true

func plot_unlock_level(index: int) -> int:
	return 2 + maxi(0, index - 6) / 2

func plot_unlock_cost(index: int) -> int:
	return 35 + maxi(0, index - 6) * 15

func unlock_plot(index: int) -> bool:
	if index < 0 or index >= plots.size() or plots[index].unlocked:
		return false
	if LevelXP.level < plot_unlock_level(index) or not Economy.spend(plot_unlock_cost(index)):
		return false
	plots[index].unlocked = true
	plot_changed.emit(index)
	persist()
	return true

func _on_level_up(level: int) -> void:
	Economy.earn(25)
	Events.toast_requested.emit("LEVEL %d · +25 coins · new seeds await" % level)

func snapshot() -> Dictionary:
	var result := {"catalog_version": 3, "plots": plots.duplicate(true), "inventory": Inventory.snapshot(), "coins": Economy.coins,
		"progression": LevelXP.snapshot(), "discovered": discovered.duplicate(), "orders": BuyerOrders.snapshot(),
		"last_seen": now()}
	for key: String in SAVE_MODULES:
		result[key] = get_node("/root/" + SAVE_MODULES[key]).snapshot()
	return result

func persist() -> void:
	if _loaded and not SaveManager.save_data(snapshot()):
		push_warning("Garden could not be saved")

func _restore(payload: Dictionary) -> void:
	LevelXP.restore(payload.get("progression", {}))
	Economy.coins = maxi(0, int(payload.get("coins", 120)))
	Inventory.restore(payload.get("inventory", []))
	discovered.assign(payload.get("discovered", []))
	var stored: Array = payload.get("plots", [])
	var completed := 0
	for i: int in PLOT_COUNT:
		var plot := empty_plot(i < 6)
		if i < stored.size() and stored[i] is Dictionary:
			var entry := stored[i] as Dictionary
			plot.merge(entry, true)
			if plot.species_id != "" and not Catalog.species.has(plot.species_id):
				# Preserve the source file rather than silently deleting unknown species.
				SaveManager.write_blocked = true
				plot = empty_plot(bool(plot.unlocked))
			elif plot.species_id != "":
				plot.genes = Inventory.normalize_genes(plot.get("genes", Catalog.get_species(plot.species_id).genes))
				if float(plot.ready_at) > float(payload.get("last_seen", now())) and float(plot.ready_at) <= now():
					completed += 1
		plots.append(plot)
	if completed > 0:
		offline_message = "%d monster plants finished growing while you were away." % completed

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		persist()
	elif what == NOTIFICATION_APPLICATION_RESUMED and _loaded:
		for i: int in plots.size():
			plot_changed.emit(i)
		BuyerOrders.refresh()
