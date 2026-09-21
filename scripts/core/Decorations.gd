extends Node
signal changed
var catalog: Dictionary={}
var storage: Dictionary={}
var placements: Dictionary={}
func _ready() -> void:
	var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/decorations.json")) as Array
	for entry: Dictionary in rows: catalog[entry.id]=entry
func can_buy(id: String) -> bool:
	return catalog.has(id) and LevelXP.level>=int(catalog[id].level) and Economy.coins>=int(catalog[id].cost)
func buy(id: String) -> bool:
	if not can_buy(id) or not Economy.spend(int(catalog[id].cost)): return false
	storage[id]=int(storage.get(id,0))+1
	Events.purchase_made.emit(id,"coins",int(catalog[id].cost))
	changed.emit();Game.persist();return true
func place(id: String, slot: int, rotation: int=0) -> bool:
	if not catalog.has(id) or LevelXP.level<int(catalog[id].level) or int(storage.get(id,0))<=0: return false
	if slot<0 or slot>=GardenLayout.DECOR_SLOTS.size() or placements.has(str(slot)): return false
	storage[id]=int(storage[id])-1
	placements[str(slot)]={"id":id,"rotation":posmod(rotation,4)}
	Events.decoration_placed.emit(id)
	changed.emit();Game.persist();return true
func remove(slot: int) -> bool:
	if not placements.has(str(slot)): return false
	var id:=String(placements[str(slot)].id)
	storage[id]=int(storage.get(id,0))+1
	placements.erase(str(slot))
	changed.emit();Game.persist();return true
func move(from: int, to: int) -> bool:
	if from==to or not placements.has(str(from)) or placements.has(str(to)) or to<0 or to>=GardenLayout.DECOR_SLOTS.size(): return false
	placements[str(to)]=placements[str(from)].duplicate(true)
	placements.erase(str(from));changed.emit();Game.persist();return true
func first_free_slot() -> int:
	for i: int in GardenLayout.DECOR_SLOTS.size():
		if not placements.has(str(i)): return i
	return -1
func snapshot() -> Dictionary:
	return {"storage":storage.duplicate(true),"placements":placements.duplicate(true)}
func restore(data: Dictionary) -> void:
	storage=data.get("storage",{}).duplicate(true)
	placements=data.get("placements",{}).duplicate(true)
	changed.emit()
