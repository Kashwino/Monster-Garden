extends Node
func _ready() -> void:
	Events.settings_changed.connect(_apply);_apply()
func _apply() -> void:
	var scene:=get_parent()
	var sun:=scene.get_node("Sun") as DirectionalLight3D
	sun.shadow_enabled=Settings.shadows
	scene.get_node("Juice").density=Settings.particle_density
