extends Node3D
const SPACING := 1.05
var _plots: Array[Node3D] = []
var _plants: Array[Node3D] = []
var _labels: Array[Label3D] = []
var _stages: Array[String] = []
var _selector: Node3D

func _ready() -> void:
	add_child(AssetFactory.create_island())
	Game.restored.connect(_build)
	Game.plot_changed.connect(_refresh_plot)
	Game.selection_changed.connect(_select)
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.timeout.connect(_refresh_growth)
	add_child(timer)
	timer.start()
	if not Game.plots.is_empty():
		_build()

func plot_position(index: int) -> Vector3:
	return GardenLayout.plot_position(index)

func _build() -> void:
	if not _plots.is_empty():
		return
	for i: int in Game.plots.size():
		var plot := Node3D.new()
		plot.position = plot_position(i)
		add_child(plot)
		_plots.append(plot)
		_plants.append(null)
		_stages.append("")
		var label := Label3D.new()
		label.position = Vector3(0, 0.18, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 28
		label.pixel_size = 0.007
		label.modulate = Color("e5e7cf")
		label.no_depth_test = true
		plot.add_child(label)
		_labels.append(label)
		_refresh_plot(i)
	_selector = Node3D.new()
	for z: float in [-0.49, 0.49]:
		AssetFactory.box(_selector, Vector3(0, 0.065, z), Vector3(1.01, 0.035, 0.035), Color("dbe6a7"))
	for x: float in [-0.49, 0.49]:
		AssetFactory.box(_selector, Vector3(x, 0.065, 0), Vector3(0.035, 0.035, 1.01), Color("dbe6a7"))
	add_child(_selector)
	_select(Game.selected_plot)

func _refresh_plot(index: int) -> void:
	if index >= _plots.size():
		return
	var holder := _plots[index]
	var old := holder.get_node_or_null("Soil")
	if old != null:
		holder.remove_child(old)
		old.queue_free()
	var soil := AssetFactory.create_plot(bool(Game.plots[index].unlocked))
	soil.name = "Soil"
	holder.add_child(soil)
	_stages[index] = ""
	_update_plant(index)

func _update_plant(index: int) -> void:
	var plot := Game.plots[index]
	var stage := Catalog.stage_for(Game.progress(index)) if plot.species_id != "" else "empty"
	if stage != _stages[index]:
		if is_instance_valid(_plants[index]):
			var old_plant:=_plants[index]
			if stage=="empty":
				var tween:=old_plant.create_tween()
				tween.tween_property(old_plant,"scale",old_plant.scale*1.2,.12)
				tween.tween_property(old_plant,"scale",Vector3.ZERO,.2)
				tween.tween_callback(old_plant.queue_free)
			else: old_plant.queue_free()
		_plants[index] = null
		if plot.species_id != "":
			var plant := AssetFactory.create(plot.species_id, stage, plot.genes)
			_plots[index].add_child(plant)
			_plants[index] = plant
			var target := plant.scale
			plant.scale *= 0.7
			plant.create_tween().tween_property(plant, "scale", target, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_stages[index] = stage
	var label := _labels[index]
	label.position.y = 1.5 if plot.species_id != "" else 0.18
	label.modulate = Color("dceab1") if stage == "blooming" else Color("9cb1a7")
	if not bool(plot.unlocked):
		label.text = "Lv.%d" % Game.plot_unlock_level(index) if index < 10 or index == Game.selected_plot else ""
	elif plot.species_id == "":
		label.text = "+"
	elif stage == "blooming":
		label.text = "READY"
	else:
		label.text = "%ds" % Game.remaining(index) if Game.remaining(index) < 60 else "%dm" % int(ceil(Game.remaining(index) / 60.0))

func _refresh_growth() -> void:
	for i: int in _plots.size():
		_update_plant(i)

func _select(index: int) -> void:
	if is_instance_valid(_selector):
		_selector.position = plot_position(index)

func select_at(screen: Vector2, camera: Camera3D) -> void:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var point: Variant = Plane(Vector3.UP, 0).intersects_ray(origin, direction)
	if point == null:
		return
	var hit: Vector3 = point
	for i: int in _plots.size():
		var delta:=hit-plot_position(i)
		if absf(delta.x)<.5 and absf(delta.z)<.5:
			Game.select_plot(i)
			return
