extends Node
## Analytics seam: structured local logs only, no network SDK or personal identifiers.
var _session_live:=false
func _ready() -> void:
	Game.restored.connect(_start)
	Events.application_resumed.connect(_start)
	Events.application_paused.connect(_end)
	LevelXP.leveled_up.connect(func(level: int) -> void: track("level_up",{"level":level}))
	Events.purchase_made.connect(func(item: String,currency: String,amount: int) -> void: track("purchase",{"item":item,"currency":currency,"amount":amount}))
	Events.species_discovered.connect(func(id: String) -> void: track("species_discovered",{"species":id}))
	Events.tutorial_step.connect(func(id: String) -> void: track("tutorial_step",{"step":id}))
	Events.order_fulfilled.connect(func(_id: String) -> void: track("order_fulfilled",{}))
func track(event: String,params: Dictionary={}) -> void:
	print("ANALYTICS "+JSON.stringify({"event":event,"params":params}))
func _start() -> void:
	if not _session_live: _session_live=true;track("session_start",{})
func _end() -> void:
	if _session_live: _session_live=false;track("session_end",{})
func _exit_tree() -> void: _end()
