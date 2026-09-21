extends Node
## Original synthesized placeholders; swap streams here for licensed recordings.
var volumes: Dictionary={"Music":.25,"SFX":.65,"UI":.45}
var _players: Dictionary={}
var _streams: Dictionary={}
func _ready() -> void:
	for category: String in volumes:
		if AudioServer.get_bus_index(category)<0:
			AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,category)
		var player:=AudioStreamPlayer.new()
		player.bus=category;add_child(player);_players[category]=player
	_streams["click"]=_tone([480.0],.07)
	_streams["harvest"]=_tone([392.0,523.25,659.25],.12)
	_streams["level"]=_tone([392.0,523.25,659.25,783.99],.18)
	_streams["music"]=_tone([196.0,0.0,261.63,0.0,293.66,0.0,220.0,0.0],.8,true)
	Events.crop_planted.connect(func(_i: int,_id: String) -> void: play("click"))
	Events.crop_harvested.connect(func(_id: String,_n: int,_g: Dictionary) -> void: play("harvest"))
	Events.species_discovered.connect(func(_id: String) -> void: play("level"))
	LevelXP.leveled_up.connect(func(_level: int) -> void: play("level"))
	Events.application_paused.connect(func() -> void: (_players.Music as AudioStreamPlayer).stream_paused=true)
	Events.application_resumed.connect(func() -> void: (_players.Music as AudioStreamPlayer).stream_paused=false)
	Game.restored.connect(func() -> void:
		var p:=_players.Music as AudioStreamPlayer
		p.stream=_streams.music;p.play())
func _tone(notes: Array, duration: float, loop: bool=false) -> AudioStreamWAV:
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=22050
	var frames:=int(duration*22050)
	var data:=PackedByteArray();data.resize(frames*notes.size()*2)
	for n: int in notes.size():
		for i: int in frames:
			var t:=float(i)/22050.0
			var envelope:=minf(1,t/.015)*exp(-t*5)*minf(1,float(frames-i)/440)
			var wave:=sin(TAU*float(notes[n])*t)+.2*sin(TAU*float(notes[n])*2*t)
			data.encode_s16((n*frames+i)*2,int(wave*envelope*4500))
	stream.data=data
	if loop:
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=frames*notes.size()
	return stream
func play(id: String, category: String="SFX") -> void:
	if not _players.has(category) or not _streams.has(id): return
	var player:=_players[category] as AudioStreamPlayer
	player.stream=_streams[id];player.play()
func set_volume(category: String,value: float) -> void:
	if not volumes.has(category): return
	volumes[category]=clampf(value,0,1)
	var index:=AudioServer.get_bus_index(category)
	AudioServer.set_bus_volume_db(index,linear_to_db(maxf(.0001,volumes[category])))
	AudioServer.set_bus_mute(index,volumes[category]<=0)
func snapshot() -> Dictionary: return volumes.duplicate(true)
func restore(data: Dictionary) -> void:
	for category: String in volumes: set_volume(category,float(data.get(category,{"Music":.25,"SFX":.65,"UI":.45}[category])))
