# npc-world (Godot)

The Godot 4 version of [npc-world](https://github.com/tibitzu/npc-world): a shared town whose residents live their own lives until a player takes one over. The HTML game stays as the reference while this version is built up milestone by milestone.

## Open it

1. Download the standard **Godot 4.7** editor (not the .NET version) from [godotengine.org](https://godotengine.org/download).
2. Clone this repo, open Godot, choose **Import**, and pick `project.godot`.
3. Press **F5** (or the play button) to run.

The project uses the Compatibility renderer, so the same build works on desktop and in a web browser.

## Where it's up to: milestone 2, a resident you can play

**Milestone 1, the ground and camera**
- The whole map: 1000 × 1000 hex tiles, 727 m × 630 m, coloured tile by tile exactly as in the HTML game (moss greens, sandy roads).
- The town's roads: the ring round the square, the north–south road and the east–west road, running on across the map.
- The world wraps both ways: go far enough east and you come back from the west, with no seam anywhere.
- The sun, shadows, and the view fading into black with distance.
- Press **V** to switch between the smooth ground and the hex tiles. The tile under the cursor shows in the top left.

**Milestone 2, one resident**
- Mira the gardener, built like the HTML game's residents, strolls around her spot by the square on her own, and heads back there if she ends up far away.
- Click her (or her card at the top right) to take control. The camera blends into her eyes; scroll out or press **T** for the view from behind and above her.
- Every walk to a destination follows a navigation mesh covering the whole map, so routes are exact (residents stop within a few centimetres of a tile's centre). Routes cross the wrap seam when that way is shorter.
- Press **P** to draw the route each resident is following.
- After 30 seconds without input, Mira goes back to her own business (a countdown shows for the last 10).

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

### Controls (playing a resident)

| Action | Control |
|---|---|
| Walk forward / back | W and S, or Up and Down |
| Step aside | A and D |
| Run (1.5 times as fast) | Hold Left Shift |
| Turn | Q and E, Left and Right, or drag |
| Look up and down | Drag |
| Walk to a tile | Click it (the tile under the cursor is outlined) |
| First / third person | Scroll, T, or the button |
| Let go | Esc, the Let go button, or click their card |

## How it's organised

```
autoload/   Game (seed, tile grid), Events (shared signals), Registry (content by id), Net (multiplayer, later)
data/       content definitions as .tres files: items, npcs (mira.tres), monsters, buildings, professions
scenes/     world, buildings, actors (resident.tscn) and UI scenes
scripts/    world (hex grid, ground, navigation, camera), actors, player, defs, components, brains, UI
shaders/    the ground shader that draws the wrapping map
tools/      editor and test helpers
```

- `scripts/world/hex.gd` holds the hex grid and wrap maths, ported from the HTML game: which tile a point is on, neighbours, and the shortest distance across the seams. Everything that measures distance goes through it.
- `scripts/world/tile_grid.gd` keeps each tile's flags, kind and colour in packed arrays, plus a texture the ground shader reads.
- The ground is one plane that follows the camera; its shader folds every point back onto the map, which is what makes the wrap seamless.
- `scripts/world/world_nav.gd` covers the map with navigation mesh in a 12 × 10 grid of chunks. The chunks along each edge also get a copy just past the opposite edge, so routes run straight across the seam; a resident who steps over it is moved back by one world width.
- `scenes/actors/resident.tscn` is every resident's body, edited like any scene; `scripts/defs/npc_def.gd` is the data each one is made from. To add a resident, add a new `.tres` to `data/npcs`.
- `scripts/player/player_controller.gd` is the local player: who they control and the keys that drive them. `scripts/world/camera_rig.gd` handles the camera and every mouse action on the world.

### Screenshots without the editor

`tools/screenshot.tscn` renders the world and saves a PNG:

```
godot --path . res://tools/screenshot.tscn -- out.png [frames] [yaw pitch dist x z] [hex]
```

## Next: milestone 3

A building you can go into: the tavern as a scene with its door, beds, stairs and its own navigation mesh. A resident walks in through the door, up the stairs and lies on a bed, with no hand-placed waypoints. It becomes the pattern every other building follows.
