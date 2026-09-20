extends Node
signal changed
signal leveled_up(level: int)
var level: int = 1
var xp: int = 0

func required_xp() -> int:
	return 30 + (level - 1) * 25

func add_xp(amount: int) -> void:
	xp += maxi(amount, 0)
	while xp >= required_xp():
		xp -= required_xp()
		level += 1
		leveled_up.emit(level)
	changed.emit()

func restore(data: Dictionary) -> void:
	level = maxi(1, int(data.get("level", 1)))
	xp = maxi(0, int(data.get("xp", 0)))
	changed.emit()

func snapshot() -> Dictionary:
	return {"level": level, "xp": xp}
