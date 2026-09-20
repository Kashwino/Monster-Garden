extends Node
## Crops are stacks of identical species + normalized genes, ready for breeding.
signal changed
var stacks: Array[Dictionary] = []
const TRAITS := ["appendages", "glow", "hue", "scale", "speed"]

func normalize_genes(genes: Dictionary) -> Dictionary:
	return {
		"appendages": clampi(int(genes.get("appendages", 3)), 1, 8),
		"glow": snappedf(clampf(float(genes.get("glow", 0.1)), 0, 1), 0.01),
		"hue": snappedf(fposmod(float(genes.get("hue", 0.3)), 1.0), 0.01),
		"scale": snappedf(clampf(float(genes.get("scale", 1)), 0.5, 1.5), 0.01),
		"speed": snappedf(clampf(float(genes.get("speed", 1)), 0.3, 2), 0.01)
	}

func stack_key(id: String, genes: Dictionary) -> String:
	return id + ":" + JSON.stringify(normalize_genes(genes)).sha256_text().left(16)

func add_crop(id: String, genes: Dictionary, count: int) -> void:
	if count <= 0 or not Catalog.species.has(id):
		return
	var clean := normalize_genes(genes)
	var key := stack_key(id, clean)
	for stack: Dictionary in stacks:
		if stack.key == key:
			stack.quantity = int(stack.quantity) + count
			changed.emit()
			return
	stacks.append({"key": key, "species_id": id, "genes": clean, "quantity": count})
	changed.emit()

func count_species(id: String) -> int:
	var count := 0
	for stack: Dictionary in stacks:
		if stack.species_id == id:
			count += int(stack.quantity)
	return count

func remove_species(id: String, quantity: int) -> bool:
	if quantity <= 0 or count_species(id) < quantity:
		return false
	var remaining := quantity
	for i: int in range(stacks.size() - 1, -1, -1):
		var stack := stacks[i]
		if stack.species_id != id:
			continue
		var taken := mini(int(stack.quantity), remaining)
		stack.quantity = int(stack.quantity) - taken
		remaining -= taken
		if int(stack.quantity) == 0:
			stacks.remove_at(i)
		if remaining == 0:
			break
	changed.emit()
	return true

func restore(data: Array) -> void:
	stacks.clear()
	for value: Variant in data:
		if value is Dictionary:
			var stack := value as Dictionary
			add_crop(String(stack.get("species_id", "")), stack.get("genes", {}), int(stack.get("quantity", 0)))
	changed.emit()

func snapshot() -> Array[Dictionary]:
	return stacks.duplicate(true)
