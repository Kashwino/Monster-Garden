extends RefCounted
## Additional views call gameplay commands; validation/rewards stay in modules.
static func breed(h: Node) -> void:
	h._modal_title.text = "The grafting house"
	if not Breeding.bench_owned:
		var c: VBoxContainer = h._card("Build a breeding bench", "Combine two harvested plants to create a seed carrying both parents’ genes. Available at level %d." % Breeding.BENCH_LEVEL)
		var buy: Button = h._button("Build · %d coins" % Breeding.BENCH_COST, func() -> void: Breeding.buy_bench(); h._queue_modal_refresh(), true)
		buy.disabled = LevelXP.level < Breeding.BENCH_LEVEL or Economy.coins < Breeding.BENCH_COST
		c.add_child(buy)
		return
	var box: VBoxContainer = h._card("Choose two parents", "Identical stacks need two units. A luminous lineage can reveal a rare species; every graft keeps its genes.")
	if Inventory.stacks.is_empty():
		box.add_child(h._label("Harvest two crops to begin."))
		return
	var first := OptionButton.new()
	var second := OptionButton.new()
	for stack: Dictionary in Inventory.stacks:
		var name := "%s ×%d · glow %.2f" % [Catalog.get_species(stack.species_id).name, stack.quantity, stack.genes.glow]
		first.add_item(name)
		first.set_item_metadata(first.item_count-1, stack.key)
		second.add_item(name)
		second.set_item_metadata(second.item_count-1, stack.key)
	for option: OptionButton in [first, second]:
		option.custom_minimum_size.y = 48
		option.clip_text = true
		box.add_child(option)
	var graft: Button = h._button("Graft a seed", func() -> void:
		var result := Breeding.combine(String(first.get_item_metadata(first.selected)), String(second.get_item_metadata(second.selected)))
		if result.is_empty(): h.show_toast("Choose two available crop units.")
		h._queue_modal_refresh(), true)
	box.add_child(graft)
	if not Breeding.last_result.is_empty():
		h._card("Last graft: " + Catalog.get_species(Breeding.last_result.species_id).name, "Your new seed is in the seed cabinet. Plant it without paying another seed cost.")

static func events(h: Node) -> void:
	h._modal_title.text = "Strange arrivals"
	if not UnlockManager.drift.is_empty():
		var c: VBoxContainer = h._card("A spore drift!", "A rare visitor is available for 30 minutes. Claim it before it passes.")
		c.add_child(h._button("Welcome the stranger", func() -> void: UnlockManager.claim_drift(); h._queue_modal_refresh(), true))
	for id: String in Catalog.events:
		var event: Dictionary = Catalog.events[id]
		if event.kind != "season" or UnlockManager.granted.has(id): continue
		var c: VBoxContainer = h._card(event.label, "Window: %s to %s UTC" % [event.start, event.end])
		var button: Button = h._button("Claim species" if UnlockManager.season_active(id) else "Outside event window", func() -> void: UnlockManager.claim_season(id); h._queue_modal_refresh(), true)
		button.disabled = not UnlockManager.season_active(id)
		c.add_child(button)

