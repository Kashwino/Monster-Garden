extends Node

const PATH := "res://data/catalog.json"
const STAGES := ["seed", "sprout", "juvenile", "mature", "blooming"]
var species: Dictionary = {}
var families: Dictionary = {}
var events: Dictionary = {}
var errors: PackedStringArray = []

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		push_error("Catalog must be a JSON object")
		return
	var data := parsed as Dictionary
	families = data.get("families", {})
	events = data.get("events", {})
	for value: Variant in data.get("species", []):
		if not value is Dictionary:
			errors.append("Species must be objects")
			continue
		var entry := value as Dictionary
		var id := String(entry.get("id", ""))
		if id.is_empty() or species.has(id):
			errors.append("Missing or duplicate species id: " + id)
			continue
		if not families.has(entry.get("family", "")):
			errors.append("Unknown family: " + id)
		if not entry.has("unlock") or not entry.has("genes") or not entry.has("mesh"):
			errors.append("Missing unlock, genes or mesh: " + id)
		var unlock: Dictionary = entry.get("unlock", {})
		if unlock.size() != 2 or not unlock.has("value") or not unlock.get("type", "") in ["level", "event"]:
			errors.append("Exactly one valid unlock source required: " + id)
		elif unlock.type == "event" and not events.has(unlock.value):
			errors.append("Unknown event unlock: " + id)
		if not entry.get("rarity", "") in ["Common", "Uncommon", "Rare", "Exotic", "Mythic"]:
			errors.append("Invalid rarity: " + id)
		for key: String in ["grow_seconds", "yield", "sell_value", "seed_cost", "xp"]:
			if float(entry.get(key, 0)) <= 0:
				errors.append("Invalid " + key + ": " + id)
		species[id] = entry
	for error: String in errors:
		push_error(error)

func get_species(id: String) -> Dictionary:
	return species.get(id, {})

func is_available(id: String, level: int) -> bool:
	return UnlockManager.is_available(id, level)

func stage_for(progress: float) -> String:
	if progress >= 1.0:
		return "blooming"
	if progress >= 0.75:
		return "mature"
	if progress >= 0.4:
		return "juvenile"
	if progress >= 0.12:
		return "sprout"
	return "seed"
