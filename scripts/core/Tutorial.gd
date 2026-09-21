extends Node
signal changed
var steps: Array[String]=[]
var step:=0
var completed:=false
var skipped:=false
var target_plot:=-1
var _advancing:=false
func _ready() -> void:
	for id: String in QuestManager.definitions:
		if bool(QuestManager.definitions[id].get("is_tutorial",false)): steps.append(id)
	QuestManager.objective_completed.connect(_complete)
	Events.crop_planted.connect(func(index: int,_id: String) -> void:
		if current_id()=="tutorial_plant": target_plot=index)
	Game.restored.connect(_resume)
func current_id() -> String:
	return "" if completed or step>=steps.size() else steps[step]
func definition() -> Dictionary:
	return QuestManager.definitions.get(current_id(),{})
func _complete(id: String) -> void:
	if id==current_id() and not _advancing:
		_advancing=true;call_deferred("_advance")
func _advance() -> void:
	_advancing=false
	if completed or not QuestManager.can_claim(current_id()): return
	QuestManager.claim(current_id())
	step+=1
	if step>=steps.size(): completed=true
	_activate();Game.persist()
func _activate() -> void:
	QuestManager.tutorial_active_id=current_id()
	changed.emit()
	if not current_id().is_empty():
		Events.tutorial_step.emit(current_id())
		if QuestManager.can_claim(current_id()): _complete(current_id())
func _resume() -> void:
	_activate()
	if current_id()=="tutorial_wait" and target_plot>=0 and target_plot<Game.plots.size():
		if Game.plots[target_plot].species_id!="" and Game.progress(target_plot)>=1:
			QuestManager.record("ready",1,str(target_plot))
func skip() -> void:
	completed=true;skipped=true;_activate();Game.persist()
func snapshot() -> Dictionary:
	return {"step":step,"completed":completed,"skipped":skipped,"target_plot":target_plot}
func restore(data: Dictionary) -> void:
	step=clampi(int(data.get("step",0)),0,steps.size())
	completed=bool(data.get("completed",false)) or step>=steps.size()
	skipped=bool(data.get("skipped",false));target_plot=int(data.get("target_plot",-1))
	QuestManager.tutorial_active_id=current_id()
