extends CanvasLayer
const Extra = preload("res://scripts/ui/ExtraPanels.gd")
## Presentation and commands only; all prices, availability and transactions live in core.
const INK := Color("13272c")
const PANEL := Color("20373a")
const CREAM := Color("e6edda")
const MUTED := Color("9bafa7")
const LIME := Color("c2dc93")
const GOLD := Color("eed09a")
var _root: Control
var _coins: Label
var _level: Label
var _xp: ProgressBar
var _title: Label
var _detail: Label
var _progress: ProgressBar
var _action: Button
var _hint: Label
var _modal: PanelContainer
var _modal_body: VBoxContainer
var _modal_title: Label
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _tab: String = ""
var _refresh_pending := false
var _coin_tween: Tween
var _display_coins: float = 120
var _order_status: Label
var _order_button: Button

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _theme()
	add_child(_root)
	_build_header()
	_build_footer()
	_build_modal()
	_build_toast()
	Game.restored.connect(_on_restored)
	Game.selection_changed.connect(func(_i: int) -> void: _refresh())
	Game.plot_changed.connect(func(_i: int) -> void: _refresh())
	Economy.changed.connect(_roll_coins)
	LevelXP.changed.connect(_refresh)
	Inventory.changed.connect(_queue_modal_refresh)
	BuyerOrders.changed.connect(_queue_modal_refresh)
	Events.toast_requested.connect(show_toast)
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.timeout.connect(_refresh)
	add_child(timer)
	timer.start()

func _theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 16
	result.set_color("font_color", "Label", CREAM)
	result.set_color("font_color", "Button", CREAM)
	result.set_color("font_disabled_color", "Button", MUTED.darkened(0.2))
	result.set_stylebox("normal", "Button", _style(PANEL.lightened(0.04), 14, 12))
	result.set_stylebox("hover", "Button", _style(PANEL.lightened(0.13), 14, 12))
	result.set_stylebox("pressed", "Button", _style(PANEL.lightened(0.22), 14, 12))
	result.set_stylebox("disabled", "Button", _style(PANEL.darkened(0.12), 14, 12))
	result.set_stylebox("focus", "Button", _style(Color.TRANSPARENT, 14, 0, LIME))
	result.set_stylebox("background", "ProgressBar", _style(Color("344847"), 4, 0))
	result.set_stylebox("fill", "ProgressBar", _style(LIME, 4, 0))
	return result

func _style(color: Color, radius: int = 18, padding: int = 16, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	style.set_border_width_all(1 if border.a > 0 else 0)
	style.border_color = border
	return style

func _label(text: String, size: int = 16, color: Color = CREAM) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.pressed.connect(callback)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		button.add_theme_stylebox_override("normal", _style(LIME, 14, 12))
		button.add_theme_stylebox_override("hover", _style(LIME.lightened(0.12), 14, 12))
		button.add_theme_stylebox_override("pressed", _style(LIME.darkened(0.1), 14, 12))
		button.add_theme_color_override("font_color", INK)
		button.add_theme_color_override("font_hover_color", INK)
		button.add_theme_color_override("font_pressed_color", INK)
	return button

func _panel(parent: Node, color: Color = PANEL) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(color))
	parent.add_child(panel)
	return panel

func _vbox(parent: Node, gap: int = 8) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	parent.add_child(box)
	return box

func _build_header() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.offset_left = 22
	margin.offset_right = -22
	margin.offset_top = 28
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(margin)
	var column := _vbox(margin, 10)
	column.add_child(_label("THE NIGHT NURSERY     /     FIELD 01", 12, MUTED))
	var row := HBoxContainer.new()
	column.add_child(row)
	var name_label := _label("Monster Garden", 30)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var help := _button("?", func() -> void: _open("guide"))
	help.custom_minimum_size = Vector2(48, 48)
	row.add_child(help)
	column.add_child(_label("Cultivate the beautifully strange.", 14, MUTED))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	column.add_child(stats)
	var coin_panel := _panel(stats)
	coin_panel.custom_minimum_size.x = 130
	_coins = _label("120  coins", 20, GOLD)
	coin_panel.add_child(_coins)
	var level_panel := _panel(stats)
	level_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var level_column := _vbox(level_panel, 6)
	_level = _label("KEEPER 01", 12)
	level_column.add_child(_level)
	_xp = ProgressBar.new()
	_xp.custom_minimum_size.y = 6
	_xp.show_percentage = false
	level_column.add_child(_xp)

