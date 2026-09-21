extends Node
var shadows:=true
var particle_density:=1.0
func set_graphics(use_shadows: bool,density: float) -> void:
	shadows=use_shadows;particle_density=clampf(density,0,1)
	Events.settings_changed.emit();Game.persist()
func snapshot() -> Dictionary:
	return {"shadows":shadows,"particle_density":particle_density}
func restore(data: Dictionary) -> void:
	shadows=bool(data.get("shadows",true));particle_density=clampf(float(data.get("particle_density",1)),0,1)
	Events.settings_changed.emit()
