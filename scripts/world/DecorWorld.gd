extends Node3D
var _models: Dictionary={}
func _ready() -> void:
	Decorations.changed.connect(_refresh)
	_refresh()
func _refresh() -> void:
	for key: String in _models.keys():
		if not Decorations.placements.has(key) or _models[key].get_meta("id")!=Decorations.placements[key].id:
			_models[key].queue_free();_models.erase(key)
	for key: String in Decorations.placements:
		var entry: Dictionary=Decorations.placements[key]
		if not _models.has(key):
			var node:=AssetFactory.create_decoration(entry.id)
			add_child(node);node.set_meta("id",entry.id);_models[key]=node
		var model:=_models[key] as Node3D
		model.position=GardenLayout.DECOR_SLOTS[int(key)]
		model.rotation.y=int(entry.rotation)*PI/2
