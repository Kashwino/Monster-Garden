extends Node
## Stable gameplay signal seam for future quests, analytics, and audio.
signal crop_planted(plot_index: int, species_id: String)
signal crop_harvested(species_id: String, quantity: int, genes: Dictionary)
signal crop_sold(species_id: String, quantity: int, coins: int)
signal order_fulfilled(order_id: String)
signal species_discovered(species_id: String)
signal toast_requested(message: String)
signal reputation_changed(value: int)
signal quest_claimed(quest_id: String)
signal bred(species_id: String, is_new: bool)
signal decoration_placed(decoration_id: String)
signal plot_ready(plot_index: int)
signal purchase_made(item: String, currency: String, amount: int)
signal session_resumed(summary: Dictionary)
signal settings_changed

signal application_paused
signal application_resumed
