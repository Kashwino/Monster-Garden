extends PanelContainer
var _list: VBoxContainer
var _pending := false
func _ready() -> void:
	custom_minimum_size = Vector2(300, 360)
	var style := StyleBoxFlat.new()
	style.bg_color=Color("20373a")
	style.set_corner_radius_all(16)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel",style)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list=VBoxContainer.new()
	_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation",10)
	scroll.add_child(_list)
	QuestManager.changed.connect(_queue)
	Game.restored.connect(_queue)
	_queue()
func _queue() -> void:
	if not _pending:
		_pending=true
		call_deferred("_rebuild")
func _rebuild() -> void:
	_pending=false
	for child: Node in _list.get_children():
		_list.remove_child(child);child.queue_free()
	var title:=Label.new()
	title.text="KEEPER GOALS · " + QuestManager.utc_date
	title.add_theme_font_size_override("font_size",12)
	_list.add_child(title)
	for quest: Dictionary in QuestManager.active_quests():
		var label:=Label.new()
		label.text=("Daily · " if bool(quest.get("daily",false)) else "Journey · ")+String(quest.title)
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(label)
		var bar:=ProgressBar.new()
		bar.max_value=int(quest.objective.count)
		bar.value=int(QuestManager.progress.get(quest.id,0))
		bar.custom_minimum_size.y=12
		_list.add_child(bar)
		var claim:=Button.new()
		claim.text="Claim reward" if QuestManager.can_claim(quest.id) else "%d / %d" % [bar.value,bar.max_value]
		claim.custom_minimum_size.y=42
		claim.disabled=not QuestManager.can_claim(quest.id)
		claim.pressed.connect(func() -> void: QuestManager.claim(quest.id))
		_list.add_child(claim)
