extends Node
## All mesh creation lives here. Callers request IDs, never resource paths.
const Motion = preload("res://scripts/art/MonsterVisual.gd")
var _materials: Dictionary = {}
var _scenes: Dictionary = {}
var _warned: Dictionary = {}
var batch_meshes:=bool(ProjectSettings.get_setting("monster_garden/rendering/batch_meshes",true)) and OS.get_environment("MONSTER_GARDEN_UNBATCHED")!="1"
var _primitive_meshes: Dictionary={}
var _vertex_material: StandardMaterial3D

func create(id: String, stage: String = "blooming", genes: Dictionary = {}) -> Node3D:
	var entry := Catalog.get_species(id)
	if entry.is_empty():
		return Node3D.new()
	var clean := Inventory.normalize_genes(entry.genes if genes.is_empty() else genes)
	var root := Node3D.new()
	root.name = id + "_" + stage
	root.set_script(Motion)
	root.set("pulse_speed", float(clean.speed))
	# Art-swap seam: the catalogue is the only place that knows scene paths.
	var spec := resolve_spec(entry, stage)
	var scene_path := String(spec.get("scene", ""))
	var model := _instantiate_scene(scene_path)
	if model != null:
		root.add_child(model)
		_apply_genes(model, clean, {})
		model.scale *= float(spec.get("scale", 1.0))
		root.scale = Vector3.ONE * float(clean.scale)
		root.set_meta("asset_source", scene_path)
		root.set_meta("growth_stage", stage)
		_batch(root)
		return root
	var color := Color.from_hsv(float(clean.hue), 0.52, 0.85)
	var shape := String(spec.get("primitive", "eye"))
	_build_creature(root, shape, stage, color, clean)
	var stage_scale: float = {"seed": 0.28, "sprout": 0.45, "juvenile": 0.65, "mature": 0.88, "blooming": 1.0}.get(stage, 1.0)
	root.scale = Vector3.ONE * float(clean.scale) * stage_scale
	root.set_meta("asset_source", "primitive:" + shape)
	root.set_meta("growth_stage", stage)
	_batch(root)
	return root

func resolve_spec(entry: Dictionary, stage: String) -> Dictionary:
	var family: Dictionary = Catalog.families.get(entry.get("family", ""), {})
	var spec: Dictionary = family.get("mesh", {}).duplicate(true)
	spec.merge(entry.get("mesh", {}), true)
	var stages: Dictionary = spec.get("stages", {})
	var variant: Variant = stages.get(stage, {})
	if variant is String:
		spec["scene"] = String(variant)
	elif variant is Dictionary:
		var stage_spec := variant as Dictionary
		spec.merge(stage_spec, true)
	return spec

func _instantiate_scene(path: String) -> Node3D:
	if path.is_empty():
		return null
	if not path.begins_with("res://") or not ResourceLoader.exists(path):
		_warn_once(path, "Asset missing; using its catalog primitive: " + path)
		return null
	if not _scenes.has(path):
		var resource := ResourceLoader.load(path)
		if not resource is PackedScene:
			_warn_once(path, "Asset is not an instantiable scene: " + path)
			return null
		_scenes[path] = resource as PackedScene
	var packed := _scenes[path] as PackedScene
	var instance := packed.instantiate()
	if not instance is Node3D:
		instance.free()
		_warn_once(path, "Asset root must be Node3D: " + path)
		return null
	return instance as Node3D

func _warn_once(key: String, message: String) -> void:
	if not _warned.has(key):
		_warned[key] = true
		push_warning(message)

func _apply_genes(node: Node, genes: Dictionary, instance_materials: Dictionary) -> void:
	if node is Node3D:
		var spatial := node as Node3D
		if String(spatial.name).begins_with("Appendage_"):
			spatial.visible = String(spatial.name).trim_prefix("Appendage_").to_int() < int(genes.appendages)
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface: int in mesh_instance.mesh.get_surface_count():
				var source := mesh_instance.get_active_material(surface)
				if source is StandardMaterial3D:
					var standard := source as StandardMaterial3D
					if standard.resource_name.begins_with("Gene"):
						# Never mutate imported/shared materials: genes belong to an instance.
						var material_key:=standard.get_instance_id()
						if not instance_materials.has(material_key):
							var unique:=standard.duplicate() as StandardMaterial3D
							unique.albedo_color=Color.from_hsv(float(genes.hue),.48,.82)
							if standard.resource_name.begins_with("GeneGlow"):
								unique.albedo_color=unique.albedo_color.lightened(.25)
								unique.emission_enabled=true;unique.emission=unique.albedo_color
								unique.emission_energy_multiplier=float(genes.glow)*2
							instance_materials[material_key]=unique
						mesh_instance.set_surface_override_material(surface,instance_materials[material_key])
	for child: Node in node.get_children():
		_apply_genes(child, genes, instance_materials)

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

		_:
			_build_extended(root, shape, body, dark, pale, glow, genes)

