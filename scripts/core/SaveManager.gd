extends Node
## Only persistence interface: save_data(payload) and load_data().
## Backend seam: a future cloud adapter must keep local durability first.
const VERSION := 8
var save_path: String = OS.get_environment("MONSTER_GARDEN_SAVE_PATH") if OS.has_environment("MONSTER_GARDEN_SAVE_PATH") else "user://garden.json"
var write_blocked: bool = false

func save_data(payload: Dictionary) -> bool:
	if write_blocked:
		return false
	var data := payload.duplicate(true)
	data["schema_version"] = VERSION
	data["last_modified"] = int(Time.get_unix_time_from_system())
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write garden save")
		return false
	file.store_string(JSON.stringify(data, "\t", true, true))
	file.flush()
	file.close()
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, save_path + ".bak")
	return DirAccess.rename_absolute(temporary, save_path) == OK

func load_data() -> Dictionary:
	write_blocked = false
	for path: String in [save_path, save_path + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			continue
		var data := parsed as Dictionary
		if int(data.get("schema_version", 0)) > VERSION:
			write_blocked = true
			push_error("Save is from a newer version; writing disabled to protect it")
			return {}
		return _migrate(data)
	if FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak"):
		write_blocked = true
		push_error("Both saves unreadable; writing disabled to preserve recovery files")
	return {}

func _migrate(data: Dictionary) -> Dictionary:
	var migrated := data.duplicate(true)
	if int(migrated.get("schema_version", 0)) < 1:
		# Legacy flat inventory converts into gene-aware stacks without losing counts.
		var inventory: Variant = migrated.get("inventory", [])
		if inventory is Dictionary:
			var flat := inventory as Dictionary
			var stacks: Array = []
			for id: String in flat:
				stacks.append({"species_id": id, "quantity": int(flat[id]), "genes": Catalog.get_species(id).get("genes", {})})
			migrated["inventory"] = stacks
		migrated["schema_version"] = 1
	if int(migrated.get("schema_version", 0)) < 2:
		# V2 records the catalogue revision, not derived model paths/stages.
		migrated["catalog_version"] = 2
		migrated["schema_version"] = 2
	if int(migrated.schema_version) < 3:
		migrated["unlocks"] = {"granted":[], "drift":{}, "next_drift_at":0}
		migrated["catalog_version"] = 3
		migrated["schema_version"] = 3
	if int(migrated.schema_version) < 4:
		migrated["seeds"] = []
		migrated["breeding"] = {"bench_owned":false, "total_bred":0, "last_result":{}}
		migrated["schema_version"] = 4
	if int(migrated.schema_version) < 5:
		migrated["quests"] = {}
		migrated["schema_version"] = 5
	if int(migrated.schema_version) < 6:
		var old: Dictionary=migrated.get("orders",{})
		if not old.has("slots"):
			migrated["orders"]={"slots":[{"order":old.get("active",{}),"refill_at":old.get("next_at",0),"reroll_at":0}],"fulfilled":old.get("fulfilled",0),"reputation":0,"serial":0}
		migrated["schema_version"]=6
	if int(migrated.schema_version)<7:
		migrated["clock"]={"last_active":migrated.get("last_seen",0),"announced":[]}
		migrated["notifications"]={"enabled":false,"scheduled_at":0}
		migrated["schema_version"]=7
	if int(migrated.schema_version)<8:
		migrated["premium"]={"gems":0,"fertiliser":2}
		migrated["schema_version"]=8
	return migrated
