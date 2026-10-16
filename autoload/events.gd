extends Node
## Signals that cross systems, so they don't need to know about each other.

signal tiles_toggled(shown: bool)

## Something happened in town worth telling everyone (shown in the town chatter): a raid, a fall.
signal town_event(text: String)

## The resident a player is playing wants to trade at the general store (the HUD opens the shop).
signal shop_requested(r: Node)
