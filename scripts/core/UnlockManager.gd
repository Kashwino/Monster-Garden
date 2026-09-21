extends Node
## Single availability authority for seeds, codex and breeding.
signal changed
var granted: Array[String] = []
var drift: Dictionary = {}
var next_drift_at: float = 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	LevelXP.leveled_up.connect(func(_level: int) -> void: changed.emit())
	Events.reputation_changed.connect(_reputation)
	Events.quest_claimed.connect(_quest)

func is_available(id: String, level_override: int = -1) -> bool:
	var species := Catalog.get_species(id)
	if species.is_empty():
		return false
	var unlock: Dictionary = species.unlock
	if unlock.type == "level":
		return (LevelXP.level if level_override < 0 else level_override) >= int(unlock.value)
	return granted.has(String(unlock.value))

func grant(event_id: String) -> bool:
	if granted.has(event_id) or not Catalog.events.has(event_id):
		return false
	granted.append(event_id)
	changed.emit()
	return true

func unlock_text(id: String) -> String:
	var unlock: Dictionary = Catalog.get_species(id).get("unlock", {})
	if unlock.get("type") == "level":
		return "Keeper level %d" % int(unlock.value)
	return String(Catalog.events.get(unlock.get("value", ""), {}).get("label", "Undiscovered event"))

func available_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in Catalog.species:
		if is_available(id):
			ids.append(id)
	return ids

func season_active(event_id: String, at: float = -1) -> bool:
	var event: Dictionary = Catalog.events.get(event_id, {})
	if event.get("kind") != "season":
		return false
	var date := Time.get_date_string_from_unix_time(int(Game.now() if at < 0 else at))
	return date >= String(event.start) and date < String(event.end)

func claim_season(event_id: String) -> bool:
	if not season_active(event_id) or not grant(event_id):
		return false
	Game.persist()
	return true

func refresh(at: float = -1) -> void:
	var now := Game.now() if at < 0 else at
	if not drift.is_empty() and float(drift.expires_at) <= now:
		drift = {}
		changed.emit()
	if next_drift_at <= 0:
		next_drift_at = now + 21600
	elif now >= next_drift_at:
		next_drift_at = now + 21600
		var options: Array[String] = []
		for id: String in Catalog.events:
			if Catalog.events[id].kind == "drift" and not granted.has(id):
				options.append(id)
		if not options.is_empty() and rng.randf() < 0.25:
			drift = {"event_id":options[rng.randi_range(0, options.size()-1)], "expires_at":now+1800}
			changed.emit()

func claim_drift() -> bool:
	if drift.is_empty() or float(drift.expires_at) <= Game.now():
		return false
	if not grant(drift.event_id):
		return false
	drift = {}
	Game.persist()
	return true

func _reputation(value: int) -> void:
	for id: String in Catalog.events:
		var event: Dictionary = Catalog.events[id]
		if event.kind == "reputation" and value >= int(event.threshold):
			grant(id)

func _quest(id: String) -> void:
	for event_id: String in Catalog.events:
		var event: Dictionary = Catalog.events[event_id]
		if event.kind == "quest" and event.quest_id == id:
			grant(event_id)

func snapshot() -> Dictionary:
	return {"granted":granted.duplicate(), "drift":drift.duplicate(true), "next_drift_at":next_drift_at}

func restore(data: Dictionary) -> void:
	granted.assign(data.get("granted", []))
	drift = data.get("drift", {}).duplicate(true)
	next_drift_at = float(data.get("next_drift_at", 0))
	refresh()