static func orders(h: Node) -> void:
	h._card("Courier reputation %d · tier %d" % [BuyerOrders.reputation,BuyerOrders.tier()], "Deliveries raise reputation. Expired requests lower it. New tiers add mixed and gene-specific requests.")
	for i: int in BuyerOrders.slots.size():
		var slot:=BuyerOrders.slots[i]
		var order: Dictionary=slot.order
		if order.is_empty():
			h._card("Courier %d is returning"%(i+1),"This slot refills after its cooldown.")
			continue
		var lines: PackedStringArray=[]
		for request: Dictionary in order.requests:
			var name:=String(Catalog.get_species(request.species_id).name) if request.has("species_id") else String(request.family).capitalize()+" family"
			lines.append("%d × %s%s"%[request.quantity,name," · glow ≥ %.2f"%request.min_glow if request.has("min_glow") else ""])
		var c: VBoxContainer=h._card("%d / %s request"%[i+1,String(order.type).capitalize()],"\n".join(lines))
		var countdown: Label=h._label("",13)
		c.add_child(countdown)
		var timer:=Timer.new()
		timer.wait_time=1
		var update:=func() -> void: countdown.text="%s left · %d coins · %d XP"%[h._duration(maxi(0,int(float(order.expires_at)-Game.now()))),order.coins,order.xp]
		update.call();timer.timeout.connect(update);c.add_child(timer);timer.start()
		var fulfill: Button=h._button("Fulfil delivery",func() -> void: BuyerOrders.fulfill(i),true)
		fulfill.disabled=not BuyerOrders.can_fulfill(i)
		c.add_child(fulfill)
		c.add_child(h._button("Reroll · %d coins"%BuyerOrders.reroll_cost(),func() -> void: BuyerOrders.reroll(i)))
		c.add_child(h._button("Instant reroll · 2 gems",func() -> void: BuyerOrders.reroll(i,"gems")))

static func boosters(h: Node) -> void:
	h._modal_title.text="Gems & growth"
	var c: VBoxContainer=h._card("%d gems · %d fertiliser"%[Premium.gems,Premium.fertiliser],"Earn gems through keeper levels, quests and first discoveries.")
	var index:=Game.selected_plot
	if Premium.can_boost(index):
		c.add_child(h._button("Finish selected crop · %d gems"%Premium.finish_cost(index),func() -> void: Premium.finish(index);h._queue_modal_refresh(),true))
		c.add_child(h._button("Apply fertiliser · 35% less waiting",func() -> void: Premium.apply_fertiliser(index);h._queue_modal_refresh()))
		c.add_child(h._label("Fertiliser also increases harvest mutations.",12))
	if not Game.plots[index].unlocked:
		var plot_buy: Button=h._button("Buy plot · %d gems"%Premium.plot_cost(index),func() -> void: Game.unlock_plot(index,"gems");h._queue_modal_refresh())
		plot_buy.disabled=LevelXP.level<Game.plot_unlock_level(index)
		c.add_child(plot_buy)
	c.add_child(h._button("Buy fertiliser · 20 coins",func() -> void: Premium.buy_fertiliser();h._queue_modal_refresh()))
	for id: String in UnlockManager.available_ids():
		var cost:=Premium.rare_seed_cost(id)
		if cost<=0: continue
		var box: VBoxContainer=h._card(Catalog.get_species(id).name,"Rare seed · standard genes")
		box.add_child(h._button("Buy seed · %d gems"%cost,func() -> void: Premium.buy_rare_seed(id)))

static func decorations(h: Node) -> void:
	h._modal_title.text="The garden atelier"
	h._card("Make the grounds your own", "Buy ornaments as your keeper level rises, then choose a garden site. Store or move them freely.")
	var names: Array[String]=["NW estate","NE estate","Centre fountain","West upper","East upper","West middle","East middle","West lower","East lower","West courtyard","East courtyard","Entrance"]
	for key: String in Decorations.placements:
		var entry: Dictionary=Decorations.placements[key]
		var c: VBoxContainer=h._card(names[int(key)],Decorations.catalog[entry.id].name)
		var destination:=OptionButton.new()
		for slot: int in GardenLayout.DECOR_SLOTS.size():
			if not Decorations.placements.has(str(slot)):
				destination.add_item(names[slot]);destination.set_item_metadata(destination.item_count-1,slot)
		if destination.item_count>0:
			destination.custom_minimum_size.y=48;c.add_child(destination)
			c.add_child(h._button("Move to selected site",func() -> void: Decorations.move(int(key),int(destination.get_item_metadata(destination.selected)))))
		c.add_child(h._button("Return to storage",func() -> void: Decorations.remove(int(key))))
	for id: String in Decorations.catalog:
		var e: Dictionary=Decorations.catalog[id]
		var c: VBoxContainer=h._card(e.name,"Level %d · %d coins\n%s"%[e.level,e.cost,e.description])
		var buy: Button=h._button("Buy ornament" if LevelXP.level>=int(e.level) else "Unlocks at level %d"%e.level,func() -> void: Decorations.buy(id),true)
		buy.disabled=not Decorations.can_buy(id);c.add_child(buy)
		if int(Decorations.storage.get(id,0))>0:
			var destination:=OptionButton.new()
			for slot: int in GardenLayout.DECOR_SLOTS.size():
				if not Decorations.placements.has(str(slot)):
					destination.add_item(names[slot]);destination.set_item_metadata(destination.item_count-1,slot)
			if destination.item_count>0:
				destination.custom_minimum_size.y=48;c.add_child(destination)
				c.add_child(h._button("Place owned ornament (%d)"%Decorations.storage[id],func() -> void: Decorations.place(id,int(destination.get_item_metadata(destination.selected))),true))

