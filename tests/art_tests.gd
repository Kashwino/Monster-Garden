extends SceneTree
var _checks := 0
var _failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var factory := root.get_node("AssetFactory")
	factory.batch_meshes=false
	var catalog := root.get_node("Catalog")
	var stage_paths: Array[String] = []
	for stage: String in catalog.STAGES:
		var plant: Node3D = factory.create("witness_bud", stage)
		var source := String(plant.get_meta("asset_source"))
		check(source.ends_with(stage + ".glb"), stage + " resolves to real GLB")
		check(plant.get_child_count() > 0, stage + " has instanced geometry")
		stage_paths.append(source)
		plant.free()
	var entry: Dictionary = catalog.species.witness_bud
	var original: Dictionary = entry.mesh.duplicate(true)
	entry.mesh.stages.blooming.scene = stage_paths[1]
	var swap: Node3D = factory.create("witness_bud", "blooming")
	check(swap.get_meta("asset_source") == stage_paths[1], "catalog-only path change swaps GLB without caller changes")
	swap.free()
	entry.mesh.stages.blooming.scene = "res://assets/does-not-exist.glb"
	var fallback: Node3D = factory.create("witness_bud", "blooming")
	check(fallback.get_meta("asset_source") == "primitive:eye", "missing GLB gracefully falls back to old primitive")
	fallback.free()
	entry.mesh = original
	var first: Node3D = factory.create("witness_bud", "blooming", {"hue":0.1, "scale":0.6, "appendages":2})
	var second: Node3D = factory.create("witness_bud", "blooming", {"hue":0.8, "scale":1.3, "appendages":5})
	check(is_equal_approx(first.scale.x, 0.6) and is_equal_approx(second.scale.x, 1.3), "instance scale genes drive visuals")
	var body_a := first.find_child("Body", true, false) as MeshInstance3D
	var body_b := second.find_child("Body", true, false) as MeshInstance3D
	check(body_a != null and body_b != null, "GLB contains named body geometry")
	if body_a != null and body_b != null:
		var mat_a := body_a.get_active_material(0) as StandardMaterial3D
		var mat_b := body_b.get_active_material(0) as StandardMaterial3D
		check(mat_a != mat_b and mat_a.albedo_color != mat_b.albedo_color, "gene materials are isolated between cached scene instances")
	var hidden := first.find_child("Appendage_3", true, false) as Node3D
	var visible_appendage := second.find_child("Appendage_3", true, false) as Node3D
	check(hidden != null and visible_appendage != null and not hidden.visible and visible_appendage.visible, "appendage count gene hides optional GLB parts")
	first.free()
	second.free()
	for id: String in catalog.species:
		for stage: String in catalog.STAGES:
			var plant: Node3D = factory.create(id, stage)
			check(plant.get_child_count() > 0, id + "/" + stage + " has a model")
			plant.free()
	print("RESULT: %d art checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)
