extends Node
func _ready() -> void:
	Events.species_discovered.connect(_reward)
func _reward(id: String) -> void:
	var entry := Catalog.get_species(id)
	Economy.earn(20 + int(entry.seed_cost) / 2)
	LevelXP.add_xp(10 + int(entry.xp) / 2)
