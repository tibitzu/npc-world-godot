class_name Items
extends RefCounted
## Treasure and trade (as in the HTML game): every kind of thing that can be found, carried,
## used, bought or sold, and the general store's stock and till.
##
## Values are in gold; a gold coin is worth 10 silver. Tilda sells at an item's value and buys
## back at half of it. The chests in the goblins' lair hold gems, weapons, potions, odds and ends
## and the occasional bit of magic, and coin (see GoblinLair).
##
## Using things (from the inventory, I): a weapon is wielded in place of the tool of their trade
## (and put away again); a healing potion restores health; the elixir of strength adds 3 to
## every blow for a while; the ring of protection takes 2 off every blow that lands; the cloak of
## shadows makes goblins see the wearer only from half as far. An ability potion adds 4 to one of
## the six abilities for six hours (see Abilities). Gems are for selling.
##
## Charisma shifts Tilda's prices: 5% off what you buy and 5% more for what you sell per point of
## modifier, at most 25% either way (and worse, for the uncharming).

const ALL := {
	# gems
	"ruby": {"name": "Ruby", "type": "gem", "value": 50},
	"sapphire": {"name": "Sapphire", "type": "gem", "value": 50},
	"emerald": {"name": "Emerald", "type": "gem", "value": 60},
	"amethyst": {"name": "Amethyst", "type": "gem", "value": 30},
	"topaz": {"name": "Topaz", "type": "gem", "value": 25},
	"diamond": {"name": "Diamond", "type": "gem", "value": 120},
	# weapons (damage per hit, reach in metres, seconds between blows)
	"dagger": {"name": "Steel dagger", "type": "weapon", "value": 8, "dmg": Vector2i(3, 6), "reach": 1.4, "cd": 0.6},
	"shortsword": {"name": "Short sword", "type": "weapon", "value": 15, "dmg": Vector2i(5, 9), "reach": 1.7, "cd": 0.9},
	"mace": {"name": "Flanged mace", "type": "weapon", "value": 20, "dmg": Vector2i(6, 10), "reach": 1.6, "cd": 1.1},
	"waraxe": {"name": "War axe", "type": "weapon", "value": 25, "dmg": Vector2i(7, 12), "reach": 1.8, "cd": 1.3},
	# odds and ends
	"rope": {"name": "Coil of rope", "type": "utility", "value": 2},
	"lockpicks": {"name": "Lockpicks", "type": "utility", "value": 10},
	"torch": {"name": "Torch", "type": "utility", "value": 1},
	"oil": {"name": "Flask of lantern oil", "type": "utility", "value": 2},
	"compass": {"name": "Brass compass", "type": "utility", "value": 12},
	"tinderbox": {"name": "Tinderbox", "type": "utility", "value": 3},
	"grapple": {"name": "Grappling hook", "type": "utility", "value": 6},
	# potions
	"healminor": {"name": "Minor potion of healing", "type": "potion", "value": 20, "heal": 20.0},
	"healpot": {"name": "Potion of healing", "type": "potion", "value": 50, "heal": 40.0},
	"healgreater": {"name": "Greater potion of healing", "type": "potion", "value": 120, "heal": 80.0},
	"healsuperior": {"name": "Superior potion of healing", "type": "potion", "value": 250, "heal": 9999.0},
	"elixir": {"name": "Elixir of strength", "type": "potion", "value": 90, "might": 3},
	"potstr": {"name": "Potion of bull's strength", "type": "potion", "value": 70, "ab": "str", "amt": 4},
	"potagi": {"name": "Potion of cat's grace", "type": "potion", "value": 70, "ab": "agi", "amt": 4},
	"potcon": {"name": "Potion of bear's endurance", "type": "potion", "value": 70, "ab": "con", "amt": 4},
	"potint": {"name": "Potion of fox's cunning", "type": "potion", "value": 60, "ab": "int", "amt": 4},
	"potwis": {"name": "Potion of owl's wisdom", "type": "potion", "value": 60, "ab": "wis", "amt": 4},
	"potcha": {"name": "Potion of eagle's splendour", "type": "potion", "value": 50, "ab": "cha", "amt": 4},
	# magic
	"ringprot": {"name": "Ring of protection", "type": "magic", "value": 200, "slot": "ring", "armour": 2},
	"cloak": {"name": "Cloak of shadows", "type": "magic", "value": 220, "slot": "back"},
	"amulet": {"name": "Amulet of warding", "type": "magic", "value": 180},
	"wand": {"name": "Wand of sparks", "type": "magic", "value": 150},
	"scroll": {"name": "Scroll of light", "type": "magic", "value": 40},
}
const TYPE_COLOURS := {"gem": Color(0.5, 0.83, 1.0), "weapon": Color(0.94, 0.54, 0.48), "utility": Color(0.79, 0.71, 0.54),
	"potion": Color(1.0, 0.56, 0.64), "magic": Color(0.79, 0.64, 1.0)}
