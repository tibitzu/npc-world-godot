# npc-world (Godot)

The Godot 4 version of [npc-world](https://github.com/tibitzu/npc-world): a shared town whose residents live their own lives until a player takes one over. The HTML game stays as the reference while this version is built up milestone by milestone.

## Open it

1. Download the standard **Godot 4.7** editor (not the .NET version) from [godotengine.org](https://godotengine.org/download).
2. Clone this repo, open Godot, choose **Import**, and pick `project.godot`.
3. Press **F5** (or the play button) to run.

The project uses the Compatibility renderer, so the same build works on desktop and in a web browser.

## Where it's up to: milestone 1, ground and camera

- The whole map: 1000 × 1000 hex tiles, 727 m × 630 m, coloured tile by tile exactly as in the HTML game (moss greens, sandy roads).
- The town's roads: the ring round the square, the north–south road and the east–west road, running on across the map.
- The world wraps both ways: go far enough east and you come back from the west, with no seam anywhere.
- The sun, shadows, and the view fading into black with distance.
- Press **V** to switch between the smooth ground and the hex tiles.
- The tile under the cursor (column, row, kind and position) shows in the top left.

### Controls (free camera)

| Action | Control |
|---|---|
| Move | W A S D or the arrow keys |
| Turn | Q and E |
| Rotate the view | Left-drag |
| Pan | Right-drag, middle-drag or Shift + left-drag |
| Zoom | Scroll wheel (pinch on a trackpad) |
| Glide to a spot | Click the ground |
| Hex tiles on/off | V |

## How it's organised

```
autoload/   Game (seed, tile grid), Events (shared signals), Registry (content by id), Net (multiplayer, later)
data/       content definitions as .tres files: items, npcs, monsters, buildings, professions
scenes/     world, buildings, actors and UI scenes
scripts/    world (hex grid, ground, camera), components, brains and jobs, UI
shaders/    the ground shader that draws the wrapping map
tools/      editor and test helpers
```

- `scripts/world/hex.gd` holds the hex grid and wrap maths, ported from the HTML game: which tile a point is on, neighbours, and the shortest distance across the seams. Everything that measures distance goes through it.
- `scripts/world/tile_grid.gd` keeps each tile's flags, kind and colour in packed arrays, plus a texture the ground shader reads.
- The ground is one plane that follows the camera; its shader folds every point back onto the map, which is what makes the wrap seamless.

### Screenshots without the editor

`tools/screenshot.tscn` renders the world and saves a PNG:

```
godot --path . res://tools/screenshot.tscn -- out.png [frames] [yaw pitch dist x z] [hex]
```

## Next: milestone 2

One resident walking: click a spot and Mira walks there on a navigation mesh, then take control of her in first or third person, with Left Shift to run.
