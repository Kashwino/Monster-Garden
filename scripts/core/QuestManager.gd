extends Node
signal changed
signal objective_completed(id: String)
var definitions: Dictionary = {}
var progress: Dictionary = {}
var claimed: Array[String] = []
var daily_ids: Array[String] = []
var utc_date := ""
var tutorial_active_id := ""
var _midnight: Timer

func _ready() -> void:
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json")) as Array
	for row: Dictionary in rows:
		definitions[row.id] = row
	Events.crop_harvested.connect(func(id: String, n: int, _genes: Dictionary) -> void: record("harvest", n, id))
	Events.crop_planted.connect(func(_i: int, id: String) -> void: record("plant", 1, id))
	Events.crop_sold.connect(func(id: String, n: int, _coins: int) -> void: record("sell", n, id))
	Events.order_fulfilled.connect(func(_id: String) -> void: record("order", 1))
	Events.bred.connect(func(id: String, fresh: bool) -> void:
		record("breed", 1, id)
		if fresh: record("breed_new", 1, id))
	Events.species_discovered.connect(func(id: String) -> void: record("discover", 1, id))
	Events.decoration_placed.connect(func(id: String) -> void: record("decoration", 1, id))
	Events.plot_ready.connect(func(_i: int) -> void: record("ready", 1))
	LevelXP.leveled_up.connect(func(level: int) -> void: record("level", level))
	_midnight = Timer.new()
	_midnight.one_shot = true
	_midnight.timeout.connect(func() -> void: reconcile(); Game.persist())
	add_child(_midnight)

func is_active(id: String) -> bool:
	var q: Dictionary = definitions.get(id, {})
	if q.is_empty() or claimed.has(id) or LevelXP.level < int(q.unlock_level): return false
	if bool(q.get("is_tutorial", false)): return id == tutorial_active_id
	if bool(q.get("daily", false)): return daily_ids.has(id)
	return String(q.after).is_empty() or claimed.has(String(q.after))

func active_quests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in definitions:
		if is_active(id) and not bool(definitions[id].is_tutorial): result.append(definitions[id])
	return result

func record(kind: String, amount: int, target: String = "") -> void:
	for id: String in definitions:
		if not is_active(id): continue
		var objective: Dictionary = definitions[id].objective
		if objective.type != kind or (String(objective.target) != "" and objective.target != target): continue
		var previous := int(progress.get(id, 0))
		progress[id] = mini(int(objective.count), maxi(previous, amount) if kind == "level" else previous+amount)
		if previous < int(objective.count) and int(progress[id]) >= int(objective.count): objective_completed.emit(id)
	changed.emit()

func can_claim(id: String) -> bool:
	return is_active(id) and int(progress.get(id, 0)) >= int(definitions[id].objective.count)

func claim(id: String) -> bool:
	if not can_claim(id): return false
	claimed.append(id) # Set before rewards/signals so re-entrant claims cannot duplicate grants.
	var reward: Dictionary = definitions[id].reward
	Economy.earn(int(reward.get("coins", 0)))
	LevelXP.add_xp(int(reward.get("xp", 0)))
	var seeds: Dictionary = reward.get("seeds", {})
	for species_id: String in seeds:
		Inventory.add_seed(species_id, Catalog.get_species(species_id).genes, int(seeds[species_id]))
	var premium := get_node_or_null("/root/Premium")
	if premium != null: premium.earn(int(reward.get("gems", 0)))
	Events.quest_claimed.emit(id)
	record("level", LevelXP.level)
	changed.emit()
	Game.persist()
	return true

func reconcile(at: float = -1) -> void:
	var now := Game.now() if at < 0 else at
	var date := Time.get_date_string_from_unix_time(int(now))
	# Never roll back a daily rotation if the device clock moves backwards.
	if date > utc_date:
		for id: String in definitions:
			if bool(definitions[id].get("daily", false)):
				progress.erase(id)
				claimed.erase(id)
		utc_date = date
		var pool: Array[String] = []
		for id: String in definitions:
			if bool(definitions[id].get("daily", false)) and LevelXP.level >= int(definitions[id].unlock_level): pool.append(id)
		var generator := RandomNumberGenerator.new()
		generator.seed = date.hash()
		daily_ids.clear()
		while daily_ids.size() < 3 and not pool.is_empty():
			var index := generator.randi_range(0, pool.size()-1)
			daily_ids.append(pool[index]); pool.remove_at(index)
		changed.emit()
	record("level", LevelXP.level)
	_midnight.start(maxf(1, 86400-fposmod(now,86400)))

func snapshot() -> Dictionary:
	return {"progress":progress.duplicate(true), "claimed":claimed.duplicate(), "daily_ids":daily_ids.duplicate(), "utc_date":utc_date}
func restore(data: Dictionary) -> void:
	progress = data.get("progress", {}).duplicate(true)
	claimed.assign(data.get("claimed", []))
	daily_ids.assign(data.get("daily_ids", []))
	utc_date = String(data.get("utc_date", ""))
	reconcile()
