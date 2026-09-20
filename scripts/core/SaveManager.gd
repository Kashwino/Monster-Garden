extends Node
## Only persistence interface: save_data(payload) and load_data().
## Backend seam: a future cloud adapter must keep local durability first.
const VERSION := 2
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
	return migrated
