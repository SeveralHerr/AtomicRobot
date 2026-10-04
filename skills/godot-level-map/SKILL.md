---
name: godot-level-map
description: Turn a player's phone screenshot ("put X here", circled spot) into Atomic Robot world coordinates — pan the bot along the street into a labelled contact sheet, match the buildings, then read exact node positions. Use when the user sends screenshots to say WHERE to place a pickup/prop/enemy or where a bug happened.
---
# Screenshot → world coordinates

1. `python tools/level_pan.py [--from X --to X --step 450]` (MCP `level_pan`) → one JPEG,
   one bot snap per world x, x printed top-left. Match the user's screenshot by building
   facade / sign / tree pattern. Camera trails the bot: a tile labelled x shows ~x-250..x+250.
2. Dump positions in that range: a throwaway SceneTree script that instantiates
   `res://scenes/main.tscn`, awaits one frame, walks nodes and prints
   `get_path() | scene_file_path | script | global_position` filtered by kind
   (crack, tree, scaffold, platform, pickup, car, building). Group scenes are offset
   (e.g. AtomicBuildingGroup at (-258,-97)): convert world → local before editing a sub-scene.
3. Rooftop / ledge spots: the bot teleports on the ground, so the roof is only in view if it
   is low. Platforms columns (`Platforms/Platform*`) give the reachable heights.
4. Write the coords + matched tile into each fan-out prompt; agents must not re-derive them.

2026-10-04 map (main.tscn): AR Tattoo roof scaffold (-210,-241); stone WindowEventBuilding
(594,-305), its platform column x=343 y -212..-532; twin plank scaffolds (1098,-49) and
(1183,-49) between trees 1044/1245; door-encounter cracks x 389, 2361, 4721, 5492, 6080,
6949, 7775; intersections x 1587-2027 and 4018-4458.
