extends Node
## Android plugin seam. No notification side effects in editor/unsupported platforms.
## Native singleton contract: request_permission(), schedule_ready(unix_seconds), cancel_ready().
var enabled:=false
var scheduled_at: int=0
func _ready() -> void:
	Events.application_paused.connect(schedule_pending)
	Events.application_resumed.connect(cancel)
func supported() -> bool:
	return OS.get_name()=="Android" and Engine.has_singleton("MonsterGardenNotifications")
func schedule_pending() -> void:
	scheduled_at=0
	if not enabled: return
	for plot: Dictionary in Game.plots:
		if plot.species_id!="" and float(plot.ready_at)>Game.now(): scheduled_at=maxi(scheduled_at,int(plot.ready_at))
	if supported():
		var plugin:=Engine.get_singleton("MonsterGardenNotifications")
		if scheduled_at>0: plugin.schedule_ready(scheduled_at)
		else: plugin.cancel_ready()
func cancel() -> void:
	scheduled_at=0
	if supported(): Engine.get_singleton("MonsterGardenNotifications").cancel_ready()
func set_enabled(value: bool) -> void:
	enabled=value
	if supported() and value: Engine.get_singleton("MonsterGardenNotifications").request_permission()
	if not value: cancel()
	Game.persist()
func snapshot() -> Dictionary:
	return {"enabled":enabled,"scheduled_at":scheduled_at}
func restore(data: Dictionary) -> void:
	enabled=bool(data.get("enabled",false))
	scheduled_at=int(data.get("scheduled_at",0))
