extends Node
## Only persistence interface: save_data(payload) and load_data().
## Backend seam: a future cloud adapter must keep local durability first.
const VERSION := 9
var save_path: String = OS.get_environment("MONSTER_GARDEN_SAVE_PATH") if OS.has_environment("MONSTER_GARDEN_SAVE_PATH") else "user://garden.json"
var write_blocked: bool = false
signal cloud_loaded(payload: Dictionary)
const Conflict=preload("res://scripts/services/SaveConflict.gd")
var backend: Node
var _cache: Dictionary={}
var _digest:=""
func _ready() -> void:
	backend=Node.new()
	backend.set_script(preload("res://scripts/services/FirebaseBackend.gd"))
	add_child(backend)
	backend.supported_version=VERSION
	backend.data_ready.connect(_accept_cloud)
	backend.state_changed.connect(_store_cloud_state)


func save_data(payload: Dictionary) -> bool:
	if write_blocked:
		return false
	var data := payload.duplicate(true)
	data["schema_version"] = VERSION
	var digest:=Conflict.fingerprint(data)
	data["last_modified"] = int(_cache.get("last_modified",0)) if digest==_digest else maxi(int(Time.get_unix_time_from_system()*1000),int(_cache.get("last_modified",0))+1)
	data["cloud_state"]=backend.state()
	if not _write_local(data): return false
	_cache=data.duplicate(true);_digest=digest
	backend.queue_sync(data)
	return true

func _write_local(data: Dictionary) -> bool:
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
		var migrated:=_migrate(data)
		_cache=migrated.duplicate(true);_digest=Conflict.fingerprint(migrated)
		backend.restore(migrated.get("cloud_state",{}))
		backend.queue_sync(migrated)
		return migrated
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
	if int(migrated.schema_version)<9:
		migrated["cloud_state"]={"auth":{},"choices":{}}
		migrated["last_modified"]=int(migrated.get("last_modified",0))*1000
		migrated["schema_version"]=9
	return migrated

func _accept_cloud(payload: Dictionary) -> void:
	if write_blocked or not payload.get("plots") is Array or not payload.get("inventory") is Array or not payload.get("progression") is Dictionary: return
	if int(_cache.get("last_modified",0))>int(payload.get("last_modified",0)): return
	var data:=_migrate(payload)
	data["cloud_state"]=backend.state()
	if not _write_local(data): return
	_cache=data.duplicate(true);_digest=Conflict.fingerprint(data)
	cloud_loaded.emit(data)
func _store_cloud_state() -> void:
	if not _cache.is_empty() and not write_blocked:
		_cache["cloud_state"]=backend.state()
		_write_local(_cache)