func _build_extended(root: Node3D, shape: String, body: Material, dark: Material, pale: Material, glow: Material, genes: Dictionary) -> void:
	match shape:
		"maw":
			ellipsoid(root, Vector3(0, .55, 0), Vector3(.5, .55, .5), body)
			ellipsoid(root, Vector3(.12, .85, .18), Vector3(.4, .13, .4), dark)
			for i: int in 8:
				var a := TAU * i / 8.0
				cone(root, Vector3(cos(a)*.31, .96, sin(a)*.31), .06, .28, pale)
		"spore":
			for i: int in int(genes.appendages):
				var a := TAU * i / float(genes.appendages)
				ellipsoid(root, Vector3(cos(a)*.3, .5+i*.06, sin(a)*.3), Vector3(.23,.38,.23), body)
				ellipsoid(root, Vector3(cos(a)*.3,.88+i*.06,sin(a)*.3),Vector3(.08,.06,.08),glow)
		"parasite":
			ellipsoid(root, Vector3(0,.55,0),Vector3(.3,.6,.26),pale)
			for i: int in 7:
				var a := i * 1.1
				ellipsoid(root, Vector3(cos(a)*.27,.18+i*.14,sin(a)*.27),Vector3(.2,.16,.19),body)
			ellipsoid(root,Vector3(.2,1.04,.24),Vector3(.14,.15,.08),dark)
		"void":
			ellipsoid(root,Vector3(0,.75,0),Vector3(.25,.3,.25),dark)
			for i: int in 6:
				var a := TAU*i/6.0
				ellipsoid(root,Vector3(cos(a)*.43,.75+sin(a)*.43,0),Vector3(.15,.13,.16),glow)
		"chitin":
			for i: int in 4:
				ellipsoid(root,Vector3(0,.2+i*.23,0),Vector3(.46-i*.07,.2,.39-i*.04),body)
			for side: int in [-1,1]:
				var antenna := ellipsoid(root,Vector3(side*.23,1.18,0),Vector3(.04,.3,.04),pale)
				antenna.rotation.z = -side*.4
				ellipsoid(root,Vector3(side*.33,1.43,0),Vector3(.09,.09,.09),glow)
		"coral":
			for i: int in int(genes.appendages):
				var a := TAU*i/float(genes.appendages)
				var stem := ellipsoid(root,Vector3(cos(a)*.25,.45,sin(a)*.25),Vector3(.08,.5,.08),pale)
				stem.rotation.z = -cos(a)*.5
				ellipsoid(root,Vector3(cos(a)*.46,.87,sin(a)*.36),Vector3(.18,.17,.18),body)
				ellipsoid(root,Vector3(cos(a)*.46,1.0,sin(a)*.36),Vector3(.09,.04,.09),dark)

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
	if not _primitive_meshes.has("sphere"):
		var sphere:=SphereMesh.new();sphere.radius=1;sphere.height=2;sphere.radial_segments=12;sphere.rings=6
		_primitive_meshes["sphere"]=sphere
	var mesh:=_primitive_meshes["sphere"] as SphereMesh
	var node := _mesh(parent, mesh, position, mat)
	node.scale = size
	return node

