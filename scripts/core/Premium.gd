extends Node
signal changed
var gems:=5
var fertiliser:=2
var rng:=RandomNumberGenerator.new()
func _ready() -> void:
	rng.randomize()
	LevelXP.leveled_up.connect(func(_level: int) -> void: earn(2))
	Events.species_discovered.connect(func(_id: String) -> void: earn(1))
func earn(amount: int) -> void:
	gems+=maxi(0,amount);changed.emit()
func spend(amount: int) -> bool:
	if amount<0 or gems<amount: return false
	gems-=amount;changed.emit();return true
func finish_cost(index: int) -> int:
	return maxi(1,int(ceil(Game.remaining(index)/300.0)))
func can_boost(index: int) -> bool:
	return index>=0 and index<Game.plots.size() and Game.plots[index].species_id!="" and Game.progress(index)<1
func finish(index: int) -> bool:
	if not can_boost(index): return false
	var cost:=finish_cost(index)
	if not spend(cost): return false
	Game.plots[index].ready_at=Game.now()
	Game.plot_changed.emit(index)
	Events.purchase_made.emit("instant_growth","gems",cost)
	Game.persist();return true
func buy_fertiliser() -> bool:
	if not Economy.spend(20): return false
	fertiliser+=1;changed.emit()
	Events.purchase_made.emit("fertiliser","coins",20)
	Game.persist();return true
func apply_fertiliser(index: int) -> bool:
	if not can_boost(index) or fertiliser<=0 or bool(Game.plots[index].get("fertilised",false)): return false
	fertiliser-=1
	Game.plots[index].ready_at=Game.now()+ceil(Game.remaining(index)*.65)
	Game.plots[index].fertilised=true
	Game.plots[index].mutation_bonus=.25
	Game.plot_changed.emit(index)
	changed.emit();Game.persist();return true
func harvest_genes(plot: Dictionary) -> Dictionary:
	var result: Dictionary=plot.genes.duplicate(true)
	if rng.randf()<.03+float(plot.get("mutation_bonus",0)):
		result=Breeding.mix_genes(result,result,1.0)
	return result
func rare_seed_cost(id: String) -> int:
	return int({"Rare":6,"Exotic":12,"Mythic":24}.get(Catalog.get_species(id).get("rarity",""),0))
func buy_rare_seed(id: String) -> bool:
	var cost:=rare_seed_cost(id)
	if cost<=0 or not UnlockManager.is_available(id) or not spend(cost): return false
	Inventory.add_seed(id,Catalog.get_species(id).genes)
	Events.purchase_made.emit(id+"_seed","gems",cost)
	Game.persist();return true
func plot_cost(index: int) -> int:
	return 5+maxi(0,index-6)
func snapshot() -> Dictionary:
	return {"gems":gems,"fertiliser":fertiliser,"rng_state":str(rng.state)}
func restore(data: Dictionary) -> void:
	gems=maxi(0,int(data.get("gems",5)))
	fertiliser=maxi(0,int(data.get("fertiliser",2)))
	if data.has("rng_state"): rng.state=String(data.rng_state).to_int()
	changed.emit()
