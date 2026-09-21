extends Node3D
## Three reused bursts cap GPU work; cosmetics never advance gameplay timers.
var _bursts: Array[GPUParticles3D]=[]
var _cursor:=0
var density:=1.0
func _ready() -> void:
	for i: int in 3:
		var burst:=AssetFactory.create_burst();add_child(burst);_bursts.append(burst)
	Events.crop_harvested.connect(func(id: String,_n: int,_g: Dictionary) -> void:
		burst();float_text("+%d XP"%Catalog.get_species(id).xp,Color("f6e8b8")))
	Events.crop_sold.connect(func(_id: String,_n: int,coins: int) -> void: float_text("+%d coins"%coins,Color("fae0a1")))
	Events.species_discovered.connect(func(_id: String) -> void: burst();float_text("NEW SPECIES",Color("f5b0d0")))
	LevelXP.leveled_up.connect(func(level: int) -> void: burst();float_text("KEEPER %d"%level,Color("e4f8ad")))
func burst() -> void:
	if density<=0: return
	var particle:=_bursts[_cursor];_cursor=(_cursor+1)%_bursts.size()
	particle.position=GardenLayout.plot_position(Game.selected_plot)+Vector3.UP*.8
	particle.amount=maxi(1,int(24*density));particle.restart();particle.emitting=true
func float_text(value: String,color: Color) -> void:
	var label:=Label3D.new();label.text=value;label.font_size=48;label.pixel_size=.014
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.modulate=color
	add_child(label);label.position=GardenLayout.plot_position(Game.selected_plot)+Vector3.UP*1.8
	var tween:=create_tween().set_parallel(true)
	tween.tween_property(label,"position:y",label.position.y+1.4,1.25)
	tween.tween_property(label,"modulate:a",0.0,.6).set_delay(.65)
	tween.chain().tween_callback(label.queue_free)
