# npc-world (Godot)

The Godot 4 version of [npc-world](https://github.com/tibitzu/npc-world): a shared town whose residents live their own lives until a player takes one over. The HTML game stays as the reference while this version is built up milestone by milestone.

## Open it

1. Download the standard **Godot 4.7** editor (not the .NET version) from [godotengine.org](https://godotengine.org/download).
2. Clone this repo, open Godot, choose **Import**, and pick `project.godot`.
3. Press **F5** (or the play button) to run. The game opens in a maximised window; **F11** switches to fullscreen and back.

The project uses the Compatibility renderer, so the same build works on desktop and in a web browser.

## Where it's up to: milestone 3, a building you can go into

**Milestone 1, the ground and camera**
- The whole map: 1000 × 1000 hex tiles, 727 m × 630 m, coloured tile by tile exactly as in the HTML game (moss greens, sandy roads).
- The town's roads: the ring round the square, the north–south road and the east–west road, running on across the map.
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
- The Hex & Lantern stands north of the square: 7 × 5.2 m, twice the HTML game's floor area. Downstairs are the bar, bottle shelves, barrels, fireplace and rug, plus two tables with chairs; a stair up the east wall leads to an upper floor of six guest beds. The door is 2 m high and the beds 1.9 m long. Every walkway is wide enough for residents to pass easily (all seven of a test crowd reach a bed together in about 15 seconds).
- Its door opens for anyone who comes near and closes behind them.
- The tavern bakes its own navigation mesh from its walls, furniture, floors and stair when the game starts, and the open ground's mesh is carved away under it, so the two meet all round. Nothing is placed by hand: move a table in the editor and the routes go round it.
- Residents' feet follow whatever is under them (floor, step or upper floor), so they walk up and down the stair like any other route.
- Press **B** and every resident nobody is playing walks in, up the stairs and lies down in the nearest free bed (as long as beds are free); press **B** again and they all get up and go back out.
- Playing a resident, click any floor inside to walk there, and press **F** at the foot of a bed to lie down (or get up). Walking gets you out of bed too.
- In third person inside, the roof fades away, and the upper floor too while you're downstairs, so you can see in. The same happens whenever the camera itself is inside the walls, such as just after you walk out of the door. Faded parts keep their shadows, so the room stays dim.

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
| Everyone else to bed / up again | B |

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
| Lie down / get up | F at the foot of a bed |
| First / third person | Scroll, T, or the button |
| Let go | Esc, the Let go button, or click their card |

## How it's organised

```
autoload/   Game (seed, tile grid), Events (shared signals), Registry (content by id), Net (multiplayer, later)
data/       content definitions as .tres files: items, npcs (mira.tres), monsters, buildings (tavern.tres), professions
scenes/     world, buildings (tavern.tscn), actors (resident.tscn) and UI scenes
scripts/    world (hex grid, ground, navigation, camera), buildings, actors, player, defs, components, brains, UI
shaders/    the ground shader that draws the wrapping map
tools/      editor and test helpers
```

- `scripts/world/hex.gd` holds the hex grid and wrap maths, ported from the HTML game: which tile a point is on, neighbours, and the shortest distance across the seams. Everything that measures distance goes through it.
- `scripts/world/tile_grid.gd` keeps each tile's flags, kind and colour in packed arrays, plus a texture the ground shader reads.
- The ground is one plane that follows the camera; its shader folds every point back onto the map, which is what makes the wrap seamless.
- `scripts/world/world_nav.gd` covers the map with navigation mesh in a 12 × 10 grid of chunks. The chunks along each edge also get a copy just past the opposite edge, so routes run straight across the seam; a resident who steps over it is moved back by one world width. A building carves its area out, and only the chunks it touches are baked again (about a tenth of a second each).

### How a building is made

Every building follows the tavern's pattern. `data/buildings/tavern.tres` says which scene it is and where it stands; `scenes/buildings/tavern.tscn` is the building, edited like any scene, with `scripts/buildings/building.gd` on its root and these children:

| Node | What it holds |
|---|---|
| Ground | the ground storey's meshes, including the stair |
| Upper | everything from the first floor up, with its own `Solid` body |
| Roof | the roof (fades while you look in) |
| Solid | a StaticBody3D on the "world" layer: walls, furniture, floors and stair steps as collision shapes |
| Door | a `Door` hinge; its leaf and collider are on the "doors" layer, which residents bump into and the navigation bake ignores |
| Nav | an empty NavigationRegion3D, baked from the collision shapes at start-up |
| Upper/Beds | `Bed` nodes, each at the middle of a mattress with -Z toward the head |

So the walkable area always comes from the collision shapes: give a new piece of furniture a shape under `Solid` and residents walk round it. Residents need a gap of 0.6 m (the navigation mesh keeps 0.3 m clear of everything) to pass between two things and 1.5 m of headroom, including where an upper floor overhangs a stair; stair steps can be up to 0.3 m high. To add a building, make a scene like this and a `.tres` for it in `data/buildings`.
- `scenes/actors/resident.tscn` is every resident's body, edited like any scene; `scripts/defs/npc_def.gd` is the data each one is made from. To add a resident, add a new `.tres` to `data/npcs`.
- `scripts/player/player_controller.gd` is the local player: who they control and the keys that drive them. `scripts/world/camera_rig.gd` handles the camera and every mouse action on the world.

### Screenshots without the editor

`tools/screenshot.tscn` renders the world and saves a PNG:

```
godot --path . res://tools/screenshot.tscn -- out.png [frames] [yaw pitch dist x z] [hex]
```

## Next: milestone 4

The clock: the time of day, a day counter and game speed.
