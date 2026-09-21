extends Node
signal summary_ready(summary: Dictionary)
var last_active: float=0
var announced: Array[String]=[]
var last_summary: Dictionary={}
var _timer: Timer
func _ready() -> void:
	_timer=Timer.new();_timer.one_shot=true
	_timer.timeout.connect(_tick);add_child(_timer)
	Game.restored.connect(_initial)
	Game.plot_changed.connect(func(_i: int) -> void: _tick())
	Events.application_paused.connect(_pause)
	Events.application_resumed.connect(reconcile)
func _key(index: int) -> String:
	var plot:=Game.plots[index]
	return "%d:%s:%d"%[index,plot.species_id,int(plot.planted_at)]
func _initial() -> void:
	var expired:=BuyerOrders.last_expired.duplicate()
	reconcile(expired)
func reconcile(initial_expired: Array=[]) -> void:
	var now:=Game.now()
	var completed:=0
	for plot: Dictionary in Game.plots:
		if plot.species_id!="" and float(plot.ready_at)>last_active and float(plot.ready_at)<=now: completed+=1
	var expired:=initial_expired if not initial_expired.is_empty() else BuyerOrders.refresh()
	QuestManager.reconcile()
	UnlockManager.refresh()
	last_summary={"ready":completed if last_active>0 else 0,"expired":expired.size(),"elapsed":maxf(0,now-last_active) if last_active>0 else 0}
	last_active=now
	_tick()
	if int(last_summary.ready)>0 or int(last_summary.expired)>0:
		summary_ready.emit(last_summary.duplicate(true))
		Events.session_resumed.emit(last_summary.duplicate(true))
	Game.persist()
func _tick() -> void:
	var current: Array[String]=[]
	for i: int in Game.plots.size():
		if Game.plots[i].species_id=="": continue
		var key:=_key(i)
		if Game.progress(i)>=1.0:
			current.append(key)
			if not announced.has(key):
				announced.append(key)
				Events.plot_ready.emit(i)
	announced.assign(current)
	UnlockManager.refresh()
	_schedule()
func _schedule() -> void:
	var at:=Game.now()+86400
	for i: int in Game.plots.size():
		if Game.plots[i].species_id!="" and float(Game.plots[i].ready_at)>Game.now(): at=minf(at,float(Game.plots[i].ready_at))
	if UnlockManager.next_drift_at>Game.now(): at=minf(at,UnlockManager.next_drift_at)
	if not UnlockManager.drift.is_empty(): at=minf(at,float(UnlockManager.drift.expires_at))
	_timer.start(maxf(1,at-Game.now()))
func _pause() -> void:
	last_active=Game.now()
func snapshot() -> Dictionary:
	return {"last_active":Game.now(),"announced":announced.duplicate()}
func restore(data: Dictionary) -> void:
	last_active=float(data.get("last_active",0))
	announced.assign(data.get("announced",[]))
