extends Control
## Four panels form an input mask around the current play area.
var hud: Node
var _masks: Array[ColorRect]=[]
var _line: Label
var _bar: PanelContainer
var _last_id:=""
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	for i: int in 4:
		var mask:=ColorRect.new();mask.color=Color(0.04,.12,.1,.4)
		mask.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(mask);_masks.append(mask)
	_bar=PanelContainer.new();_bar.position=Vector2(12,216);_bar.size=Vector2(456,60)
	_bar.add_theme_stylebox_override("panel",hud._style(Color("e0e9bd"),14,10));add_child(_bar)
	var row:=HBoxContainer.new();_bar.add_child(row)
	_line=hud._label("",13,Color("213d35"));_line.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;row.add_child(_line)
	row.add_child(hud._button("Skip",Tutorial.skip))
	Tutorial.changed.connect(_refresh)
	Game.restored.connect(func() -> void: _last_id="";_refresh())
	_refresh()
func _refresh() -> void:
	visible=not Tutorial.completed
	hud._modal.offset_top=286 if visible else 216
	if not visible:
		_last_id=""
		return
	_line.text="%d/6 · %s"%[Tutorial.step+1,Tutorial.definition().get("title","")]
	if _last_id!=Tutorial.current_id():
		_last_id=Tutorial.current_id();call_deferred("_focus")
func _focus() -> void:
	if Tutorial.completed: return
	match String(Tutorial.definition().get("focus","")):
		"plant":
			for i: int in Game.plots.size():
				if Game.plots[i].unlocked and Game.plots[i].species_id=="": Game.select_plot(i);break
			hud._open("seeds")
		"plot", "action":
			hud._close()
			if Tutorial.target_plot>=0: Game.select_plot(Tutorial.target_plot)
		"basket", "orders", "breed": hud._open(String(Tutorial.definition().focus))
func _process(_delta: float) -> void:
	if not visible: return
	# Presentation-only geometry; progression is entirely signal/data driven.
	var hole:=Rect2(Vector2(0,282),Vector2(size.x,size.y-282))
	if hud._modal.visible: hole=hud._modal.get_global_rect()
	var rectangles: Array[Rect2]=[Rect2(0,0,size.x,hole.position.y),Rect2(0,hole.end.y,size.x,size.y-hole.end.y),Rect2(0,hole.position.y,hole.position.x,hole.size.y),Rect2(hole.end.x,hole.position.y,size.x-hole.end.x,hole.size.y)]
	for i: int in 4: _masks[i].position=rectangles[i].position;_masks[i].size=rectangles[i].size
