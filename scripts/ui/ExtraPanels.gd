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