func _build_footer() -> void:
	var footer := VBoxContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 18
	footer.offset_right = -18
	footer.offset_top = -263
	footer.offset_bottom = -18
	footer.add_theme_constant_override("separation", 12)
	_root.add_child(footer)
	_hint = _label("TAP A PLOT  ·  DRAG TO EXPLORE  ·  PINCH TO ZOOM", 10, MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(_hint)
	var selection := _panel(footer, INK.lightened(0.035))
	var column := _vbox(selection, 6)
	_title = _label("Your first strange harvest", 20)
	column.add_child(_title)
	_detail = _label("", 13, MUTED)
	column.add_child(_detail)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.custom_minimum_size.y = 5
	column.add_child(_progress)
	_action = _button("Harvest", _selected_action, true)
	column.add_child(_action)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	footer.add_child(nav)
	for tab: String in ["seeds", "basket", "orders", "codex", "breed"]:
		var button := _button(tab.capitalize(), _open.bind(tab))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		nav.add_child(button)

func _build_modal() -> void:
	_modal = PanelContainer.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.offset_left = 12
	_modal.offset_right = -12
	_modal.offset_top = 216
	_modal.offset_bottom = -18
	_modal.add_theme_stylebox_override("panel", _style(INK, 22, 20, Color("3b554c")))
	_root.add_child(_modal)
	var column := _vbox(_modal, 16)
	var row := HBoxContainer.new()
	column.add_child(row)
	_modal_title = _label("Seeds", 25)
	_modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_modal_title)
	row.add_child(_button("Close", _close))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_modal_body = _vbox(scroll, 12)
	_modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal.hide()

func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 220
	_toast.offset_left = -215
	_toast.offset_right = 215
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_stylebox_override("panel", _style(LIME, 16, 14))
	_toast_label = _label("", 15, INK)
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_child(_toast_label)
	_root.add_child(_toast)
	_toast.hide()

func show_toast(message: String) -> void:
	if is_instance_valid(_toast_tween):
		_toast_tween.kill()
	_toast_label.text = message
	_toast.modulate.a = 1
	_toast.show()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_toast.hide)

func _on_restored() -> void:
	_display_coins = Economy.coins
	_refresh()
	if Game.offline_message != "":
		show_toast(Game.offline_message)

func _roll_coins() -> void:
	if is_instance_valid(_coin_tween):
		_coin_tween.kill()
	_coin_tween = create_tween()
	_coin_tween.tween_method(func(value: float) -> void:
		_display_coins = value
		_coins.text = "%d  coins" % int(value), _display_coins, float(Economy.coins), 0.35)
	_queue_modal_refresh()

func _refresh() -> void:
	if Game.plots.is_empty():
		return
	if _tab == "orders" and not BuyerOrders.active.is_empty() and is_instance_valid(_order_status):
		var order := BuyerOrders.active
		_order_status.text = "%d / %d collected · %s left" % [Inventory.count_species(order.species_id), order.quantity, _duration(maxi(0, int(float(order.expires_at) - Game.now()))) ]
		_order_button.disabled = not BuyerOrders.can_fulfill()
	_coins.text = "%d  coins" % int(_display_coins)
	_level.text = "KEEPER %02d    ·    %d / %d XP" % [LevelXP.level, LevelXP.xp, LevelXP.required_xp()]
	_xp.max_value = LevelXP.required_xp()
	_xp.value = LevelXP.xp
	var index := Game.selected_plot
	var plot := Game.plots[index]
	_progress.value = Game.progress(index) * 100
	_action.disabled = false
	if not bool(plot.unlocked):
		_title.text = "Untamed earth · plot %02d" % (index + 1)
		_detail.text = "Opens at keeper level %d" % Game.plot_unlock_level(index)
		_action.text = "Expand garden · %d coins" % Game.plot_unlock_cost(index)
		_action.disabled = LevelXP.level < Game.plot_unlock_level(index) or Economy.coins < Game.plot_unlock_cost(index)
	elif plot.species_id == "":
		_title.text = "Something strange belongs here"
		_detail.text = "Empty plot %02d · choose a seed to begin" % (index + 1)
		_action.text = "Choose a monster seed"
	else:
		var entry := Catalog.get_species(plot.species_id)
		_title.text = entry.name
		if Game.progress(index) >= 1:
			_detail.text = "%s · %d crops · +%d XP" % [entry.family.capitalize(), entry.yield, entry.xp]
			_action.text = "Harvest monster plant"
		else:
			_detail.text = "%s · %s remaining" % [Catalog.stage_for(Game.progress(index)).capitalize(), _duration(Game.remaining(index))]
			_action.text = "Growing in real time…"
			_action.disabled = true

func _selected_action() -> void:
	var plot := Game.plots[Game.selected_plot]
	if not bool(plot.unlocked):
		Game.unlock_plot(Game.selected_plot)
	elif plot.species_id == "":
		_open("seeds")
	else:
		Game.harvest(Game.selected_plot)

func _open(tab: String) -> void:
	_tab = tab
	_render_modal()
	_modal.show()

func _close() -> void:
	_tab = ""
	_modal.hide()

func _queue_modal_refresh() -> void:
	if not _refresh_pending:
		_refresh_pending = true
		call_deferred("_refresh_modal")

func _refresh_modal() -> void:
	_refresh_pending = false
	if _tab != "":
		_render_modal()

