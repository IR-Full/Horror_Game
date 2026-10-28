# Smily horror monster

By Bento (@gostbento), licensed CC Attribution 4.0 International.

- Original: https://sketchfab.com/3d-models/smily-horror-monster-3d3fc31eddaa409a8f2df564823154e1
- Author: https://sketchfab.com/gostbento
- License: https://creativecommons.org/licenses/by/4.0/
- Downloaded GLB: https://models.codelove.in/library/ghosts/smiley-horror-monster.glb
- Original-author API: https://api.sketchfab.com/v3/models/3d3fc31eddaa409a8f2df564823154e1
- Retrieved 2026-10-28; API metadata preserved in sketchfab-metadata.json.
- Untouched source.glb SHA-256: 5a2478566b1ddf1fadecc2c3f9e01a3421b7cf682fdbdfc67430b7f36c565ad6

Changes in tools/adapt_monster.py: upright repose, scale and head proportions, mapping original skin weights to our 15-bone rig. Original UV/material textures retained. Eleven gameplay animations are authored by this project. Mirror animation packs are not used.

## Previous creature

The previous procedural model is preserved at art-source/legacy/entity_procedural_v05.glb and its Blender library at art-source/legacy/station_assets_procedural_v05.blend. Close Godot before replacing models. To restore it immediately, copy the legacy GLB to assets/models/entity.glb and reimport in Godot; all eleven clip names remain compatible. To rebuild the old version, run Blender tools/build_art.py with -- --procedural-creature. To restore the downloaded version, run the builder normally. No runtime download occurs.
