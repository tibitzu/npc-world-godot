class_name NpcDef
extends Resource
## One resident: who they are and how they behave when nobody is playing them.
## Make a new resident by adding a .tres of this type to res://data/npcs.

@export var id := ""
@export var display_name := ""
@export var role := ""
@export var colour := Color.WHITE
## Where they stand when a new game starts, and the spot they stroll around: their home's front
## yard (world x, z in metres).
@export var start := Vector2.ZERO
## Walking speed when they move on their own (m/s). Played residents walk at 2.3 m/s.
@export var speed := 1.0
## How far one stroll takes them (m).
@export var wander_range := 5.0
## How far from their start they will wander (m).
@export var home_radius := 10.0
## The chance that a stroll, instead, takes them into the town square for a while (where they
## meet the others), before they head home again.
@export_range(0.0, 1.0, 0.01) var town_visits := 0.2
@export var lines: PackedStringArray = []

## Daily routine (local time where their bed is, in hours 0-24). They go to bed at sleep_hour
## and get up at wake_hour; a sleep that runs past midnight is fine (21 to 5).
@export_range(0.0, 24.0, 0.25) var sleep_hour := 22.0
@export_range(0.0, 24.0, 0.25) var wake_hour := 6.0
## One of these is said on the way to bed, and one on getting up.
@export var bed_lines: PackedStringArray = []
@export var wake_lines: PackedStringArray = []

## Meeting someone: one of greet_lines to open ({n} is the other's name), and when greeted (or
## spoken to by a player) one of reply_lines; a question from a player gets one of answer_lines.
@export var greet_lines: PackedStringArray = []
@export var reply_lines: PackedStringArray = []
@export var answer_lines: PackedStringArray = []

## Their day job (see scripts/brains): "shop", "woodcutter", "post", "lamplighter", "patrol", or
## none. They work between work_from and work_to (local hours; a shift may run past midnight),
## walking at work_speed while they do (0: their usual speed).
@export var job := ""
@export_range(0.0, 24.0, 0.25) var work_from := 8.0
@export_range(0.0, 24.0, 0.25) var work_to := 18.0
@export var work_speed := 0.0

## What they wear and carry (see Gear): a hat ("strawhat", "couriercap", "tophat", "beanie",
## "headscarf", "guardhelm"), the tool in their hand ("trowel", "lanternpole", "fellingaxe",
## "guardspear", "cudgel"), trouser colour (0xRRGGBB, 0: the default), shoes ("clogs",
## "runshoes", "buckleshoes", "workboots", "guardboots"), extras ("beard", "apron", "tabard",
## "bracers") and a helmet's plume colour.
@export var hat := ""
@export var tool := ""
@export var trousers := 0
@export var shoes := ""
@export var extras: PackedStringArray = []
@export var plume := Color(0.79, 0.19, 0.17)

## Health when unhurt (as in the HTML game), before Constitution adds to it.
@export var hp_max := 100.0

@export_group("Abilities")
## Their trade, as the character sheet names it (the scores below come from it in the HTML game).
@export var profession := ""
## The six abilities, 3–18 (10 is an ordinary person); see Abilities for what each does.
@export_range(3, 18) var strength := 10
@export_range(3, 18) var agility := 10
@export_range(3, 18) var constitution := 10
@export_range(3, 18) var intelligence := 10
@export_range(3, 18) var wisdom := 10
@export_range(3, 18) var charisma := 10
@export_group("")


## Their own scores, by Abilities key ("str", "agi", ...).
func abilities() -> Dictionary:
	return {"str": strength, "agi": agility, "con": constitution, "int": intelligence, "wis": wisdom, "cha": charisma}
## Gold coins they start with (as in the HTML game).
@export var gold := 0
## Unknown to the town until someone finds them and talks to them (the wizard): until then they
## can't be played and have no card on the roster.
@export var hidden := false