const MIGHT_FOR := 20.0            # game seconds the elixir of strength lasts (four hours)

## What Tilda keeps on her shelves (restocked each morning), and what's in her till (silver).
const SHOP_BASE := {"healminor": 4, "healpot": 3, "healgreater": 1, "elixir": 1, "potstr": 1, "potagi": 1, "potcon": 1,
	"potwis": 1, "torch": 4, "rope": 2, "oil": 3,
	"tinderbox": 2, "compass": 1, "lockpicks": 1, "dagger": 2, "shortsword": 1, "mace": 1}
const SHOP_COIN := 3000

static var shop_stock := {}
static var shop_coin := -1


static func info(k: String) -> Dictionary:
	return ALL.get(k, {})


static func title(k: String) -> String:
	return ALL[k].name if ALL.has(k) else k


## How much Charisma moves r's prices (a fraction: + is in their favour).
static func price_edge(r: Resident) -> float:
	return Abilities.price_edge(r.ability("cha")) if r else 0.0


## Price at the store, in silver (for r, if given: their Charisma counts).
static func buy_price(k: String, r: Resident = null) -> int:
	return maxi(1, roundi(int(ALL[k].value) * 10 * (1.0 - price_edge(r))))


## What Tilda gives r for one, in silver.
static func sell_price(k: String, r: Resident = null) -> int:
	return maxi(1, floori(int(ALL[k].value) * 5 * (1.0 + price_edge(r))))


## "3 gold 4 silver"
static func money(silver: int) -> String:
	var g := silver / 10
	var s := silver % 10
	if g and s:
		return "%d gold %d silver" % [g, s]
	return "%d gold" % g if g else "%d silver" % s


## A line about an item: what it does, or what it's worth.
static func describe(k: String) -> String:
	var it := info(k)
	match it.get("type", ""):
		"weapon":
			return "%d–%d damage, reach %.1f m" % [it.dmg.x, it.dmg.y, it.reach]
		"potion":
			if it.has("heal"):
				return "restores all health" if it.heal > 1000.0 else "restores %d health" % int(it.heal)
			if it.has("ab"):
				return "+%d %s for six hours" % [it.amt, Abilities.NAMES[it.ab]]
			return "+%d damage for four hours" % it.might
		"magic":
			if k == "ringprot":
				return "takes 2 off every blow"
			if k == "cloak":
				return "goblins see you only from half as far"
			return "worth %d gold (no use yet)" % it.value
	return "worth %d gold" % it.get("value", 0)


## Something found in a chest: a gem a quarter of the time, then a weapon, an odd or end, a
## potion, or now and then a bit of magic.
static func roll(rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	return of_type(rng, "gem" if r < 0.27 else "weapon" if r < 0.44 else "utility" if r < 0.64 else "potion" if r < 0.88 else "magic")


static func of_type(rng: RandomNumberGenerator, t: String) -> String:
	var keys := ALL.keys().filter(func(k: String) -> bool: return ALL[k].type == t)
	return keys[rng.randi() % keys.size()]


# ---- the store ----

static func _ensure_shop() -> void:
	if shop_coin < 0:
		shop_stock = SHOP_BASE.duplicate()
		shop_coin = SHOP_COIN


## Tilda's morning: anything sold out is back on the shelves.
static func restock() -> void:
	_ensure_shop()
	for k in SHOP_BASE:
		if shop_stock.get(k, 0) < SHOP_BASE[k]:
			shop_stock[k] = SHOP_BASE[k]


static func stock() -> Dictionary:
	_ensure_shop()
	return shop_stock


static func till() -> int:
	_ensure_shop()
	return shop_coin


## r buys one k from the store: false if it's sold out or they can't pay.
static func buy(r: Resident, k: String) -> bool:
	_ensure_shop()
	var p := buy_price(k, r)
	if shop_stock.get(k, 0) <= 0 or not r.pay(p):
		return false
	shop_stock[k] -= 1
	if shop_stock[k] <= 0:
		shop_stock.erase(k)
	shop_coin += p
	r.give(k)
	return true


## r sells one k to the store (one they aren't wearing or wielding): false if Tilda can't pay.
static func sell(r: Resident, k: String) -> bool:
	_ensure_shop()
	var p := sell_price(k, r)
	if r.spare(k) < 1 or shop_coin < p:
		return false
	r.take_item(k)
	shop_stock[k] = shop_stock.get(k, 0) + 1
	shop_coin -= p
	r.add_coin(p)
	return true
