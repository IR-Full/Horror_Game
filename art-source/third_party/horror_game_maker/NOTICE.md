# Horror Game Maker creature

Author: City Building Game Art / HorrorGameMaker.com.
Source: https://opengameart.org/content/3d-horror-game-monster
Download: https://opengameart.org/sites/default/files/Poses.zip
License: CC0 1.0, https://creativecommons.org/publicdomain/zero/1.0/.
Original readme and unmodified FBX/textures retained. File hashes: provenance.json.

Adapted in Blender by tools/adapt_horror_maker.py: proportion changes, upright repose, mapping original skin weights to the 15-bone gameplay rig, new eleven animations, 2048px albedo and 1024px normal for runtime. The game uses ready GLB; FBX and source textures are not imported or exported by Godot.

Previous Bento entity: art-source/legacy/entity_bento_v06.glb and station_assets_bento_v06.blend. Earlier procedural entity remains next to them. To restore a previous model, copy its GLB to assets/models/entity.glb and reimport in Godot. The eleven gameplay clips remain compatible. For Blender rebuilding, -- --bento-creature selects Bento, -- --procedural-creature selects the procedural version; default selects HorrorGameMaker.