func box(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	if not _primitive_meshes.has("box"): _primitive_meshes["box"]=BoxMesh.new()
	var node:=_mesh(parent,_primitive_meshes["box"],position,material(color))
	node.scale=size
	return node

func cone(parent: Node3D, position: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var key:="cone:%s:%s"%[radius,height]
	if not _primitive_meshes.has(key):
		var cylinder:=CylinderMesh.new();cylinder.top_radius=.02;cylinder.bottom_radius=radius;cylinder.height=height;cylinder.radial_segments=5
		_primitive_meshes[key]=cylinder
	var mesh:=_primitive_meshes[key] as CylinderMesh
	return _mesh(parent, mesh, position, mat)

func create_plot(unlocked: bool) -> Node3D:
	var root := Node3D.new()
	if unlocked:
		box(root, Vector3(0, -.04, 0), Vector3(.96, .14, .96), Color("c4a174"))
		box(root, Vector3(0, .04, 0), Vector3(.84, .06, .84), Color("72513d"))
		for i: int in 3:
			box(root, Vector3(-.25+i*.25, .078, 0), Vector3(.035, .012, .74), Color("92694a"))
	else:
		for x: float in [-.37,.37]:
			box(root,Vector3(x,.04,-.37),Vector3(.06,.15,.06),Color("ada984"))
	_batch(root)
	return root

func create_island() -> Node3D:
	var root: Node3D=preload("res://scripts/art/GardenArt.gd").garden(self)
	_batch(root)
	return root

func create_decoration(id: String) -> Node3D:
	var entry: Dictionary=Decorations.catalog.get(id,{})
	var root: Node3D=preload("res://scripts/art/GardenArt.gd").decoration(self,String(entry.get("mesh","lamp")))
	_batch(root)
	return root

func create_burst() -> GPUParticles3D:
	var p:=GPUParticles3D.new()
	p.amount=24;p.lifetime=.7;p.one_shot=true;p.explosiveness=1.0
	p.emitting=false
	var m:=ParticleProcessMaterial.new()
	m.direction=Vector3.UP;m.spread=110;m.initial_velocity_min=1;m.initial_velocity_max=2.4
	m.gravity=Vector3(0,-3,0);m.scale_min=.035;m.scale_max=.075
	m.color=Color("e3d68a")
	p.process_material=m
	var mesh:=SphereMesh.new()
	mesh.radius=.5;mesh.height=1;mesh.radial_segments=6;mesh.rings=3
	mesh.material=material(Color("d9dda0"),.3)
	p.draw_pass_1=mesh
	p.visibility_aabb=AABB(Vector3(-3,-3,-3),Vector3(6,6,6))
	return p

func _batch(root: Node3D) -> void:
	# Bake static pieces per material. The plant root still carries gene scale and sway.
	if not batch_meshes: return
	var groups: Dictionary={}
	for child: Node in root.get_children(): _collect_surfaces(child,Transform3D.IDENTITY,groups)
	if groups.is_empty(): return
	var combined:=ArrayMesh.new()
	for key: int in groups:
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pieces: Array=groups[key]
		surface.set_material(pieces[0].material)
		for piece: Dictionary in pieces:
			var source:=piece.mesh as Mesh
			var surface_index:=int(piece.surface)
			if piece.has("vertex_tint"):
				var arrays:=source.surface_get_arrays(surface_index)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var colors:=PackedColorArray();colors.resize(vertices.size())
				var tint: Color=piece.vertex_tint
				# Preserve authored vertex colors, if present, while merging flat materials.
				var original: Variant=arrays[Mesh.ARRAY_COLOR]
				for i: int in colors.size(): colors[i]=tint*(original[i] if original is PackedColorArray and original.size()==colors.size() else Color.WHITE)
				arrays[Mesh.ARRAY_COLOR]=colors
				var colored:=ArrayMesh.new();colored.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				surface.append_from(colored,0,piece.transform)
			else: surface.append_from(source,surface_index,piece.transform)
		surface.commit(combined)
	for child: Node in root.get_children(): root.remove_child(child);child.free()
	_mesh(root,combined,Vector3.ZERO,null)
func _collect_surfaces(node: Node, transform: Transform3D, groups: Dictionary) -> void:
	var local:=transform
	if node is Node3D:
		var spatial:=node as Node3D
		if not spatial.visible: return
		local=transform*spatial.transform
	if node is MeshInstance3D:
		var instance:=node as MeshInstance3D
		if instance.mesh!=null:
			for index: int in instance.mesh.get_surface_count():
				var mat:=instance.get_active_material(index)
				var piece: Dictionary={"mesh":instance.mesh,"surface":index,"material":mat,"transform":local}
				if mat is StandardMaterial3D:
					var standard:=mat as StandardMaterial3D
					if standard.albedo_texture==null and not standard.emission_enabled and standard.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED:
						if _vertex_material==null:
							_vertex_material=StandardMaterial3D.new();_vertex_material.vertex_color_use_as_albedo=true;_vertex_material.roughness=.86
						piece["vertex_tint"]=standard.albedo_color
						piece.material=_vertex_material
				var key: int=piece.material.get_instance_id() if piece.material!=null else 0
				if not groups.has(key): groups[key]=[]
				groups[key].append(piece)
	for child: Node in node.get_children(): _collect_surfaces(child,local,groups)
