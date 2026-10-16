class_name Abilities
extends RefCounted
## The six abilities (as in the HTML game), on the familiar 3–18 scale where 10 is an ordinary
## person. A resident's scores are in their NpcDef (set by their trade); the goblins have their
## own. Each score gives a modifier, (score − 10) ÷ 2 rounded down, and the modifier does this:
##
##   Strength      + modifier to every blow with a weapon swung by hand
##   Agility       + modifier to blows with fists and daggers; each point makes attacks 5% quicker
##                 (up to 40% quicker, or 30% slower) and gives a 4% chance to dodge a blow (up to 25%)
##   Constitution  + 8 health per point
##   Intelligence  + modifier to magic (the wizard's bolts of light)
##   Wisdom        sharper eyes and quicker mending: trouble is spotted 1 m further off per point,
##                 and health comes back 25% faster per point (never below a quarter of the usual)
##   Charisma      5% better prices at Tilda's per point, buying and selling (at most 25%)
##
## Tilda's ability potions add BOOST to one score for BOOST_FOR game seconds; another dose of the
## same potion starts the time again rather than adding to it.

const KEYS := ["str", "agi", "con", "int", "wis", "cha"]
const NAMES := {"str": "Strength", "agi": "Agility", "con": "Constitution", "int": "Intelligence", "wis": "Wisdom", "cha": "Charisma"}
const SHORT := {"str": "STR", "agi": "AGI", "con": "CON", "int": "INT", "wis": "WIS", "cha": "CHA"}
const HP_PER_CON := 8
const BOOST := 4
const BOOST_FOR := 30.0            # game seconds (six hours)

## The goblins' scores (as in the HTML game): quick and cowardly; their chief is tougher all round.
const GOBLIN := {"str": 8, "agi": 14, "con": 10, "int": 9, "wis": 8, "cha": 7}
const GOBLIN_CHIEF := {"str": 12, "agi": 14, "con": 13, "int": 11, "wis": 9, "cha": 12}

## Weapons that go by something other than Strength.
const AGILITY_WEAPONS := ["", "dagger"]          # "" is bare fists
const MAGIC_WEAPONS := ["wizstaff", "wand"]


static func mod(score: int) -> int:
	return floori((score - 10) / 2.0)


static func signed(v: int) -> String:
	return ("+%d" % v) if v >= 0 else str(v)


## Which ability adds to a weapon's damage (k: an item key, a tool of the trade, or "" for fists).
static func weapon_ability(k: String) -> String:
	if k in MAGIC_WEAPONS:
		return "int"
	if k in AGILITY_WEAPONS:
		return "agi"
	return "str"


## Seconds between blows are multiplied by this.
static func quickness(agi: int) -> float:
	return clampf(1.0 - 0.05 * mod(agi), 0.6, 1.3)


static func dodge(agi: int) -> float:
	return clampf(0.04 * mod(agi), 0.0, 0.25)


## Health comes back this many times as fast.
static func mending(wis: int) -> float:
	return maxf(0.25, 1.0 + 0.25 * mod(wis))


## How much better (positive) or worse (negative) Tilda's prices are, as a fraction.
static func price_edge(cha: int) -> float:
	return clampf(0.05 * mod(cha), -0.25, 0.25)


## "5 h", "40 min": how long game seconds last on the clock.
static func duration(secs: float) -> String:
	var mins := ceili(secs / (Game.DAY_SECONDS / 24.0) * 60.0)
	if mins >= 60:
		return "%d h" % ceili(mins / 60.0)
	return "%d min" % mins


## Tenths of an hour left on all r's boosts (changes as they tick down, for redrawing panels).
static func boost_minutes(r: Resident) -> int:
	var t := 0
	for k in r.boosts:
		t += ceili(r.boost_left(k) / (Game.DAY_SECONDS / 24.0) * 6.0)
	return t


## A line on what a score does for someone (for the character sheet).
static func effect(k: String, score: int) -> String:
	var m := mod(score)
	match k:
		"str":
			return "%s damage with weapons swung by hand" % signed(m)
		"agi":
			var q := roundi((1.0 - quickness(score)) * 100.0)
			return "%s with fists and daggers, attacks %d%% %s, %d%% dodge" % [signed(m), absi(q),
				"quicker" if q >= 0 else "slower", roundi(dodge(score) * 100.0)]
		"con":
			return "%s health" % signed(HP_PER_CON * m)
		"int":
			return "%s damage with magic" % signed(m)
		"wis":
			return "spots trouble %s m, mends %d%% as fast" % [signed(m), roundi(mending(score) * 100.0)]
		"cha":
			return "%d%% %s prices at the store" % [roundi(absf(price_edge(score)) * 100.0), "better" if m > 0 else "worse"] if m != 0 \
				else "no effect on prices"
	return ""
