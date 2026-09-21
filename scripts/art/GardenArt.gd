extends RefCounted
## Mesh authoring helper used exclusively by AssetFactory.
static func garden(f: Node) -> Node3D:
	var root:=Node3D.new()
	f.box(root,Vector3(0,-.6,0),Vector3(13,.8,14),Color("52764c"))
	f.box(root,Vector3(0,-.16,0),Vector3(13.2,.12,14.2),Color("8eaf57"))
	# Formal avenues, blue canals and clipped hedges echo a miniature estate.
	for z: float in [-6.0,-2.7,2.1,5.3]:
		f.box(root,Vector3(0,-.07,z),Vector3(11.8,.05,.48),Color("e0c994"))
	for x: float in [-4.4,0.0,4.4]:
		f.box(root,Vector3(x,-.06,0),Vector3(.55,.05,12),Color("e0c994"))
	for x: float in [-1.0,1.0]:
		f.box(root,Vector3(x,-.055,-4.1),Vector3(.75,.04,2.5),Color("587e74"))
		f.box(root,Vector3(x,-.02,-4.1),Vector3(.58,.03,2.3),Color("42b4c8"))
		for z: float in [-4.8,-3.7]: f.box(root,Vector3(x,.01,z),Vector3(.35,.02,.035),Color("94dfdf"))
	for x: float in [-2.65,2.65]:
		for z: float in [-2.95,2.05,5.2]:
			f.box(root,Vector3(x,.13,z),Vector3(3.3,.32,.22),Color("426f3c"))
			for i: int in 12:
				var pos:=Vector3(x-1.45+i*.26,.3,z)
				f.ellipsoid(root,pos,Vector3(.07,.11,.07),f.material(Color("dd77a6") if i%2==0 else Color("d9bb5c")))
	# Low fences leave sight-lines to the plants clear.
	for x: float in [-6.0,6.0]:
		for i: int in 21:
			f.box(root,Vector3(x,.3,-5.8+i*.57),Vector3(.08,.65,.08),Color("f2e6c6"))
		for y: float in [.2,.48]: f.box(root,Vector3(x,y,0),Vector3(.07,.065,12),Color("eadfbf"))
	for z: float in [-6.1,6.1]:
		for i: int in 21:
			var x: float=-5.8+i*.57
			if absf(x)<.7: continue
			f.box(root,Vector3(x,.3,z),Vector3(.08,.65,.08),Color("f2e6c6"))
		for x: float in [-3.4,3.4]:
			for y: float in [.2,.48]: f.box(root,Vector3(x,y,z),Vector3(5.2,.065,.07),Color("eadfbf"))
	for pos: Vector3 in [Vector3(-5.2,0,-5.2),Vector3(5.2,0,-5.2),Vector3(-5.1,0,4.6),Vector3(5.1,0,4.6)]:
		tree(f,root,pos)
	# The keeper's small house is scenery; estate buildings must be bought.
	var home:=decoration(f,"gazebo")
	home.position=Vector3(0,0,-6.1);home.scale=Vector3.ONE*.8;root.add_child(home)
	for i: int in GardenLayout.DECOR_SLOTS.size():
		f.box(root,GardenLayout.DECOR_SLOTS[i]+Vector3(0,-.05,0),Vector3(1.15,.05,1.15),Color("94ae67"))
	return root

static func tree(f: Node, root: Node3D, pos: Vector3) -> void:
	f.box(root,pos+Vector3(0,.65,0),Vector3(.18,1.3,.18),Color("786044"))
	for i: int in 3:
		f.ellipsoid(root,pos+Vector3((i-1)*.27,1.4+i*.25,0),Vector3(.48,.55,.43),f.material(Color("497e4a").lightened(i*.065)))
	f.ellipsoid(root,pos+Vector3(.1,1.5,.43),Vector3(.14,.19,.08),f.material(Color("e9e3b0")))
	f.ellipsoid(root,pos+Vector3(.14,1.5,.49),Vector3(.055,.13,.03),f.material(Color("203b37")))