func _card(title: String, description: String, color: Color = CREAM) -> VBoxContainer:
	var panel := _panel(_modal_body)
	var column := _vbox(panel, 8)
	column.add_child(_label(title, 19, color))
	var detail := _label(description, 14, MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(detail)
	return column

func _render_modal() -> void:
	for child: Node in _modal_body.get_children():
		_modal_body.remove_child(child)
		child.queue_free()
	_modal_title.text = {"seeds": "The seed cabinet", "basket": "Your harvest", "orders": "The night courier", "codex": "Field notes", "guide": "A keeper’s guide"}.get(_tab, "")
	match _tab:
		"breed":
			Extra.breed(self)
		"events":
			Extra.events(self)
		"seeds":
			_modal_body.add_child(_button("Seasonal events & spore drifts", _open.bind("events")))
			for seed: Dictionary in Inventory.seeds:
				var c := _card("Owned seed · " + Catalog.get_species(seed.species_id).name, "%d seeds · gene glow %.2f" % [seed.quantity, seed.genes.glow])
				c.add_child(_button("Plant owned seed", func() -> void:
					if Game.plant_seed(Game.selected_plot, seed.key): _close()
					else: show_toast("Select an empty purchased plot first."), true))
			for id: String in Catalog.species:
				var entry := Catalog.get_species(id)
				var available := Catalog.is_available(id, LevelXP.level)
				var column := _card(entry.name, entry.description, Color.from_hsv(float(entry.genes.hue), 0.3, 0.95) if available else MUTED)
				column.add_child(_label("%s  ·  %s  ·  %d crops" % [entry.rarity, _duration(int(entry.grow_seconds)), entry.yield], 12, GOLD))
				var button := _button("Plant · %d coins" % entry.seed_cost if available else "Locked · " + UnlockManager.unlock_text(id), _plant.bind(id), available)
				button.disabled = not available or Economy.coins < int(entry.seed_cost)
				column.add_child(button)
		"basket":
			if Inventory.stacks.is_empty():
				_card("Quiet for now", "Harvest a fully grown monster plant. Sell it here, or save it for a courier order worth twice as much.")
			for id: String in Catalog.species:
				var count := Inventory.count_species(id)
				if count == 0:
					continue
				var entry := Catalog.get_species(id)
				var column := _card("%s × %d" % [entry.name, count], "Individual genes are preserved in your harvest stacks.")
				column.add_child(_button("Sell all · %d coins" % (count * int(entry.sell_value)), func() -> void: Economy.sell(id, count), true))
		"orders":
			if BuyerOrders.active.is_empty():
				_card("The courier will return", "A new request will arrive shortly. Close and reopen this board to check.")
			else:
				var order := BuyerOrders.active
				var entry := Catalog.get_species(order.species_id)
				var column := _card("A parcel for the other side", "Bring %d %s to the night courier." % [order.quantity, entry.name])
				_order_status = _label("%d / %d collected · %s left" % [Inventory.count_species(order.species_id), order.quantity, _duration(maxi(0, int(float(order.expires_at) - Game.now())))], 14, MUTED)
				column.add_child(_order_status)
				column.add_child(_label("REWARD   %d coins  +  %d XP" % [order.coins, order.xp], 15, GOLD))
				var button := _button("Fulfil delivery", func() -> void: BuyerOrders.fulfill(), true)
				button.disabled = not BuyerOrders.can_fulfill()
				_order_button = button
				column.add_child(button)
			_card("Worth the wait", "Courier orders pay double the basket price. Requests expire after 15 minutes; the next courier arrives after a short cooldown.")
		"codex":
			_card("%d / %d specimens recorded" % [Game.discovered.size(), Catalog.species.size()], "Ten families. One hundred and twenty strange lives. Harvest a species to record it in your field notes.", LIME)
			for id: String in Catalog.species:
				var entry := Catalog.get_species(id)
				var found := Game.discovered.has(id)
				_card(entry.name if found else "Unknown · " + entry.family.capitalize(), entry.description if found else "%s · %s" % [entry.rarity, UnlockManager.unlock_text(id)], CREAM if found else MUTED)
		"guide":
			_card("01 / Wake the garden", "Tap the Witness Bud marked READY, then Harvest. Choose an empty plot and plant another seed. Common plants take 30 seconds, even when the game is closed.")
			_card("02 / Feed the strange", "Sell harvested plants from your basket, or fulfil a courier order for more coins. Harvest and delivery XP unlock new species and plots.")
			_card("03 / Make room", "Tap a locked plot to see its level and coin cost. Drag the garden to pan; pinch to zoom. On desktop, use the mouse wheel.")
			_card("Saved as you grow", "Your garden saves after transactions, every 15 seconds and when the app pauses. No account or internet connection is required.")
			_card("Monster Garden · foundation", "Original procedural monster art. Built with Godot 4.3. Advanced breeding, quests and cloud services are planned for later phases.")

func _plant(id: String) -> void:
	var index := Game.selected_plot
	if not bool(Game.plots[index].unlocked) or Game.plots[index].species_id != "":
		show_toast("Select an empty unlocked plot before planting.")
		_close()
		return
	if Game.plant(index, id):
		_close()

func _duration(seconds: int) -> String:
	if seconds < 60:
		return "%ds" % seconds
	if seconds < 3600:
		return "%dm %02ds" % [seconds / 60, seconds % 60]
	return "%dh %02dm" % [seconds / 3600, (seconds % 3600) / 60]
