extends Node
signal changed
const SLOT_COUNT:=3
const EXPIRY_SECONDS:=900
const EXPIRY_COOLDOWN:=60
var slots: Array[Dictionary]=[]
var reputation:=0
var fulfilled:=0
var serial:=0
var last_expired: Array[String]=[]
var rng:=RandomNumberGenerator.new()
var _timer: Timer
# Compatibility accessors preserve existing slot-zero commands and old saves.
var active: Dictionary:
	get:
		return slots[0].order if slots.size()>0 else {}
	set(value):
		_ensure_slots()
		slots[0].order=_normalize(value)
var next_at: float:
	get: return float(slots[0].refill_at) if slots.size()>0 else 0.0
	set(value):
		_ensure_slots()
		slots[0].refill_at=value

func _ready() -> void:
	rng.randomize()
	_timer=Timer.new()
	_timer.one_shot=true
	_timer.timeout.connect(func() -> void: refresh(); Game.persist())
	add_child(_timer)

func _ensure_slots() -> void:
	while slots.size()<SLOT_COUNT: slots.append({"order":{},"refill_at":0.0,"reroll_at":0.0})

func _normalize(order: Dictionary) -> Dictionary:
	var result:=order.duplicate(true)
	if not result.is_empty() and not result.has("requests"):
		result["requests"]=[{"species_id":result.species_id,"quantity":result.quantity}]
		result["type"]="simple"
	return result

func restore(data: Dictionary) -> void:
	slots.clear()
	if data.has("slots"):
		for value: Dictionary in data.slots:
			if slots.size()==SLOT_COUNT: break
			slots.append({"order":_normalize(value.get("order",{})),"refill_at":value.get("refill_at",0),"reroll_at":value.get("reroll_at",0)})
	_ensure_slots()
	if data.has("active"): active=data.active
	fulfilled=int(data.get("fulfilled",0))
	reputation=int(data.get("reputation",0))
	serial=int(data.get("serial",0))
	if data.has("next_at"): next_at=float(data.next_at)
	if data.has("rng_state"): rng.state=String(data.rng_state).to_int()
	refresh()
	Events.reputation_changed.emit(reputation)

func refresh(at: float=-1) -> Array[String]:
	_ensure_slots()
	var now:=Game.now() if at<0 else at
	last_expired.clear()
	for i: int in slots.size():
		var slot:=slots[i]
		var order: Dictionary=slot.order
		if not order.is_empty() and float(order.expires_at)<=now:
			last_expired.append(String(order.get("type","simple"))+" order")
			slot.refill_at=float(order.expires_at)+EXPIRY_COOLDOWN
			slot.order={}
			reputation=maxi(0,reputation-1)
		if slot.order.is_empty() and now>=float(slot.refill_at): _generate(i,now)
	if not last_expired.is_empty(): Events.reputation_changed.emit(reputation)
	_schedule()
	changed.emit()
	return last_expired.duplicate()

func tier() -> int:
	return 3 if reputation>=30 else 2 if reputation>=10 else 1
func reroll_cost() -> int:
	return 8+tier()*2
func _generate(index: int, at: float) -> void:
	var available:=UnlockManager.available_ids()
	if available.is_empty(): return
	var id:=available[rng.randi_range(0,available.size()-1)]
	# The first request teaches the starter harvest loop.
	if fulfilled==0 and index==0: id="witness_bud"
	var entry:=Catalog.get_species(id)
	var requests: Array=[{"species_id":id,"quantity":int(entry.yield)}]
	var kind:="simple"
	var value:=int(entry.sell_value)*int(entry.yield)
	if index==1 and tier()>=2 and available.size()>1:
		var second:=available[(available.find(id)+1)%available.size()]
		requests=[{"species_id":id,"quantity":1},{"species_id":second,"quantity":1}]
		value=int(entry.sell_value)+int(Catalog.get_species(second).sell_value)
		kind="mixed"
	elif index==2 and tier()>=3:
		requests=[{"family":entry.family,"quantity":2,"min_glow":.45}]
		value=int(entry.sell_value)*3
		kind="gene"
	serial+=1
	slots[index].order={"id":"order_%d"%serial,"type":kind,"requests":requests,"coins":maxi(10,int(value*(2.0+minf(reputation,100)*.01))),"xp":int(entry.xp)+8,"expires_at":at+EXPIRY_SECONDS}

func can_fulfill(index: int=0) -> bool:
	if index<0 or index>=slots.size(): return false
	var order: Dictionary=slots[index].order
	return not order.is_empty() and float(order.expires_at)>Game.now() and not Inventory.plan_requests(order.requests).is_empty()

func fulfill(index: int=0) -> bool:
	if not can_fulfill(index): return false
	var order: Dictionary=slots[index].order.duplicate(true)
	if not Inventory.consume(Inventory.plan_requests(order.requests)): return false
	slots[index].order={}
	slots[index].refill_at=Game.now()+5
	fulfilled+=1
	reputation+=3
	Economy.earn(int(order.coins))
	LevelXP.add_xp(int(order.xp))
	Events.reputation_changed.emit(reputation)
	Events.order_fulfilled.emit(order.id)
	Events.toast_requested.emit("Delivery complete · +%d coins · +%d XP" % [order.coins,order.xp])
	_schedule()
	changed.emit()
	Game.persist()
	return true

func reroll(index: int, currency: String="coins") -> bool:
	if index<0 or index>=slots.size(): return false
	if currency=="coins":
		if Game.now()<float(slots[index].reroll_at) or not Economy.spend(reroll_cost()): return false
	elif currency=="gems":
		var premium:=get_node_or_null("/root/Premium")
		if premium==null or not premium.spend(2): return false
	else: return false
	_generate(index,Game.now())
	slots[index].reroll_at=Game.now()+15
	Events.purchase_made.emit("order_reroll",currency,2 if currency=="gems" else reroll_cost())
	_schedule()
	changed.emit()
	Game.persist()
	return true

func _schedule() -> void:
	var at:=Game.now()+EXPIRY_SECONDS
	for slot: Dictionary in slots:
		at=minf(at,float(slot.order.expires_at) if not slot.order.is_empty() else maxf(Game.now()+1,float(slot.refill_at)))
	_timer.start(maxf(1,at-Game.now()))

func snapshot() -> Dictionary:
	return {"slots":slots.duplicate(true),"fulfilled":fulfilled,"reputation":reputation,"serial":serial,"rng_state":str(rng.state)}