static func decoration(f: Node, kind: String) -> Node3D:
	var r:=Node3D.new()
	var stone:=Color("ded5b6")
	var roof:=Color("497b86")
	var dark:=Color("395453")
	match kind:
		"lamp":
			f.box(r,Vector3(0,.55,0),Vector3(.12,1.1,.12),dark)
			f.ellipsoid(r,Vector3(0,1.15,0),Vector3(.3,.32,.3),f.material(Color("e6bb70"),.6))
			f.cone(r,Vector3(0,1.44,0),.38,.25,f.material(roof))
		"topiary": tree(f,r,Vector3.ZERO)
		"pond", "fountain":
			f.ellipsoid(r,Vector3(0,.08,0),Vector3(.85,.16,.85),f.material(stone))
			f.ellipsoid(r,Vector3(0,.2,0),Vector3(.72,.035,.72),f.material(Color("49bed0")))
			if kind=="fountain":
				f.cone(r,Vector3(0,.55,0),.24,.9,f.material(stone))
				f.ellipsoid(r,Vector3(0,1.02,0),Vector3(.35,.1,.35),f.material(stone))
				f.ellipsoid(r,Vector3(0,1.22,0),Vector3(.08,.3,.08),f.material(Color("99e1da"),.2))
		"gazebo", "arch":
			f.box(r,Vector3(0,.1,0),Vector3(1.5,.2,1.5),stone)
			for x: float in [-.57,.57]:
				for z: float in [-.57,.57]:
					f.box(r,Vector3(x,.8,z),Vector3(.14,1.5,.14),stone)
			f.box(r,Vector3(0,1.55,0),Vector3(1.5,.18,1.5),stone)
			f.cone(r,Vector3(0,1.95,0),1.13,.75,f.material(Color("bb8067")))
			if kind=="arch":
				for i: int in 5: f.ellipsoid(r,Vector3(-.65+i*.3,1.7,.65),Vector3(.22,.24,.17),f.material(Color("82778f")))
		"greenhouse":
			f.box(r,Vector3(0,.13,0),Vector3(2.1,.26,1.8),stone)
			f.box(r,Vector3(0,.8,0),Vector3(1.95,1.3,1.65),Color("79c2c4"))
			var dome: MeshInstance3D=f.ellipsoid(r,Vector3(0,1.45,0),Vector3(1.0,.65,.86),f.material(Color("a2d4d3")))
			dome.name="GlassRoof"
			for x: float in [-.97,-.49,0,.49,.97]:
				for z: float in [-.86,.86]: f.box(r,Vector3(x,.88,z),Vector3(.055,1.5,.055),stone)
			for y: float in [.3,1,1.45]:
				for z: float in [-.87,.87]: f.box(r,Vector3(0,y,z),Vector3(2.05,.045,.045),stone)
			for x: float in [-1,1]: f.box(r,Vector3(x,.86,0),Vector3(.06,1.5,1.7),Color("acd5cb"))
		"castle", "tower", "observatory":
			f.box(r,Vector3(0,.7,0),Vector3(1.6,1.4,1.45),stone)
			f.box(r,Vector3(0,1.43,0),Vector3(1.75,.15,1.6),Color("f1e4ca"))
			for x: float in [-.72,.72]:
				for z: float in [-.64,.64]:
					f.box(r,Vector3(x,1.15,z),Vector3(.48,2.3,.48),stone)
					f.cone(r,Vector3(x,2.55,z),.44,.65,f.material(roof))
			for x: float in [-.43,0,.43]:
				f.box(r,Vector3(x,.97,.735),Vector3(.17,.4,.025),dark)
				f.box(r,Vector3(x,.97,-.735),Vector3(.17,.4,.025),dark)
			f.box(r,Vector3(0,.38,.74),Vector3(.36,.76,.035),Color("8b6955"))
			if kind=="observatory": f.ellipsoid(r,Vector3(0,1.6,0),Vector3(.8,.8,.8),f.material(Color("8db3cf")))
			if kind=="tower": r.scale=Vector3(.65,1.45,.65)
	return r
