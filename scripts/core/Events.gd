extends Node
## Stable gameplay signal seam for future quests, analytics, and audio.
signal crop_planted(plot_index: int, species_id: String)
signal crop_harvested(species_id: String, quantity: int, genes: Dictionary)
signal crop_sold(species_id: String, quantity: int, coins: int)
signal order_fulfilled(order_id: String)
signal species_discovered(species_id: String)
signal toast_requested(message: String)

