extends Node
## All mesh creation lives here. Callers request IDs, never resource paths.
const Motion = preload("res://scripts/art/MonsterVisual.gd")
var _materials: Dictionary = {}

func create(id: String, stage: String = "blooming", genes: Dictionary = {}) -> Node3D:
	var entry := Catalog.get_species(id)
	if entry.is_empty():
		return Node3D.new()
	var clean := Inventory.normalize_genes(entry.genes if genes.is_empty() else genes)
	var root := Node3D.new()
	root.name = id + "_" + stage
	root.set_script(Motion)
	root.set("pulse_speed", float(clean.speed))
	var color := Color.from_hsv(float(clean.hue), 0.52, 0.85)
	var shape := String(entry.mesh.get("primitive", "eye"))
	_build_creature(root, shape, stage, color, clean)
	var stage_scale: float = {"seed": 0.28, "sprout": 0.45, "juvenile": 0.65, "mature": 0.88, "blooming": 1.0}.get(stage, 1.0)
	root.scale = Vector3.ONE * float(clean.scale) * stage_scale
	return root

func _build_creature(root: Node3D, shape: String, stage: String, color: Color, genes: Dictionary) -> void:
	var body := material(color)
	var dark := material(Color("10282a"))
	var pale := material(Color("efe9cf"))
	var glow := material(color.lightened(0.2), float(genes.glow))
	if stage == "seed":
		ellipsoid(root, Vector3(0, 0.28, 0), Vector3(0.4, 0.55, 0.4), body)
		ellipsoid(root, Vector3(0.1, 0.36, 0.32), Vector3(0.15, 0.25, 0.09), glow)
		return
	for i: int in int(genes.appendages):
		var angle := TAU * i / float(genes.appendages)
		var direction := Vector3(cos(angle), 0, sin(angle))
		var rootlet := ellipsoid(root, direction * 0.31 + Vector3.UP * 0.18, Vector3(0.15, 0.34, 0.17), body)
		rootlet.rotation.z = -cos(angle) * 0.8
		rootlet.rotation.x = sin(angle) * 0.8
	match shape:
		"eye":
			ellipsoid(root, Vector3(0, 0.6, 0), Vector3(0.42, 0.62, 0.35), body)
			ellipsoid(root, Vector3(0.16, 0.84, 0.28), Vector3(0.3, 0.25, 0.2), pale)
			ellipsoid(root, Vector3(0.27, 0.85, 0.41), Vector3(0.1, 0.19, 0.07), dark)
			ellipsoid(root, Vector3(0.29, 0.91, 0.47), Vector3(0.03, 0.05, 0.025), glow)
			for i: int in 3:
				ellipsoid(root, Vector3(-0.25 + i * 0.24, 1.22, 0), Vector3(0.055, 0.27, 0.055), glow)
		"fungus":
			ellipsoid(root, Vector3(0, 0.45, 0), Vector3(0.19, 0.5, 0.2), pale)
			ellipsoid(root, Vector3(0, 0.9, 0), Vector3(0.59, 0.34, 0.55), body)
			for i: int in 3:
				ellipsoid(root, Vector3(-0.3 + i * 0.3, 0.85, 0.46), Vector3(0.07, 0.11, 0.04), dark)
			ellipsoid(root, Vector3(-0.35, 1.12, 0.08), Vector3(0.1, 0.08, 0.1), glow)
			ellipsoid(root, Vector3(0.16, 1.2, 0.0), Vector3(0.12, 0.06, 0.1), glow)
		"crystal":
			for i: int in 5:
				var angle := i * TAU / 5.0
				var shard := cone(root, Vector3(cos(angle) * 0.24, 0.4 + i * 0.07, sin(angle) * 0.24), 0.22, 0.8 + i * 0.09, glow)
				shard.rotation.z = cos(angle) * 0.2
			ellipsoid(root, Vector3(0.12, 0.45, 0.28), Vector3(0.18, 0.12, 0.07), dark)
		"tendril":
			ellipsoid(root, Vector3(0, 0.42, 0), Vector3(0.36, 0.4, 0.33), body)
			for i: int in int(genes.appendages):
				var a := i * TAU / float(genes.appendages)
				var stalk := ellipsoid(root, Vector3(cos(a) * 0.3, 0.8, sin(a) * 0.3), Vector3(0.08, 0.52, 0.08), body)
				stalk.rotation.z = cos(a) * 0.3
				ellipsoid(root, Vector3(cos(a) * 0.4, 1.25, sin(a) * 0.4), Vector3(0.13, 0.14, 0.13), glow)
			ellipsoid(root, Vector3(0.19, 0.53, 0.26), Vector3(0.16, 0.18, 0.07), pale)
			ellipsoid(root, Vector3(0.22, 0.54, 0.32), Vector3(0.07, 0.1, 0.035), dark)

func material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var key := color.to_html() + str(emission)
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.86
	mat.emission_enabled = emission > 0
	mat.emission = color
	mat.emission_energy_multiplier = emission * 1.4
	_materials[key] = mat
	return mat

func _mesh(parent: Node3D, mesh: Mesh, position: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = position
	parent.add_child(node)
	return node

func ellipsoid(parent: Node3D, position: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 12
	mesh.rings = 6
	var node := _mesh(parent, mesh, position, mat)
	node.scale = size
	return node

func box(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, position, material(color))

func cone(parent: Node3D, position: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.02
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 5
	return _mesh(parent, mesh, position, mat)

func create_plot(unlocked: bool) -> Node3D:
	var root := Node3D.new()
	box(root, Vector3(0, -0.15, 0), Vector3(1.3, 0.24, 1.3), Color("47604b") if unlocked else Color("253e3b"))
	box(root, Vector3(0, -0.01, 0), Vector3(1.14, 0.08, 1.14), Color("433f3a") if unlocked else Color("2b4540"))
	if unlocked:
		for i: int in 3:
			box(root, Vector3(-0.32 + i * 0.32, 0.04, 0), Vector3(0.04, 0.015, 0.91), Color("555043"))
	return root

func create_island() -> Node3D:
	var root := Node3D.new()
	box(root, Vector3(0, -0.62, 0), Vector3(7.1, 0.68, 7.1), Color("2b4240"))
	box(root, Vector3(0, -0.32, 0), Vector3(7.3, 0.15, 7.3), Color("51735a"))
	# Border stones and luminous alien reeds; deterministic scene dressing.
	for i: int in 12:
		var angle := i * TAU / 12.0
		var pos := Vector3(cos(angle) * 4.2, -0.15, sin(angle) * 4.2)
		ellipsoid(root, pos, Vector3(0.38, 0.3, 0.32), material(Color("385751")))
	for pos: Vector3 in [Vector3(-3.25, 0, -2.9), Vector3(3.2, 0, -2.8), Vector3(-3.2, 0, 2.8)]:
		for i: int in 3:
			cone(root, pos + Vector3(i * 0.18, 0.25 + i * 0.1, 0), 0.12, 0.8 + i * 0.2, material(Color("a1c890"), 0.4))
	return root