static func settings(h: Node) -> void:
	h._modal_title.text="Settings"
	var sound: VBoxContainer=h._card("Sound", "Music, creature sounds and interface feedback.")
	for category: String in AudioManager.volumes:
		sound.add_child(h._label(category,14))
		var slider:=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=.05
		slider.value=float(AudioManager.volumes[category]);slider.custom_minimum_size.y=44
		slider.value_changed.connect(func(value: float) -> void: AudioManager.set_volume(category,value))
		slider.drag_ended.connect(func(_changed: bool) -> void: Game.persist());sound.add_child(slider)
	var notice: VBoxContainer=h._card("Crop reminders", "A reminder when all your growing plants are ready.")
	var notifications:=CheckButton.new();notifications.text="Enable notifications";notifications.button_pressed=Notifications.enabled
	notifications.custom_minimum_size.y=48;notifications.toggled.connect(Notifications.set_enabled);notice.add_child(notifications)
	if not Notifications.supported(): notice.add_child(h._label("Reminders are unavailable on this build.",12))
	var graphics: VBoxContainer=h._card("Garden detail", "Reduce effects for a quieter, lighter garden.")
	var shadows:=CheckButton.new();shadows.text="Show shadows";shadows.button_pressed=Settings.shadows;shadows.custom_minimum_size.y=48
	shadows.toggled.connect(func(value: bool) -> void: Settings.set_graphics(value,Settings.particle_density));graphics.add_child(shadows)
	var density:=OptionButton.new();density.add_item("Particles: full");density.add_item("Particles: half");density.add_item("Particles: off")
	density.selected=0 if Settings.particle_density>.5 else 1 if Settings.particle_density>0 else 2;density.custom_minimum_size.y=48
	density.item_selected.connect(func(index: int) -> void: Settings.set_graphics(Settings.shadows,[1.0,.5,0.0][index]));graphics.add_child(density)
	h._card("Credits", "Monster Garden · original creature models, garden geometry, icon and synthesized sounds. Made with Godot 4.3 (MIT). Inspired by the garden layout you shared; no artwork copied from it.")
	var erase: VBoxContainer=h._card("Start a new garden", "Permanently replaces this garden’s progress, crops, coins and collection. Cloud sync, if enabled, will use the new garden.")
	erase.add_child(h._button("Reset all progress…",func() -> void:
		var dialog:=ConfirmationDialog.new();dialog.title="Reset your garden?"
		dialog.dialog_text="This permanently removes all progress.\nStart again with six starter plots?";dialog.ok_button_text="Reset garden"
		h._root.add_child(dialog)
		dialog.confirmed.connect(func() -> void: dialog.queue_free();h._close();Game.reset_garden())
		dialog.canceled.connect(dialog.queue_free);dialog.popup_centered(Vector2i(380,180))))
