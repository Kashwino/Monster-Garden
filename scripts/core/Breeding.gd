extends Node
signal changed
const BENCH_LEVEL := 2
const BENCH_COST := 65
var bench_owned := false
var total_bred := 0
var last_result: Dictionary = {}
var recipes: Array = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	recipes = JSON.parse_string(FileAccess.get_file_as_string("res://data/breeding.json")) as Array

func buy_bench() -> bool:
	if bench_owned or LevelXP.level < BENCH_LEVEL or not Economy.spend(BENCH_COST):
		return false
	bench_owned = true
	Events.purchase_made.emit("breeding_bench", "coins", BENCH_COST)
	changed.emit()
	Game.persist()
	return true

func can_breed(first: String, second: String) -> bool:
	if not bench_owned:
		return false
	var a := Inventory.find_stack(first)
	var b := Inventory.find_stack(second)
	return not a.is_empty() and not b.is_empty() and UnlockManager.is_available(a.species_id) and UnlockManager.is_available(b.species_id) and (first != second or int(a.quantity) >= 2)

func combine(first: String, second: String) -> Dictionary:
	if not can_breed(first, second):
		return {}
	var a := Inventory.find_stack(first)
	var b := Inventory.find_stack(second)
	var selection := {first:1}
	selection[second] = int(selection.get(second, 0)) + 1
	if not Inventory.consume(selection):
		return {}
	var genes := mix_genes(a.genes, b.genes)
	var species_id := String(a.species_id if rng.randf() < .5 else b.species_id)
	var family := String(Catalog.get_species(a.species_id).family)
	if Catalog.get_species(b.species_id).family == family:
		for value: Variant in recipes:
			var recipe := value as Dictionary
			if recipe.family == family and float(genes.glow) >= float(recipe.glow_min) and float(genes.scale) >= float(recipe.scale_min) and rng.randf() < float(recipe.chance):
				species_id = recipe.species_id
				UnlockManager.grant(recipe.event)
				break
	var is_new := Game.discover(species_id)
	Inventory.add_seed(species_id, genes)
	total_bred += 1
	last_result = {"species_id":species_id, "genes":genes, "is_new":is_new}
	Events.bred.emit(species_id, is_new)
	Events.toast_requested.emit("A new %s seed is stirring." % Catalog.get_species(species_id).name)
	changed.emit()
	Game.persist()
	return last_result.duplicate(true)

func mix_genes(a: Dictionary, b: Dictionary, mutation_chance: float = .15) -> Dictionary:
	var genes: Dictionary = {}
	for gene_name: String in Inventory.TRAITS:
		genes[gene_name] = (float(a.get(gene_name, 1)) + float(b.get(gene_name, 1))) / 2.0
	# Hue is circular: red+red must not pass through cyan at the wrap boundary.
	var ah := float(a.get("hue", 0))*TAU
	var bh := float(b.get("hue", 0))*TAU
	genes.hue = fposmod(atan2(sin(ah)+sin(bh), cos(ah)+cos(bh))/TAU, 1.0)
	genes.appendages = int(round(float(genes.appendages)))
	if rng.randf() < mutation_chance:
		var gene_name := String(Inventory.TRAITS[rng.randi_range(0, Inventory.TRAITS.size()-1)])
		genes[gene_name] = float(genes[gene_name]) + (rng.randi_range(-2,2) if gene_name == "appendages" else rng.randf_range(-.3,.35))
	return Inventory.normalize_genes(genes)

func snapshot() -> Dictionary:
	return {"bench_owned":bench_owned, "total_bred":total_bred, "last_result":last_result.duplicate(true), "rng_state":str(rng.state)}

func restore(data: Dictionary) -> void:
	bench_owned = bool(data.get("bench_owned", false))
	total_bred = int(data.get("total_bred", 0))
	last_result = data.get("last_result", {}).duplicate(true)
	if data.has("rng_state"):
		rng.state = String(data.rng_state).to_int()
