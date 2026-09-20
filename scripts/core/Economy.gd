extends Node
signal changed
var coins: int = 120

func spend(amount: int) -> bool:
	if amount < 0 or coins < amount:
		return false
	coins -= amount
	changed.emit()
	return true

func earn(amount: int) -> void:
	coins += maxi(amount, 0)
	changed.emit()

func sell(id: String, quantity: int) -> bool:
	if not Catalog.species.has(id) or not Inventory.remove_species(id, quantity):
		return false
	var reward := int(Catalog.get_species(id).sell_value) * quantity
	earn(reward)
	Events.crop_sold.emit(id, quantity, reward)
	Events.toast_requested.emit("+%d coins · sold %s" % [reward, Catalog.get_species(id).name])
	Game.persist()
	return true
