extends Node
signal changed
var active: Dictionary = {}
var fulfilled: int = 0
var next_at: float = 0.0
var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(refresh)
	add_child(_timer)
	_timer.start()

func restore(data: Dictionary) -> void:
	active = data.get("active", {}).duplicate(true)
	fulfilled = int(data.get("fulfilled", 0))
	next_at = float(data.get("next_at", 0))
	refresh()

func refresh() -> void:
	if not active.is_empty() and float(active.expires_at) <= Game.now():
		# Cooldown is anchored to expiry, even after days offline.
		next_at = float(active.expires_at) + 30.0
		active = {}
		changed.emit()
	if active.is_empty() and Game.now() >= next_at:
		_generate()

func _generate() -> void:
	var available: Array[String] = []
	for id: String in Catalog.species:
		if Catalog.is_available(id, LevelXP.level):
			available.append(id)
	if available.is_empty():
		return
	var id := available[fulfilled % available.size()]
	var entry := Catalog.get_species(id)
	var quantity := int(entry.yield)
	active = {"id": "order_%d_%d" % [int(Game.now()), fulfilled], "species_id": id, "quantity": quantity,
		"coins": int(entry.sell_value) * quantity * 2, "xp": int(entry.xp) + 8, "expires_at": Game.now() + 900}
	changed.emit()

func can_fulfill() -> bool:
	return not active.is_empty() and float(active.expires_at) > Game.now() and Inventory.count_species(active.species_id) >= int(active.quantity)

func fulfill() -> bool:
	if not can_fulfill():
		return false
	var order := active.duplicate(true)
	if not Inventory.remove_species(order.species_id, int(order.quantity)):
		return false
	active = {}
	fulfilled += 1
	next_at = Game.now() + 5.0
	Economy.earn(int(order.coins))
	LevelXP.add_xp(int(order.xp))
	Events.order_fulfilled.emit(order.id)
	Events.toast_requested.emit("Delivery complete · +%d coins · +%d XP" % [order.coins, order.xp])
	changed.emit()
	Game.persist()
	return true

func snapshot() -> Dictionary:
	return {"active": active.duplicate(true), "fulfilled": fulfilled, "next_at": next_at}
