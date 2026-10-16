# npc-world (Godot)

The Godot 4 version of [npc-world](https://github.com/tibitzu/npc-world): a shared town whose residents live their own lives until a player takes one over. The HTML game stays as the reference while this version is built up milestone by milestone.

## Open it

1. Download the standard **Godot 4.7** editor (not the .NET version) from [godotengine.org](https://godotengine.org/download).
2. Clone this repo, open Godot, choose **Import**, and pick `project.godot`.
3. Press **F5** (or the play button) to run. The game opens in a maximised window; **F11** switches to fullscreen and back.

The project uses the Compatibility renderer, so the same build works on desktop and in a web browser.

## Where it's up to: milestone 13, health and danger

**Milestone 1, the ground and camera**
- The whole map: 1000 × 1000 hex tiles, 727 m × 630 m, coloured tile by tile in the HTML game's moss greens.
- The town square: a 21 m square of grey cobblestones (three times the tavern's front) whose north edge runs along the tavern's front wall, centred on its door. (The HTML game's sandy roads and round square have been taken out.)
- The world wraps both ways: go far enough east and you come back from the west, with no seam anywhere.
- The sun, shadows, and the view fading into black with distance.
- Press **V** to switch between the smooth ground and the hex tiles. The tile under the cursor shows in the top left.

**Milestone 2, one resident**
- Mira the gardener, built like the HTML game's residents but 1.5 times the size (about 1.5 m tall, in proportion to the furniture), strolls around her spot by the square on her own, and heads back there if she ends up far away.
- Click her (or her card at the top right) to take control. The camera blends into her eyes; scroll out or press **T** for the view from behind and above her.
- Every walk to a destination follows a navigation mesh covering the whole map, so routes are exact (residents stop within a few centimetres of a tile's centre). Routes cross the wrap seam when that way is shorter.
- Press **P** to draw the route each resident is following.
- After 30 seconds without input, Mira goes back to her own business (a countdown shows for the last 10).

**Milestone 3, the tavern**
- The Hex & Lantern stands north of the square: 7 × 5.2 m, twice the HTML game's floor area. Downstairs are the bar, bottle shelves, barrels, fireplace and rug, plus two tables with chairs (one against the front wall); a stair up the east wall leads to an upper floor of six guest beds. A door in the west wall opens into a one-storey kitchen (4 × 4.4 m) with a hearth and hanging pot, a counter, a worktable with stools, a dresser of plates and jars, sacks and a barrel. The door is 2 m high and the beds 1.9 m long. Every walkway is wide enough for residents to pass easily (all seven of a test crowd reach a bed together in about 15 seconds).
- Its door opens for anyone who comes near and closes behind them.
- The tavern bakes its own navigation mesh from its walls, furniture, floors and stair when the game starts, and the open ground's mesh is carved away under it, so the two meet all round. Nothing is placed by hand: move a table in the editor and the routes go round it.
- Residents' feet follow whatever is under them (floor, step or upper floor), so they walk up and down the stair like any other route.
- Residents can walk in, up the stairs and lie down in a bed, and get up again (from milestone 5 they do this on their own at night).
- Playing a resident, click any floor inside to walk there, and press **F** at the foot of a bed to lie down (or get up). Walking gets you out of bed too.
- In third person inside, the roof fades away, and the upper floor too while you're downstairs, so you can see in. The same happens whenever the camera itself is inside the walls, such as just after you walk out of the door. Faded parts keep their shadows, so the room stays dim.

**Milestone 4, the clock**
- A day lasts 2 minutes, as in the HTML game, and the game begins at noon on Day 1.
- The sun crosses the map from east to west, so the time of day depends on where you are: when it's noon at the town square, it's midnight half the map away. The clock in the top left shows the local time where you're looking (or where the resident you're playing stands), the part of the day, and which day it is, with the HTML game's 24-hour dial.
- Day and night: the sunlight fades and warms at dawn and dusk and is gone at night, when the sky light drops to a third. The sun swings from east to west through the day, so shadows move. Lamps grow brighter after dark and windows glow; fires burn the same all day.
- Game speed: 1×, 2× or 5× from the bar at the top (or **[** and **]**). Everything runs faster, residents included; the camera and your turning keys keep their normal pace.

**Milestone 5, daily routines**
- Each resident has sleeping hours, as in the HTML game (Mira sleeps 21:00–05:00, by the local time where she is). At bedtime a resident nobody is playing says one of their goodnight lines, walks to the nearest free bed (for now, in the tavern: there are no homes yet), and lies down. At waking time they get up, say a morning line and go back to their day.
- If every bed is taken they keep going about their business and look again every couple of game seconds.
- Let go of a resident at night and they go back to bed; take over one who is asleep and you can walk them out of bed.
- Lines appear in a bubble above the speaker's name for a few seconds.
- Each card in the top right now shows what the resident is doing (Walking, Going to bed, Asleep, Played by you) and their sleeping hours.
- The **B** shortcut from milestone 3 is gone: the routines do its job.

**Milestone 6, homes and roads**
- Five more buildings from the HTML game, built larger so 1.5 m residents fit (2 m doors, 1.9 m beds, at least 0.6 m of floor wherever residents walk):
  - **Rosehip Cottage**, Mira's: whitewash and thatch, green door and shutters with flower boxes; her bed under a patchwork quilt, a table and chairs, a dresser, herbs drying from a beam. Its fenced garden is bigger than in the HTML game and freshly dug into furrows, with nothing planted yet.
  - **Bolt Post**, the post office, on the square's western edge between the west road and the corner, facing the square: blue boards, a flat roof with an aerial, a roller door; pigeonholes of parcels, a counter with a bell and scale, mail sacks, Bolt's cot under a map of the town. Its red pillar box is the letterbox.
  - **Timber Hollow**, Brann's log cabin, out to the north-west with its door facing Rosehip Cottage: stacked log walls, a shingle roof and a stone chimney; his bed, a table and bench, a chair on a bearskin rug, an axe rack; the woodpile's sleepers and a chopping block outside.
  - **The barracks**, halfway along the east road, facing it: grey stone with battlements, a flag and crimson banners; a bed each for Dax and Dex, a shield and spears, a table and stools, footlockers and a weapon rack; a training dummy outside.
  - **The Wick**, Old Fen's round stone lamp tower, across the square from the tavern and facing it: 7.2 m across, two storeys under a lantern room and a slate cone. Downstairs the lamplighter's workroom (a bench of lanterns being mended, an oil barrel, a crate of candles, a coat stand with a spare top hat, a rug) round a spiral stair that climbs a central post; a second door on the east side leads to a small kitchen (the oven, a worktable, a shelf of pots, a barrel). Upstairs Fen's bed, a desk under the front window, a bookshelf and a brass telescope. Its round walls, floors and stair are built from `RingPiece`s (`scripts/buildings/ring_piece.gd`): pieces of a ring between two radii and two angles, with colliders the navigation bake reads.
  - **The general store**, its front wall on the square's western edge, just north of the west road: two storeys of timber-framed plaster; the shop downstairs (counter, shelves of goods, barrels, a display table, tools) and a stair up to Tilda's rooms (bed, wardrobe, table, rug, chest).
- Every building except the post office has a wood-fired oven: a brick base with logs stored underneath and a clay dome with embers glowing in its mouth. The tavern's is in the kitchen corner.
- Cobbled roads lead out of the square: straight ones west (along the general store's south wall, ending just past Rosehip Cottage) and east (past the barracks), and a curving one north round the tavern. Where the north road's cobbles stop it's still being laid (stones thinning out onto a sand bed, a pallet of cobbles, a sand pile and shovel, a wheelbarrow, a string line), and a dirt track carries on past Timber Hollow's front door. Every building faces a road or the square, with a letterbox by the road (the tavern's is on the square).
- Beds belong to someone now: each home's bed is its owner's, and the tavern's are guest beds. At bedtime a resident goes to their own bed, or the nearest free guest bed if they haven't one. Mira lives by her cottage and sleeps there. Only Mira lives in town so far, so the other homes are empty.

**Milestone 7, the residents move in**
- Six more residents from the HTML game, each living in their own home with their own bed, sleeping hours and lines (`data/npcs/*.tres`):

  | Resident | Role | Home | Sleeps |
  |---|---|---|---|
  | Mira | Gardener | Rosehip Cottage | 21:00–05:00 |
  | Bolt | Courier (fast, roams 30 m round the post office) | Bolt Post | 23:00–06:00 |
  | Old Fen | Lamplighter (slow, sleeps by day) | The Wick, upstairs | 08:00–16:00 |
  | Brann | Lumberjack | Timber Hollow | 20:00–04:00 |
  | Dax | Guard, day watch | The barracks | 22:00–06:00 |
  | Dex | Guard, night watch | The barracks | 10:00–18:00 |
  | Tilda | Shopkeeper (stays close to the store) | The general store, upstairs | 22:00–07:00 |

- Each one strolls round their own front yard, goes home to their own bed at bedtime (saying goodnight) and gets up again in the morning. The twins split the day: Dex is asleep while Dax is up, and the other way round. Fen, the lamplighter, sleeps through the day in his tower and is out from late afternoon until morning.
- Their cards are all down the right-hand side, showing what each is doing and when they sleep; click one (or the resident) to take them over.

**Milestone 8, talking**
- Residents talk, as in the HTML game. Every so often, at the end of a stroll, one says one of their lines; their mouth moves while they speak, and longer lines stay up longer.
- When two residents nobody is playing come within sight of each other on the same floor (and neither is busy talking or heading to bed), one walks over while the other waits. They stop, face each other, and one greets the other by name ("Yo, Tilda!", "Good evening, Mira.") and the other replies. The same two won't stop again for half a minute or so. Greetings know the time of day where they are.
- Now and then a stroll takes a resident into the town square for a while instead (some more than others: Tilda and Fen live on it, Brann is a long walk away), so the square is where they run into each other.
- **Say something** as the resident you're playing: press **Enter**, type, and Enter again (Esc to cancel). It shows over their head, and everyone within earshot stops, turns and replies one after another; ask a question (with a ?) and they answer it instead. While you're typing, keys don't move anyone.
- **Town chatter**, bottom left: the last few things said near where you are (or where the camera is looking), in each speaker's colour, fading after a while.
- Each resident's greetings, replies and answers are in their `.tres` (`greet_lines`, `reply_lines`, `answer_lines`; `{n}` is the other's name, `{tod}` / `{Tod}` the time of day), along with how often they visit the square (`town_visits`). The meeting rules are in `scripts/world/conversations.gd`.

**Milestone 9, work**
- Residents with a trade do it in their working hours (local time), then have the rest of the day to themselves. The cards say what they're up to.

  | Who | Job | Hours |
  |---|---|---|
  | Tilda | Minds the general store: stands at the till behind the counter facing the door, potters along the shelves now and then, and welcomes whoever comes up to the counter. While she's there the shop is open, and the others sometimes drop in. | 08:00–19:00 |
  | Brann | Fells trees in the new pine woods behind Timber Hollow: chops (axe over his head) until it topples ("Timber!"), gathers the three logs it leaves, carries them home on his back and stacks them on his woodpile. The fire burns a log every few hours; when the pile's full he takes the day off. Felled trees leave a stump and grow back in a day and a half. | 05:00–18:00 |
  | Bolt | Rounds: collects the post from the pillar box outside Bolt Post, runs it (parcels in his arms) to two of the town's letterboxes, posts it, and comes back for more. | 07:00–17:00 |
  | Old Fen | Lights the four new street lamps by the tavern and the Wick, one by one with his lighting pole, from late afternoon. They burn all night and gutter out at dawn. | from 16:15 |
  | Dax and Dex | Patrol: from the barracks along the east road and round the square's corners and back, stopping to look about at each. Dax by day, Dex (the other way round) by night. | 07:00–20:00 / 19:00–09:00 |

- Everyone sets off home in time to be in bed by bedtime (the town is a long walk end to end in a two-minute day); the cards say "Heading home" on the way.
- Take over a resident at work and the job stops (whatever they were carrying is put away); let go and they pick it up again.
- Jobs live in `scripts/brains` (one script each, on a shared `Job` base); a resident's job and hours are in their `.tres` (`job`, `work_from`, `work_to`, `work_speed`). The woods are `scripts/world/forest.gd`, the street lamps `scripts/world/lamp_posts.gd`, and the woodpile `scripts/buildings/wood_pile.gd`.

**Milestone 10, doing the work yourself**
- Whoever you're playing can do the town's work with **F**. A hint above the bottom of the screen says what F will do where you stand:

  | Where | F |
  |---|---|
  | By a standing tree | Fell it: a few seconds' chopping (moving stops you), then "Timber!" and three logs on the ground |
  | By a loose log | Pick it up (three fit in a pack, on your back) |
  | Beside Brann's woodpile, carrying logs | Stack them |
  | By Bolt Post's pillar box | Collect the post (two parcels, in your arms) |
  | By a letterbox, carrying post | Post a parcel there |
  | At the general store's till | Mind the shop: while you stay at the till it's open, and customers drop in and ask for things (answer them with Enter) |
  | By a street lamp | Light it with a pole, or put it out (one lit by day burns until the next dawn) |
  | At the foot of a bed | Lie down, or get up (as before) |

- **Packs**: everyone carries their logs and parcels in a pack now (bottom right while you play: logs and parcels slots). What's in it stays when you let go or take someone over, and the residents' jobs use it too: Brann carries on stacking the logs you gathered, Bolt delivers the post you collected.
- The actions are in `scripts/player/work_actions.gd`.

**Milestone 11, looks**
- Everyone wears what they wore in the HTML game, so you can tell them apart at a glance:

  | Who | Hat | In hand | And |
  |---|---|---|---|
  | Mira | Straw hat with a red band | Trowel | Clogs |
  | Bolt | Blue courier's cap | (fists) | White running shoes |
  | Old Fen | Top hat | Lantern pole with a little lit lantern | Buckle shoes |
  | Brann | Red beanie with a bobble | Felling axe | Beard, work boots, canvas trousers |
  | Tilda | Ochre headscarf | Cudgel | Apron, buckle shoes |
  | Dax | Steel helmet, red plume | Spear | Gold tabard, leather bracers, boots |
  | Dex | Steel helmet, gold plume | Spear | Gold tabard, leather bracers, boots |

- The everyday tool goes away while they're using something else (the axe for chopping, the long pole for lighting a lamp), carrying parcels, or in bed.
- Outfits are in each resident's `.tres` (`hat`, `tool`, `trousers`, `shoes`, `extras`, `plume`); the shapes are in `scripts/actors/gear.gd`.

**Milestone 12, needs**
- Every resident has four needs, as in the HTML game, shown as bars along the bottom of their card (hover for the numbers): **fatigue** (lilac), **happiness** (gold), **hunger** (orange) and **thirst** (blue). Full is fine; a bar turns red when it's nearly empty.
  - Fatigue runs down while they're awake (faster at work) and a night's sleep restores it. Worn right out, they'll take a nap whatever the time.
  - Thirst and hunger run down through the day (slower asleep). When one gets low they go for a drink at the new **well** in the middle of the square (or a cup of water at home, if that's nearer), or a meal by their own oven or the tavern's; if it gets very low they leave work to do it. They say so ("My throat's dry as dust." / "That hit the spot.").
  - Happiness slips slowly and comes back with company (every chat cheers both up), food and drink. Glum residents go looking for company in the square more often.
- Playing someone, F at the well has a drink and F in front of an oven has a meal.
- Fixed on the way: street lamps (and trees) standing inside a building's walkable area were walked straight through; buildings now leave them out of their own navigation meshes (`blocker_rects()` on the Forest, LampPosts and Well).

**Milestone 13, health and danger**
- **Health**: every resident has health (Mira 90, Bolt 100, Fen 70, Brann 120, the twins 140, Tilda 80, as in the HTML game), the first bar on their card. It comes back slowly once they're out of danger and quickly in bed.
- **Weapons**: they fight with the tool of their trade: Mira's trowel, Fen's lantern pole, Brann's felling axe, the guards' spears (the longest reach), Tilda's cudgel, and Bolt's fists. Damage numbers pop up over whoever's hit.
- **Goblins**: a camp of five in the hills north-east of town (tents round a fire, at about x 46, z -30). Every few nights (the first on the second night) four of them march on the town at dusk, prowl it for anyone out of doors (a closed door keeps them out; those in bed are safe) and go home at dawn. A badly hurt goblin runs for it; the camp patches them up and makes its numbers up again each noon.
- **The guards** turn out for any raider within 30 m, even from their beds ("To arms! Goblins!"); anyone else hits back when attacked, and runs for home when badly hurt ("Help! Help!"). The cards say Fighting or Running for home, and the town chatter tells you when a raid starts and ends.
- **Fighting yourself**: while playing someone, **Space** strikes at the goblin in front of you.
- **Death**: at no health a resident dies. They lie where they fell, their card greys out, and they can't be played until a new game.
- Happiness now slips more slowly, and a good night's sleep lifts it a little.
- The goblins are `scripts/actors/monster.gd`, their camp and the raids `scripts/world/goblin_camp.gd`; residents' fighting is in `scripts/actors/resident.gd`, the weapons in `Gear.WEAPONS`.

**Milestone 14, the bell and the goblins' lair**
- **The alarm bell**: a bronze bell in a timber frame on the square, west of the well. When a raid comes, the guard on watch (whichever guard is on duty) spots it coming down the road, runs to the bell ("Raiders! To the bell!") and rings it. You can ring it too: F beside it.
- **The alarm**: while it's up (for as long as the raid lasts, or a couple of hours if it's rung with no raid on), everyone who isn't a guard hurries home and stays in ("The bell! Inside, quick!"), and both guards turn out for raiders anywhere in town, the one off duty getting out of bed for it. The cards say Running to ring the bell, Hurrying indoors and Sheltering indoors.
- **The goblins' lair, The Black Warrens**: a small stone gatehouse just north of the camp, with a stair down to a warren of rooms and winding tunnels 3 m underground (about 34 m across, built the way the HTML game builds its dungeons, from a fixed seed so it's the same every game). Torches on the walls, bones and rubble about, barrels and chests in the side rooms, and at the far end the chief's hall: pillars, braziers and an altar.
- **Down there**: twelve goblins walk the tunnels and go for anyone who comes down (they don't run, and don't follow you up the stair). Their **chief**, bigger, crowned, with a cleaver and buckler (90 health, hits hard), paces before his altar. Kill him and the raids stop for good: "With their chief dead, the goblins won't raid the town again."
- While you're playing someone underground, the grass over the lair is left out so the camera can see in, the torches light up, and clicks walk you about the lair's floor. From above, only the stairwell shows through the gatehouse arch.
- The bell is `scripts/world/bell.gd`, the lair `scripts/world/goblin_lair.gd` (its layout, its navigation mesh, and the goblins it starts with); the lair goblins and the chief are `Monster`s with `in_lair` / `chief` set.

**Milestone 15, treasure and trade**
- **Coins**: everyone has a purse (gold, and silver at 10 to the gold), starting with what they had in the HTML game: Mira 30 gold, Bolt 24, Fen 45, Brann 32, the guards 40 each, Tilda 80.
- **Chests**: the lair's chests (five of them, the richest in the chief's hall) hold gems, weapons, potions, odds and ends, a bit of magic, and coin. F beside one opens it and takes the lot; the town chatter says what was found.
- **Inventory (I)**: coins, what's in hand, what's worn, health, and everything carried. Click a thing to use it:

  | Kind | Using it |
  |---|---|
  | Weapon (steel dagger, short sword, flanged mace, war axe) | Wield it instead of the tool of their trade (it shows in their hand); click again to put it away |
  | Healing potion (minor, normal, greater, superior) | Restores 20, 40, 80 or all health |
  | Elixir of strength | +3 damage on every blow for four hours |
  | Ring of protection | Takes 2 off every blow that lands (a blow always does at least 1) |
  | Cloak of shadows | Goblins see you only from half as far |
  | Gems, odds and ends, the amulet, wand and scroll | For selling (no use yet) |

- **The general store**: F at Tilda's counter while she's at the till opens her shop: buy what's on her shelves at its value (healing potions, the elixir, weapons, rope, torches...), sell what you carry at half (what you're wearing or wielding stays on). She restocks every morning, and her till isn't bottomless.
- **The residents use it too**: one badly hurt in a fight drinks a healing potion if they have one, and residents who drop into the store now and then buy a minor healing potion, just in case.
- Items, prices and the store are `scripts/items/items.gd`; the inventory and shop panels `scripts/ui/inventory_panel.gd` and `scripts/ui/shop_panel.gd`; each resident's purse, bag and what they have on are in `scripts/actors/resident.gd` (`bag`, `equip`, `use_item`).

### Coordinates

A tooltip by the mouse cursor shows the ground under it: **x** (metres, + is east) and **z** (metres, + is south), measured from the middle of the map at the tavern's end of the square, and the tile and what it is. Those x and z are the numbers buildings are placed with (`position` in each `data/buildings/*.tres`).

### Controls (overview camera)

| Action | Control |
|---|---|
| Move | W A S D or the arrow keys |
| Turn | Q and E |
| Rotate the view | Left-drag |
| Pan | Right-drag, middle-drag or Shift + left-drag |
| Zoom | Scroll wheel (pinch on a trackpad) |
| Glide to a spot | Click the ground |
| Take control of a resident | Click them, or their card |
| Hex tiles on/off | V |
| Show routes | P |
| Game speed slower / faster | [ and ] |

### Controls (playing a resident)

| Action | Control |
|---|---|
| Walk forward / back | W and S, or Up and Down |
| Step aside | A and D |
| Run (1.5 times as fast) | Hold Left Shift |
| Turn | Q and E, Left and Right, or drag |
| Look up and down | Drag |
| Walk to a tile | Click it (the tile under the cursor is outlined) |
| Walk somewhere inside | Click the floor |
| Lie down / get up, or the work at hand (including ringing the alarm bell) | F (the hint on screen says what it'll do) |
| Say something | Enter, type, Enter (Esc cancels) |
| Strike (at a goblin in front) | Space |
| Inventory: coins, gear, things carried (click to use) | I |
| First / third person | Scroll, T, or the button |
| Let go | Esc, the Let go button, or click their card |

## How it's organised

```
autoload/   Game (seed, tile grid, clock and speed), Events (shared signals), Registry (content by id), Net (multiplayer, later)
data/       content definitions as .tres files: items, npcs (mira.tres), monsters, buildings (tavern.tres), professions
scenes/     world, buildings (tavern.tscn), actors (resident.tscn) and UI scenes
scripts/    world (hex grid, ground, navigation, camera), buildings, actors, player, defs, components, brains, UI
shaders/    the ground shader that draws the wrapping map, and the cobblestones
tools/      editor and test helpers
```

- `scripts/world/hex.gd` holds the hex grid and wrap maths, ported from the HTML game: which tile a point is on, neighbours, and the shortest distance across the seams. Everything that measures distance goes through it.
- `scripts/world/tile_grid.gd` keeps each tile's flags, kind and colour in packed arrays, plus a texture the ground shader reads.
- `autoload/game.gd` keeps the clock: game time, the speed, local time at any east–west position, the day number. `scripts/world/day_night.gd` sets the sun, sky light, lamps and windows from it each frame.
- `scripts/world/roads.gd` draws the roads: each is a smooth curve through a few points, listed in the Roads node in the world scene, so adding or bending a road is a matter of editing those points.
- `scripts/world/town_square.gd` lays the cobbled square (its size and centre are settings on the TownSquare node in the world scene); `shaders/cobbles.gdshader` draws the stones and the kerb round the edge.
- The ground is one plane that follows the camera; its shader folds every point back onto the map, which is what makes the wrap seamless.
- `scripts/world/world_nav.gd` covers the map with navigation mesh in a 12 × 10 grid of chunks. The chunks along each edge also get a copy just past the opposite edge, so routes run straight across the seam; a resident who steps over it is moved back by one world width. A building carves its area out, and only the chunks it touches are baked again (about a tenth of a second each).

### How a building is made

Every building follows the same pattern (the tavern, cottage, post office, cabin, barracks and store all do). Its `.tres` in `data/buildings` says which scene it is, where it stands and which way it faces; `scenes/buildings/tavern.tscn` is the building, edited like any scene, with `scripts/buildings/building.gd` on its root and these children:

| Node | What it holds |
|---|---|
| Ground | the ground storey's meshes, including the stair |
| Upper | everything from the first floor up, with its own `Solid` body |
| Roof | the roof (fades while you look in) |
| Solid | a StaticBody3D on the "world" layer: walls, furniture, floors and stair steps as collision shapes |
| Door | a `Door` hinge; its leaf and collider are on the "doors" layer, which residents bump into and the navigation bake ignores |
| Nav | an empty NavigationRegion3D, baked from the collision shapes at start-up |
| Upper/Beds | `Bed` nodes, each at the middle of a mattress with -Z toward the head; `owner_id` is the resident whose bed it is (empty for a guest bed) |
| Ground/Kitchen | a room built on beside the main block; its outer walls are listed in the root's `extra_parts`, so it counts as inside, gets its own tiles and is covered by the baked navigation |

A building with a garden or yard sets `nav_area` on its root to the whole area its navigation covers, so fences, letterboxes and the like are walked round. So the walkable area always comes from the collision shapes: give a new piece of furniture a shape under `Solid` and residents walk round it. Residents need a gap of 0.6 m (the navigation mesh keeps 0.3 m clear of everything) to pass between two things and 1.5 m of headroom, including where an upper floor overhangs a stair; stair steps can be up to 0.3 m high. To add a building, make a scene like this and a `.tres` for it in `data/buildings`.
- `scenes/actors/resident.tscn` is every resident's body, edited like any scene; `scripts/defs/npc_def.gd` is the data each one is made from. To add a resident, add a new `.tres` to `data/npcs`; its sleep and wake hours and its goodnight and morning lines are set there too.
- `scripts/player/player_controller.gd` is the local player: who they control and the keys that drive them. `scripts/world/camera_rig.gd` handles the camera and every mouse action on the world.

### Screenshots without the editor

`tools/screenshot.tscn` renders the world and saves a PNG:

```
godot --path . res://tools/screenshot.tscn -- out.png [frames] [yaw pitch dist x z] [hex] [hour=H]
```

## Next: milestone 16

The wizard, as in the HTML game: Orrin lives alone in a stone tower out in the woods. He can't be played until someone has found him and said hello; after that he's a resident like the rest, with a staff that throws bolts of light.
